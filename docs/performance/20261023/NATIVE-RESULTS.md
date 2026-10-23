# Final native measurements — descriptive results

PR7 is not faster overall in these runs. Its open-idle p99 is lower; closed-idle ranges overlap; navigation is worse than PR6, and opening Q-event frame gaps are longer than both baselines. No statistical significance or causal attribution is established.

All times below are milliseconds. Cells are median [minimum–maximum] across independent cold processes. These are run ranges, not confidence intervals.

Steady percentiles use MsBetweenPresents; Q-event gaps below use adjacent CPUStartQPC intervals.

## Prespecified matched comparison

| Case (per-process p99) | Main | PR6 | PR7 | Processes Main/PR6/PR7 |
|---|---:|---:|---:|---|
| closed | 14.213 [13.928–14.227] | 14.142 [13.929–14.860] | 13.930 [13.838–14.126] | 3/3/3 |
| open | 14.523 [14.382–14.624] | 14.621 [14.287–14.954] | 13.877 [13.806–13.948] | 3/2/2 |
| nav | 17.457 [17.054–17.746] | 16.428 [16.427–16.428] | 17.431 [17.291–17.570] | 3/2/2 |

Open/nav exclude only C1/D1 per the predeclared preconditioning rule; every raw sample remains in the full table below. Closed uses all three runs per arm.

## Q-event windows

The first event is first-in-process with generated artwork already cached, not first-ever drawing. Repeat value is the worse of open:2/open:3 in each process. Close value below is the worst of its three close events per process. These are longest CPU-start intervals around intended key presses, not input latency or visual open/close completion.

| Window statistic | Main | PR6 | PR7 | Processes |
|---|---:|---:|---:|---|
| First intended open | 18.139 [18.065–18.736] | 20.797 [19.792–21.801] | 22.700 [20.921–24.480] | 3/2/2 |
| Worst repeat open/process | 14.332 [13.400–15.493] | 15.076 [13.822–16.330] | 24.444 [22.969–25.920] | 3/2/2 |
| Worst intended close/process | 26.113 [25.504–26.278] | 25.414 [25.014–25.815] | 15.212 [14.744–15.680] | 3/2/2 |

Both CPU and presentation interval mappings have zero maximum absolute difference from their respective CSV metrics in all seven runs. No >=50 ms opening/closing window was observed. The asymmetric open/close gaps are observations, not an identified mechanism.

## All steady samples, without selection

| Label | p50 | p95 | p99 | p99.9 | Maximum | >=50 ms frames | >=100 ms frames |
|---|---:|---:|---:|---:|---:|---:|---:|
| B2-closed | 10.5294 | 12.7963 | 14.2135 | 25.6093 | 52.8477 | 1 | 0 |
| B2-nav | 11.1391 | 14.0877 | 17.0540 | 27.5844 | 75.6203 | 1 | 0 |
| B2-open | 10.9040 | 13.0361 | 14.3819 | 25.5569 | 27.4654 | 0 | 0 |
| B3-closed | 10.5161 | 12.5572 | 13.9285 | 25.7418 | 28.4288 | 0 | 0 |
| B3-nav | 11.2413 | 15.3869 | 17.7461 | 30.0078 | 49.9827 | 0 | 0 |
| B3-open | 10.9158 | 13.0455 | 14.5230 | 28.2622 | 31.1808 | 0 | 0 |
| B4-closed | 10.5603 | 12.5841 | 14.2274 | 28.5026 | 55.6226 | 1 | 0 |
| B4-nav | 11.2627 | 15.1396 | 17.4568 | 30.9149 | 114.3503 | 1 | 1 |
| B4-open | 10.9527 | 13.1746 | 14.6241 | 25.3810 | 27.4655 | 0 | 0 |
| C1-closed | 10.5315 | 12.5272 | 14.1256 | 26.9901 | 55.5951 | 1 | 0 |
| C1-nav | 10.6159 | 12.0616 | 13.6478 | 26.8456 | 29.4474 | 0 | 0 |
| C1-open | 10.5256 | 12.1353 | 13.6770 | 26.1091 | 28.2119 | 0 | 0 |
| C2-closed | 10.5196 | 12.5392 | 13.8375 | 26.9890 | 33.1407 | 0 | 0 |
| C2-nav | 10.8637 | 14.1472 | 17.2915 | 29.7180 | 51.8064 | 1 | 0 |
| C2-open | 10.6201 | 12.6319 | 13.9485 | 25.4044 | 27.3202 | 0 | 0 |
| C3-closed | 10.4576 | 12.4032 | 13.9295 | 26.3932 | 77.3042 | 1 | 0 |
| C3-nav | 10.8903 | 15.0743 | 17.5702 | 28.4337 | 79.7052 | 1 | 0 |
| C3-open | 10.5600 | 12.3613 | 13.8065 | 25.3032 | 26.7007 | 0 | 0 |
| D1-closed | 10.5566 | 12.5592 | 14.1419 | 32.7338 | 34.0186 | 0 | 0 |
| D1-nav | 10.9181 | 12.4671 | 13.6015 | 26.8610 | 28.7077 | 0 | 0 |
| D1-open | 10.7999 | 12.7260 | 14.1182 | 25.1374 | 27.5517 | 0 | 0 |
| D2-closed | 10.4899 | 12.4866 | 13.9292 | 27.6685 | 61.7217 | 1 | 0 |
| D2-nav | 11.0518 | 14.1994 | 16.4278 | 29.3128 | 77.8608 | 2 | 0 |
| D2-open | 10.8796 | 13.0475 | 14.2875 | 26.8204 | 27.9195 | 0 | 0 |
| D3-closed | 10.5505 | 12.5540 | 14.8595 | 26.8732 | 35.6524 | 0 | 0 |
| D3-nav | 11.0825 | 13.7544 | 16.4272 | 28.3665 | 77.2866 | 1 | 0 |
| D3-open | 10.9029 | 13.1588 | 14.9537 | 27.8968 | 29.8766 | 0 | 0 |

## Interpretation

- Matched open-idle median p99 is 4.4% lower than Main and 5.1% lower than PR6; observed run ranges do not overlap. This is a small single-PC sample.
- Matched navigation median p99 is 6.1% higher than PR6 and essentially equal to Main. PR7 and PR6 run ranges do not overlap here.
- Closed-idle ranges overlap; there is no clear closed-wheel advantage from this test.
- Repeat-open worst-frame median is 24.444 ms for PR7 versus 14.332 Main and 15.076 PR6. PR7 had longer event-window frames. Conversely its worst close-event median was lower (15.212 versus 26.113/25.414 ms). Do not pool open and close or claim input latency.
- The severe closed-wheel difference between these builds is not reproduced here. There is no mod-off arm in this final set, so it cannot quantify overhead versus the unmodified game or show the reporter’s issue fixed.
- Casting reuse was not tested natively and is not included. No production merge/release is justified by this report alone.

See NATIVE-COMPARISON-DRAFT.md for environment/method, PRECONDITIONING-NOTE.md for selection provenance, final JSON for CPU/GPU metrics and receipt fields, and the independent audit for recomputation. Functional acceptance and cleanup remain separately tracked.
