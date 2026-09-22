"""Overworld art in the style of the Game Boy Color Pokemon games (original drawings).

Every metatile is 16x16 px, colour indices 0-3, plus one BG palette per 8x8 quadrant.
"""


def rgb(r, g, b):
    return (r & 31) | ((g & 31) << 5) | ((b & 31) << 10)


# BG palettes (index: purpose)
PAL_TEXT, PAL_GREEN, PAL_STONE, PAL_ROOF_RED, PAL_ROOF_GREY, PAL_WALL, PAL_WATER, PAL_NEON = range(8)
OW_BG = [
    [rgb(31, 31, 31), rgb(26, 26, 28), rgb(12, 12, 16), rgb(3, 3, 8)],       # text box
    [rgb(24, 30, 17), rgb(13, 24, 9), rgb(5, 15, 6), rgb(2, 6, 3)],          # grass / trees
    [rgb(28, 27, 24), rgb(20, 20, 20), rgb(13, 13, 15), rgb(4, 4, 7)],       # pavement / road / rails
    [rgb(30, 28, 22), rgb(29, 12, 8), rgb(18, 5, 4), rgb(5, 3, 5)],          # red roofs
    [rgb(30, 28, 22), rgb(17, 18, 22), rgb(10, 11, 15), rgb(4, 4, 7)],       # grey roofs
    [rgb(30, 28, 22), rgb(12, 19, 30), rgb(25, 29, 31), rgb(5, 4, 6)],       # walls + windows
    [rgb(24, 29, 31), rgb(9, 17, 29), rgb(5, 9, 21), rgb(3, 4, 10)],         # water
    [rgb(6, 3, 11), rgb(15, 5, 21), rgb(31, 8, 24), rgb(31, 31, 31)],        # Ballhaus West neon
]


def P(rows):
    assert len(rows) == 16 and all(len(r) == 16 for r in rows), rows
    return [[int(c) for c in r] for r in rows]


def fill(c):
    return [[c] * 16 for _ in range(16)]


def transpose(m):
    return [list(r) for r in zip(*m)]


def mt(img, pal):
    """metatile = (16x16 image, [pal TL, TR, BL, BR])"""
    if isinstance(pal, int):
        pal = [pal] * 4
    return (img, pal)


GRASS = P([
    "0000000000000000",
    "0000000000000000",
    "0010000000000000",
    "0101000000000100",
    "0000000000001010",
    "0000000000000000",
    "0000000001000000",
    "0000000010100000",
    "0000000000000000",
    "0000000000000000",
    "0100000000000000",
    "1010000000000010",
    "0000000000000101",
    "0000000000000000",
    "0000010000000000",
    "0000101000000000",
])

TREE = P([
    "0000333333330000",
    "0033111111113300",
    "0311101111111130",
    "0311011111111130",
    "3111111111101113",
    "3111111111011113",
    "3111111111111113",
    "3210111111111123",
    "3221111111111223",
    "0322211111122230",
    "0332222222222330",
    "0003322222233000",
    "0000033223300000",
    "0000003223000000",
    "0000003223000000",
    "0000000330000000",
])

BUSH = P([
    "0000000000000000",
    "0000000000000000",
    "0000333003330000",
    "0003111331113000",
    "0031101111011300",
    "0031011110111300",
    "0311111111111130",
    "0311111111111130",
    "0321111111111230",
    "0322111111112230",
    "0032222222222300",
    "0003333333333000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
    "0000000000000000",
])


def pavement():
    """large light slabs, like the town ground in the GBC games"""
    m = fill(0)
    for i in range(16):
        m[15][i] = 1
        m[i][15] = 1
    for x, y in ((3, 4), (11, 10), (6, 12)):
        m[y][x] = 1
    return m


def plaza():
    """pedestrian zone: small offset cobbles"""
    m = fill(0)
    for y in range(16):
        for x in range(16):
            ox = 2 if (y // 4) % 2 else 0
            if y % 4 == 3 or (x + ox) % 4 == 3:
                m[y][x] = 1
    return m


def road(curbs=(False, False, False, False)):
    """asphalt; curbs = (north, south, west, east) edges drawn as a kerb line"""
    m = fill(1)
    for x, y in ((2, 2), (9, 5), (13, 11), (5, 13), (12, 1), (7, 9)):
        m[y][x] = 2
    n, s, w, e = curbs
    for i in range(16):
        if n:
            m[0][i], m[1][i] = 3, 2
        if s:
            m[15][i], m[14][i] = 3, 2
        if w:
            m[i][0], m[i][1] = 3, 2
        if e:
            m[i][15], m[i][14] = 3, 2
    return m


def road_dash(vertical=False):
    m = road()
    for i in range(16):
        if i % 8 < 5:
            m[7][i] = m[8][i] = 0
    return transpose(m) if vertical else m


def tram(vertical=False):
    m = road()
    for x in range(16):
        for ry in (3, 12):
            m[ry - 1][x] = 0
            m[ry][x] = 3
    return transpose(m) if vertical else m


def rails(vertical=False):
    m = fill(2)
    for y in range(16):
        for x in range(16):
            if (x * 7 + y * 3) % 11 == 0:
                m[y][x] = 1
    for x in range(16):
        if x % 4 == 1:
            for y in range(2, 14):
                m[y][x] = 1
        for ry in (4, 11):
            m[ry][x] = 3
            m[ry - 1][x] = 0
    return transpose(m) if vertical else m


def water():
    m = fill(1)
    for y, x0 in ((3, 2), (3, 10), (8, 6), (12, 1), (12, 12)):
        for dx in range(4):
            m[y][(x0 + dx) % 16] = 0
        m[y + 1][(x0 + 4) % 16] = 2
        m[y + 1][(x0 - 1) % 16] = 2
    return m


def roof(top, left, right, bottom_eave):
    """GSC-style tiled roof: courses every 4 rows, staggered seams, dark outline on edges"""
    m = fill(1)
    for y in range(16):
        for x in range(16):
            if y % 4 == 3:
                m[y][x] = 2
            elif y % 4 == 1 and (x + (2 if (y // 4) % 2 else 0)) % 4 == 0:
                m[y][x] = 2
            elif y % 4 == 0 and x % 8 == 5:
                m[y][x] = 0
    if top:
        for x in range(16):
            m[0][x] = 3
            m[1][x] = 0 if 0 < x < 15 else m[1][x]
    if bottom_eave:
        for x in range(16):
            m[14][x] = 2
            m[15][x] = 3
    if left:
        for y in range(16):
            m[y][0] = 3
    if right:
        for y in range(16):
            m[y][15] = 3
    return m


def wall(left, right, door=False):
    m = fill(0)
    for x in range(16):
        m[0][x] = 3
        m[1][x] = 3 if x % 2 else 0          # eave shadow
        m[15][x] = 3
    if door:
        for y in range(4, 15):
            for x in range(4, 12):
                edge = x in (4, 11) or y == 4
                m[y][x] = 3 if edge else 1
        for y in range(6, 10):
            for x in (6, 9):
                m[y][x] = 2
        m[10][10] = 2
    else:
        for x0 in (2, 9):
            for y in range(4, 11):
                for x in range(x0, x0 + 5):
                    edge = x in (x0, x0 + 4) or y in (4, 10)
                    m[y][x] = 3 if edge else 1
            m[5][x0 + 1] = m[6][x0 + 1] = m[5][x0 + 2] = 2   # glint
            for x in range(x0 - 1, x0 + 6):
                m[11][x] = 3                              # sill
    if left:
        for y in range(16):
            m[y][0] = 3
    if right:
        for y in range(16):
            m[y][15] = 3
    return m


def text_band(text, font_render, color=3, bg=0, width_mt=None):
    """image with text drawn using the 8x8 font renderer, centred, 16 px high"""
    w = len(text) * 8
    wm = width_mt or (w + 15) // 16
    img = [[bg] * (wm * 16) for _ in range(16)]
    x0 = (wm * 16 - w) // 2
    for i, ch in enumerate(text):
        g = font_render(ch)
        for y in range(8):
            for x in range(8):
                if g[y][x] == 3:
                    img[4 + y][x0 + i * 8 + x] = color
                elif g[y][x] == 1:
                    img[4 + y][x0 + i * 8 + x] = 1 if color != 1 else 2
    return img


def fence():
    """dark wooden fence on grass (the zoo boundary)"""
    m = [row[:] for row in GRASS]
    for x in range(16):
        m[5][x] = m[6][x] = 2
        m[10][x] = m[11][x] = 2
        m[4][x] = m[9][x] = 3
    for x0 in (1, 9):
        for y in range(2, 15):
            for x in range(x0, x0 + 4):
                m[y][x] = 3 if x in (x0, x0 + 3) or y in (2, 14) else 1
    return m


def neon_door():
    m = fill(0)
    for y in range(2, 16):
        for x in range(3, 13):
            edge = x in (3, 12) or y == 2
            m[y][x] = 2 if edge else 1
    for y in range(3, 16):
        m[y][7] = m[y][8] = 0
    for y in range(5, 8):
        m[y][5] = m[y][10] = 3
    m[10][6] = m[10][9] = 3
    return m


def neon_roof():
    m = fill(1)
    for y in range(16):
        for x in range(16):
            if y % 4 == 3:
                m[y][x] = 0
    return m


GREEN_SET = {
    "grass": mt(GRASS, PAL_GREEN),
    "tree": mt(TREE, PAL_GREEN),
    "bush": mt(BUSH, PAL_GREEN),
}
