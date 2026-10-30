# FitNotes — Communicator kit (installable patch)

Patches that rebuild **your own copy** of FitNotes 25.1 with **selectable
mods**: a compact Track screen tuned for near-square displays — first target
the Clicks Communicator (1080×1200, 9:10), verified via a Pixel 7a
split-screen pane — and a YouTube search shortcut for every exercise.

The patches are diffs only: nothing here distributes FitNotes itself, a
signature, or a keystore. Your build signs with your key, from your APK.

## Target look

Before → after on the Track screen (left: stock 25.1 at full phone ratio;
right: the modded build at the Communicator ratio — sets on top, 50/50
inputs, secondary action left):

![Before and after: stock FitNotes Track vs the modded Track](assets/track-before-after.png)

## Mods

Checklist of the kit's mods — every checked box ships in this patch series;
unchecked ones are planned with no patch yet.

- [x] **Sizes + spacing diet** — paddings 10→6 / 20→10 / 5→3, numerals
  32→26sp, steppers capped at 40dp touch — patches `001+002` → `compact`
- [x] **Side-by-side input row** — WEIGHT/REPS share one 50/50 row; single
  fields stay full width (time falls back full-width below) — patch `003`
  → `communicator`
- [x] **Inputs at the window bottom** — the history list moves above the
  input row (sets at top), so inputs pin to the window bottom — patch `004`
  → `communicator`
- [x] **Button order + gray CLEAR** — secondary action goes left, CLEAR
  dimmed `#363B42`; palette otherwise stock — patch `005` → `communicator`
- [x] **Stepper glyph shrink** — smaller ± ink, touch targets keep 40dp —
  patch `006` → `communicator`
- [x] **Search YouTube** — overflow item opens a YouTube search for the
  exercise's name, built at runtime (renames/new exercises just work;
  works on any layout) — patch `007` → `youtube`
- [ ] auto-mark sets complete on save/update
- [ ] swipe-to-adjust field values
- [ ] keyboard focus chain
- [ ] Enter-to-save
- [ ] hardware-keyboard shortcuts
- [ ] stepper haptic feedback

![Track screen overflow menu: calculators + Search YouTube](assets/track-youtube-menu.png)

See `patches/*.patch` for every hunk — plain XML (+ a little smali for the
YouTube wiring), human-readable.

## Picking your mods

Patch hunks chain together (later hunks assume earlier ones), so selection is
by **named group** — not per-patch, and not arbitrary. `build.sh` accepts
`MODS="group [group ...]"`; the result is the union of the groups:

| `MODS=` group | patches | gives you |
|---|---|---|
| `compact` | 001–002 | sizes + spacing diet only; every layout detail stays stock |
| `communicator` | 001–006 | the compact near-square Track screen + restyle (includes `compact`) |
| `youtube` | 007 | the "Search YouTube" overflow item; independent of any layout |

- default (`MODS` unset, or `all`) applies everything
- combinations work freely: `MODS="compact youtube"`, `MODS="communicator youtube"`…
- anything not in the table (`MODS="banana"`, raw patch numbers, untested
  combos) **fails loudly** before touching anything

## Quick start (humans)
```sh
# once: a JDK (java + keytool), patch, curl
bash build.sh "/path/to/FitNotes - Gym Workout Log_25.1_APKPure.apk"
# -> dist/fitnotes-modded-aligned-signed.apk

# optional — select mods (default: all). Patch hunks chain together, so
# selection is by named group, not per-patch:
#   MODS="compact"       → sizes+spacing diet only (padding, smaller type/steppers)
#   MODS="youtube"       → stock layout, only the "Search YouTube" overflow item
#   MODS="communicator"  → compact Track screen + restyle (+sizes)
#   MODS="compact youtube" / "compact communicator" / "communicator youtube" / all
MODS="youtube" bash build.sh "/path/to/FitNotes-25.1.apk"
```
Then: export your data in-app and copy it off-device → uninstall FitNotes →
install the built APK → in-app Restore. (Uninstalling wipes the local database;
that export is your only safety net. Details: `AGENTS.md`.)

## Delegating to an AI agent
Give an agent this whole folder and say: *follow AGENTS.md in here*. It pins the
exact APK (sha256 in `manifest.txt`), verifies every step, and refuses to touch
your device without your confirmation.

## Files
| file | purpose |
|---|---|
| `AGENTS.md` | agent-facing full procedure + safety gates |
| `build.sh` | decode → group-selected patch → rebuild → sign, fail-loud, idempotent |
| `manifest.txt` | pinned APK/tools checksums and expectations |
| `patches/` | the mod: per-edit series `0NN-<edit-id>.patch` — bare unified diffs of the decoded APK tree only, applied in filename order, no authorship metadata |

Personal use only. Don't redistribute signed builds or your keystore.