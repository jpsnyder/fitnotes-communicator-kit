# FitNotes — Clicks Communicator mod (installable patch)

A patch that rebuilds **your own copy** of FitNotes 25.1 with a compact,
bottom-pinned Track screen for near-square displays — first target: the Clicks
Communicator (1080×1200, 9:10), verified via a Pixel 7a split-screen pane.

The patch is diffs only: nothing here distributes FitNotes itself, a signature,
or a keystore. Your build signs with your key, from your APK.

## Target look

![Track screen mock-up: current FitNotes (left) vs the Progression-style restyle (right), 1 px = 1 dp](assets/track-mockup.svg)

> **This is a design mock-up, not a screenshot.** Generated during mod planning;
> it will be swapped for a real on-device capture once the first build lands.

The real thing — Track screen running the modded build at the Communicator
ratio (top pane of a Pixel 7a 50:50 split, 1080×1187 px ≈ 432×482 dp):

![Track screen at the Communicator ratio: 4 sets visible, inputs and CLEAR/SAVE pinned at the bottom](assets/track-screenshot-communicator.png)

## What changes
- input row compacted (WEIGHT/REPS side-by-side, smaller steppers + numerals)
- history list pins to the bottom, newest set nearest the inputs
- tighter global spacing; Progression-style dark restyle
- (optional, conditional) sets auto-mark complete on save/update

See `patches/*.patch` for every hunk — all plain XML, human-readable.

## Quick start (humans)
```sh
# once: a JDK (java + keytool), patch, curl
bash build.sh "/path/to/FitNotes - Gym Workout Log_25.1_APKPure.apk"
# -> dist/fitnotes-modded-aligned-signed.apk
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
| `build.sh` | decode → patch → rebuild → sign, fail-loud, idempotent |
| `manifest.txt` | pinned APK/tools checksums and expectations |
| `patches/` | the mod: per-edit series `0NN-<edit-id>.patch` — bare unified diffs of the decoded APK tree only, applied in filename order, no authorship metadata |

Personal use only. Don't redistribute signed builds or your keystore.