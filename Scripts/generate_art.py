#!/usr/bin/env python3
"""Deterministic, dependency-free pixel art. Every game sprite is 32×32 indexed PNG.

All sprites share this exact palette (including transparent index zero). PNGs are
committed; this generator is an authoring tool and never runs on the phone.
"""
import binascii
import json
import pathlib
import random
import struct
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / 'DarkFortress/Resources/Pixel.atlas'
COLORS = {
    'clear': '000000', 'ink': '10121c', 'void': '181b26', 'panel': '202330',
    'edge': '363747', 'muted': '79798e', 'text': 'd8d4df', 'white': 'f3edf7',
    'purple_dark': '302840', 'purple_deep': '463354', 'purple': '705382',
    'lilac': 'a580bd', 'purple_light': 'b89aca', 'gold': 'c2a36b', 'gold_light': 'e0c997',
    'wood_dark': '302625', 'wood_seam': '392b28', 'wood': '4b3830',
    'wood_mid': '594136', 'wood_light': '6d5140', 'wood_glint': '82624b',
    'grass_dark': '1b292a', 'grass': '213530', 'grass_mid': '2a4036',
    'grass_light': '375044', 'grass_tip': '456253', 'moss': '52664b',
    'stone_dark': '292d36', 'stone': '414652', 'stone_mid': '505764',
    'stone_light': '646c78', 'stone_top': '7c8389', 'steel_dark': '303a48',
    'steel': '566c7c', 'steel_light': '8babb6', 'steel_glint': 'bbd0cf',
    'skin_dark': '867666', 'skin': 'b6ac90', 'skin_light': 'dbd0ad',
    'red_dark': '542c3d', 'red': '994457', 'red_light': 'd16a78',
    'blue_dark': '293e52', 'blue': '426079', 'blue_light': '64849a',
    'teal_dark': '2c5150', 'teal': '4a7d72', 'teal_light': '79aa93',
    'rust': '755048', 'rust_light': 'a16e50', 'dust': '9f8b75',
}
NAMES = list(COLORS)
INDEX = {name: i for i, name in enumerate(NAMES)}
RGB = [tuple(bytes.fromhex(value)) for value in COLORS.values()]


class Art:
    def __init__(self, fill='clear', size=32):
        self.size = size
        self.pixels = [[INDEX[fill]] * size for _ in range(size)]

    def dot(self, x, y, color):
        if 0 <= x < self.size and 0 <= y < self.size:
            self.pixels[y][x] = INDEX[color]

    def rect(self, x, y, w, h, color):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.dot(xx, yy, color)

    def line(self, x0, y0, x1, y1, color):
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for n in range(steps + 1):
            self.dot(round(x0 + (x1 - x0) * n / steps), round(y0 + (y1 - y0) * n / steps), color)

    def save(self, name, path=None, transparent=True):
        def chunk(kind, data):
            return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', binascii.crc32(kind + data) & 0xffffffff)
        raw = b''.join(b'\0' + bytes(row) for row in self.pixels)
        palette = b''.join(bytes(color) for color in RGB)
        png = b'\x89PNG\r\n\x1a\n'
        png += chunk(b'IHDR', struct.pack('>IIBBBBB', self.size, self.size, 8, 3, 0, 0, 0))
        png += chunk(b'PLTE', palette)
        if transparent:
            png += chunk(b'tRNS', b'\0' + b'\xff' * (len(RGB) - 1))
        png += chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
        (path or OUT / f'{name}.png').write_bytes(png)


def ground():
    for variant in range(4):
        rng = random.Random(170 + variant)
        a = Art('wood')
        for y in range(0, 32, 8):
            a.rect(0, y, 32, 1, 'wood_seam')
            a.rect(0, y + 1, 32, 1, 'wood_light')
            seam = (variant * 7 + y * 2 + 9) % 32
            a.line(seam, y, seam, y + 7, 'wood_dark')
            a.dot(seam + 2, y + 2, 'wood_dark')
            a.dot(seam - 2, y + 6, 'wood_dark')
            for _ in range(4):
                x, yy = rng.randrange(32), y + rng.randrange(3, 7)
                a.line(x, yy, min(31, x + rng.randrange(3, 11)), yy, rng.choice(['wood_mid', 'wood_light']))
        kx, ky = rng.randrange(4, 27), rng.choice([4, 12, 20, 28])
        a.line(kx - 3, ky, kx + 3, ky, 'wood_dark')
        a.line(kx - 1, ky + 1, kx + 2, ky + 1, 'wood_glint')
        a.save(f'wood_{variant}')

        a = Art('grass')
        for _ in range(52):
            x, y = rng.randrange(32), rng.randrange(32)
            a.rect(x, y, rng.randrange(1, 4), 1, rng.choice(['grass_dark', 'grass_mid']))
        for _ in range(17):
            x, y = rng.randrange(1, 30), rng.randrange(3, 31)
            a.line(x, y, x, y - 2, 'grass_light')
            a.dot(x - 1, y - 3, 'grass_mid')
            a.dot(x + 1, y - 1, 'grass_tip')
        a.save(f'grass_{variant}')

        a = Art('stone_dark')
        # Three courses of irregular hand-cut blocks. Never rotated in the scene.
        for row, y in enumerate([1, 10, 20]):
            cuts = [-8 + ((row + variant) % 2) * 8, 8 + ((row + variant) % 2) * 8, 24 + ((row + variant) % 2) * 8, 40]
            for left, right in zip(cuts, cuts[1:]):
                shade = rng.choice(['stone', 'stone_mid'])
                a.rect(left + 1, y, right - left - 2, 8, shade)
                a.line(left + 2, y, right - 2, y, 'stone_light')
                a.line(left + 1, y + 1, left + 1, y + 6, 'stone_light')
                a.line(left + 2, y + 7, right - 2, y + 7, 'stone_dark')
        for _ in range(12):
            x, y = rng.randrange(32), rng.randrange(29)
            a.dot(x, y, rng.choice(['stone', 'stone_mid']))
        a.rect(0, 30, 32, 2, 'ink')
        a.line(1, 29, 30, 29, 'stone')
        a.save(f'wall_{variant}')


def gate():
    for stage in range(3):
        a = Art()
        a.rect(0, 0, 32, 32, 'ink')
        a.rect(1, 1, 30, 29, 'steel_dark')
        a.rect(3, 3, 26, 25, 'stone_dark')
        for x in [4, 10, 16, 22, 28]:
            a.rect(x, 3, 2, 25, 'steel')
            a.line(x, 3, x, 26, 'steel_light')
        for y in [5, 22]:
            a.rect(2, y, 28, 4, 'steel')
            a.rect(2, y, 28, 1, 'steel_light')
            for x in [4, 11, 20, 27]:
                a.dot(x, y + 2, 'gold')
        a.rect(14, 13, 6, 7, 'ink')
        a.rect(15, 13, 4, 5, 'gold')
        a.rect(16, 15, 2, 2, 'wood_dark')
        if stage >= 1:
            a.line(7, 4, 14, 13, 'ink')
            a.line(8, 4, 15, 13, 'rust_light')
            a.rect(9, 12, 4, 4, 'ink')
            a.line(21, 20, 27, 27, 'rust')
        if stage == 2:
            a.rect(10, 15, 14, 6, 'ink')
            a.line(23, 9, 18, 18, 'steel_glint')
            a.line(5, 21, 13, 25, 'ink')
            a.rect(16, 22, 7, 4, 'ink')
        a.save(f'gate_{stage}')


def chairs():
    for variant, colors in enumerate([('red_dark', 'red', 'red_light'), ('teal_dark', 'teal', 'teal_light'), ('purple_deep', 'purple', 'lilac')]):
        dark, mid, light = colors
        a = Art()
        a.rect(6, 8, 21, 22, 'grass_dark')
        for x in [7, 23]:
            a.rect(x, 17, 3, 12, 'wood_dark')
            a.rect(x, 17, 2, 10, 'wood_glint')
        a.rect(6, 6, 21, 12, 'wood_dark')
        a.rect(7, 6, 19, 2, 'wood_glint')
        a.rect(9, 9, 15, 7, dark)
        a.rect(10, 9, 13, 5, mid)
        a.rect(10, 9, 13, 1, light)
        a.rect(7, 17, 19, 8, 'wood_dark')
        a.rect(9, 17, 15, 6, mid)
        a.rect(9, 17, 15, 1, light)
        a.rect(8, 24, 17, 2, 'wood_light')
        a.save(f'chair_{variant}')


def character(kind, direction, phase, action):
    a = Art()
    human = kind == 'human'
    walking = action == 'walk'
    attack = action == 'attack'
    bob = -1 if (walking and phase % 2) or (action == 'idle' and phase == 1) else 0
    stride = ([-1, 0, 1, 0][phase % 4] if walking else 0)
    a.rect(9, 27, 15, 2, 'grass_dark')
    a.rect(7, 26, 19, 1, 'grass_dark')
    # Boots sit within the same 32px cell throughout the animation.
    a.rect(10 - stride, 25, 5, 3, 'ink')
    a.rect(18 + stride, 25, 5, 3, 'ink')
    if human:
        a.rect(9, 12 + bob, 15, 13, 'ink')
        a.rect(10, 13 + bob, 13, 11, 'red_dark')
        a.rect(11, 13 + bob, 11, 7, 'steel')
        a.rect(11, 13 + bob, 11, 2, 'steel_light')
        a.rect(13, 16 + bob, 7, 4, 'steel_dark')
        a.rect(15, 21, 3, 5, 'red')
        a.rect(10, 21 + bob, 13, 2, 'wood_dark')
        a.rect(16, 21 + bob, 2, 2, 'gold')
    else:
        a.rect(10, 12 + bob, 13, 5, 'ink')
        a.rect(9, 16 + bob, 15, 7, 'ink')
        a.rect(7, 23, 19, 4, 'ink')
        a.rect(11, 12 + bob, 11, 5, 'purple')
        a.rect(10, 17 + bob, 13, 6, 'purple_deep')
        a.rect(9, 22, 15, 4, 'purple_deep')
        a.line(12, 16 + bob, 10, 25, 'purple')
        a.line(20, 16 + bob, 23, 25, 'purple_dark')
        a.line(16, 16 + bob, 16, 24, 'lilac')
        a.rect(11, 25, 12, 1, 'purple')
        a.dot(16, 18 + bob, 'gold_light')
    # Oversized hood/helmet with top-down crown and readable face.
    a.rect(11, 4 + bob, 11, 10, 'ink')
    a.rect(13, 3 + bob, 7, 12, 'ink')
    if human:
        a.rect(12, 5 + bob, 9, 8, 'steel')
        a.rect(13, 4 + bob, 7, 3, 'steel_light')
        a.rect(15, 4 + bob, 2, 5, 'steel_glint')
        if direction != 'north':
            a.rect(12, 10 + bob, 9, 2, 'ink')
            a.rect(15, 10 + bob, 2, 4, 'steel_light')
        a.rect(13, 1 + bob, 6, 3, 'red_dark')
        a.rect(15, 1 + bob, 4, 1, 'red')
    else:
        a.rect(12, 5 + bob, 9, 9, 'purple_deep')
        a.rect(13, 4 + bob, 7, 3, 'purple')
        a.rect(14, 4 + bob, 4, 1, 'lilac')
        if direction != 'north':
            face_x = 14 if direction == 'east' else 12 if direction == 'west' else 13
            a.rect(face_x, 8 + bob, 7, 5, 'skin')
            a.rect(face_x + 1, 8 + bob, 5, 2, 'skin_light')
            a.dot(face_x + 1, 10 + bob, 'ink')
            a.dot(face_x + 5, 10 + bob, 'ink')
            a.dot(face_x + 1, 11 + bob, 'teal_light')
            a.rect(face_x + 2, 13 + bob, 3, 2, 'skin_dark')
    a.rect(7, 15 + bob, 4, 6, 'steel_dark' if human else 'purple')
    a.rect(22, 15 + bob, 4, 6, 'steel_dark' if human else 'purple')
    a.rect(8, 20 + bob, 3, 3, 'skin_dark')
    a.rect(23, 20 + bob, 3, 3, 'skin')
    if direction == 'north':
        a.rect(11, 13 + bob, 11, 11, 'red_dark' if human else 'purple_deep')
        a.line(12, 14 + bob, 12, 23, 'red' if human else 'purple')
    if human:
        if attack and phase in (1, 2):
            if direction == 'north':
                a.line(24, 17, 24, 1, 'steel_light')
                a.line(25, 17, 25, 2, 'steel_glint')
                a.rect(21, 15, 7, 2, 'gold')
            elif direction == 'south':
                a.line(23, 18, 13, 30, 'steel_light')
                a.line(24, 18, 14, 30, 'steel_glint')
                a.line(19, 18, 25, 23, 'gold')
            else:
                end = 31 if direction == 'east' else 0
                a.line(23 if direction == 'east' else 8, 18, end, 16, 'steel_glint')
                a.line(23 if direction == 'east' else 8, 19, end, 17, 'steel')
            if phase == 2:
                a.line(25, 3, 29, 7, 'dust')
                a.line(29, 7, 30, 12, 'dust')
        else:
            a.rect(26, 12 + bob, 2, 11, 'ink')
            a.rect(26, 12 + bob, 1, 9, 'steel_glint')
            a.rect(24, 20 + bob, 6, 2, 'gold')
            a.rect(26, 22 + bob, 2, 3, 'wood_light')
    a.save(f'{kind}_{direction}_{action}_{phase}')


def icons():
    a = Art()
    a.rect(6, 8, 8, 5, 'red_light')
    a.rect(18, 8, 8, 5, 'red_light')
    a.rect(4, 11, 24, 8, 'red')
    a.rect(7, 19, 18, 3, 'red')
    a.rect(10, 22, 12, 3, 'red')
    a.rect(13, 25, 6, 2, 'red')
    a.rect(15, 27, 2, 1, 'red_dark')
    a.rect(7, 11, 5, 3, 'red_light')
    a.save('icon_heart')
    for name in ['bone', 'stone', 'moon', 'new', 'build', 'raise', 'pause', 'play']:
        a = Art()
        if name == 'bone':
            a.line(9, 23, 23, 9, 'muted')
            a.line(10, 24, 24, 10, 'muted')
            for x, y in [(7, 21), (9, 23), (21, 7), (23, 9)]:
                a.rect(x, y, 4, 4, 'muted')
        elif name in ('stone', 'build'):
            for x, y, w in [(6, 18, 10), (17, 18, 10), (10, 10, 12)]:
                a.rect(x, y, w, 7, 'muted' if name == 'stone' else 'lilac')
                a.line(x + 1, y + 1, x + w - 2, y + 1, 'stone_light')
        elif name == 'moon':
            for y in range(6, 26):
                for x in range(6, 26):
                    if (x - 16) ** 2 + (y - 16) ** 2 < 100 and (x - 21) ** 2 + (y - 12) ** 2 > 80:
                        a.dot(x, y, 'muted')
        elif name == 'new':
            for x0, y0, x1, y1 in [(8, 9, 23, 9), (23, 9, 26, 15), (26, 15, 23, 23), (23, 23, 10, 24), (10, 24, 6, 18)]:
                a.line(x0, y0, x1, y1, 'lilac')
                a.line(x0, y0 + 1, x1, y1 + 1, 'lilac')
            a.rect(7, 6, 3, 9, 'lilac')
            a.rect(7, 12, 8, 3, 'lilac')
        elif name == 'raise':
            a.rect(9, 7, 14, 14, 'lilac')
            a.rect(11, 5, 10, 17, 'lilac')
            a.rect(11, 11, 4, 4, 'panel')
            a.rect(18, 11, 4, 4, 'panel')
            for x in [12, 16, 20]:
                a.rect(x, 21, 2, 4, 'lilac')
        elif name == 'pause':
            a.rect(9, 8, 5, 17, 'lilac')
            a.rect(19, 8, 5, 17, 'lilac')
        elif name == 'play':
            for x in range(11, 25):
                h = max(1, 18 - (x - 11) * 2)
                a.rect(x, 16 - h // 2, 1, h, 'lilac')
        a.save(f'icon_{name}')
    a = Art()
    a.rect(15, 15, 2, 2, 'purple_light')
    a.save('path_dot')
    a = Art()
    for x, y, dx, dy in [(3, 3, 1, 1), (28, 3, -1, 1), (3, 28, 1, -1), (28, 28, -1, -1)]:
        a.line(x, y, x + 5 * dx, y, 'purple_light')
        a.line(x, y, x, y + 5 * dy, 'purple_light')
    a.save('destination')
    a = Art()
    # Sparse opaque pixels flash without introducing blended out-of-palette artwork.
    for y in range(32):
        for x in range(32):
            if (x + y) % 3 == 0:
                a.dot(x, y, 'red_light')
    a.save('damage_flash')
    for n in range(4):
        a = Art()
        a.rect(13, 13, 3 + n, 3, 'steel' if n % 2 else 'rust')
        a.line(13, 13, 15 + n, 13, 'steel_light')
        a.save(f'debris_{n}')


def app_icon():
    # App Store metadata requires 1024px; nearest-neighbor enlargement of a 32px tile.
    small = Art('void')
    small.rect(4, 6, 24, 22, 'stone_dark')
    for x in [5, 13, 21]:
        small.rect(x, 4, 6, 8, 'stone')
        small.rect(x, 4, 6, 1, 'stone_light')
    small.rect(6, 12, 20, 15, 'stone')
    small.rect(12, 15, 8, 13, 'ink')
    small.rect(13, 13, 6, 13, 'ink')
    small.rect(14, 17, 4, 8, 'purple')
    small.rect(13, 23, 6, 3, 'lilac')
    small.dot(15, 18, 'skin_light')
    small.dot(17, 18, 'skin_light')
    large = Art('void', 1024)
    for y in range(1024):
        for x in range(1024):
            large.pixels[y][x] = small.pixels[y // 32][x // 32]
    folder = ROOT / 'DarkFortress/Resources/Assets.xcassets/AppIcon.appiconset'
    large.save('AppIcon', folder / 'AppIcon.png', transparent=False)
    (folder / 'Contents.json').write_text(json.dumps({'images': [{'filename': 'AppIcon.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}], 'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    # Remove only this generator's previous character frames when frame counts change.
    for previous in OUT.glob('*.png'):
        if previous.stem.startswith(('human_', 'necromancer_')):
            previous.unlink()
    ground()
    gate()
    chairs()
    for kind in ['necromancer', 'human']:
        for direction in ['north', 'east', 'south', 'west']:
            for action, count in [('idle', 2), ('walk', 4)] + ([('attack', 3)] if kind == 'human' else []):
                for phase in range(count):
                    character(kind, direction, phase, action)
    icons()
    app_icon()
    (ROOT / 'DarkFortress/Resources/palette.json').write_text(json.dumps(COLORS, indent=2) + '\n')
    print(f'Generated {len(list(OUT.glob("*.png")))} 32×32 sprites, all sharing {len(COLORS)} palette entries.')
