# 0.4.3 — Much lighter in the background; cooldowns update while closed

- Much lower background cost. The mod no longer searches the game's objects every
  frame: with the wheel closed it now uses about 2-3 ms of game-thread time per second
  instead of about 35, and about half as much while the wheel is open. The wheel only
  redraws what changed.
- Cooldown timers keep updating from the game after a cast while the wheel is closed,
  so the right time shows as soon as you open the wheel again.
- Instant spells (such as Tempest Shield and Windstep) start their timer when the cast
  animation ends; aimed and placed spells still wait for your confirmation, and a
  cancelled cast starts no timer.
- The game still decides whether a spell can be cast; timers never block a cast.
- New troubleshooting setting `PerfLog` in `config.txt` (default `false`): set `true` to
  log the mod's per-second cost and the frame time to UE4SS.log. Leave it off for normal
  play. Updating keeps your existing `config.txt`; add the line if you need it.

Measured and checked in-game: `tests/live-perf-0.4.3.txt`, `docs/COOLDOWN-VALIDATION.md`.

# 0.4.2 — Cooldowns follow the game (no-cooldown mods work again)

- Fixed: with a mod that removes spell cooldowns (e.g. Utility Spells - No Cooldowns),
  the wheel still showed cooldown timers and refused to cast those spells, mostly when
  playing on someone else's server. The wheel ran its own timer after each cast and
  blocked the spell until it ran out, even though the game would have allowed it.
- The game now always decides. The wheel never refuses a cast because of its own timer:
  it hands the spell to the game, and only says "On cooldown" when the game refuses it.
- When the game accepts a spell the timer thought was on cooldown, the timer is dropped
  and no new one is started for that spell until the game itself reports a cooldown.
- Cooldown lengths are read live from the game's spell data on every cast and while the
  wheel is open; a cooldown of 0 shows nothing. Timers re-sync with the game every second
  while the wheel is open.
- New `ShowCooldowns` setting in `config.txt` (default `true`): set `false` to hide the
  timers entirely. Updating keeps your existing `config.txt`; add the line to use it.
- Creative worlds don't enforce spell cooldowns; the wheel no longer blocks casts there either.
- Cooldowns still show and count down as before for players without such a mod.

Tested in-game with and without Utility Spells - No Cooldowns (`tests/live-cooldowns-0.4.2.txt`).

# 0.4.1 — CurseForge-ready packages

- The release ZIP now contains only `.lua` and `.txt` files, as CurseForge requires for
  Dragonwilds UE4SS mods. The wheel artwork is no longer shipped as images: the mod draws
  it on first launch (about a second, once) and keeps it in its `Assets` folder.
- README, LICENSE and NOTICE ship as `README.txt`, `LICENSE.txt` and `NOTICE.txt`.
- No change to the wheel, casting or cooldowns since 0.4.0.

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
- A refused selection (on cooldown, missing runes or a tool) says why, in red, in the
  tooltip bar.
- Fixed a crash in the fork's code: it re-hid the game's own wheel every frame and could
  call into it after the game had rebuilt it. The mod now leaves it alone while closed
  and checks it still exists before touching it.

Tested in-game with mouse and keyboard (instant and aimed casts, cancel, cooldowns,
rune colours, walking while open). The new controller behaviour (right stick, emote
hand-off) has not been tested on a gamepad yet.

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

