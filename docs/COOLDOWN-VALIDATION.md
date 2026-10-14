# Cooldown display validation — 2026-10-14

Source: work/l-bsw-cooldown 98500dd, on v0.4.2. Unreleased; intended for the coordinator's combined 0.4.3 cooldown/performance release.

Changes: process native timestamps and queued cooldown notices while closed at the existing cadence; invalidate the old catalogue on world rebind. Instant CastType=0 can enter SpellcastingMode for animation without a second confirmation click. It now starts an estimate when that animation ends. Unknown/placed/aimed/movement-then-cast spells retain confirmation and cancellation rules. The game remains authoritative and estimates never block a cast.

Full tests/run.py passed. New regressions reproduced both issues before the fixes. Existing refusal, cancellation, no-cooldown, slot restoration and fallback checks passed.

SudoBlade, njoy account, throwaway Standard TRADE_TEST / BSWStdTest:

- Tempest Shield: wheel closed after selection; at +2.5 seconds, 43.8 seconds remaining from the native timestamp.
- Early recast: game refused, displayed 17-second cooldown, timestamp unchanged.
- Recall cancelled with Escape: no native stamp and zero remaining estimate.
- Surge with native polling disabled in the dev runtime: wheel closed, 44.1 seconds remaining at +2.5 seconds. This simulates unavailable timestamp polling; it is not a dedicated-client network test.
- All 48 selected spell slots unchanged.
- Creative MODTEST / TradeTesterB: first cast timer appeared closed; a permitted recast waived the estimate.

Header and live CastType checks: Instant=0 (Tempest Shield, Windstep), Placed=1 (Summon Shelter), Aimed=2, AllowMovementThenCastInstant=3 (Recall).

Evidence in project-root dist/BetterSpellWheel/cooldown-investigation/: raw bsw-cooldown-proof.mkv, all-live.txt, tests-final.log and before/after slot lists. Raw recording is 85 seconds, captured on SudoBlade only: Tempest Shield cast, later countdown view, Recall targeting/cancel. It is single-client proof, not a polished two-player showcase. Dedicated joined-client, controller input, exact user spell reproduction and performance measurements remain pending. The separate performance agent owns FPS investigation.

Cleanup: game/Steam closed, Sarah locked, original Mods restored hash-identical (32 files), NightRec XML restored, No-Intro untouched, test save files removed after Steam exit, original save sizes unchanged. Steam Cloud can resurrect deleted throwaways (observed). Backup C:\Users\Public\bsw-cooldown-backup retained; dev helper/staging files and raw recording remain in Public. No production or network/security configuration changes.
