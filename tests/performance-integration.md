# PR6 integration and three-way comparison

Baseline Main: `320ebdde44f37470ed432d06d952ff1b11ac53fe`. Pristine community [PR6](https://github.com/Proxify/rsdw-betterspellwheel/pull/6): `81e1e0383c59d5d854eb83176a6f2af87f327370`. Integrated PR7 runtime source: `00e98ac5617e4a853f96f3d7a9f2703cb095d147` (port `5a6a048`, rune-key fix `00e98ac`, on cropped artwork `67e7024`). This is an unreleased candidate with partial native acceptance. The completed three-build measurements are mixed; see [native results](../docs/performance/20261023/NATIVE-RESULTS.md).

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
| Artwork | full transparent rectangles | unchanged | cropped original pixels; sampled native placement passes, full sweep pending |
| Input-release drain |17 key queries|17|5, same quiet timing |
| Casting | native temporary-slice handoff | unchanged | unchanged |

Main's original replaced-controller regression test fails against pristine PR6. That is a simulated regression, not evidence of a native crash. PR7 retains both replaced- and removed-controller tests, the native-panel guard on open and the guard before native IsOpen on close. The no-repeated-hide change still needs a native no-flash check on first open, reopen, after cast/emote, resolution change and respawn.

The catalogue cache does not freeze cooldown durations: existing liveCooldown reads native spell data and cooldown perks each opening. Selection rechecks native unlock status. Rune addresses are read once per detail entry; no per-frame address lookup was added. Cached counts expire after one second and reset on reopen.

## Verified offline

The coordinator independently ran `tests/run.py` on `00e98ac` using lupa 2.8 / Lua 5.4: exit 0, 14 PASS suites. Syntax, existing input/model/controller/lifetime/casting/cooldown tests and exact cropped-art/placement tests pass. New cases cover catalogue reuse, unbind/rebind, a new pawn with the same controller, panel replacement, ten-second group throttling, unverified controller rejection, unlock/lock changes at selection, and a cooldown perk unlocked after the scan.

Rune tests cover distinct wrappers with the same rune address, only the uncached rune requiring a query, immediate sufficient-count colour and insufficient-count colour after expiry. Focused colour assertions replace only the comparison against the old delayed colour behaviour. Mutating the new safety/cache paths made the corresponding tests fail. The package check passes with 18 production entries, `.lua` and `.txt` only; no development console marker, tests or generated PNGs ship.

The historical view simulation changes from 5090→1980 calls before integration to 5090→1998 after it, because immediate rune queries add first-hover work. These are mocked scenario counts, not game FPS or native timings. Cropped-art byte totals and generator microbenchmarks are documented in [cropped-art-evidence.md](cropped-art-evidence.md).

## Native comparison and remaining gates

Exact-source cold-process comparison completed on SudoBlade (client26162923, UE4SSf6d5f942):27 steady captures and7 Q-event processes. [Full results, run ranges and all samples](../docs/performance/20261023/NATIVE-RESULTS.md) retain regressions. [Method](../docs/performance/20261023/METHOD.md) explains the prespecified matched open/navigation subset and limitations. PR7 has lower open-idle p99 in these runs, overlapping closed-idle ranges, worse navigation p99 than PR6 and longer opening Q-event frame gaps than both baselines. It is not faster overall; Q-event metrics are not input latency. No mod-off control was measured.

Native sampled pivot/outer Tempest hit, real casting/refusal/closed cooldown, cold binding, integrated game-thread reload and actual same-process menu exit/rejoin pass. Full all-sector selection, physical controller, multiplayer, cancellation, native cache-unlock/perk/rune-change checks and the full no-flash matrix remain incomplete. Sparse footage cannot establish absence of a transient flash. These limitations remain explicit when the PR is marked ready for review; they are not blanket native acceptance.

The casting-reuse experiment is isolated at59a98b1 and not included. No native benefit result exists. Any later inclusion changes the candidate and requires renewed exact-source acceptance/comparison. Real separate gameplay takes exist for all three builds; the [polished showcase](../docs/review-media/20261023/bsw-pr7-performance-README.md) is attached. They run at1x wall time with about17–18fps capture, not game-FPS evidence. No release/deployment is part of this PR.

## Merge reconciliation (2026-10-24)

Main merged pristine PR6 at `6817e02`. PR7 merges that history while retaining its already reviewed implementations in `Scripts/main.lua`, `Scripts/view.lua`, `tests/run.py`, `tests/runtime_test.lua` and `tests/view_perf_test.lua`. The conflicts cover the deliberate lifetime guards, cache invalidation, rune-address cache, cropped-art assertions and equivalent portable paths; they do not introduce a new runtime revision.

After resolution, all 17 production mod files match native-tested `a8553ad` byte for byte (18 ZIP entries when the root `INSTALL.txt` is included). Lua 5.4 / lupa 2.8 syntax and all 14 offline PASS suites were rerun successfully. Extension checks remain `.lua`/`.txt` only. Existing native measurements and footage therefore still describe the exact production payload. No game reload, process restart, installer build or new native benchmark was needed for this history-only reconciliation. Known performance regressions and incomplete functional coverage above remain unchanged.
