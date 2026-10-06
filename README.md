# SpellBranches

**Your skills. Your magic.** A skill-first Q wheel for RuneScape: Dragonwilds 1.0.

Open your spell wheel, hover a skill, then move outward to choose its spell.
Twelve fixed skill positions organize all 39 current perk spells. Native icons,
gold highlights, a short fade, and a dedicated description panel keep the wheel
readable without covering neighboring spells with tooltips.

Version **0.1.0 — keyboard/mouse beta**. Tested in TRADE_TEST as TradeTester.

## Controls

| Input | Action |
| --- | --- |
| Q / your normal spell-wheel binding | Open the skill wheel |
| Move over an inner slice | Reveal that skill's spell branch |
| Move outward + left click | Select a spell; use the game's normal cast/aim/placement controls |
| Move back into the inner ring | Change skills |
| Right click | Return to skill selection |
| Q or Escape | Close without selecting |
| F / G | Previous/next branch page if a future skill has more than six spells |

Opening centers the pointer on the wheel. Skill positions and spell order stay
stable as you progress. A small hover delay prevents boundary flicker, and the
outer branch stays attached to the skill you chose. The center, ring gap and
space outside the wheel never cast a previously hovered spell.

Locked spells remain visible with their required skill level. The side panel
shows the game's spell description, **base** rune cost and **base** cooldown.
Equipment, perks and other modifiers can change actual costs/cooldowns; native
casting makes the final decision. Failed selection keeps the wheel open with
feedback. Hovering alone never casts.

## Install

Requires the Dragonwilds-compatible UE4SS build already installed in your game.
PlayerTrading and RuneSchema are not dependencies.

1. Extract the `SpellBranches` folder into:
   `RSDragonwilds/RSDragonwilds/Binaries/Win64/ue4ss/Mods/`
2. Keep `enabled.txt` in that folder. If your loader uses `Mods/mods.txt`, add
   `SpellBranches : 1` on its own line.
3. Restart the game and open the spell wheel in a world.

The folder must contain `Scripts/`, `Assets/`, `config.txt`, `README.md` and
`enabled.txt`. Install on the client that wants this interface. There is no
server component, and other players do not need this UI mod.

To use the standard wheel, set `Enabled=false` in `config.txt` and restart.
To uninstall, exit the game, remove the folder and its `mods.txt` entry.

## Casting and spellbooks

SpellBranches reads your actual spell unlocks. It does not grant abilities,
change levels, remove costs, bypass cooldowns, or call a custom server cast RPC.
Selection goes through the game's radial selection function and its normal
validation and targeting flow.

The adapter temporarily substitutes one **client-side** slot in the active
spellbook. It restores the original after a denied cast, completed cast or
cancelled placement. Aimed/placed spells keep the temporary slot until the
native casting mode ends, because the game rereads it at confirmation. The mod
never calls `Server_UpdateSpellData` or writes a saved spellbook assignment.
Native server updates take precedence over a pending restoration.

## Verified / limitations

Verified on 2026-10-05, Dragonwilds 1.0 / UE 5.6, Windows UE4SS:

- Live catalogue: 39 perk spells across 12 skills, including Fishing/Agility
  plugin content and the game's `Runecraftng` naming typo.
- Custom UMG rendering at 1920×1080, native skill/spell icons, neutral open,
  descriptions, rune/cooldown information, and locked-state rendering.
- Real mouse selection: Windstep instant cast, Axtral Projection aim/confirm,
  and Recall advanced-movement targeting/confirmation.
- Summon Shelter enters the correct native placement preview; blocked ground
  remains blocked, and Escape cancels normally.
- Missing-rune rejection, right-click back, Q/Escape close, repeated opening,
  hot reload, and all 48 slot values preserved after cast/cancel/rejection.
- Casting from native spellbooks one and two; adapter regression tests cover
  the fourth book and empty slots. Locked selection was also tested using a
  temporary UI fixture after unlocking the test character for icon discovery.
- Standalone UE4SS startup and re-entry to TRADE_TEST (see test report).
- Lua syntax, 58 radial checks, the 39-record catalogue snapshot, and native
  adapter simulations for rejection, aim/cancel, slot offsets, empty slots,
  concurrent server updates, locked/dead-zone selection and shutdown.

**Not yet verified:** dedicated-server client play, gamepad control, ultrawide /
high-DPI display configurations, death/disconnect during targeting, every
individual spell's effect, or compatibility with another spell-wheel mod.
The custom wheel currently requires a mouse; controller users should disable it.
No multiplayer compatibility or complete spell-effect coverage is claimed.

No game textures are redistributed: icon paths load installed game assets.
The five ring textures are procedurally generated for this mod. No dev console,
test fixture, test-character unlock or inventory change runs in a normal install.

## Development

Tests and artwork/package tools are in the source repository and excluded from
the installable ZIP.

Source: `Scripts/model.lua` (geometry/catalogue), `catalogue.lua` (safe asset
reads), `view.lua` (reusable UMG), `icons.lua` (native asset paths), `main.lua`
(native lifecycle/input/casting adapter). Widgets are hidden and reused rather
than detached. All engine calls run on the game thread.

Run `python tests/run.py` in an environment with `lupa` (Lua 5.4).
Rebuild artwork with `python tools/build_art.py` (Pillow).
Build the release with `python tools/package.py`.

For a test installation only, `dev.txt` may contain an absolute directory ending
in `/`; `in.lua` executes there and writes `out.txt`. This file and all tests are
excluded from release archives. Test only TradeTester in TRADE_TEST or MODTEST.
