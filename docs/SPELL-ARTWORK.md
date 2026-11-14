# Current spell artwork coverage

Baseline: v0.4.8 / 4d8b63b177dd544d10871927d45261d40df4c35a.
Game asset audit: installed Windows client build 26574764, 2026-11-14.

The spell catalogue resolves native progression dynamically, but artwork uses
explicit native texture paths. Before this change, an Earth enchantment record
would render the generic Attack icon. The new entry maps USD_EnchantWeapon_Earth
to the game's T_Skill_Attack_Spell_Enchantweapon_Earth texture. Game artwork remains
in the player's installation; no texture is bundled or redistributed.

The current game IoStore directory contains all 40 mapped spell textures and all
12 skill textures. Seven older paths differ only in folder capitalization; those
are not missing-art findings. UTOC SHA-256:
298bb33ef8bc57c64b275e0da4fed8cba16f34dc5898adc40bb30f87d4eede0d.
See evidence/spell-artwork/asset-paths-26574764.json for the path-only receipt.
Unused/development utility assets are not evidence of playable spells, so their
names alone are not used to extend the supported catalogue.

## Verification so far

- Full python tests/run.py passed, including input, controller, catalogue,
  cooldown/native-adapter mocks, shortcut persistence, layout and artwork checks.
- The new view regression fails with the released icon map: the Earth fixture
  receives the Attack skill brush. With the new entry, the actual view code selects
  the Earth brush, retains it and places the expanded Attack branch correctly.
  The additional record is explicitly a test fixture, not a native census.
- Existing native texture warming/pinning handles the new mapping. No additional
  polling loop, soft-reference access, key bind or engine API was introduced.
- The October 39-spell snapshot stays historical. Current README copy describes
  progression-based discovery without asserting that old count is still current.
- tests/live_artwork.lua is a development-only, read-only TEST probe for complete
  discovered-icon coverage and warmed texture existence. It also requires Earth
  to be in the native catalogue. It has not yet been executed in the game.

## Native acceptance pending

This change is not released or verified in-game. Asset-path existence and mocked
brush selection do not prove visual correctness, actual progression membership,
native casting, cost/cooldown behavior or input handling in the updated client.

Required: capture the released Earth fallback and corrected native icon at matching
viewport/UI scale; inspect all discovered spell branches and rune/tool details;
check locked/available Earth states, mouse selection, native cast/refusal/cancel,
saved-key behavior, open/close/input return, repeated integrated reload and a
separate final-source cold start. Preserve saved spell slots and original TEST
Mods/Saved/config state by hash. Include gameplay footage directly in the PR.

Use the existing game-thread main.lua dofile boundary after syncing/hash-checking
the complete Scripts set to an owned target. Close the wheel and finish/cancel any
spell first; no Ctrl+R and no independent icons.lua reload into old closures.

Native baseline/candidate screenshots, gameplay video, all-spell census and final
visual self-review are pending machine access. SudoBlade is reserved for another
run. nJoyDesk's four-server comparison cannot be interrupted; its owner offered
a handoff after about 10:30 UTC, and Anders' Windows session is currently locked.
No occupied desktop was taken. Existing shortcut footage only documents the
previous wheel and is not evidence of this fix or the new Earth spell.
