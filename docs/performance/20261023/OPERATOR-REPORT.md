## Independent test results — Main vs PR6 vs PR7

Tested Main `320ebdd`, pristine PR6 `81e1e038`, and PR7 `a8553ad` (runtime `00e98ac`). **Results are mixed; this does not establish an overall performance win or a fix for dmhenri’s reported slowdown.** No merge/release approval implied.

### Native measurements

SudoBlade: i9-13950HX / RTX 4080 Laptop / 32 GB; game build 26162923; UE4SS f6d5f942 with successful hash-table self-test, UObjectArray cache off. 2560×1600 borderless, DLSS Auto Quality, frame generation/VSync off, uncapped; mod PerfLog and recording off. Same isolated Standard character/world, 39 test-unlocked spells and frozen 48-slot fixture; identical source/config/scene checks. Three interleaved cold-process repeats per arm, 30 seconds per case: **27 steady captures**. PresentMon 2.6.0 receipts retain PID, timestamps, hashes, schema and post-capture checks.

Median of the three per-run p99 frame times, milliseconds (lower is better):

| Case | Main | PR6 | PR7 |
|---|---:|---:|---:|
| Wheel closed | 14.21 | 14.14 | 13.93 |
| Wheel open, stationary | 14.52 | 14.29 | 13.81 |
| Pointer navigation | 17.46 | 16.43 | 17.29 |

Closed p50 was approximately 10.5 ms for every arm. No sustained closed-wheel collapse reproduced on this setup. All hitches were retained, including PR7's 77.3 ms closed and 79.7 ms navigation frames; no best-run selection.

**Preconditioning limitation:** first PR6/PR7 blocks opened directly; later blocks included opening cycles before steady open/navigation. Matched-sequence sensitivity (Main n=3, PR6/PR7 n=2) gives open p99 **14.523 / 14.621 / 13.878 ms**, and navigation **17.457 / 16.428 / 17.431 ms**, respectively. PR7's open-idle improvement survives this check; navigation is worse than PR6. Daylight/weather and time in world drifted; these are small-sample observations, not confidence-bound causal estimates.

**Separate Q-event captures:** seven cold processes (Main3 / PR6 2 / PR7 2), QPC-aligned real Q inputs, no recording. CPU and presentation interval mappings independently verified. Worst repeated-open CPU interval per process: Main **13.40–15.49 ms**, PR6 **13.82–16.33 ms**, PR7 **22.97–25.92 ms**. First-in-process maximum across runs: **18.74 / 21.80 / 24.48 ms**. PR7 improved the sampled close-event maxima (**15.68 ms**, vs Main26.28/PR6 25.81), but its opening-event result is worse here. These are event-window hitches, **not input-to-render latency**; individual taps are not independent process samples.

### Functional and offline checks

- **PASS, native:** cold binding; real Q/mouse Attack and outer Tempest Shield hit/cast; cooldown updating while closed; early native cooldown refusal; return to gameplay.
- **PASS, PR7 native default-mode lifetime path:** actual menu exit/rejoin in the same PID; controller, pawn and radial addresses all changed; real Q/Attack worked afterward with the 39-spell catalogue. This is solo rejoin, not multiplayer proof.
- **Partial:** real navigation and sampled crop alignment, rapid Q cycles, default and temporary live `KeepNativeHidden=false` recordings. Sparse recording cadence cannot exclude single-frame native flashes. This does not establish every sector/hit or native-panel replacement in both settings.
- **Not tested fully:** cast cancellation, live unlock/perk/rune-cache invalidation, physical controller hardware, simultaneous two-client behavior. No blanket pass inferred from offline tests.
- **PASS, offline:** each arm's own test suite; PR7 14-check suite; production package 18 entries, only `.lua`/`.txt`. Identical old Main controller-replacement fixture passes Main/PR7 and fails pristine PR6. That is an offline lifetime regression, **not a native crash claim**.

The supplied reporter log used UE4SS0196ef29 and different AMD hardware. Its profiler adds lookup work, so we used external captures with PerfLog off. Stock/0.4.3 diagnostic packages were staged but **not measured natively**; no reproduction/fix claim for that reported comparison.

Separate 1× illustrative takes were captured after each final timed block. Their sparse capture rate is not game FPS or smoothness evidence. Raw CSVs, immutable receipts, event logs, hashes and recordings are retained; calibration and the earlier config-policy sample are excluded from the comparison.

Cleanup: original157 mod files,265 nonvolatile Saved files and mods.txt restored and hash-verified, including a second verification after Cloud sync. Steam Cloud restoredON; one normal Retry Sync succeeded (ChangeNumber159), no local/cloud copy choice. Game/Steam/recorders exited normally. Updated game26162923 and matching appmanifest retained together. Verified NAS archives preserve rollback/evidence; all owned remote staging/test directories and processes are removed. Local disposable environments, source/package staging and duplicate full-resolution screenshots were removed after archive verification.


## Retained evidence

- `runs/`: 27 comparable steady CSVs, receipts and scene probes; `final-table.json`.
- `opening-runs/`: seven comparable QPC captures and event/order receipts; `opening-final.json`.
- `supplementary-B1/`, `calibration/`, `opening-calibration/`, `opening-dry/`: explicitly excluded or supplementary tool/earlier-context evidence.
- `FUNCTIONAL-MATRIX.md`: bounded native coverage and missing gates.
- `screenshots/`: review JPEGs; full-resolution originals verified on NAS.
- Project `dist/bsw-pr712-native/`: three raw illustrative takes, event/hash/decode evidence, alternate-setting clip and generated art for producer. Polished showcase coordinated by BSW root; pending its delivery at this report revision.
- `cleanup-final.txt`, `cloud-retry-log.txt`, `END.txt`: restored file counts, successful Cloud sync and released Blade ownership.

NAS rollback/evidence retained at `/volume1/Public/Backups/sudomagic2/rsdw-mods/native-rollback/prtest712-sudoblade-25994193`: original549-file game and305-file state rollback; final669-file task,91-file tools and179-file screenshots archives, each verified against per-file SHA manifests. Retain rollback until the updated game is accepted; retain cited evidence through PR review. No worktrees created. No production deployment or release. Local temporary venv/source/package staging/cache removed. Updated game26162923 and matching appmanifest intentionally retained; test saves/mods/configs restored.
