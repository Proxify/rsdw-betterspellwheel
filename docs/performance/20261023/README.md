# BetterSpellWheel native comparison — 2026-10-23

[Results](NATIVE-RESULTS.md) · [Method](METHOD.md) · [Selection rule](PRECONDITIONING-NOTE.md) · [Independent audit](receipt-audit-115.md)

Tested Main320ebdd / pristine PR6 81e1e038 / PR7 a8553ad (runtime00e98ac). These are descriptive single-PC results, including nulls and regressions. PR7 is not faster overall. Subsequent evidence/media commits do not change these tested runtime files.

`primary-final.json` contains all27 steady per-process summaries and receipt provenance; `opening-final.json` contains7 cold processes and42 Q-events. `accepted-runs.json` pins the JSON hashes and the prespecified matched labels. Its analyzerSha256 fields refer to result JSON bytes. `analysis-provenance.json` separately records exact analyzer-source and result hashes (paths there are relative to the original project coordination directory).

The complete immutable raw CSV, receipt, scene and input logs are retained in project `coordination/pr-comparison-712395b3/{runs,opening-runs}` and the operator’s verified private NAS task archive. They are not bundled in this repository snapshot. Summary files do not replace raw evidence. Analyzer sources are included here; they can recompute raw captures when those private files are available. `opening/fixtures/c1-native-head.csv` is an80-row calibration excerpt for timestamp-orientation tests only, excluded from comparison data.

`NATIVE-RESULTS.md` and the audit retain original coordination filenames for provenance; `NATIVE-COMPARISON-DRAFT.md` corresponds to the completed-method text copied here as `METHOD.md`. The generator `summarize-final.py` reproduces accepted-runs.json and NATIVE-RESULTS.md from the two result JSONs without reading media or running the game.

Physical-controller and simultaneous-two-player acceptance are unavailable; full no-flash/all-sector/cache-change native gates remain incomplete. Casting59a98b1 is isolated and untested natively, not included in PR7. See [functional coverage](FUNCTIONAL-MATRIX.md) and [operator cleanup receipt](cleanup-final.txt). Cloud was restoredON; a single normal retry succeeded (Up to date, no conflict copy choice), and original hashes were rechecked afterward. Verified backups remain on NAS. Review-media delivery and producer cleanup are tracked separately until final attachment.
