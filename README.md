# BetterSpellWheel

A skill-based spell wheel for **RuneScape: Dragonwilds**. Press **Q**, hover a skill,
then move outward to choose a spell. Or use your controller to choose a skill,
browse its spells, and cast without reaching for the mouse.

![BetterSpellWheel in-game, showing Agility and its three spell slots](docs/skill-wheel.png)

## Your skills. Your magic.

- **39 spells across 12 skills**, grouped using the game's actual progression data.
- **A clean, centred wheel:** the hovered spell's name, tool requirement and rune costs
  appear in the middle, with each rune count **green** when you carry enough and **red**
  when you don't. Its description sits in a tooltip bar under the wheel.
- **Live cooldowns** synced from the game, including cooldowns started before you loaded
  in and perks that shorten them. Spells on cooldown can't be selected.
- **Keep moving:** walk while the wheel is open.
- **Controller navigation:** right stick or D-pad, with matching button hints.
- **Normal game rules:** your unlocks, rune requirements and targeting still apply.
  Saved spellbook assignments are preserved.

## Download and install

**0.3.0 · Windows · Keyboard, mouse and controller beta**

| Download | Installation |
| --- | --- |
| [Easy installer (.exe)](https://github.com/Proxify/rsdw-betterspellwheel/releases/download/v0.3.0/BetterSpellWheel-0.3.0-setup.exe) | Close the game and run setup. It finds your Steam installation and installs UE4SS if needed. |
| [Manual install (.zip)](https://github.com/Proxify/rsdw-betterspellwheel/releases/download/v0.3.0/BetterSpellWheel-0.3.0.zip) | Follow the included `INSTALL.txt`. Requires Dragonwilds-compatible UE4SS already installed. |

The EXE is a separate download. Setup preserves other mods and your existing
settings on update; run it again to update or uninstall. The installer is unsigned.

Install on the client where you want the new wheel. PlayerTrading and RuneSchema
are not dependencies, and there is no server component.

**Coming from SpellBranches?** Close the game and remove its old mod folder and
`SpellBranches : 1` entry from `mods.txt` before installing BetterSpellWheel.
Keep only one wheel enabled.

[Full installation and troubleshooting guide](INSTALL.txt) · [Release notes](CHANGELOG.md)

## Controls

| Input | Action |
| --- | --- |
| Q / your normal spell-wheel binding | Open the wheel |
| Q / Escape | Close without selecting |
| Hover an inner skill icon | Reveal that skill's spells |
| Move outward + left-click | Select a spell, then use the game's normal casting controls |
| Return to the inner ring | Change skills |
| Right-click | Go back to skill selection |
| WASD | Keep walking while the wheel is open |

With a controller:

| Input | Action |
| --- | --- |
| Y / Triangle (or your normal binding) | Open or close |
| Right stick | Point at a skill; after choosing it, point straight at a spell |
| Left stick | Keep walking |
| D-pad | Browse skills or spells, with hold-to-repeat |
| A / Cross | Choose the skill, then select its highlighted spell |
| B / Circle | Back to skills; press again to close |
| X / Square | Switch to the game's emote wheel |
| LB / RB or L1 / R1 | Change pages when a skill has more than six spells |

Release the stick after choosing a skill before pointing at its spells. Once a spell
is selected, use the game's normal targeting controls (RT / R2 to confirm, LT / L2 to
cancel). Moving the mouse switches back to mouse navigation. `ControllerPrompts=PlayStation`
in `config.txt` overrides Xbox hints when using Steam Input.

Locked spells remain visible with their required level. Hovering alone never casts.
To disable the mod, set `Enabled=false` in `config.txt` and restart the game.

## Credits

Version 0.4.0 brings in improvements first made in a community fork by jackisace
(centred layout, rune counts, cooldown timers, movement while open, right-stick
navigation), reviewed and adapted here.

## Compatibility

Tested on **Dragonwilds 1.0 / UE 5.6**, Windows, at **1920×1080**. Controller input is tested with a virtual Xbox controller through the native
Windows input path. Physical controllers and native PlayStation input remain
unverified; PlayStation button labels can be selected in the config.

The controller flow was exercised on a client connected to a local dedicated
MODTEST server. Ultrawide/high-DPI displays, death or disconnect
while targeting, every individual spell effect, and other spell-wheel mods remain
unverified. See the [test report](tests/TEST-REPORT.md) for exact coverage.

## Development

Run `python tests/run.py` with Python and `lupa` installed. Artwork is generated
with `python tools/build_art.py` (Pillow). Game icons load from your installed game;
no game textures are redistributed.

Build the manual ZIP with `python tools/package.py`. Follow the
[installer build guide](installer/README.md) for the separate setup EXE and Windows
validation. Every release includes both files; developer consoles, tests and
runtime data are excluded from the downloads.

## License

BetterSpellWheel is © 2026 Proxify, licensed under the [Apache License 2.0](LICENSE).
You may use, modify and share it, but any redistribution or derivative work
(forks, ports, modified builds, mods that include its code or artwork) must keep
the [NOTICE](NOTICE) file and credit the original:
"Based on BetterSpellWheel by Proxify — https://github.com/Proxify/rsdw-betterspellwheel".
