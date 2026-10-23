# Casting handoff experiment (development only, not for release)

Experimental branch `work/l-bsw-cast-reuse-20261023` from `866aa2f`. Release installs (no `dev.txt`) always use the
legacy slot-0 handoff; there is no config option. Nothing here is a native result.

## Variants (dev console only)

`BetterSpellWheel.castDev.set(v)`, refused while the wheel is open, a cast is pending, input is draining, during an
emote hand-off, unbound/transit, retired (reloaded) or disabled. A change rebuilds no UI and registers no hooks.

| variant | slot 0 already holds the chosen spell | otherwise |
|---|---|---|
| `legacy` (default) | notify + highlight + select, restore (notify, direct write) | same |
| `restore-only` | full bind, restore skipped | legacy |
| `same-slot` | warm: no notify, CachedSectionId=0 + HighlightSlice(0) kept, no restore; cold: legacy | legacy |

Warm = a full handoff ran on the same book and absolute slot index since binding. It is reset by load/reload, rebind,
a new pawn, a variant change, and a book change seen at open, select or cast end. Warm is **not** proof that the
native slice is current; a book change away and back between checks is not observed. Only slot 0 of the visible
book is ever considered: no search, book/page change, Server_UpdateSpellData or permanent assignment.

## Receipts

`castDev.csv()` (all fields), `castDev.report()` (min/median/p95/max per variant/path/eligibility/warm/status),
`castDev.status()`, `castDev.reset()`. Ring of 256 receipts; overflow is counted. Times are Lua `os.clock` deltas
whose resolution in the game process is not yet measured. `complete=1` only for `finished`/`refused`; `aborted` rows
(reopen, rebind, shutdown, error) are not samples. Phases: prepareUs, eligibilityUs (outside the path for legacy,
`eligibilityInPath=0`), bindUs, handoffUs (input release, mute, SelectSlice, requirement text), restoreUs. targetMs
is sampled at tick granularity; pendingMs includes the player's aiming. Neither is CPU cost, and both use the mod's
`elapsed` clock (summed `os.clock` deltas), which is not proven wall time until the native clock calibration.
`report()` summarises prepareUs, eligibilityUs, bindUs, handoffUs, restoreUs, targetMs and pendingMs per group;
groups keep the status, so aborted rows are never pooled with finished/refused samples.

## Measurement switch

`castDev.measure(false|true)` (same guards as `set`; on by default with dev.txt). Off skips every clock, receipt,
counter and the legacy diagnostic eligibility compare, while the chosen variant keeps operating. Instrumented phase
sums are not a frame result: compare the variants with measurement off, same PID and cold launches, using an
external frame-time capture, and use receipts only to attribute paths, hit rate and in-code phase cost.

Offline counts per cast (simulated objects, measurement off, select key through cast end; not timing):

| | notify | slot reads | slot writes | book reads | IsValid | GetAddress | total |
|---|---|---|---|---|---|---|---|
| legacy / release, hit | 2 | 4 | 1 | 2 | 9 | 6 | 26 |
| legacy / release, miss | 2 | 4 | 0 | 2 | 9 | 6 | 25 |
| restore-only, hit | 1 | 2 | 0 | 1 | 5 | 4 | 15 |
| restore-only, miss | 2 | 4 | 0 | 2 | 11 | 8 | 29 |
| same-slot, warm hit | 0 | 1 | 0 | 2 | 3 | 2 | 10 |
| same-slot, miss (cold hit +1 write) | 2 | 4 | 0 | 3 | 11 | 8 | 30 |

Totals include 1 HighlightSlice and 1 SelectSlice on every path. Miss overhead vs legacy: +4 calls (restore-only) or +5
(same-slot, +1 book read at cast end), plus 1 book read per wheel open while same-slot is warm. A notify ignored
by the game adds 1 notify, 1 forced write, 1 highlight and 2 slot reads in every variant.

## Coverage

Offline, `tests/cast_variant_test.lua` (simulation): gating without dev.txt; per-variant call counts for hit, cold,
miss and ignored notify; all four books; cancel, confirm, held click, refusal, closed cooldown notice; newer server
update; warm reset cases; empty/invalid slot 0; non-zero RadialSlice_0.SpellSlotNum; switch refusals; aborted
receipts; ring bound; CSV. The mock SelectSlice reads the slot array directly, so it cannot model stale native
slice/UI state, which is the actual uncertainty. Existing `runtime_test.lua` covers legacy only.

Native, pending (needs a leased host and admission): first cast after cold launch on a slot-0 hit, book changes,
mouse and controller, instant/aimed/placed/movement-then-cast, refusals, newer server update, reload; os.clock
resolution and instrumentation overhead; paired timing and frame time. No gain is claimed.
