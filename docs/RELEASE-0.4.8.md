# BetterSpellWheel 0.4.8 verification

Released from merged PR #10 (`388016a584333639adbba20e3cc7ffabf9167bc2`).
The release changes the version literal and release documentation. All Lua
modules match native-tested `06b0bede0cbe44382597f128d317f6111e9b4eab`, except
that version literal (line endings normalized for the comparison).

Checks on 2026-11-14:

- Full `python tests/run.py` suite passed on 0.4.8.
- `tests/release_test.py` verified all 18 production files against source in
  the ZIP and EXE; the ZIP also includes root installation instructions.
  ZIP extensions are `.lua` and `.txt` only. No development console, runtime
  data, tests or evidence is packaged.
- The RSence package is built from the same ZIP and read back with the shared
  installer payload reader. All production bytes and version match.
- Windows installer Suite: all ten cases passed in isolated throwaway folders
  on Windows/SudoDesk. Fresh install, repeated update, shortcut config/data
  preservation, uninstall, shared dependencies, modern/legacy UE4SS, loader
  collisions, invalid targets, old-folder conflicts and junction refusal passed.
  The installer log was restored to its original absent state.
- A first suite attempt used an excessively deep test path and was refused
  before installation because native game-path discovery failed. A short test
  root passed. This is not evidence of long-path support.
- Installer C source and extracted executable stub are unchanged from the
  verified 0.4.7 release. Prior real running-game refusal and interactive checks
  are reused for that identical engine; no game was started for this packaging
  verification.

Native gameplay evidence is the PR #10 acceptance in
[SHORTCUTS-VALIDATION.md](SHORTCUTS-VALIDATION.md), with the
[narrated showcase](evidence/shortcuts/shortcuts-showcase.mp4) and
[continuous raw take](evidence/shortcuts/shortcuts-raw-take.mp4).
It covers one Standard test World, keyboard/mouse, first use, saved keys,
native restrictions/aim/cancel, reload and cold start of the tested runtime.
It is reused evidence, not a new 0.4.8 packaged gameplay recording.
Two-player/dedicated-server/current Together combination, controller hardware,
other resolutions and wider compatibility remain unverified.

Both shortcut options remain off by default. Native casting rules remain
authoritative; existing user configurations are preserved on update.

Artifact SHA-256:

| Artifact | SHA-256 |
| --- | --- |
| ZIP | `d2251d2251c81370c502c1cb4299fe548e86f980a26b469a39b10fe536c4cb7e` |
| Windows setup EXE | `a8148bab4727cb020ad6146347cd6c44ac3ea835d06d11d90ccb8ae7451ce2c0` |
| RSence package | `3d31478801794f3fe0856c26185937f6195a2c076e7746619c3511b21e88102d` |

Nexus Mods and CurseForge receive only the mod ZIP. The setup EXE is distributed
through RSence and the GitHub release. Publication status is recorded separately
from these build and test results.
