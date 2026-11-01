# AGENTS.md — installing the FitNotes Communicator mod

**Audience: an AI coding agent executing this for a user on their machine.**
Human quick-start is in `README.md`; this file is the full, verbatim-tested
procedure. Run every command from this directory, one step at a time, verifying
each step before moving on.

## What you are doing

You are rebuilding the user's own copy of FitNotes (the same APK file they
already have) with layout resources tuned for a near-square 9:10 screen, then
signing it with a local keystore. You are NOT downloading FitNotes, NOT
redistributing the app, and NOT touching our signature — the patch carries only
text diffs applied to a tree the user's APK decodes to.

## Hard rules (STOP conditions)

1. **Pins are pins.** If the source APK sha256 does not match `manifest.txt`,
   stop and tell the user — never proceed on a different FitNotes build.
2. **Do not use `--fuzz`**, `--force`, or retry loops on the patch step. A
   rejected patch means a mismatched base; report it.
3. **Never run uninstall/reinstall or adb commands on the user's device
   without explicit user confirmation** — see the data-safety gate below.
4. If any step's expected output (printed after each command here) does not
   appear, stop and interpret per the troubleshooting table before retrying.
5. **Mods are the user's choice.** Before building, ask which mods they want
   (step 1). Never choose for them, and never hardcode group names from
   memory — the current list lives in `README.md` under "Picking your mods";
   read it every time, mods ship and change without this file being updated.

## Data-safety gate — read before any install step

Re-signing changes the APK signature. Android refuses to update over the
existing app, so installing the mod means **uninstall the current FitNotes →
local database is wiped**. All of the user's workout history survives only in
an export made BEFORE the uninstall:

- On the device: FitNotes → Settings → Backup & Restore → **Backup**, then copy
  the resulting `.fitnotes` file OFF the app (email it to themselves, or place
  it in shared Downloads/Documents — app-private storage dies with the app).
- After the mod is installed: Settings → Backup & Restore → **Restore** with
  that file. Restore replaces the whole DB and validates fine (schema ≤ 22
  auto-upgrades) — this round trip is proven in this user's history.
- Play Protect will show an "unknown app" warning on install. That is expected;
  the user taps through.

You may only proceed to uninstall once the user has confirmed a fresh export
exists and is copied to shared storage.

## Steps

### 0. Decide the machine
The mod builds on any OS with a JDK 8+ (`java` + `keytool`), `patch`, `curl`,
and `sha256sum`. On Fedora Silverblue/Atomic hosts there is no writable system
root — use a `toolbox`/`distrobox` container (Fedora base is fine):
`toolbox create fn-mod; toolbox enter fn-mod; sudo dnf install -y java-21-openjdk-devel patch`.

### 1. Ask the user which mods they want
Mod selection is by **named group** — never a bare patch number, never a
guess. Open `README.md`, read **"Picking your mods"** (its group table is the
one source of truth: the current group names, what each gives you, and which
patches belong to which group — it changes as mods ship, so read it fresh
every time rather than relying on anything written here), then present the
options to the user and ask which they want:

- the default (build all mods), or
- one or more named groups from that table, combined freely
  (`MODS="group1 group2"`).

Do not proceed until they have picked. Record the answer for step 3; if they
say "everything", that is the default — confirm it once anyway.

### 2. Get the pinned APK (only if the user doesn't have one)
Ask the user first — the pinned build is the
"FitNotes - Gym Workout Log_25.1_APKPure.apk" file (identity = the
`SOURCE_APK_SHA256` in `manifest.txt`; if they have it, use their path in
step 3). If not, fetch and verify before anything else — this recipe was
tested 1 Nov 2026 and served exactly 25.1, but `?version=latest` serves
whatever upstream-latest is, so verify fresh EVERY time:

```sh
curl -L -o pinned.apk "https://d.apkpure.net/b/APK/com.github.jamesgay.fitnotes?version=latest"
sha256sum pinned.apk
```
(Again pinned as `SOURCE_APK_URL` in `manifest.txt`.)

- The hash MUST equal `SOURCE_APK_SHA256` in `manifest.txt`. A mismatch is
  a STOP (hard rule 1) plus a report — most often upstream moved past 25.1
  and this URL now serves a newer build. Re-pinning is a maintainer edit
  to `manifest.txt`, never the installing agent's prerogative, and never a
  reason to "build anyway": the patches hardcode version-specific ids.
- If the URL stops returning APK bytes entirely (HTML page, 403/404, CDN
  reshuffle), stop and ask the user for the file some other way; the
  sha256 is the only arbiter of identity, wherever the bytes came from.

### 3. Run the build
```sh
MODS="<groups the user chose in step 1>" \
  bash build.sh "/absolute/path/to/FitNotes - Gym Workout Log_25.1_APKPure.apk"
```
(Omit `MODS` entirely for the default/all build.) Patches within a group
chain and are never individually selectable; only the vetted groups from
README's table — and their combos — are accepted, everything else refuses
loudly before touching anything. The script performs everything below itself
and is the source of truth for exact commands. Expected milestones, roughly:

| stage | telltale line | if missing |
|---|---|---|
| tools | `ok` on both sha256 checks | network/proxy issue — fetch URLs in build.sh manually |
| identity | `sha256 match: 3461836b…` | wrong APK build → STOP (hard rule 1) |
| decode | `decode sanity check OK` | decode didn't restore names → wrong apktool version? |
| patch | no `FAILED` hunks, exit 0 | rejected hunks → STOP (hard rule 2) |
| rebuild | `Built apk into: …fitnotes-modded.apk` (~5 s) | XML mismatch — paste build errors |
| keystore | `NEW KEYSTORE GENERATED` (first run) | — |
| sign | `signature verified [v3]`, `Successfully processed 1 APKs` | see signer note below |

Known signer quirk: uber-apk-signer refuses `-o OUT` together with
`--overwrite` ("either provide out path or overwrite argument"). Use one.

### 4. Optional device-side pre-checks (with user's consent)
```sh
adb shell dumpsys package com.github.jamesgay.fitnotes | grep -E 'versionName|versionCode'
# expect: versionName=25.1   versionCode=64
```
If the device shows anything other than 25.1/64, that's fine for building —
the mod is built from the pinned APK regardless of what's installed — but
flag it to the user so they don't assume their old build's settings carry.

### 5. Hand over to the human (do not automate this)
Present the user with:
1. `dist/fitnotes-modded-aligned-signed.apk` location
2. the reminder to make + offload a fresh `.fitnotes` export
3. the uninstall → install → Restore sequence
4. the Play Protect expectation, and that installs of future patch versions
   must come from the same `keystore/` (backed up offline)

### 6. Post-install verification (user, on device)

Base, any build:
- FitNotes opens.
- Data restored: open any past date and confirm sets are present.

Then verify every mod the build included — driven entirely by README; this
file deliberately names no mods, so never verify from memory or from here:

1. Re-read the "Picking your mods" table in README.md (again — it is the
   live list, and it changes as mods ship).
2. Form the checklist from the rows of the groups chosen in step 1: each
   row's description IS the test recipe. Whatever trigger it names (an
   overflow item, a confirm dialog, a settings toggle), have the user
   perform it on-device and confirm the promised result — including the
   negative cases the row itself states (e.g. a "skipped when…" clause).
3. For rows with visual promises, compare the Track screen against
   README.md's before/after screenshot.
4. Walk through every chosen group — none skipped — and report the outcome
   of each check to the user.
5. Any mismatch with a row's promise: stop, report the failing check in
   that row's own wording, and consult the Troubleshooting table below.
   Do not "fix" anything by uninstalling/reinstalling again.

## Troubleshooting

| symptom | meaning | action |
|---|---|---|
| `checksum mismatch` on a jar | partial download | delete `tools/*.jar`, re-run |
| `sha256 differs` on APK | source build ≠ pinned | stop; user must obtain the pinned build (see manifest) |
| decode fails | corrupted APK copy | re-download the pinned APK, retry |
| patch rejects | decode base ≠ patch base | stop; confirm apktool 3.0.3 + pinned APK; report rejects |
| rebuild: XML error named file/line | patch + decode mismatch, or manual edit typo | paste the error; fix on that file/line only |
| `signature verified` absent | signing failed | inspect signer output; check keystore password |
| device refuses install | signature downgrade? Play Protect? | confirm uninstall of old app first; tap through Play Protect |

## If contributing back (values you changed)
Resource hunks in the patch are diff-safe to discuss. Do not export keystore
material, do not attach `dist/*.apk` — patched apps may not be redistributed.