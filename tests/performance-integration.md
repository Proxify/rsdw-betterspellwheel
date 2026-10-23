# PR6 integration and three-way comparison

Baseline Main: `320ebdde44f37470ed432d06d952ff1b11ac53fe`. Pristine community [PR6](https://github.com/Proxify/rsdw-betterspellwheel/pull/6): `81e1e0383c59d5d854eb83176a6f2af87f327370`. Integrated PR7 runtime source: `00e98ac5617e4a853f96f3d7a9f2703cb095d147` (port `5a6a048`, rune-key fix `00e98ac`, on cropped artwork `67e7024`). This is an unreleased candidate with native acceptance pending.

## What is incorporated

Credit to dhenriques for PR6's catalogue caching, rune feedback, cursor positioning and open-stage profiling. The port retains useful reductions in work while keeping Main's lifetime checks.

| Area | Main | Pristine PR6 | Integrated PR7 |
|---|---|---|---|
| Spell catalogue on reopen | two global scans | per-world cache | cache cleared on unbind, rebind and pawn change |
| Unlock status | scan/open and select | throttled group refresh and select | throttled refresh through live controller, native selection-time check |
| Rune feedback | global refresh delay | immediate per-item cache | immediate cache shared by rune address across wrappers |
| Cursor | visible before centring | centred first | centred first |
| Default native panel | repeated hide writes | repeated writes removed, open guard skipped | repeated writes removed provisionally; live panel guard kept |
| Controller lifetime | next-tick path/address check | removed | kept, with original tests |
| Artwork | full transparent rectangles | unchanged | cropped original pixels; native placement pending |
| Input-release drain |17 key queries|17|5, same quiet timing |
| Casting | native temporary-slice handoff | unchanged | unchanged |

Main's original replaced-controller regression test fails against pristine PR6. That is a simulated regression, not evidence of a native crash. PR7 retains both replaced- and removed-controller tests, the native-panel guard on open and the guard before native IsOpen on close. The no-repeated-hide change still needs a native no-flash check on first open, reopen, after cast/emote, resolution change and respawn.

The catalogue cache does not freeze cooldown durations: existing liveCooldown reads native spell data and cooldown perks each opening. Selection rechecks native unlock status. Rune addresses are read once per detail entry; no per-frame address lookup was added. Cached counts expire after one second and reset on reopen.

## Verified offline

The coordinator independently ran `tests/run.py` on `00e98ac` using lupa 2.8 / Lua 5.4: exit 0, 14 PASS suites. Syntax, existing input/model/controller/lifetime/casting/cooldown tests and exact cropped-art/placement tests pass. New cases cover catalogue reuse, unbind/rebind, a new pawn with the same controller, panel replacement, ten-second group throttling, unverified controller rejection, unlock/lock changes at selection, and a cooldown perk unlocked after the scan.

Rune tests cover distinct wrappers with the same rune address, only the uncached rune requiring a query, immediate sufficient-count colour and insufficient-count colour after expiry. Focused colour assertions replace only the comparison against the old delayed colour behaviour. Mutating the new safety/cache paths made the corresponding tests fail. The package check passes with 18 production entries, `.lua` and `.txt` only; no development console marker, tests or generated PNGs ship.

The historical view simulation changes from 5090→1980 calls before integration to 5090→1998 after it, because immediate rune queries add first-hover work. These are mocked scenario counts, not game FPS or native timings. Cropped-art byte totals and generator microbenchmarks are documented in [cropped-art-evidence.md](cropped-art-evidence.md).

## Native comparison still pending

Measure Main, pristine PR6 and the frozen integrated PR7 on the same admitted PC, build, scene and settings. Use interleaved cold processes, repeated cases, exact source/payload receipts and per-run p50/p95/p99/p99.9/max/hitches with spread. Separate cold first-open from warm reopens, and keep optional Lua profiling and recording outside external frame-time runs. Preserve null results and regressions. No claim that PR7 is faster than either baseline is established yet.

Verify cropped pivot/hit alignment, all skill branches, mouse/controller, cast/cancel/fast reopen, cooldown state while closed, rune colours, cache freshness, repeated controlled reloads and cold loading with/without old caches. Lua iteration uses complete syntax-checked, hash-verified source and the game-thread dofile console; never UE4SS Ctrl+R. Cold benchmarks avoid contamination from retained widgets across reloads.

The casting-reuse experiment is isolated and not included. It requires native correctness and useful measured benefit; any later inclusion changes the candidate and requires renewed exact-source acceptance/comparison. The requested showcase will use real separately recorded runs at 1× speed with all three arms in the statistics. No video or native results are available yet. No release or deployment is part of this PR.
