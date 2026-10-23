# Cropped artwork: evidence and remaining gates

2026-10-23. Baseline: 0.4.5, `320ebdde44f37470ed432d06d952ff1b11ac53fe`.
Cropped-art implementation: `67e7024fb66ed3b8a575c58742b3298d6bc7c198`. PR6 integration and rune-cache correction: `5a6a048`, `00e98ac`. See [performance-integration.md](performance-integration.md) for the three-arm scope and additional tests.
This is an unreleased candidate. Native validation, game performance measurements and the showcase are pending.

## Implemented

The six procedural textures retain the original pixel functions and sample coordinates, but draw only their
cropped rectangles. The view uses matching widget rectangles and rotates each sector around the original wheel
centre. Crops include nonzero RGB even at zero alpha, with a four-pixel transparent margin wherever the original
frame permits it. The active spell glow already touches the original top edge; that edge is preserved.

Versioned `Assets/v2/` caches coexist with the original cache without overwriting it. Input release samples the
five buttons it actually reads instead of all 17 navigation inputs. Quiet timing, model hit tests, casting,
cooldowns and controller lifetime checks are unchanged by the crop/input change. The later integration ports reviewed community PR6 improvements with contributor credit, as documented separately.

## Offline validation

The coordinator independently reran `python tests/run.py` using Python with lupa 2.8 / Lua 5.4. All checks passed:

- Lua syntax, catalogue, model, controller, input, runtime adapter, view performance and brush retention.
- All six crops, pasted back into a zero-filled full frame, equal the baseline generator byte for byte.
  The frozen `tests/reference/art-v1.lua` equals baseline `Scripts/art.lua` (SHA-256
  `2fb52203e3608d850c819993eed309e33114d7b82671697ea604484d6b4cfb5e`).
- 9,876 mathematical placement checks for actual skill/spell branches and a 360-degree sweep, in both pivot and
  offset placement modes; tooltip texel centres; existing 3,078 layout containment checks.
- Cache creation, repeated reuse, stale stamp, missing/truncated/wrong-size files, and alternating v1/v2 reuse.
- Five queries per release-drain tick, held-button protection, eight quiet ticks, forced release without polling,
  and unchanged 17-query full navigation sampling.
- `python tools/package.py --output-dir <temporary directory>` verified 18 ZIP entries against the production
  manifest, with `.lua` and `.txt` extensions only. No test/reference files or generated PNGs ship.

| Quantity | Baseline | Candidate |
|---|---:|---:|
| Decoded RGBA bytes, six textures | 15,580,160 | 1,453,872 |
| Generated PNG cache bytes | 15,586,165 | 1,455,461 |
| Native key queries per input-release drain tick | 17 | 5 |

Decoded byte counts are not measured GPU allocation. Smaller widget area is a mechanism to reduce transparent
overdraw; GPU cost and game frame times have not been measured for this candidate.

`python tools/art_metrics.py 5` independently measured fresh `art.ensure` in temporary directories, interleaving
baseline and candidate on the same Linux/Cuttle host with Lua 5.4. This is static artwork generation, not video
processing or a game benchmark. No engine was running.

| Offline generation time (ms) | Run 1 | Run 2 | Run 3 | Run 4 | Run 5 | Median |
|---|---:|---:|---:|---:|---:|---:|
| Baseline | 1357 | 1311 | 1340 | 1350 | 1374 | 1350 |
| Candidate | 599 | 591 | 623 | 601 | 591 | 599 |

These timings show less work in this local generator. They do not establish game startup time or FPS gains.
The view-performance simulation compares against a historical 0.4.2 reference: 5090-to-1980 before PR6 integration, 5090-to-1998 after it (immediate rune queries add work on first hover). These are simulated scenario counts, **not native timing gains from this PR**.

## Native gates before readiness

- Validate the default render pivot outside the widget rectangle on UE 5.6, including every skill/branch,
  highlights, glow edges, tooltip, mouse hit points, controller navigation and multiple resolutions.
  If unsupported, use `R.placement='offset'` and rerun the same checks; only its mathematics is tested so far.
- Test cast/cancel, input release and fast reopening, native cooldown state while closed and timer on reopen.
- Verify repeated controlled reloads with the same PID, complete source hashes, safe input release and a single
  active generation; then validate a fresh process with absent caches and with existing v1 caches.
- Measure interleaved clean-process Main `320ebdd` / pristine PR6 `81e1e038` / integrated PR7 runs on one fixed machine, scene and settings, initially three 30–60 s repetitions per representative case. Stock and AllSpellsOneWheel 1.0.1 are optional secondary controls. Never load both wheels together.
- Report per-run p50/p95/p99/p99.9, maxima and hitches, run ranges and CPU/GPU busy where supported. Recording
  runs are separate from benchmarks. Preserve null or regressing results rather than claiming an uplift.
- Record and produce the requested motion showcase using the `kevinbadi/claude-motion-skills` catalogue and
  selected motion/data-animation packs. Label the split-screen comparison “Same PC · separate runs · 1× speed”.
  Any simultaneous two-player proof is a separate shot and needs two admitted clients.

At integration review, SudoBlade is under a single coordinated tester preparing a full game backup on NAS before Steam admission/update. Its Windows harness passed23 checks. No client benchmarks or recordings have run. nJoyDesk's absolute TradeTesterB no-relaunch/Cloud-choice hold remains.
All video compute remains restricted to verified nJoyDesk or SudoBlade. The showcase is not yet attached.

## Iteration and scope

Use full Scripts sync after syntax checking, verify hashes, then invoke the established BSW game-thread `dofile`
reload. Never use UE4SS Ctrl+R. Source switching keeps both cache generations. Existing shutdown retains hidden
widgets, so repeated reloads can accumulate resources: reported comparisons must use cold processes. Restarting
for benchmarks is deliberate isolation, not an assertion that ordinary Lua iteration requires it.

This PR is not a release: no installer was rebuilt, no installer integration tests were run, and nothing was
merged, deployed or published to stores. Final packaged cold-load and installer checks remain release gates.
