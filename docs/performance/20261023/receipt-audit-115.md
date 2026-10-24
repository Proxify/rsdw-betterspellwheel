# Receipt audit (session 115173b7, source/data only, 2026-10-23)

Scope: read-only audit of the raw evidence copied to `coordination/pr-comparison-712395b3/`:
- `runs/` steady captures: B2, B3, C1, C2, D1, D2 × closed/open/nav;
- `opening-runs/`: B2, B3, C2, D2;
- `opening-calibration/`: C1 warm.

No host access, no video work, no harness/runtime edits; raw files untouched. **This is not a final comparison.** C3/D3 and any later blocks were absent at audit time, and no arm verdict is made here.

Tools, kept beside this file: `receipt-audit-115-receipts.py` (receipt table) and `receipt-audit-115-recompute.py`. The recompute script independently recomputes the numbers from raw CSV/events with nearest-rank percentiles and **does not import** analyze.py or opening_analyze.py.

## Identity: consistent

- Every one of the 23 receipts has:
  - the same host (SUDOBLADE), client build 26162923 and exe A1BA2F51…;
  - effective configDigest 0239868C… (policy exclude-top-level-CrashReportClient-only-v1);
  - `otherMods` = {} and otherModsDigest 44136FA3…, which is SHA256 of the empty map `{}`: no other mod folder was present in Mods;
  - non-wheel mods.txt lines `PlayerTrading : 1, FrameProbe : 1` are preserved;
  - scene `standard-temple-fixture-v1`, 60 s warmup and 30 s captures;
  - activation ok, aliveAfter true, payloadAfterOk true and PresentMon exit 0. The pm.logs say only "Started/Stopped recording".
- Payload per arm: one wheel digest per arm, and `Scripts/main.lua` matches git:
  - B = 320ebdd `be0e3c3e…`, D = PR6 81e1e038 `dc244587…`, C = PR7 a8553ad `52e9d250…`.
  - Generated art: B and D use `Assets\*` (7 files) and C uses `Assets\v2\*` (7 files), identical lists within each arm, so the caches are isolated.
- Scene: across all 18 `.scene.txt`, PRE and POST each show one position and one rotation, paused=false, and the expected wheel state and input mode (closed = DIM_Gameplay, open/nav = DIM_RadialMenu).
- Same-process relationships: each block's closed, opening, open and nav captures share one PID and procStartUtc. Opening driver logs:
  - match their receipt's host, PID, procStart and exe;
  - driver e0d3305e…, status complete, 3 cycles, no safety release;
  - go→first tap 4045–4052 ms; the first SendInput bracket is 8.3–9.7 ms, later ones are sub-ms.

## Arithmetic and orientation: no errors found

- **Steady** (MsBetweenPresents, receipt PID, main swap chain, all rows): for all 18 runs, my n, p50, p95, p99, p99.9 and max equal `review/primary-in-progress.json` exactly (worst |diff| 0).
- **Opening** (raw integer ticks, 10 MHz): I rebuilt the windows myself.
  - Definition: CPU interval [cs_i, cs_{i+1}) with value MsBetweenAppStart_i; present interval [tp_{i-1}, tp_i) with value MsBetweenPresents_i; window [down.before, up.after + 750 ms] by overlap; baseline wholly inside [−1100, −100] ms.
  - Max |tick interval − metric| is 0.0000 ms for both series in all 4 runs.
  - All 24 events (max, excess and window counts for both series) match `review/opening-in-progress.json` within 1e-3.
- Event coverage margins: first tap 4.42–4.45 s after capture start; last tap 13.49–13.54 s before capture end.

## Confounds the analyser grouping does not capture

1. **Block 1 and blocks 2/3 have different histories.**
   - Order per process: blocks 2/3 run closed (game t≈70 s), then the 6-tap opening capture (t≈120 s), then open (t≈211 s) and nav (t≈272 s). Block 1 (C1, D1) has no opening capture: open starts at t≈142 s and nav at t≈201 s.
   - So the open/nav cases differ between blocks in prior wheel openings and in game time / time of day. The context hash cannot see either, because the scene id is the same.
   - Effect, observed rather than attributed: nav p99 is 13.6 ms in C1/D1 but 16.4–17.7 ms in B2/B3/C2/D2. That difference between blocks is larger than any difference between arms within a block.
   - This difference was prespecified before the C2/D2/B3 results (`review/PRECONDITIONING-NOTE.md`). The **full table keeps all cold-process samples per arm**, D1/C1 included, with the reason stated. The **matched-protocol open/nav comparison** excludes D1/C1 and uses only the prespecified later blocks; this audit agrees with that rule and is not a reason to drop samples. Closed is comparable across blocks (t≈70 s in all).
2. **Steady "open" is never a first opening.** In blocks 2/3 it follows the opening capture's 3 opens in the same process; in block 1 the operator's opening precedes it. So the steady open/nav numbers say nothing about first-open cost. That comes only from the opening `first-in-process` events, one per cold process. So far: Main n = 2 (B2, B3), PR6 n = 1 (D2), PR7 n = 1 (C2).
3. **Arm order is not yet counterbalanced.** Chronological order: D1 20:14, C1 20:19 (+C1-warm 20:28), B2 20:30, C2 20:40, D2 20:47, B3 20:54; C3/D3 pending. Thermal or time drift is confounded with arm until the blocks are complete.
4. **Other mods and background processes (corrected).** The `PlayerTrading : 1` / `FrameProbe : 1` lines remain in mods.txt, but 712 parked both folders outside Mods for every arm (STATUS.md 19:29Z: "moved to task/parked-other-mods"). `otherMods` is the empty map in every receipt, so neither was loaded and no FrameProbe loop ran. A pre-existing **PresentMonService, PID 2576** (started 2026-10-15, per hardware.txt; untouched per STATUS.md 20:41Z) ran on the host during all captures. It is a separate ETW consumer present equally in every arm, recorded here as a background condition and not measured.
5. **Upscaler and render resolution (corrected).**
   - The UI shows DLSS Best / Auto quality, borderless 2560x1600, VSync off, frame generation off, and a "Dynamic" frame-rate cap.
   - `graphics-receipt.txt` records `GameFrameRateLimit=0` (the UI "Dynamic" cap means no fixed game cap, not dynamic resolution) and `bUseDynamicResolution=False` (l.97), with UpscalingMode=5. The ini still remembers 2048x1280 while the actual window is 2560x1600 (UI/ini distinction as recorded by 712).
   - The same settings and the same effective config digest apply in every arm. DLSS's actual internal render resolution was not measured, so whether "Auto" quality stays constant during a run is unknown. Active dynamic-resolution adjustment is **not** claimed.
6. **Single-frame maxima and close events are noisy** (small first-open counts as in item 2). Closed-case maxima of 52.8 (B2), 55.6 (C1) and 61.7 ms (D2) are single frames. In the opening runs, many close taps show a 23–26 ms frame (B2, B3, D2 and C2#3), and open #1 excess is 7.6–10.3 ms. With one first-open per process, no arm ranking is supportable yet.
7. **Labels hold, with one caveat.** `first-in-process` rests on the operator sidecar (cold PID, only the closed case before), which is consistent with the receipts' order. Its `artCache` is "present" in every run, so the first opening is first-in-process, not first-ever art generation.

## Not checked

- Screenshots/visual state: pre/post proofs were taken as recorded text only.
- Graphics settings inside Config, beyond the digest.
- Host thermal and power state.
- PresentMonService 2576's own CPU cost.
- The B1 supplementary runs, which are excluded by the operator.

## Retained

This file plus the two audit scripts. My scratch (/tmp/bsw115-audit) is deleted.

---

# Final audit: all 27 steady + 7 cold opening runs (session 115173b7, data only)

The interim audit above covered the earlier subset; it is kept unchanged as provenance. This section covers the final set.
- Inputs:
  - `review/primary-final.json` dbb41184…, identical to `pr-comparison-712395b3/final-table.json`;
  - `review/opening-final.json` 726a2662…;
  - `review/accepted-runs.json` 0d835de4…;
  - `review/NATIVE-RESULTS.md` ee854e82…;
  - `summarize-final.py`.
- Tool: `receipt-audit-115-final.py`, independent and importing no analyser. Its full output is in `receipt-audit-115-final-output.txt`.

## Verified, no discrepancies

**Identity.**
- All 34 receipts share one value each of host, build, exe, effective configDigest + policy, otherModsDigest (= `{}`), scene and UE4SS ini.
- All have PresentMon exit 0, alive, payloadAfterOk and activation ok.
- Each arm has one payload and `main.lua` matches git (B = 320ebdd, D = PR6 81e1e038, C = PR7 a8553ad). Generated art: 7 files per arm (v1 for B/D, v2 for C).

**Processes and scenes.**
- Each of the 9 cold processes holds exactly one arm. Order within each process: closed, then opening (blocks 2/3), then open, then nav.
- Process order: D1, C1, B2, C2, D2, B3, D3, B4, C3.
- All 27 scene files show one position and one rotation, paused=false and the expected wheel state.

**Steady.**
- For all 27 runs, my nearest-rank n/p50/p95/p99/p99.9/max of MsBetweenPresents equal primary-final.json exactly, and the ≥50/≥100 ms counts match.
- All 9 arm×case full-table medians (p50/p99/max) equal root's summary.

**Opening.**
- All 7 driver logs are complete, use driver e0d330 and match their receipt identity, with every SendInput = 1 and no safety release.
- CPU and present mappings have max |diff| 0.0000 ms in all 7 runs. All 42 events (max, excess and window counts for both series) match within 1e-3. All runs share one opening context (552b7246d94d).

**Selection** (`accepted-runs.json` / summarize-final.py) follows the prespecified rule (PRECONDITIONING-NOTE.md):
- closed: all 3 per arm (C1/D1 included);
- open/nav: B2–B4 vs D2–D3 vs C2–C3;
- supplementary: B1-*, C1-open/nav, D1-open/nav;
- full table: all 27 samples.

**NATIVE-RESULTS.md math.** Recomputed from my own numbers:
- matched p99 medians and ranges for all 9 cells;
- open p99: PR7 13.877 vs Main 14.523 (−4.45%) and PR6 14.621 (−5.09%); the ranges don't overlap;
- nav p99: PR7 17.431 vs PR6 16.428 (+6.1%) and Main 17.457 (−0.15%); PR7 and PR6 ranges don't overlap;
- Q-event first open (18.139 / 20.797 / 22.700), worst repeat open (14.332 / 15.076 / 24.444) and worst close (26.113 / 25.414 / 15.212) for Main / PR6 / PR7, medians and ranges;
- no window ≥50 ms (max of any window: 26.28 / 25.82 / 25.92 ms).

**Reproducibility.** Re-running `summarize-final.py` on copies in a temp dir reproduces `accepted-runs.json` and `NATIVE-RESULTS.md` byte-identically. I did not run it in place, because it rewrites both files.

## Wording/provenance issues (not arithmetic)

1. **Headline overreach:** "Q-event frame gaps are longer than both baselines". That holds for the open events (first and repeat), but PR7's worst close-event gap is **shorter** (15.212 vs 26.113 / 25.414 ms), as the Interpretation section says. Suggested: "Q-open event gaps are longer than both baselines; close-event gaps are shorter."
2. **Manifest field names:** `analyzerSha256` and `openingAnalyzerSha256` hold the SHA256 of the result JSONs (primary-final.json dbb41184…, opening-final.json 726a2662…), not of analyser source. Either rename them (e.g. `primaryResultSha256`), or add the analyser source hashes (shared `native-harness/analyze.py`; `opening/opening_analyze.py` 6e290ab4…).
3. **"The reporter's severe closed-wheel slowdown is not reproduced":** no BSW-absent (stock) arm is in this three-arm set. The data only show no large closed-wheel difference *between the three BSW builds*; they cannot compare against the game without the mod. Suggested: add "between these builds; no mod-off baseline was measured in this set".
4. **Metric naming:** state that the steady p99 is MsBetweenPresents (present-to-present), while the Q-event values are CPU-start intervals (maxQpcIntervalMs). The two tables use different series.

## Limitations (unchanged or final)

- One PC.
- n = 3/2/2 processes (Main/PR6/PR7) for matched open/nav and the opening events; n = 3/3/3 for closed. Ranges, not confidence intervals.
- Arm order is interleaved but not fully counterbalanced (see the process order above).
- Steady open/nav are never first openings.
- First-in-process openings had the art cache present.
- DLSS Auto quality with internal render resolution unmeasured; dynamic resolution was off.
- The pre-existing PresentMonService (PID 2576) ran during all captures.
- Not checked: screenshots, thermal/power state, and B1 supplementary content.
- No casting-reuse data.

## Retained

- This file (interim + final sections);
- `receipt-audit-115-receipts.py`, `receipt-audit-115-recompute.py` (interim);
- `receipt-audit-115-final.py` and `receipt-audit-115-final-output.txt`.

Raw evidence and root outputs are untouched; scratch is removed.
