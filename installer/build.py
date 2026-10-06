#!/usr/bin/env python3
"""Append the shared BetterSpellWheel production payload and clean UE4SS to the Windows stub.
Usage: build.py stub.exe ue4ss-directory dwmapi.dll UE4SS-LICENSE.txt output.exe
"""
from pathlib import Path
import hashlib
import struct
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from release_manifest import version, production_files

def unpack(blob):
    assert blob[-8:] == b'BSWPAY01', 'invalid payload marker'
    pos = struct.unpack_from('<Q', blob, len(blob)-16)[0]
    end = len(blob)-16
    result = {}
    while pos < end:
        n = struct.unpack_from('<I', blob, pos)[0]; pos += 4
        assert 0 < n < 260 and pos+n+8 <= end
        name = blob[pos:pos+n].decode('utf-8'); pos += n
        size = struct.unpack_from('<Q', blob, pos)[0]; pos += 8
        assert pos+size <= end and name not in result
        assert not name.startswith('/') and not any(c in name for c in ('..', '\\', ':', '\0'))
        result[name] = blob[pos:pos+size]; pos += size
    assert pos == end
    return result

def main():
    stub, ue4ss, dwmapi, license_file, out = map(Path, sys.argv[1:6])
    files = {'VERSION': version().encode(), 'dwmapi.dll': dwmapi.read_bytes(),
             'UE4SS.dll': (ue4ss/'UE4SS.dll').read_bytes(),
             'UE4SS-settings.ini': (ue4ss/'UE4SS-settings.ini').read_bytes(),
             'UE4SS-LICENSE.txt': license_file.read_bytes(), **production_files()}
    assert len(files) < 256
    data = bytearray(stub.read_bytes())
    assert data[:2] == b'MZ', 'Windows executable required'
    offset = len(data)
    for name, body in files.items():
        n = name.encode(); data += struct.pack('<I', len(n)) + n + struct.pack('<Q', len(body)) + body
    data += struct.pack('<Q', offset) + b'BSWPAY01'
    assert unpack(data) == files
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(data)
    manifest = {name: hashlib.sha256(body).hexdigest() for name, body in files.items()}
    import json
    out.with_suffix('.manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
    print(f'{out}: {version()}, {len(files)} entries, {len(data):,} bytes; payload hashes verified')

if __name__ == '__main__': main()
