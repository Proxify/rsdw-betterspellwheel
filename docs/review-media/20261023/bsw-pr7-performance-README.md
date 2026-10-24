# BetterSpellWheel draft PR #7 — performance review film

**Tested build:** PR #7 candidate `a8553ad` (runtime `00e98ac`), compared with main 0.4.5 `320ebdd` and community PR #6
as submitted `81e1e038`. The later docs commit `4ee3a0b` has an empty runtime diff. Unreleased.

**Machine:** one SudoBlade (i9-13950HX, RTX 4080 Laptop, 32 GB, driver 32.0.16.1047), client 26162923, UE4SS f6d5f942.
These are same-PC separate cold-process runs, interleaved. This is an exploratory single-PC test, not a significance
test. It is not a mod-off/stock comparison, and it does not claim to fix the outside report (UE4SS 0196ef29).

**Fixture:** a Standard MODTEST disposable test character, with all 39 spells test-unlocked and the rune inventory
seeded. The footage is real single-client native gameplay, not natural progression, a normal inventory or synthetic UI.

## What the film shows
- Cropped artwork: crop sizes from art.lua. The game-generated PR #7 crops re-assemble byte-for-byte into the
  game-generated main textures (all 6, verified on the render host), plus the offline test results.
- Gameplay: one warm illustrative take per build, recorded after that build's final measured block. Wall-time 1×,
  never retimed. Each clip starts at its observed wheel-open frame. The takes were recorded at about 17 fps (sparse
  cadence, gaps up to 0.87 s), so the footage is not a smoothness measure. Small native UI text, such as the
  countdown and refusal notice, stays small; the captions state it.
- Results (per-process p99 frame time, median and range across processes), from root's accepted-runs.json:
  closed — no clear difference (ranges overlap); open-stationary — PR #7 lower than main and PR #6 in these runs;
  navigation — PR #7 slower than PR #6, about equal to main.
- Required caveat: around repeated opening Q presses, PR #7's median worst frame per process was 24.4 ms, against
  14.3 for main and 15.1 for PR #6. Close-press gaps were lower for PR #7. These are frame times, not input latency.
- Functional matrix: 17 rows (2 PARTIAL, 6 NOT TESTED). The PR #6 column shows only the offline replaced-controller result.

## Sources
- Full results: https://github.com/Proxify/rsdw-betterspellwheel/blob/4ee3a0bc6e9b4900352dcc63d19a8bbf41929a26/docs/performance/20261023/NATIVE-RESULTS.md
- Every on-screen claim → its source: `CLAIMS.md`. Props hash and file hashes: `SHA256SUMS.txt`. Probe/decode/loudness: `PROBE.txt`.
- Footage: B4 `7a572748…6bfd` (main), D3 `d4a8fbfe…50fe` (PR #6; recorder wrapper failed, decode-validated),
  C3 `dc882509…53fd` (PR #7).

## Files and checks (completed 2026-10-23 on nJoyDesk WSL)
- `bsw-pr7-performance.mp4`: PR copy, 9,637,429 bytes, H.264 High yuv420p 1920×1080 30 fps, 3540 frames,
  118.06 s, AAC 64 kb/s 48 kHz stereo, faststart (moov before mdat).
- `bsw-pr7-performance-hq.mp4`: master, 16,123,790 bytes, Remotion H.264 CRF 16 (full-range yuvj420p), AAC 192 kb/s.
- `bsw-pr7-performance-poster.jpg`: frame at 46.2 s (cooldown beat).
- Both MP4s decode fully (`ffmpeg -xerror … -f null`, exit 0) and measure −20.0 LUFS integrated (peak −9.0 / −9.7 dBFS).
- Sampled encoded frames from the PR copy (`verification/encoded-sampled-frames.jpg`) match the root-approved stills.
  Chart labels show the exact measured values at animation onset, midpoint and completion
  (`verification/chart-label-onset-mid-complete.jpg`). An earlier encode whose labels counted up through
  intermediate values was discarded.

## Audio and review status
Quiet original synthesized bed. Nobody has listened to the audio, and no human has watched the film in full motion.
The checks above are technical: full decode, loudness and sampled encoded frames.

## Review links and retained evidence
[Watch/download the film](bsw-pr7-performance.mp4) · [Poster](bsw-pr7-performance-poster.jpg) ·
[Claims](CLAIMS.md) · [Technical verification](PROBE.txt).

The SHA manifest includes both the files committed here and private render inputs. The HQ master, original takes,
render source/props and raw test receipts remain in the project evidence directories; their absence from this folder
is intentional. The committed review film and sampled verification sheets are the final corrected encode.

Machine cleanup completed: SudoBlade original mods/saves were restored and hash-verified, Cloud restored and synced,
and owned test processes/staging removed. Producer nJoyDesk lease ended 2026-10-23 21:53:11 UTC after removing its
three owned render directories and processes; shared settings and existing Steam were untouched.
