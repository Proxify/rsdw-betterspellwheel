# Claims manifest — BetterSpellWheel draft PR #7 performance film (filled from props/final.json)

Every on-screen claim with its source. Built `--final` by video/tools/build_props.py (131/131 fixtures).

| Beat | On-screen text | Source |
|---|---|---|
| title | Spell wheel performance: main vs PR #6 vs PR #7 / main 0.4.5 320ebdd · PR #6 as submitted 81e1e03 · PR #7 candidate a8553ad · draft PR #7, unreleased | NATIVE-PLAN superseding section; PR #7 frozen tested build a8553ad (runtime 00e98ac); docs commit 4ee3a0b has an empty runtime diff |
| wedge | Old texture 848 × 848; Skill 140 × 146 (+ 4 px clear margin); 35.2× fewer pixels; per-wedge sizes; all 6 textures decoded artwork bytes 15.6 MB → 1.45 MB (arithmetic, not measured GPU memory) | art.lua A.crops @67e7024 (unchanged through a8553ad); CROPPED-ART-REPORT.md metrics |
| reassemble | Original / Reassembled / Difference images; 6 textures match the 0.4.5 art · passed; 9,876 placement checks · passed (offline tests) | images: game-generated PNGs (hashes = B4-nav/C3-nav wheelHashes) re-assembled by exact byte paste on nJoyDesk, all 6 identical; tests/run.py:103, tests/art_view_test.lua:139 |
| compare | Same PC · separate runs · 1× speed; Recorded at ≈ 17 fps · footage is not a smoothness measure (probed rates {'main': 17.3, 'pr6': 17.4, 'pr7': 17.5}); column labels with hashes; captions incl. 'Standard MODTEST · test spells/runes' | takes B4/D3/C3 (sha in receipts), ffprobe -count_frames on nJoyDesk; fixture per FUNCTIONAL-MATRIX/user note |
| compare 1 (main/pr6/pr7, 8.0 s) | Warm reopen and 12-skill navigation · Standard MODTEST · test spells/runes | observed open frames (detector + strips); cue receipts: review/D3-, B4-, C3-media-review.md + observed C3 frames |
| compare 2 (main/pr7, 7.0 s) | Cast Tempest Shield · Standard MODTEST · test spells/runes; @3.77 s: Wheel closed · spell effect in game | observed open frames (detector + strips); cue receipts: review/D3-, B4-, C3-media-review.md + observed C3 frames |
| compare 3 (main/pr7, 10.5 s) | Wheel reopened · Standard MODTEST · test spells/runes; @3.93 s: Tempest Shield cooldown still counting; @6.83 s: Recast refused by the game: On cooldown | observed open frames (detector + strips); cue receipts: review/D3-, B4-, C3-media-review.md + observed C3 frames |
| chart intro | Measured on SudoBlade; Frame times (ms) · lower is better; Bars: median · lines: range · exploratory single-PC test | NATIVE-COMPARISON-DRAFT.md (SudoBlade i9-13950HX / RTX 4080 Laptop) |
| chart: Closed wheel, steady | main 14.21 [13.93–14.23] n=3; PR #6 14.14 [13.93–14.86] n=3; PR #7 13.93 [13.84–14.13] n=3 · verdict 'No clear difference: run ranges overlap' | accepted-runs.json 0d835de4 → primary-final.json dbb41184; NATIVE-RESULTS.md matched table |
| chart: Wheel open, stationary | main 14.52 [14.38–14.62] n=3; PR #6 14.62 [14.29–14.95] n=2; PR #7 13.88 [13.81–13.95] n=2 · verdict 'PR #7 lower than main and PR #6 in these runs; ranges do not overlap' | accepted-runs.json 0d835de4 → primary-final.json dbb41184; NATIVE-RESULTS.md matched table |
| chart: Navigation | main 17.46 [17.05–17.75] n=3; PR #6 16.43 [16.43–16.43] n=2; PR #7 17.43 [17.29–17.57] n=2 · verdict 'PR #7 slower than PR #6; about equal to main' | accepted-runs.json 0d835de4 → primary-final.json dbb41184; NATIVE-RESULTS.md matched table |
| caveat | Not a blanket improvement: Median worst frame per process around repeated opening Q presses: PR #7 24.4 ms; main 14.3; PR #6 15.1. / Close-press gaps were lower for PR #7 · not input latency · NATIVE-RESULTS.md | opening-final.json 726a2662 via accepted openingCases (open:2+open:3, max per process, median across processes); close-press statement from NATIVE-RESULTS.md Q-event table |
| in PR #7 | Cropped wheel artwork · Release check: 5 keys per tick, not 17 · PR #6 catalogue, rune and cursor changes; controller checks kept | CROPPED-ART-REPORT.md; casting/PR6-PORT-REPORT.md |
| checks | Cold load and world binding: PR #7 pass, PR #6 — | Cold load / solo world binding |
| checks | Crop hit, sampled sectors: PR #7 pass, PR #6 — | Crop pivot / outer mouse hit (sampled Attack / Tempest Shield sector only) |
| checks | Native cast: PR #7 pass, PR #6 — | Native cast (real Tempest Shield click and effect) |
| checks | Cooldown counts while closed: PR #7 pass, PR #6 — | Cooldown updating while closed (real cast, 4 s closed, reopen remaining 40 s) |
| checks | Early recast refused: PR #7 pass, PR #6 — | Early cooldown refusal (real early click, visible Ready in 24s) |
| checks | Q close releases input: PR #7 pass, PR #6 — | Q close / captured input release (basic close) |
| checks | Menu rejoin, new controller: PR #7 pass, PR #6 — | Menu rejoin / controller replacement lifetime (same PID 17928, default solo path; network joins not tested) |
| checks | Fast close and reopen: PR #7 partial, PR #6 — | Fast close/reopen (QPC driver intended cycles; not per-cycle visual proof) |
| checks | No native wheel flash: PR #7 partial, PR #6 — | Native panel no-flash, both hidden modes (sparse cadence cannot exclude single-frame flashes) |
| checks | Every sector hit alignment: PR #7 not-tested, PR #6 — | All-sector crop and hit alignment |
| checks | Cast cancellation: PR #7 not-tested, PR #6 — | Cast cancellation |
| checks | Unlock / perk refresh: PR #7 not-tested, PR #6 — | Catalogue unlock / perk freshness |
| checks | Rune availability colours: PR #7 not-tested, PR #6 — | Rune availability feedback |
| checks | Physical controller: PR #7 not-tested, PR #6 — | Physical controller interaction |
| checks | Two clients at once: PR #7 not-tested, PR #6 — | Simultaneous two-client behavior |
| checks | Replaced controller (suite) (offline test): PR #7 pass, PR #6 fail | Replaced/removed controller lifetime test (offline runtime suite; PR #6 as submitted fails it, PR #7 keeps pcAlive/rememberPc) |
| checks | ZIP has .lua/.txt only (offline test): PR #7 pass, PR #6 — | Release ZIP contains only .lua/.txt (package.py, 18 entries on 00e98ac) |
| end | BetterSpellWheel · draft PR #7 · Not released · not a blanket improvement · full results in NATIVE-RESULTS.md | PR #7 draft; https://github.com/Proxify/rsdw-betterspellwheel/blob/4ee3a0bc6e9b4900352dcc63d19a8bbf41929a26/docs/performance/20261023/NATIVE-RESULTS.md |

Provenance: results {"analyzerSha256": "dbb4118445cfa4b54cd87b235450cfac3c8440a27521d5b3454f4a360f71e41b", "manifestSha256": "0d835de43a266b5cadd6c83925c5af4aae6d23b4b33a194b342bb24491a735eb", "computer": "SUDOBLADE", "clientBuild": "26162923", "accepted": {"closed": {"main": ["B2-closed", "B3-closed", "B4-closed"], "pr6": ["D1-closed", "D2-closed", "D3-closed"], "pr7": ["C1-closed", "C2-closed", "C3-closed"]}, "open": {"main": ["B2-open", "B3-open", "B4-open"], "pr6": ["D2-open", "D3-open"], "pr7": ["C2-open", "C3-open"]}, "nav": {"main": ["B2-nav", "B3-nav", "B4-nav"], "pr6": ["D2-nav", "D3-nav"], "pr7": ["C2-nav", "C3-nav"]}}}
Opening: {"analyzerSha256": "726a26622035342565fd94b6de5a6595eb18d6416afd41fb12dea1ada93c8bd9", "manifestSha256": "0d835de43a266b5cadd6c83925c5af4aae6d23b4b33a194b342bb24491a735eb", "events": ["open:2", "open:3"], "class": "repeat-intended", "aggregate": "max per process, then median and min-max across processes", "accepted": {"open-repeat": {"main": ["B2-opening", "B3-opening", "B4-opening"], "pr6": ["D2-opening", "D3-opening"], "pr7": ["C2-opening", "C3-opening"]}}}
