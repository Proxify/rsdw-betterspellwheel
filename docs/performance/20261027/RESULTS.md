# 0.4.7 closed-wheel frame rate: native results (2026-10-27)

Runtime under test: `e272ec0` Scripts (0.4.7 code before the version bump; the release only changes the
version string, README links and CHANGELOG). Baseline: 0.4.6 (`v0.4.6`, `e3343e9`). Each run is a cold game
process.

## Setup

- SudoDesk (Windows 11, 4K). Client build 26162923, user's own Steam account, test character TradeTester.
- Only BetterSpellWheel plus a test-only frame sampler mod (`B47Probe`) were loaded. The user's other mods were
  disabled for the runs and restored afterwards (hash-verified).
- UE4SS builds:
  - `0196ef29`, the reporter's build: official asset `UE4SS_v3.0.1-944-g0196ef29.zip`, SHA-256
    `b7be1824…45bd`, matching GitHub's digest.
  - `f6d5f942`, the current build, which the easy installer ships.
- CPU-bound settings, applied as runtime console variables only, never saved:
  - frame generation off, DLSS off, `r.ScreenPercentage 10`, VSync off, `t.MaxFPS 1000`.
  - At the user's 4K settings the game is GPU-bound at about 50 fps and hides a game-thread cost below about 12 ms.
    The reporter ran uncapped at 168 fps.
- Metric: the engine's `GameplayStatics.GetWorldDeltaSeconds`, sampled every frame for 45 s with the wheel closed,
  standing still. PresentMon 2.6.0 ran alongside as a cross-check; its CPU-busy p50 agrees within 0.3 ms.

## Results

| Run | UE4SS | Build | World | fps | frame p50 | p99 |
|---|---|---|---|---:|---:|---:|
| C2 | 0196ef29 | 0.4.6 | TRADE_TEST | 59.3 | 16.89 ms | 18.92 ms |
| C5 | 0196ef29 | 0.4.6 | TRADE_TEST | 60.9 | 16.59 ms | 18.79 ms |
| C6 | 0196ef29 | 0.4.7 | TRADE_TEST | **154.2** | 6.36 ms | 8.61 ms |
| C3 | 0196ef29 | 0.4.7 | other solo world | 131.4 | 7.57 ms | 8.97 ms |
| C4 | 0196ef29 | BSW off | other solo world | 135.3 | 7.34 ms | 8.76 ms |
| C7 | f6d5f942 | 0.4.6 | TRADE_TEST | 154.4 | 6.39 ms | 8.39 ms |
| C8 | f6d5f942 | 0.4.7 | TRADE_TEST | 152.5 | 6.43 ms | 8.80 ms |

C3 and C4 were captured in a different solo world, which was entered by mistake (see Limits). They form a matched
pair with each other, not with the TRADE_TEST rows.

Direct timing of the calls in game on `0196ef29`:

| Call | Time |
|---|---:|
| `StaticFindObject(controller path)` (the 0.4.6 per-tick check) | 11.85 ms |
| `FindFirstOf('BP_PlayerController_C')` | 11.60 ms |
| `LocalPlayer.PlayerController` read plus validity/address check (0.4.7) | 0.001 ms |
| `pc.Pawn` read | 0.0015 ms |

The same `StaticFindObject` call measured 3 µs on `f6d5f942` (`tests/live-perf-0.4.3.txt`).

## Object-lookup counts

Counted in game on `f6d5f942`, branch build, using counting wrappers around the globals in BSW's own Lua state.

| Phase | StaticFindObject | FindFirstOf | FindAllOf |
|---|---:|---:|---:|
| Closed, 10 s | 0 | 0 | 0 |
| First open of the world | 7 | 0 | 2 |
| Skill hover | 0 | 0 | 0 |
| First spell hover | 3 | 0 | 0 |
| Next spell hover | 1 | 0 | 0 |
| Select and close | 1 | 0 | 0 |
| Main menu (unbound), 10 s | 0 | 0 | 0 |
| Closed after rejoin, 8 s | 0 | 0 | 0 |

Notes on the counts:
- **First open:** class caching plus the native-panel guard (7); the per-world catalogue scan (2 `FindAllOf`).
- **First spell hover:** the cost-module and inventory classes are cached once; the rune icon texture is looked
  up once.
- **Next spell hover:** one rune icon texture.
- **Select and close:** the native-panel guard only.

## Native functional checks

Run on `f6d5f942` with the branch build:
- **Cold bind:** used the local-player check; no fallback line was logged.
- **Open, hover and details:** the wheel opens on a real Q press. Skill and spell hover, spell details and the
  tooltip all display.
- **Cast hand-off:** selecting Enfeeble entered native targeting (`DIM_SpellPlacementMode`); Esc cancelled it back
  to gameplay.
- **Real cast and cooldown:** Surge was cast. With the wheel closed, the cooldown showed 39.1 s remaining; on
  reopen the slot showed `32s`.
- **Exit and rejoin in the same process:**
  - Exiting to the main menu unbinds the wheel without errors.
  - On rejoin it binds to a new controller (different address) through the same `DominionLocalPlayer`, whose
    address is unchanged. The local player therefore persists across travel.
  - After rejoin, open, hover and close all work.
- **Engine calls the fix relies on:**
  - `pc.Pawn:GetComponentByClass(PlayerUtilityMagicComponent)` returns the pawn's component.
  - `SubsystemBlueprintLibrary.GetLocalPlayerSubSystemFromPlayerController` returns the same CommonInput and
    Enhanced Input subsystems as `FindFirstOf`.
  - `GameplayStatics.GetGameState(pc)` returns the game state.

On `0196ef29`, cold bind with the branch build also used the local-player check (runs C3 and C6).

## Limits

- **Single PC, small sample:** one Intel/NVIDIA PC; one or two 45 s samples per arm. The time of day drifted
  between runs.
- **No AMD CPU tested.** The reporter's CPU is a Ryzen 7 7700X. The cause measured here is the UE4SS build, not the
  CPU.
- **Not tested in game:** respawn (covered by the offline tests), physical controller, multiplayer, emote
  hand-off, and opening-event hitches on `0196ef29`. The native-panel guard still costs one lookup per
  open/select/close, about 12 ms on that build.
- **Development reload crashes on `0196ef29`:** a dev-console `dofile` reload issued from inside BSW's own loop
  crashed the game (UE4SS dump at reload; the dump was deleted). It works on `f6d5f942`. Players never take this
  path: the dev console isn't shipped. Use cold starts on older UE4SS.
- **Wrong world entered:** runs C3 and C4 and the rejoin/functional pass entered another of the PC owner's solo
  worlds instead of TRADE_TEST, because the world list re-sorts by last played. That world's files, the test
  character and the configs were restored byte-for-byte from the pre-test backup.
- **No gameplay video:** video capture and encoding are restricted to hosts that were unavailable.
