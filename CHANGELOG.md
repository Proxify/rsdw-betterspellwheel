# Changelog

## 0.2.2

A separate Windows setup EXE now installs the mod and includes UE4SS for fresh
installs. The ZIP includes INSTALL.txt with manual installation instructions.
The wheel and casting behavior are unchanged.


## 0.2.1

The mod is now **BetterSpellWheel** (formerly SpellBranches), with its own source
repository: [Proxify/rsdw-betterspellwheel](https://github.com/Proxify/rsdw-betterspellwheel).
The install folder, in-game title and release archive use the new name. The skill
mapping and casting behavior are unchanged from 0.2.0.

## 0.2.0

Windstep is now under **Agility**, alongside Phase Dash and Recall. Jagex moved
it in [update 0.12.1](https://dragonwilds.runescape.com/news/0.12.1-update);
its asset filename retained the old skill. This release reads the native
progression lists for all skills instead of inferring ownership from filenames.
All 39 current assignments were checked against that progression data.

The wheel now uses larger icons and compact slot numbers. A matching spell list
keeps full names and required levels in a fixed panel, with separate space for
the selected spell's description, cost, cooldown and feedback. Text is fitted
using the game's rendered font metrics. No full spell name crosses a wheel slice.

