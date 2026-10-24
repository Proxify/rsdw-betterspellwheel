# BetterSpellWheel: native three-build comparison

Status: numeric collection complete. See NATIVE-RESULTS.md for mixed findings; functional acceptance remains partial.

| Role | Source | Payload digest recorded by harness |
|---|---|---|
| Main / 0.4.5 | 320ebdde44f37470ed432d06d952ff1b11ac53fe | 506f69ac057c4c70 |
| Pristine community PR6 | 81e1e0383c59d5d854eb83176a6f2af87f327370 | 8a6ab99f4fa409c7 |
| Integrated PR7 | a8553adf90182f4bdd0168c30f07c900825fe73b | 39dc0bd8c57001dc |

PR7 runtime is00e98ac; a8553ad changes test documentation only. A later review-media/documentation commit does not change the tested runtime. Casting59a98b1 is separate and has no native result in these measurements.

## Environment and fixture

All primary measurements use the same SudoBlade: i9-13950HX, RTX4080 Laptop,32GB RAM, driver32.0.16.1047; client26162923/protocol254097. Game executable SHA256 A1BA2F510458B47BDDA073658AE8795036F32D4753169A05C96610C51BD1B29F. UE4SS f6d5f942, DLL D936FD2D66AE9287F0B32AEC5F698AA81FF20EF744EAC43BF62D8475469393DF, hash-table selftest passed. Frame generation/VSync off, Dynamic cap,2560x1600 borderless. Full receipt supplies graphics/config hashes.

Disposable Standard MODTEST/TradeTester,39 test-unlocked spells, seeded runes and a frozen39-filled/48-slot loadout; this is actual native gameplay with an explicit test fixture, not normal progression. Original player saves were isolated and backed up. Fixed measured spawn position and camera, unpaused gameplay checks before/after each capture. Time of day/weather are not pinned; between-case elapsed game time is disclosed. Original PlayerTrading/FrameProbe folders were parked outside the loader across all arms. An unrelated existing PresentMon process2576 remained untouched throughout.

## Measurement method

PresentMon2.6.0 SHA256 B2A706BC6AD475749E3B7E3409263AA1E6906D45BDCF993F6DBC0F660188F1AF; one cold game process per block, exact payload/activation checks before and after each capture. PerfLog off, no recording or console during the measured30-second cases. Initial case follows at least60 seconds of game time. Completed sequence: D1/C1/B2, C2/D2/B3, D3/B4/C3. Each block measures closed idle, intended Q cycles where available, open stationary, and an identical12-point pointer sweep twice. The Q-cycle driver is separate from steady capture.

Steady frame times use MsBetweenPresents for the verified game PID/main swapchain; CPU/GPU busy are separate metrics. Percentiles are per process. Summary values are medians of per-process statistics with min–max run ranges, not pooled-frame confidence intervals. Three processes per arm cannot establish hardware-wide or statistically significant improvement. All >=50/100ms frames stay in the report; no best-run selection.

Config comparison excludes only the top-level CrashReportClient directory because it contains per-process GUID filenames. Full Config digests/excluded manifests remain in raw receipts. D1/C1 open/navigation lacked the later Q-cycle preconditioning. The full table retains all3 runs/arm; the prespecified matched subset uses B2/B3/B4 versus D2/D3 and C2/C3 for open/navigation. Closed idle uses3/3/3. This selection was recorded before C2/D2 outcomes. B1 is supplementary due its older Config fingerprint. Paused/unproven initial calibration and warm C1 QPC calibration are excluded from comparative results; failed attempts remain evidence.

Opening windows are frame intervals around intended Q presses, not input-to-render latency and not proof the wheel visually opened on every tap. CPU-start intervals use adjacent absolute QPC timestamps, with the containing pre-event frame included. Each window runs from the recorded key-down bracket through key-up+750ms, with a separate preceding baseline. CPU and presentation interval mappings are verified independently. First-in-process events stay separate. The optional repeat chart uses the worse of open:2/open:3 for each process, then median and range across processes; taps are not independent repeats.

## Interpretation limits

The reported community35–45FPS regression used a different UE4SS build0196ef29. This Blade test uses f6d5f942 with successful hash-table selftest and has not reproduced a severe closed-wheel difference between these three builds. No mod-off arm was measured, so these results cannot quantify overhead versus the unmodified game or establish that the reporter issue is fixed. Smaller artwork and fewer mocked engine calls are separate, directly verified reductions in work; neither is a measured GPU-memory or FPS result. Native captures establish only the named cases on this configuration.

Full native functionality is tracked separately in FUNCTIONAL-MATRIX.md. Offline controller replacement/removal tests pass Main/PR7 and fail pristinePR6; that is a simulated regression, not a filmed crash. No physical controller or simultaneous two-client acceptance is inferred from keyboard/mouse solo gameplay.

Footage is captured after timings, separately for each build, at1x speed. Any side-by-side video is labelled same PC/separate runs; it is illustrative and does not replace raw measurements. Final report must include exact raw/accepted manifests, functional limits, restoration receipts and the verified video URL.
