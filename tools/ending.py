"""Ending illustration: night at Ballhaus West, 160x112 px (tile rows 0-13).

Painted per region so that each 8x8 tile uses exactly one of the ending's BG palettes.
Rows 14-17 stay free for text drawn at runtime.
"""
import math
import random


def rgb(r, g, b):
    return (r & 31) | ((g & 31) << 5) | ((b & 31) << 10)


SKY0, SKY1 = rgb(2, 1, 8), rgb(7, 3, 16)
WALL = rgb(5, 3, 10)
TEXT_BG = rgb(2, 1, 6)
PAL_TEXT, PAL_LOGO, PAL_SKY, PAL_BUILDING, PAL_NEON, PAL_CROWD, PAL_CYAN, PAL_YELLOW = range(8)
END_BG = [
    [TEXT_BG, rgb(0, 0, 2), rgb(16, 16, 22), rgb(31, 31, 31)],
    [SKY0, rgb(1, 0, 4), rgb(20, 4, 20), rgb(31, 20, 31)],        # logo, cycled at runtime
    [SKY0, SKY1, rgb(31, 12, 26), rgb(31, 31, 31)],                # sky: 2 = beams (cycled), 3 = stars
    [WALL, rgb(9, 5, 15), rgb(31, 24, 10), rgb(1, 0, 3)],          # building: 2 = lit windows
    [WALL, rgb(15, 4, 21), rgb(31, 8, 24), rgb(31, 31, 31)],       # neon sign
    [WALL, rgb(13, 3, 17), rgb(1, 0, 2), rgb(31, 18, 28)],         # crowd: 2 = silhouettes, 3 = rim light
    [TEXT_BG, rgb(0, 0, 2), rgb(0, 18, 22), rgb(8, 31, 31)],
    [TEXT_BG, rgb(0, 0, 2), rgb(22, 16, 0), rgb(31, 28, 6)],
]

W, H = 160, 112
BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def build(font_glyph, big_glyph):
    """font_glyph(ch) -> 8x8 (0/1/3), big_glyph(ch) -> 16x16 (0-3)"""
    px = [[0] * W for _ in range(H)]
    tpal = [[PAL_SKY] * (W // 8) for _ in range(H // 8)]
    rnd = random.Random(29102026)

    def region(c0, r0, c1, r1, pal):
        for r in range(r0, r1):
            for c in range(c0, c1):
                tpal[r][c] = pal

    # --- sky: gradient, beams, moon, stars (rows 0-7) -----------------------------
    for y in range(64):
        for x in range(W):
            t = max(0.0, (y - 16) / 48)
            px[y][x] = 1 if t * 16 > BAYER[y % 4][x % 4] else 0

    def beam(x0, y0, x1, spread):
        for y in range(0, y0):
            f = (y0 - y) / y0
            cx = x0 + (x1 - x0) * f
            half = 2 + spread * f
            for x in range(int(cx - half), int(cx + half) + 1):
                if 0 <= x < W:
                    edge = abs(x - cx) > half - 2
                    if not edge or (x + y) % 2 == 0:
                        px[y][x] = 2

    beam(36, 50, 4, 10)
    beam(124, 50, 156, 10)
    beam(56, 50, 36, 6)
    beam(104, 50, 124, 6)
    # moon
    for y in range(4, 20):
        for x in range(128, 146):
            d = math.hypot(x - 137, y - 12)
            d2 = math.hypot(x - 141, y - 9)
            if d <= 7 and d2 > 6:
                px[y][x] = 3
    for _ in range(60):
        x, y = rnd.randrange(W), rnd.randrange(52)
        if px[y][x] in (0, 1):
            px[y][x] = 3

    # --- ENKA in the 2x font, top centre (rows 1-2, cols 6-13) ---------------------
    region(6, 1, 14, 3, PAL_LOGO)
    for y in range(8, 24):
        for x in range(48, 112):
            px[y][x] = 0
    for i, ch in enumerate("ENKA"):
        g = big_glyph(ch)
        for y in range(16):
            for x in range(16):
                if g[y][x]:
                    px[8 + y][48 + i * 16 + x] = g[y][x]

    # --- the building (cols 3-16, rows 6-11) --------------------------------------
    region(3, 6, 17, 12, PAL_BUILDING)
    for y in range(48, 96):
        for x in range(24, 136):
            c = 0
            if y in (48, 49) or x in (24, 135):
                c = 3                               # roof line / outline
            elif y == 50:
                c = 1
            elif (y - 52) % 6 == 5 and (x // 3) % 2 == 0:
                c = 1                               # brick courses
            px[y][x] = c
    # lit windows (row 10)
    for wx in range(30, 130, 14):
        if 60 <= wx <= 92:
            continue
        for y in range(81, 90):
            for x in range(wx, wx + 8):
                px[y][x] = 3 if (x == wx or x == wx + 7 or y in (81, 89)) else 2
        for y in range(82, 89):
            px[y][wx + 4] = 3

    # neon sign (rows 7-9, cols 4-15): light strips above and below the letters
    region(4, 7, 16, 10, PAL_NEON)
    for y in range(56, 80):
        for x in range(32, 128):
            px[y][x] = 0
    for x in range(34, 126):
        if x % 2 == 0:
            px[57][x] = px[78][x] = 3
    for text, y0 in (("BALLHAUS", 60), ("WEST", 69)):
        x0 = 80 - len(text) * 4
        for i, ch in enumerate(text):
            g = font_glyph(ch)
            for y in range(8):
                for x in range(8):
                    X, Y = x0 + i * 8 + x, y0 + y
                    if g[y][x] == 3:
                        px[Y][X] = 2
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                            if px[Y + dy][X + dx] == 0 and 59 <= Y + dy <= 77:
                                px[Y + dy][X + dx] = 1
    # door glow (row 10-11 centre, part of the building region)
    for y in range(82, 96):
        for x in range(68, 92):
            edge = x in (68, 91) or y == 82
            px[y][x] = 3 if edge else 2
    for y in range(83, 96):
        px[y][79] = px[y][80] = 1

    # --- crowd (rows 12-13) ---------------------------------------------------------
    region(0, 12, 20, 14, PAL_CROWD)
    for y in range(96, 112):
        for x in range(W):
            inside = 24 <= x < 136
            px[y][x] = 0 if inside else (1 if (y + x) % 2 == 0 and y > 100 else 0)
            if inside and 68 <= x < 92:
                px[y][x] = 1                        # light spilling from the door
    x = 2
    while x < W - 4:
        hx = x + rnd.randrange(2, 5)
        top = 99 + rnd.randrange(0, 4)
        for y in range(top, 112):
            for xx in range(hx - 3, hx + 4):
                body = y >= top + 7 and abs(xx - hx) <= 3 + (y - top - 7) // 3
                head = math.hypot(xx - hx, y - (top + 3)) <= 3
                if (body or head) and 0 <= xx < W:
                    px[y][xx] = 2
        if rnd.random() < 0.55:                     # hands up!
            side = rnd.choice((-1, 1))
            for i in range(9):
                ax, ay = hx + side * (3 + i // 3), top + 8 - i
                if 0 <= ax < W and 96 <= ay < 112:
                    px[ay][ax] = 2
        for xx in range(hx - 2, hx + 3):            # rim light on the head
            if 0 <= xx < W and 96 <= top < 112 and px[top][xx] == 2:
                px[top][xx] = 3
        x += rnd.randrange(7, 11)

    tiles, idx = [], {}
    tmap, amap = [], []
    for r in range(H // 8):
        for c in range(W // 8):
            t = tuple(tuple(px[r * 8 + y][c * 8:c * 8 + 8]) for y in range(8))
            if t not in idx:
                idx[t] = len(tiles)
                tiles.append([list(row) for row in t])
            tmap.append(idx[t])
            amap.append(0x08 | tpal[r][c])
    return tiles, tmap, amap


def preview(tiles, tmap, amap, path):
    from PIL import Image
    img = Image.new("RGB", (W, H))
    for i, (t, a) in enumerate(zip(tmap, amap)):
        pal = END_BG[a & 7]
        r, c = divmod(i, W // 8)
        for y in range(8):
            for x in range(8):
                v = pal[tiles[t][y][x]]
                img.putpixel((c * 8 + x, r * 8 + y), ((v & 31) * 8, ((v >> 5) & 31) * 8, ((v >> 10) & 31) * 8))
    img.resize((W * 3, H * 3), 0).save(path)
