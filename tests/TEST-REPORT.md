# BetterSpellWheel 0.3.0 controller verification — 2026-10-06

Test environment: Dragonwilds 1.0 / UE 5.6 / Windows 1080p, TradeTester connected to
local dedicated MODTEST. Virtual Xbox360 device via existing ViGEmBus and test-only
vgamepad0.1.0, driving the engine input path. No physical controller was connected.

- PASS: native Y opens; both analog polling and D-pad reach the mod.
- PASS: all 12 skill directions, A enters, D-pad advances spells, B returns to
  skills and a second press closes. Held A/B cannot skip stages. See
  [recorded sweep](controller-live-results.txt).
- PASS: zero text overflows at every sweep stage; visually inspected
  [Xbox wheel](../docs/controller-xbox.jpg) and
  [PlayStation label fixture](../docs/controller-playstation-labels.jpg).
- PASS: real Windstep instant cast and AxtralProjection RT confirmation recorded
  in LastCastTimeBySpellData; all 48 saved spell slots restored after gameplay
  mode returned. LT cancellation also returned to gameplay with all 48 restored.
- PASS: locked-record selection shows denial without closing or casting.
- PASS: stick navigation did not move the character or turn the camera while
  browsing. Y close restored native camera input. Mouse movement switched back
  to mouse navigation; raw MouseX/Y fixes hidden-cursor handoff.
- PASS: hot reload into final0.3.0, repeated open/back/close and layout audit.
- PASS: tests/run.py — Lua syntax,66 model checks,2340 layout checks,39 progression
  records, controller navigation/input-capture unit tests and real-adapter mocks
  covering controller stages, mouse handoff, casts, denial, all book offsets,
  cancellation, newer server updates, shutdown and native fallback.
- PASS: final EXE running-game refusal and complete Windows disposable-directory
  installer suite (fresh/update/repeat/uninstall, config/data/other-mod retention,
  loader/old-name/junction refusal and both UE4SS layouts). See
  [installer results](installer-results-0.3.0.txt).
- PASS: interactive installer fresh install, update and uninstall in a disposable
  game directory, with all three success screens visually inspected.
- PASS: release_test.py —17 production files match source in both outputs;
  ZIP has18 entries including root INSTALL.txt; EXE is separate.

Live failures caught and resolved: native B initially closed the whole wheel
before polling; the scoped consuming mapping fixed it. Cursor-position-only
handoff missed hidden-cursor movement; raw mouse deltas fixed it. Early native
animation/cancel assertions ran before mode restoration; settled-state checks
confirmed correct cast/cancel and slot restoration. Short camera check similarly
ran too early; a subsequent held-stick check confirmed controls restored.

Not verified: physical Xbox hardware, native DualShock/DualSense input, Bluetooth,
Steam Deck, ultrawide/high-DPI, device disconnect mid-selection, death/disconnect
while targeting, every spell effect, and other wheel mods. PlayStation labels
were verified visually, not with PlayStation hardware. Paging is unit-tested;
none of the current39 spells creates a skill with more than six entries.

Earlier release results follow as historical evidence (their unsupported-controller
statements describe those earlier versions).

---

# BetterSpellWheel 0.2.2 test report

2026-10-05. Dragonwilds 1.0 / UE 5.6, Windows client with project UE4SS build.
Only TradeTester in TRADE_TEST was used for client mutations. MODTEST was used
for the earlier read-only spell catalogue investigation.

## 0.2.2 release packaging and installer (2026-10-05/06)

This release adds the standalone Windows installer and INSTALL.txt. The mod's
runtime changes only its version string; wheel/casting behavior is unchanged.

- ZIP: 15 production mod files plus top-level INSTALL.txt; no EXE, dev.txt, tests,
  data or developer configuration. Instructions are also installed with the mod.
- Separate setup EXE: same 15 production files plus version metadata, the tested
  Dragonwilds UE4SS loader/settings and the dependency license. Shared manifest
  and `tests/release_test.py` verify exact source bytes in both outputs.
- Existing Lua model/catalogue/layout/casting-adapter regressions passed again.
- `tests/installer_windows.ps1` ran on Windows in disposable fake game directories.
  Installed SHA-256 values matched all mod files and bundled dependencies.
  Running-game refusal, fresh install, upgrade/repeat install, config/data
  retention, deduplicated enablement, existing UE4SS layouts, other-mod retention,
  uninstall cleanup, invalid path, loader conflict, legacy-name collision and
  junction refusal passed. See `tests/installer-results.txt`.
- Interactive installation, the Update/Uninstall choice, update completion and
  uninstall completion were checked with real desktop clicks and screenshots
  against the disposable target. Read-only Steam detection also found the actual
  Dragonwilds installation. The real game folder was never an installer target.
- The EXE is not code-signed. Tests do not certify every antivirus/SmartScreen
  environment or protected Steam-directory permissions. The game was not launched
  from fake test folders. Earlier in-game coverage remains listed below.

## 0.2.1 rename verification

The mod was renamed from SpellBranches to BetterSpellWheel and moved to the
standalone `Proxify/rsdw-betterspellwheel` repository, preserving its mod history.
The casting adapter and skill mapping are unchanged.

- All automated checks below passed again with the renamed Lua globals.
- Hot reload from `D:/rsdw-mods/mods/BetterSpellWheel/Scripts/main.lua` returned
  0.2.1. The Windows junction and loader entry now use BetterSpellWheel.
- Real Q opening and Agility → Windstep hover passed. The new title was reviewed
  in-game at 1920×1080; the layout audit reported zero text overflows.
- The renamed key bindings close with Q, hide the cursor and restore gameplay.
- `docs/preview.jpg` shows 0.2.1; the other screenshots record 0.2.0 coverage under
  its former name. No fresh cold-start or casting-effect rerun is claimed for
  this naming-only release.

## Automated checks

`/tmp/luav/bin/python mods/BetterSpellWheel/tests/run.py` passed:

- Every Lua source/fixture compiles with Lua 5.4.
- 66 model checks: boundaries, dead zones, angular wrap, skill dwell/hysteresis,
  branch latching, lock handling, stable order, pagination and catalogue filtering.
- All 39 captured spell records map through native progression, including Windstep
  in Agility. The prior filename-based assertion missed this reassignment.
- Native-progression fixture verifies legacy asset names and localized skill names
  cannot change ownership; missing progression fails closed.
- 2,340 layout checks cover the corners of every skill/spell icon and number box,
  including branch sizes 1–6 in all 12 orientations, plus panel text separation.
- The real `main.lua` runs against a native-UI simulation: rejection preserves
  slots, aimed selection stays substituted until targeting ends, cancellation,
  second/fourth book offsets, empty slot restoration, newer server update wins,
  changing books while pending, locked/center clicks, shutdown cleanup and
  renderer failure leaving the native wheel available.

The simulation does not substitute for the live tests below.

## Live 0.2.0 verification

- Read-only native progression audit: all 39 spells; counts 3/3/4/3/4/2/3/4/4/4/2/3
  in the wheel's fixed skill order. Only Windstep differed from the 0.1.0 mapping.
  Agility owns Windstep (5), Phase Dash (44), Recall (57); Runecrafting has four.
- `tests/live_layout.lua`: real pointer movement through 52 states (neutral,
  all 12 skills, all 39 spells). Slate `GetDesiredSize` measured every visible
  text node: **zero overflows**, with the expected skill/spell selected each time.
  Results are preserved in `tests/live-layout-result.txt`.
- Real mouse sweep and screenshot review of all 12 branches at 1920×1080.
  Full names are confined to the roster/detail panel. Icons and compact numbers
  stay within their wheel wedges. Uproot and Summon Elemental Spirits checked.
- Real LMB on **Agility → Windstep** produced a new native Windstep cast-map
  timestamp; returned to gameplay with all 48 spellbook entries preserved.

- UI-only locked Recall fixture: click denied, dim icon and feedback visible,
  no text overflow and all 48 slots unchanged. Fresh open resets the fixture.
- Real RMB back, Q/Escape close and repeated opening passed; cursor/gameplay input
  restored after close. Final view is Agility → Windstep with the fixture cleared.

The first text sweep caught a two-pixel height shortage in the neutral help
paragraph. Its box was enlarged, then all 52 states were swept again successfully.

## Earlier 0.1.0 live casting coverage

The casting adapter is unchanged. These checks were recorded before the visual
redesign; they are retained as prior coverage, not claimed as new 0.2.0 reruns.

| Scenario | Evidence |
| --- | --- |
| Catalogue and art | 39 perk spells/12 skills; native paths for all icons loaded; screenshots inspected |
| Default Q open | Native open detected; centered cursor; neutral custom wheel; no automatic cast |
| Skill/branch navigation | Real pointer movement; branch remains attached outside inner ring; RMB returns to skills without immediately reopening the branch |
| Instant cast | Real LMB on Windstep (incorrectly grouped in 0.1.0); `LastCastTimeBySpellData` recorded Windstep; original slot restored |
| Aimed cast | Real LMB on Woodcutting → Axtral Projection; native prepared data matches Axtral; real confirmation recorded Axtral in cast map; all 48 slot values restored |
| Advanced movement cast | Agility → Recall enters `DIM_SpellPlacementModeAdvancedMovement`, retains the Recall slot through movement/confirmation, records Recall in the cast map, and restores all 48 slots on return to gameplay |
| Placed spell | Construction → Summon Shelter enters native placement preview with correct prepared data; native BLOCKED feedback remains; Escape restores all 48 slots |
| Rune shortage | Splinter with insufficient runes keeps custom wheel open, gives denial feedback, restores original slot |
| Locked selection | Temporary plain-Lua UI fixture makes Trunk Totem locked; dim icon, LV50 badge, denial feedback; no changed slots |
| Close/input cleanup | Q/Escape, multiple repeat cycles, cursor hidden and `DIM_Gameplay` restored |
| Native book two | Real native book switch to zero-based1; Windstep cast; all 48 slots unchanged afterward |
| Reload/standalone | Hot reload closes safely; junctioned standalone mod loads after full game restart; enters TRADE_TEST as TradeTester; custom wheel and Axtral casting work in its own Lua state |
| Long text | Uproot's 212-character description fits beside the wheel, above costs and status; final screenshot inspected |
| Empty slots / absolute write | `Client_NotifySelectedSpell(nil,slot)` verified; direct absolute TArray entry write/restore tested, including an invalid/empty entry |

Slot comparisons are made after the native casting animation returns to
`DIM_Gameplay`. An initial check after only1.8 seconds saw the deliberately
retained targeting slot; checking after animation completion passed. The adapter
must not restore during that animation/confirmation window.

Unlocking all spells for icon discovery was a **test-character-only fixture**.
The game can auto-fill previously empty spellbook slots after those unlocks.
Tests compare snapshots taken before each selection sequence, not before that
fixture. No unlock or inventory mutation is in the production mod.

## Experimental failures that informed the implementation

Before implementation, soft-reference reads crashed the MODTEST server, and
client `GetSpellDisplayInfo` plus an invalid prepared-data dereference froze the
client. Each frozen process was restarted. These calls are excluded from the mod.
An immediate-restore prototype prepared Axtral but cast Oculus when confirmed;
the final adapter retains the selected slot until native targeting/casting ends.
Native book offsets were verified because notifications take relative slots while
the backing array contains all four books.

## Not verified

Dedicated-server client play, controller navigation, other display resolutions /
DPI settings, death/disconnect mid-targeting, every spell's resulting effect,
all third-party UI combinations, and successful Summon Shelter placement on valid
open ground. The package is a keyboard/mouse beta, not a multiplayer-certified
release. PlayerTrading code is unchanged; its trade/protection tests were not run.
