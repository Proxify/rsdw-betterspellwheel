# BetterSpellWheel 0.4.4 candidate: rapid navigation

Unpublished candidate on `work/l-bsw-instant`, based on released 0.4.3 (`8cdd846`).
Testing: 2026-10-14, SudoBlade, sarah/njoy, Creative TradeTesterB in MODTEST.
No production deployment, public tag, or store upload was made.

## Finding and fix

The released view cached Lua texture wrappers, which did not retain native textures
through Unreal garbage collection. Revisiting a branch loaded icons synchronously,
15–21 ms per icon. A live intervention retaining textures in hidden UMG Image
brushes removed all asset loads from the repeated sweep. The candidate retains that
bounded icon set and warms spell icons one per closed tick during world entry.

Navigation now uses the current pointer sample, no dwell or angular smoothing,
and immediate highlight/branch/tooltip opacity. Five-degree spatial hysteresis
still prevents edge chatter. A 1 ms callback samples each rendered game frame while
open/pending; the closed path remains throttled. Cast deadlines use actual elapsed
time. Tooltip sizing prepasses only the text widget and retains bounded fits across
opens. Local component enumeration and native item counts replace a global inventory
search and stack traversal.

## Same-machine observations

| Measurement | Released 0.4.3 | Candidate |
|---|---:|---:|
| Worst measured draw call | 77 ms | 3 ms |
| Median open-wheel update interval | 25 ms | 12 ms |
| p99 open-wheel update interval | 77 ms | 19 ms |
| p99 draw call | 58 ms | 1 ms |

Separate frame-time runs in the same scene: candidate p99 **15.63 ms**; stock wheel
p99 **15.89 ms**. Candidate maximum 23.30 ms; native maximum 166.35 ms. Candidate
whole mod tick p99 2 ms, maximum 5 ms. Lua timings have roughly 1 ms resolution.
This establishes native-like pacing in this test scene, not an absolute guarantee
against engine, loading, hardware, or every-world stalls. Runs were sequential;
lighting and unrelated engine work can differ. Immediate opening before incremental
prewarming finishes can still require first-use asset loads.

## Validation

- Full offline model/catalogue/layout/controller/input/runtime/view/art suites pass.
  Same-sample selection across all skills, boundary hysteresis, retained texture
  brushes, prewarming/reopen reuse, and bounded rendering work are covered.
- Visible final widget content matches the frozen legacy fixture across 1,310 frames;
  immediate highlights deliberately replace animation. Engine calls 5,090 to 1,980
  in that scenario; steady open frames 2.13 to 1.12 calls/frame.
- Real pointer sweeps across all 12 skills and all 39 spells; all 39 native tooltip
  desired sizes fit the allocated text box. No tooltip overflow observed.
- Native Tempest Shield mouse cast: timer continued while closed (42.55 seconds
  remaining at the observed check). Recall selection then Escape returned to gameplay
  with no cooldown. All 48 native spell slots matched before/after the final checks.
- Native GetNumItemsByData returned 37 after adding 37 Air runes to the disposable
  Creative character. Full saved-state restoration removed that test mutation.
- ZIP and EXE share 17 production files verified against source; ZIP includes root
  INSTALL.txt. ZIP extensions are **.lua and .txt only**. No dev console/tests/data
  or executable is included in the ZIP.
- Windows game-running guard refused without writes. Fresh install, upgrade/repeat,
  uninstall, shared/existing dependencies, other mods, legacy layout, invalid paths,
  loader/name collisions, and junction refusals passed in throwaway Windows folders.
  Every installed payload hash matched. Config/data preservation passed.

No physical-controller, two-client multiplayer, or new Standard-world cooldown
run was performed in this iteration. Casting remains native; Creative does not
prove Standard cooldown enforcement. The fresh capture demonstrates navigation;
functional assertions above also use native state probes and separate mouse tests.

## Evidence and cleanup

Project evidence: `dist/BetterSpellWheel/instant-investigation/` (outside this repo).
Raw capture: `bsw-instant-candidate-raw.mp4`; supplied report: `user-original.mp4`.
CSV: baseline.csv, pinned.csv, candidate2.csv, bsw-candidate-frames.csv,
bsw-native-frames.csv. The two video views are different machines/times, explicitly
labeled; they are not simultaneous two-player proof or a controlled FPS comparison.

SudoBlade backup `C:\Users\Public\bsw-instant-backup`; test aftermath retained in
`C:\Users\Public\bsw-instant-after-test`. Game exited normally; original Mods32 and
Saved168 files restored and every SHA-256/count verified. Steam left as found;
sarah locked. cu.ps1 and NightRec unchanged; own BSWInstantRec_3a4 task removed.
Temporary scripts, screenshots, installer-test folders and evidence remain in Public.
No firewall changes, personal characters, production saves, or hub DB were touched.
The temporary REPL directory received Users modify permission; it remains only in
Public, outside restored Mods/Saved. SudoBlade handed back to banking session f9e5542a.
All frame extraction, recording, rendering and audio work ran only on verified
SudoBlade/nJoyDesk. No media processing ran on the Cuttle host.
