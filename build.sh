#!/usr/bin/env bash
# build.sh — decode, patch, rebuild and sign FitNotes for a 9:10 square window.
# Written to fail loudly: every step verifies its own output before continuing.
#
# Usage:   bash build.sh "/path/to/FitNotes - Gym Workout Log_25.1_APKPure.apk"
#          MODS="youtube" bash build.sh ...        # stock + Search YouTube only
#          MODS="communicator" bash build.sh ...   # layout mods only, no YouTube
# Result:  dist/fitnotes-modded-aligned-signed.apk   (installable)
#
# Data-losing steps (uninstall/reinstall) are NOT run by this script — see
# AGENTS.md "Install & data safety" before touching the device.
set -euo pipefail
cd "$(dirname "$0")"

# ---- pinned toolchain (verified: apktool 3.0.3 + uber-apk-signer 1.3.0) ----
APKTOOL_URL="https://github.com/iBotPeaches/Apktool/releases/download/v3.0.3/apktool_3.0.3.jar"
APKTOOL_SHA256="dbf930b076c6b9be08d57c449cacefc3bdd6b71ebd59b3066fc0e1f5b14f9423"
SIGNER_URL="https://github.com/patrickfav/uber-apk-signer/releases/download/v1.3.0/uber-apk-signer-1.3.0.jar"
SIGNER_SHA256="e1299fd6fcf4da527dd53735b56127e8ea922a321128123b9c32d619bba1d835"
DECODE_DIR="build/fitnotes-25.1-src"          # patch paths assume exactly this depth
APKSIGNER_SCHEME_LINE="signature verified"    # expected verifier output substring

fail() { echo "BUILD FAILED: $*" >&2; exit 1; }
step() { printf '\n== %s ==\n' "$*"; }

APK="${1:-}"
[ -f "$APK" ] || fail "usage: bash build.sh /path/to/FitNotes-25.1.apk  (got: '$APK')"

# ---- step 0: prerequisites -------------------------------------------------
step "0. prerequisites"
command -v java    >/dev/null || fail "java not found — install a JDK 8+ (keytool must come with it)"
command -v keytool >/dev/null || fail "keytool not found (ships with the JDK)"
command -v patch   >/dev/null || fail "patch not found (usually just: dnf/apt install patch)"
command -v curl    >/dev/null || fail "curl not found"
java -version 2>&1 | head -2

# ---- step 1: tools ---------------------------------------------------------
step "1. pinned jars (download once, checksum-verify every time)"
mkdir -p tools dist keystore
fetch_verify() {  # $1=url $2=sha256 $3=dest
  local f="$3" src="$1" sum="$2"
  if [ ! -f "$f" ]; then echo "downloading: $src"; curl -sL -o "$f" "$src"; fi
  echo "$sum  $f" | sha256sum -c - || { rm -f "$f"; fail "checksum mismatch for $f (delete it and re-run)"; }
}
fetch_verify "$APKTOOL_URL" "$APKTOOL_SHA256" tools/apktool.jar
fetch_verify "$SIGNER_URL"  "$SIGNER_SHA256"  tools/uber-apk-signer.jar

# ---- step 2: source APK identity -------------------------------------------
step "2. source APK identity"
echo "given: $APK"
ACTUAL_SHA=$(sha256sum "$APK" | cut -d' ' -f1)
EXPECTED_SHA=$(grep '^SOURCE_APK_SHA256=' manifest.txt | cut -d= -f2)
if [ "$ACTUAL_SHA" = "$EXPECTED_SHA" ]; then
  echo "sha256 match: $ACTUAL_SHA"
else
  fail "source APK sha256 differs:
     got:      $ACTUAL_SHA
     expected: $EXPECTED_SHA
  This mod is tuned for ONE exact build (25.1 / versionCode 64). A different
  build will have different resource ids and the patch may misapply. STOP and
  obtain the exact APK listed in manifest.txt."
fi

# ---- step 3: decode ---------------------------------------------------------
step "3. decode"
apktool() { java -jar tools/apktool.jar "$@"; }
apktool d -f -o "$DECODE_DIR" "$APK"
grep -F "$(grep '^DECODE_ANCHOR=' manifest.txt | cut -d= -f2-)" "$DECODE_DIR/res/values/public.xml" \
  || fail "decode sanity check failed: manifest DECODE_ANCHOR not found in public.xml
           (wrong APK? resource obfuscation not restored? wrong apktool version?)"
echo "decode sanity check OK (public.xml has clean layout names)"

# ---- step 4: patch (mod-group selection) ------------------------------------
step "4. apply mod patch series"
shopt -s nullglob
ALL_PATCHES=(patches/0*.patch)   # NNN-<edit-id>.patch, zero-padded → glob IS edit order
shopt -u nullglob
[ ${#ALL_PATCHES[@]} -gt 0 ] || fail "patches/0*.patch missing — the mod is not attached
  (regenerate patches with the repo's make-deliverable.sh)"

id_of() { basename "$1" | cut -d- -f1; }

# ---- mod groups -------------------------------------------------------------
# Patches that chain together (later hunks authored against the earlier ones'
# output) are ONE selectable unit — they are never individually selectable:
#   communicator = 001–006  E1–E5 + stepper-glyph: the compact Track screen +
#                           restyle; entangled hunks in the same layout files
#                           (E5's divider/button hunks assume E3/E4's edits)
#   youtube      = 007      E12 overflow "Search YouTube"; independent of the
#                           layout chain (touch-only disjoint files); verified
#                           standalone 30 Oct 2026.
# Every selectable SET below was proven by a scratch build before being baked
# in. New edits: join a group if their hunks depend on its output, else add a
# new group — then scratch-verify before shipping.
# Selectable sets: "" / "all" / any subset of ${MOD_GROUPS[*]}.
GROUP_PATCHES_communicator="001 002 003 004 005 006"
GROUP_PATCHES_youtube="007"
MOD_GROUPS=(communicator youtube)

SELECTED=()
KIND="all groups (default)"
if [ "${MODS:-}" = "" ] || [ "${MODS:-}" = "all" ]; then
  SELECTED=("${ALL_PATCHES[@]}")
else
  declare -A WANTID=() GOTTEN=()
  KIND_SEL=""
  for tok in ${MODS//,/ }; do
    known=0
    for g in "${MOD_GROUPS[@]}"; do
      if [ "$tok" = "$g" ]; then known=1; fi
    done
    if [ $known -eq 0 ]; then
      fail "MODS token '$tok' is not a known mod group (valid: ${MOD_GROUPS[*]})"
    fi
    if [ -n "${GOTTEN[$tok]:-}" ]; then continue; fi
    GOTTEN["$tok"]=1
    if [ -n "$KIND_SEL" ]; then KIND_SEL="$KIND_SEL + $tok"; else KIND_SEL="$tok"; fi
    ids_var="GROUP_PATCHES_$tok"
    for id in ${!ids_var}; do WANTID["$id"]=1; done
  done
  for f in "${ALL_PATCHES[@]}"; do
    id=$(id_of "$f")
    if [ -n "${WANTID[$id]:-}" ]; then SELECTED+=("$f"); unset "WANTID[$id]"; fi
  done
  if [ ${#SELECTED[@]} -eq 0 ] || [ ${#WANTID[@]} -ne 0 ]; then
    fail "MODS='$MODS' does not map fully onto patches/ — check the group table"
  fi
  KIND="groups: $KIND_SEL"
fi
echo "mods: $KIND (patches: ${#SELECTED[@]}/${#ALL_PATCHES[@]})"

SUM_BEFORE=$(cd "$DECODE_DIR" && find res -type f -exec sha256sum {} + | sha256sum | cut -d' ' -f1)
for PATCH_FILE in "${SELECTED[@]}"; do
  [ -s "$PATCH_FILE" ] || fail "$PATCH_FILE is empty — regenerate the series
    with the repo's make-deliverable.sh"
  echo "applying: $PATCH_FILE"
  patch -p1 -i "$PATCH_FILE" || fail "patch rejected ($PATCH_FILE). The decoded tree did not match
  the patch context (wrong APK build, or a different apktool produced the
  decode). Do NOT retry with fuzz; report the reject list above.
  NOTE: series apply strictly in order — partial failures mean the base tree
  is mismatched, not the individual edit."
done
SUM_AFTER=$(cd "$DECODE_DIR" && find res -type f -exec sha256sum {} + | sha256sum | cut -d' ' -f1)
[ "$SUM_BEFORE" != "$SUM_AFTER" ] || fail "patches applied cleanly but changed
  nothing under res/ — an empty or vestigial series. This silent no-op build is
  exactly what we must never ship. Report to the patch author."

# ---- step 5: rebuild --------------------------------------------------------
step "5. rebuild (tested at ~5s)"
apktool b "$DECODE_DIR" -o dist/fitnotes-modded.apk
[ -s dist/fitnotes-modded.apk ] || fail "rebuilt APK missing or empty"

# ---- step 6: keystore -------------------------------------------------------
step "6. keystore"
KS=keystore/fitnotes.keystore
if [ ! -f "$KS" ]; then
  PW=$(openssl rand -base64 18 2>/dev/null || head -c 24 /dev/urandom | base64)
  keytool -genkeypair -keystore "$KS" -alias fitnotes -keyalg RSA -keysize 2048 \
    -validity 10000 -storetype PKCS12 -storepass "$PW" \
    -dname "CN=FitNotes Communicator Mod, OU=personal, O=local"
  printf 'KEYSTORE_PASSWORD=%s' "$PW" > keystore/credentials.txt
  chmod 600 "$KS" keystore/credentials.txt
  echo "NEW KEYSTORE GENERATED."
  cat <<'EOF'
  >>> BACK UP keystore/ NOW (offline copy of BOTH files). <<<
  The keystore is the identity of every future install: lose it and the next
  patched APK can't install over this one without wiping your data again.
EOF
else
  PW=$(grep KEYSTORE_PASSWORD keystore/credentials.txt | cut -d= -f2) \
    || fail "keystore exists but keystore/credentials.txt doesn't — provide the password manually"
  [ -n "$PW" ] || fail "empty KEYSTORE_PASSWORD in keystore/credentials.txt"
fi

# ---- step 7: sign -----------------------------------------------------------
step "7. zipalign + sign (v1/v2/v3)"
java -jar tools/uber-apk-signer.jar -a dist/fitnotes-modded.apk \
  --ks "$KS" --ksAlias fitnotes --ksPass "$PW" --ksKeyPass "$PW" -o dist \
  | tee /tmp/uas.log | grep -iE 'success|verif'
grep -qi "$APKSIGNER_SCHEME_LINE" /tmp/uas.log \
  || fail "signer did not report signature verification — inspect /tmp/uas.log"
rm -f /tmp/uas.log

# ---- step 8: done -----------------------------------------------------------
step "8. done"
echo "Installable APK: $(pwd)/dist/fitnotes-modded-aligned-signed.apk"
echo
echo "NEXT (per AGENTS.md — involves DATA LOSS on the device):"
echo "  1. user makes fresh in-app export (.fitnotes) and copies it OFF-DEVICE"
echo "  2. uninstall existing FitNotes   (wipes its local DB!)"
echo "  3. install dist/fitnotes-modded-aligned-signed.apk (Play Protect prompt is expected)"
echo "  4. Settings -> Backup & Restore -> Restore  with the export from step 1"