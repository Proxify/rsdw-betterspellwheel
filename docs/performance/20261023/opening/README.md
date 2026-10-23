# BSW opening-hitch driver and event analysis (session 115173b7)

Source/offline tools only. Not executed on any host. **Native acceptance of the driver belongs to the Blade operator (712).** No media, Lua injection, mod change or recording is involved.

Files:
- `opening-driver.ps1`: Windows PowerShell 5.1 Q-tap driver.
- `opening_analyze.py`: strict QPC event-window analyser.
- `test_opening_analyze.py`: 14 fixture tests (all pass offline with python3 -I; every rejection path checked for its intended message).

## What it measures

Frame times around a bounded number of **intended** wheel open/close taps (Q down/up toggles the wheel on Main/PR6/PR7, as 712 verified). It does NOT measure input-to-render latency and does not prove the UI opened; the operator's pre/post state proofs cover that. It targets the opening hitch (the catalogue-cache change), which is a separate question from steady-open FPS. The existing steady captures (default ms schema) are untouched, and the shared `native-harness/analyze.py` keeps rejecting QPC CSVs.

## Time base (verified in source, not by column name)

PresentMon v2.6.0 `PresentMon/CsvOutput.cpp` (FrameMetrics header writer l.531–623, row writer l.942–945 and l.1004): with `--qpc_time` the default CSV has `TimeInQPC` and `CPUStartQPC`, both raw `%llu` QueryPerformanceCounter ticks, instead of `TimeInMs`/`CPUStartTimeInMs`. The driver brackets every injection with `[Diagnostics.Stopwatch]::GetTimestamp()` and refuses to run unless `Stopwatch.IsHighResolution` (QPC) holds. It logs `Stopwatch.Frequency`. Both clocks are in one domain, so no UTC alignment is guessed. The analyser parses ticks as integers, and ms = ticks × 1000 / frequency.

## Definitions (reported with every result)

- Two interval series, **each analysed on its own intervals** (row attribution verified on the native C1 warm calibration sample: 2,600 intervals per series, median and max |diff| = 0.0000 ms; the wrong orientation does not match):
  - CPU (primary): row i = [CPUStartQPC_i, CPUStartQPC_{i+1}), value `MsBetweenAppStart_i` (**same row**; the last row has no end).
  - Present: row i = [TimeInQPC_{i-1}, TimeInQPC_i), value `MsBetweenPresents_i` (**preceding row**; the first row has no start).
  - Presents are never selected through CPU intervals. A present interval can overlap a window while the same row's CPU interval does not, and vice versa (fixture `test_present_interval_attributed_by_its_own_interval`). Raw rows are unchanged.
- Event = one logical tap: [down.qpcBefore, up.qpcAfter]. Each injection keeps its own bracket (widths reported). Its own key-up is part of the event, not a separate transition.
- Window = [down.qpcBefore, up.qpcAfter + 750 ms]. Per series, it includes **every interval overlapping it**, including one that started before the tap.
- Baseline = per series, the intervals wholly inside [down.qpcBefore − 1100 ms, down.qpcBefore − 100 ms]. Excess = window max − baseline median, for MsBetweenAppStart, MsBetweenPresents and the CPU-start interval derived from adjacent `CPUStartQPC` ticks. Per run, `qpc_mapping.cpu` and `qpc_mapping.present` report each series' median/max |tick interval − its metric|. Both must be ≈0 before numbers are trusted (C1 warm calibration: both 0.0). `fixtures/c1-native-head.csv` (first 80 native rows, from C1-opening-warm.csv SHA256 da3a26b25fa549d3…) is a regression test for this. Flags at ≥50 and ≥100 ms.
- Labels:
  - first open: `first-in-process` only with operator sidecar `coldProcess=true` + `noEarlierOpenProof`; `warm-proven` with `earlierOpenProof` (e.g. D1, where an earlier opening already occurred); else `first-unproven`.
  - later opens: `warm-proven` only with `openingsObserved=true` + proof; else `repeat-intended`.
  - closes: `close-intended`.
- Art-cache condition (`present` / `absent-before-run`) is part of the comparison context, so the two are never pooled.

## Rejections (fail closed)

Malformed or missing inputs:
- wrong schema/case/label;
- capture flags not exactly the pinned default-metrics `--qpc_time` set (`--qpc_time_ms`, `--date_time`, `--v1/--v2_metrics` refused);
- forbidden ms/second/date time columns, a missing required column, or a CSV header differing from the receipt;
- non-integer or non-monotonic `CPUStartQPC`;
- NA/non-finite `MsBetweenAppStart`/`MsBetweenPresents`;
- no rows for the receipt PID;
- missing or incomplete operator sidecar (pre/post state proof, art cache).

Failed or mismatched runs:
- failed capture (exit, alive, payload-after, activation);
- missing `configDigestPolicy`;
- driver status not `complete`, with the reason reported (this covers lost focus, identity change, SendInput≠1 and go timeout);
- wrong injection count/order;
- non-monotonic or non-integer brackets;
- a safety key release in a "complete" run;
- driver host/PID/procStartUtc/exe hash not matching the receipt.

Timing and comparison:
- an event's baseline+window overlapping another event's;
- a capture not covering every baseline/window;
- a sparse window or baseline;
- in the table, mixed wheel payloads within one context/arm.

Comparison context = computer, client build, exe hash, schema, capture settings, scene, **effective** `configDigest` + `configDigestPolicy`, UE4SS ini hashes, other-mod digest, non-wheel mods.txt lines, CSV header, driver hash/params and art cache. PID and procStartUtc identify the run but don't split context.

## Driver invocation (operator 712, sarah session)

1. Prove the scene: wheel closed, correct input mode, gameplay focus (existing scene probe + screenshot). No SetForegroundWindow is ever used.
2. Start the driver: `cu "run powershell.exe|-WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Users\Public\<task>\opening-driver.ps1 -GamePid <pid> -ProcStartUtc <Get-Process StartTime UTC 'o'> -ExeSha256 <hash> -ExpectHost SUDOBLADE -Out C:\Users\Public\<task>\runs\<label>.events.json"`.
3. The driver does all setup first (self hash, exe hash, Add-Type, identity, focus) and writes `<label>.events.json.ready`, then waits at most 30 s for `.go`.
4. After `.ready` appears, start the capture: bench `capture -QpcTime -Case opening -Seconds 30 ...` (see `BENCH-QPC-SUGGESTION.md`). Once PresentMon is running, create `<label>.events.json.go`.
5. The driver's timeline after go: fixed 4000 ms lead, then 3 cycles × (open tap, 2000 ms, close tap, 2500 ms) ≈ 18.2 s, inside the 30 s capture. The analyser's coverage check rejects any run where it didn't fit.
6. Prove the post state (wheel closed, focus). Copy the CSV, receipt and events JSON, and write `<label>.opening.json`.

Defaults: `-Cycles 3` (1–4), `-HoldMs 120`, `-OpenDwellMs 2000`, `-ClosedGapMs 2500`. The total after go must stay ≤ 30 s, or the driver refuses. The lead is fixed at 4000 ms as assigned. 712 preferred 3000; with the ready/go gate the startup margin no longer depends on the lead.

## Limits

- `opening-driver.ps1` is not parse-checked here (no PowerShell on the Cuttle host). 712 must parse-check it, then run one dry run against the game, before any accepted capture.
- Guards: 64-bit PowerShell only (the INPUT struct is laid out for x64); no key down if Q is already held (GetAsyncKeyState high bit); no key up unless our own key down is pending; the existing-output refusal runs before any write. The table reports `events` and distinct `process_runs` separately: events within one process are not independent repeats. `qpcFrequency` and `cycles` (integer 1–4) are validated, and `qpcFrequency` is part of the context.
- Q taps go to whatever has focus. The driver aborts if the foreground window is not owned by the game PID before each key down/up. A focus change *between* the check and SendInput (microseconds) cannot be excluded; post-state proof covers it.
- Frame times are CPU-start to CPU-start (MsBetweenAppStart) and present-to-present (MsBetweenPresents), not GPU-only time.
- No cold label without operator proof. D1 is warm-only (an earlier opening occurred); C1 can be cold only if the driver is ready before any opening.
