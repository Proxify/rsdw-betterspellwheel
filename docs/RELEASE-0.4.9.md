# BetterSpellWheel 0.4.9

This patch includes merged PR #11: Enchant Weapon: Earth maps to its native game
texture instead of the generic Attack icon. It changes no casting, cooldown,
input or progression behavior. Game artwork remains in the player's installation.

Production payload source: `4f911919421f4f53dd98dd382e063731cd71f630`, based on
merged main `6d4066def02266de2e0c629b11ceacbaf4ac287f`. The release documentation
commit adds no payload changes. Installer source/stub is unchanged from 0.4.7.

| Artifact | SHA-256 |
| --- | --- |
| BetterSpellWheel-0.4.9.zip | `4d9e2dfa4f10ddaf5b096404ccd8ed1e415bb47d5e1bb617448769fbf2a2fe8e` |
| BetterSpellWheel-0.4.9-setup.exe | `14aa52b0ac89cc38ec533f2688ae9f6ce0abe0f0cd815b08ac2510a5c11b5e5b` |
| BetterSpellWheel-0.4.9.rspkg | `041bca99e4bf2141391b9423d8349d5603f5b38c771719f5bccaa165600e5fe5` |

The ZIP contains only `.lua` and `.txt`, including its root installation guide.
All 18 production files match source across the ZIP and EXE. The RSence package
was read back with the installer reader and matched its source entries. No tests,
developer console files or runtime data are shipped. Stores receive only the ZIP;
the separate setup EXE is hosted by RSence and the private GitHub release.

## Checks and limits

- Full `python tests/run.py` passed on the versioned source, including the real
  view's mocked Earth brush regression, input/casting adapter, cooldowns, shortcut
  persistence and layout. This is offline evidence, not native gameplay.
- All 40 mapped spell and 12 skill texture paths exist in installed game build
  26574764's IoStore directory. Seven paths differ in capitalization only.
- All ten Windows installer Suite cases passed in isolated SudoDesk folders:
  fresh install, update/repeat with settings and shortcut/data preservation,
  uninstall isolation, both existing UE4SS layouts, loader/name collisions,
  invalid targets and junction refusal. No actual game/mod/save/desktop was changed.
- Installer log restored to its original absent state. Unchanged installer-engine
  game guard/interactive evidence is reused; no new interactive installer test.
- Fresh Earth display/cast, all-spell native census, repeated reload, cold start,
  screenshots and gameplay footage remain pending access to the reserved test PCs.
  The prior 0.4.8 video demonstrates keyboard shortcuts only. No fresh Earth or
  two-player evidence is claimed. Details: [SPELL-ARTWORK.md](SPELL-ARTWORK.md).

The source merge, public release and native acceptance are separate states.
The publication ledger records actual website/store availability, including any
pending CurseForge moderation; a tag or upload alone is not proof of availability.
