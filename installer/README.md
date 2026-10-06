# BetterSpellWheel Windows installer

The setup EXE is a separate release download. It finds Dragonwilds through Steam,
asks for a folder if detection fails, and installs the same production files as
the ZIP. The ZIP includes INSTALL.txt and never includes the EXE.

The installer adds the tested Dragonwilds UE4SS bundle only if absent. Existing
UE4SS and loader files are preserved, config.txt is kept on updates, and mods.txt
is merged without replacing other entries. Run again for Update / Uninstall.
Uninstall removes this mod's folder and removes installer-owned UE4SS only if no
other mod folders remain. Runtime data is untouched during updates.

Commands: `/silent`, `/dir=<game folder>`, `/uninstall`, `/detect`.
The log is `%TEMP%/BetterSpellWheel-install.log`. Exit 0 means success; failures
return 1. The installer is unsigned. It refuses a running game, conflicting
loader, old SpellBranches folder, or junction/symlink target.

## Build

Run from the repository root, using Zig 0.13.0 and a clean copy of the tested
Dragonwilds UE4SS bundle (3.0.1-f6d5f942). Dependencies and generated binaries are
not stored in Git. Include the UE4SS MIT license with the bundle.

```sh
mkdir -p dist
zig cc -target x86_64-windows-gnu -O2 -municode -Wl,--subsystem,windows \
  -o dist/setup-stub.exe installer/setup.c -lshell32 -lole32 -ladvapi32 -luser32
python3 tools/package.py
python3 installer/build.py dist/setup-stub.exe /path/to/clean/ue4ss \
  /path/to/dwmapi.dll installer/UE4SS-LICENSE.txt dist/BetterSpellWheel-0.3.0-setup.exe
python3 tests/release_test.py dist/BetterSpellWheel-0.3.0.zip dist/BetterSpellWheel-0.3.0-setup.exe
```

Both builders use `tools/release_manifest.py`. The EXE builder emits a companion
`.manifest.json` with SHA-256 values for all payload entries, used by Windows
installation checks. It also reads its payload back and verifies exact bytes.
The setup stub derives its installed file list from those entries, including
all production PNGs and Lua scripts.

Source adapted from this project's PlayerTrading installer. The BSWPAY01 payload
format is documented in setup.c. No new external installer runtime is required.

## Test

Use `tests/installer_windows.ps1 -Mode Guard` while the authorized test client is
running, then `-Mode Suite` with it closed. The script only creates disposable
fake game directories beneath D:/rsdw-mods/repl. It verifies installed hashes,
configuration/data retention, idempotent enablement, loader collisions, old-name
collisions, junction refusal, both existing UE4SS layouts and uninstall isolation.
Use `/dir=<disposable game folder>` without `/silent` for interactive UI checks.
Never run these tests against a real game folder or the development junctions.
