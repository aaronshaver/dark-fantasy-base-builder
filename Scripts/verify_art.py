#!/usr/bin/env python3
"""Check the committed artwork contract without third-party packages."""
from pathlib import Path
import json
import struct
import zlib

ROOT = Path(__file__).resolve().parents[1]
palette = json.loads((ROOT / 'DarkFortress/Resources/palette.json').read_text())
expected = b''.join(bytes.fromhex(color) for color in palette.values())
assert len(palette) <= 256
files = sorted((ROOT / 'DarkFortress/Resources/Pixel.atlas').glob('*.png'))
assert files
for path in files:
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', path
    chunks = {}
    offset = 8
    while offset < len(data):
        length = struct.unpack('>I', data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        chunks[kind] = chunks.get(kind, b'') + data[offset + 8:offset + 8 + length]
        offset += length + 12
    width, height, depth, color_type, _, _, _ = struct.unpack('>IIBBBBB', chunks[b'IHDR'])
    assert (width, height, depth, color_type) == (32, 32, 8, 3), path
    assert chunks[b'PLTE'] == expected, f'{path}: inconsistent palette'
    assert chunks[b'tRNS'] == b'\0' + b'\xff' * (len(palette) - 1), path
    raw = zlib.decompress(chunks[b'IDAT'])
    assert len(raw) == 33 * 32, path
    assert all(raw[y * 33] == 0 for y in range(32)), path
    assert all(pixel < len(palette) for y in range(32) for pixel in raw[y * 33 + 1:(y + 1) * 33]), path
    if path.stem.startswith('wall_'):
        transparent = {(x, y) for y in range(32) for x in range(32) if raw[y * 33 + 1 + x] == 0}
        corners = set()
        for cx, cy, dx, dy in [(0, 0, 1, 1), (31, 0, -1, 1), (0, 31, 1, -1), (31, 31, -1, -1)]:
            corners.update([(cx, cy), (cx + dx, cy), (cx, cy + dy)])
        assert transparent == corners, f'{path}: only the small rounded corners should reveal grass'
print(f'PASS: {len(files)} sprites are 32×32 indexed PNGs with one identical {len(palette)}-entry palette and binary transparency.')
