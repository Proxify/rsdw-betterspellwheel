# Keyboard shortcuts: implementation and acceptance

Source base: main 4b256fdbc4fcc71ec2bf19fe034de66d3ec89e86 (0.4.7).
Proposal credit: nachobenedetto, PR #9. Implemented independently against the
existing wheel adapter; no PR #9 code or claimed native evidence is adopted.

Player task: reach a frequently used utility spell with fewer pointer movements.
Primary actions: number-row skill then spell selection; bind/cast a named slot.
Both are opt-in. Preserve native unlock/rune/equipment/cooldown checks, targeting,
cancel, the 48 saved native spell slots, mouse/controller handoff, input return,
world rebinding, settings and upgrade preservation. No new always-visible HUD.

Frozen self-review rubric (1–10; 9 is the design target, not objective acceptance):
hierarchy/clarity, readability, spacing/density, contrast, component consistency,
interaction/input, resolution/scale. Use the existing wheel as the reference;
no website/phone rubric applies. Score actual gameplay images after implementation.
Budget: at most eight candidates or 90 minutes of design iteration. No independent
review council is authorized. Native and safety checks remain separate gates.

Baseline and candidate: SudoBlade, sarah/njoy112, TradeTester, TRADE_TEST,
2560x1600 initially; record actual UI scale and build from the runtime. Back up
Saved and Mods by SHA-256 before launching. nJoyDesk has an active holder; a
handoff is requested for required simultaneous two-player coverage.

Reload loop: syntax/offline checks → sync the complete Scripts set to the owned
BSW test install → compare source hashes → game-thread dev-console dofile(main)
while the wheel is closed and no spell is pending → native key tests. Existing
dev-console/current-module guards are used, never UE4SS Ctrl+R. Record PID and
repeat reloads, then cold-start the final source. A packaged release is not part
of this task, but shared manifest/config preservation must remain correct.

Acceptance checklist:
- Defaults retain the existing input query counts and closed-wheel behavior.
- Number keys are consumed only with quick pick enabled and the wheel open.
- Holding a key cannot choose a skill and cast a spell in one press.
- Mouse motion/controller activity takes over predictably; timeout/reopen reset.
- Slot assignments use stable catalogue IDs, persist across reload/rejoin, and
  never save engine objects or localized display names as identity.
- No new RegisterKeyBind callback, independent loop, hook or HUD generation.
- Slot presses are ignored in menus/chat/targeting; locked/native-refused casts
  preserve slots and return input correctly. Configuration conflicts fail safely.
- Baseline suites plus focused tests exercise old/controlled-broken behavior.
- Real footage and screenshots go directly into the draft PR; missing coverage
  stays explicit. Credit/link the original proposal and post findings there.

Evidence and final results: pending.
