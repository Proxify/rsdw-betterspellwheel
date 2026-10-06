# SpellBranches — development in progress

A skill-first replacement for Dragonwilds' Q spell wheel, inspired by the supplied
Spellbook Sub-Branches reference. Hover a skill on the inner ring, move outward
into its spell branch, and select a spell to enter the game's usual casting flow.

**This is the tested catalogue and interaction core, not an installable mod yet.**
There is intentionally no `Scripts/main.lua`, `enabled.txt`, or release zip until
the native client integration is probed and tested. Steam is signed out on the
nJoyDesk test machine. It must be signed in through the txwil desktop before the
remaining work can be verified. Do not install this development folder as a mod.

## Interaction specification

- Q should follow the game's spell-menu input, including its remapped binding.
- Twelve skill positions remain stable as spells unlock. Unavailable spells stay
  visible with their required level; selecting them must never cast.
- Hovering a skill reveals its outer branch after 55 ms. Three degrees of
  angular hysteresis prevent flicker along a skill boundary.
- Moving outward keeps the current branch latched. Return to the inner ring to
  change skills. The center, gap between rings, and space outside the wheel
  never select a spell or reuse a previous hover target.
- Spell order follows required level and stable asset ID. More than six spells
  use branch pages rather than disappearing.
- Escape/Q close; right click returns to skills. Clicking a spell should enter
  normal targeting/casting. Opening the wheel must never cast automatically.
- Use native skill/spell icons, gold selection trim, readable names and
  descriptions, rune costs, cooldowns, and clear locked-state feedback.
- Scale the entire wheel with the viewport; no separate fixed-pixel hit regions.
- The game remains authoritative for unlocks, rune consumption, placement and
  cooldowns. The intended mod is client-side and must preserve saved spellbooks.

These are implementation requirements; only the engine-independent selection
behavior and catalogue reads listed below have been verified so far.

## Verified on 2026-10-05

- MODTEST server, Dragonwilds 1.0: 52 loaded `UtilitySpellData` assets; 39 have a
  valid `OwningPerk` and map to 12 skills. Internal/unassigned assets are excluded.
- Safe reads: `SpellDisplayName`, `OwningPerk`, `PerkUnlockInfo.RequiredSkillLevel`,
  `PerkDescription`, `CooldownDuration`, `SkillData.Name` and `SkillType`.
- Skill grouping handles the game's `Runecraftng` typo and plugin assets.
  Farming's Rapid Growth lives under the Agility plugin and still maps to Farming.
- The live catalogue test passed: 39 distinct records, correct per-skill counts,
  valid assets, levels and descriptions, and no availability granted without a
  player query. A plain Lua snapshot preserves that regression fixture.
- Lua 5.4 syntax checks and 58 interaction checks passed locally. A further
  snapshot check verifies the owning skill of all 39 live records.

Two read-only soft-reference probes crashed the test server. Both were followed
by a restart with its configured OwnerId. Avoid accessing or marshalling
`OwningPerk.PerkUnlockInfo.AssociatedSkill`; the adapter uses verified perk asset
names instead. `pcall` does not prevent native crashes.

## Remaining live work

1. Sign into Steam on nJoyDesk; launch TradeTester in TRADE_TEST or MODTEST.
2. Run `tests/client_probe.lua` via the PlayerTrading console, with Q closed and
   open. Verify the native wheel's lifecycle, unlock query and selection state.
3. Probe native icon brush reuse, spell display info and `SelectSlice` selection
   routing. Establish a transient selection method that preserves every saved
   slot and uses normal cast validation. Do not assume an RPC changes only UI.
4. Build the UMG renderer and native Q integration, using reusable widgets and
   game-thread updates. Restore native UI/input on close, reload and errors.
5. Test unlocked/locked spells, rune shortage, cooldowns, targeting, cancel,
   repeated opening, keyboard/mouse, gamepad behavior, UI conflicts, resolution
   changes, world travel, death, disconnect, and saved spellbook preservation.
6. Verify on a listen host and MODTEST client, inspect screenshots, polish, then
   build an installable release. No release has been built or published yet.

PlayerTrading has not been changed. Its trade/protection suites do not validate
this spell UI; they were not rerun for these independent modules.

## Development checks

```sh
/tmp/luav/bin/python mods/SpellBranches/tests/run.py
```

Requires the existing project's `lupa` venv (Lua 5.4). On the Windows mirror,
copy this folder to `D:\rsdw-mods\mods\SpellBranches`, then run through `srvr`:

```lua
return dofile("D:/rsdw-mods/mods/SpellBranches/tests/live_catalogue.lua")
```

The server test reads game assets and writes only its plain-text test snapshot.
It neither loads the mod automatically nor changes a character or inventory.
The client probe is prepared but has not run.
