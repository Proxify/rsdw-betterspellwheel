# 0.4.0 — Centred radial, cooldowns, move while choosing

Brings in the improvements from the community fork (jackisace/rsdw-betterspellwheel,
PR #1 and its later 1.x builds), reviewed and adapted:

- The wheel is centred on screen with no background or side list. The hovered
  spell's name, tool requirement and rune costs appear in the middle of the wheel;
  each rune count is green when you carry enough and red when you don't. Its
  description appears in a tooltip bar under the wheel.
- Live cooldown timers on the outer ring. They come from the game itself: the last
  cast time of every spell (so cooldowns started before loading in or outside the
  wheel show correctly), the server's "on cooldown" notices, and the perk-adjusted
  duration (a spell's cooldown modifier perk, once unlocked). A spell still on
  cooldown can't be selected; the wheel says when it's ready.
- Keep walking while the wheel is open (WASD / left stick). Only the wheel's own
  buttons and the right stick are captured; the camera doesn't turn while the right
  stick drives the wheel.
- Controller: the right stick picks skills and, after choosing one, points straight
  at a spell (wider slices than the mouse). X / Square hands over to the game's emote wheel.
- Mouse: smoother pointing (light angular smoothing, wider rings with no gap, and
  hysteresis so slices don't flicker at their edges).
- The native wheel no longer flashes for a frame when the custom wheel opens or closes
  (`KeepNativeHidden`, on by default). The game's select sound is muted for the cast.
- The click or button that casts must be released for a moment before gameplay sees
  input again, so it can't also swing a tool or confirm targeting.
- If the game ignores the slot hand-off, the selected spell is written directly and
  re-checked, so the first cast after launch fires the spell you chose.

# 0.3.0 — Controller navigation

- Open using the native controller binding and browse skills with either stick or D-pad.
- Confirm to enter a skill, browse its spells, then confirm to cast through native targeting.
- Back returns to skills; a second press closes. Held buttons cannot skip both stages.
- Deadzone, directional hysteresis, repeat timing, neutral-stick gate and mouse handoff.
- Xbox / PlayStation hints, with a config override for Steam Input.
- Temporary input capture blocks gameplay and native UI bindings during browsing;
  teardown removes only this mod's mapping and actor.

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

