"""Turn the rasterised OSM grid into GBC metatiles (map, tiles, collision, street names)."""
import owart as A
import osmmap as O

SOLID = 0x80
GOAL_EVENT = 0x01


def build(font_render):
    m = O.build()
    W, H, kind, bid = m["W"], m["H"], m["kind"], m["bid"]
    hbf, ballhaus, goal = m["hbf_id"], m["ballhaus_id"], m["goal"]

    metas = []          # (img, pals, collision)
    index = {}

    def meta(key, img, pals, coll=0):
        if key not in index:
            index[key] = len(metas)
            if isinstance(pals, int):
                pals = [pals] * 4
            metas.append((img, pals, coll))
        return index[key]

    def is_b(x, y):
        return 0 <= x < W and 0 <= y < H and kind[y][x] == O.BUILDING

    # Hauptbahnhof sign across the top row of the station roof
    hbf_cells = [(x, y) for y in range(H) for x in range(W) if bid[y][x] == hbf]
    top = min(y for _, y in hbf_cells)
    row = sorted(x for x, y in hbf_cells if y == top)
    sign_text = "HAUPTBAHNHOF"
    sign_w = (len(sign_text) * 8 + 8 + 15) // 16
    mid = row[len(row) // 2]
    sign_x0 = mid - sign_w // 2
    sign = A.text_band(sign_text, font_render, color=3, bg=0, width_mt=sign_w)
    for y in range(16):
        for x in range(sign_w * 16):
            if y in (1, 14):
                sign[y][x] = 2
            if y in (0, 15):
                sign[y][x] = 3

    # connected building blocks share one roof colour
    comp = [[0] * W for _ in range(H)]
    ncomp = 0
    for y0 in range(H):
        for x0 in range(W):
            if kind[y0][x0] == O.BUILDING and not comp[y0][x0]:
                ncomp += 1
                stack = [(x0, y0)]
                comp[y0][x0] = ncomp
                while stack:
                    x, y = stack.pop()
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        xx, yy = x + dx, y + dy
                        if is_b(xx, yy) and not comp[yy][xx]:
                            comp[yy][xx] = ncomp
                            stack.append((xx, yy))

    def is_road(x, y):
        return not (0 <= x < W and 0 <= y < H) or kind[y][x] in (O.ROAD, O.TRAM)

    out = [[0] * W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            k = kind[y][x]
            if k == O.GRASS:
                out[y][x] = meta("grass", A.GRASS, A.PAL_GREEN)
            elif k == O.TREE:
                out[y][x] = meta("tree", A.TREE, A.PAL_GREEN, SOLID)
            elif k == O.PAVE:
                out[y][x] = meta("pave", A.pavement(), A.PAL_STONE)
            elif k == O.PLAZA:
                out[y][x] = meta("plaza", A.plaza(), A.PAL_STONE)
            elif k == O.ROAD:
                curbs = (not is_road(x, y - 1), not is_road(x, y + 1), not is_road(x - 1, y), not is_road(x + 1, y))
                out[y][x] = meta(("road",) + curbs, A.road(curbs), A.PAL_STONE)
            elif k == O.TRAM:
                d = m["tram_dir"][y][x]
                if d == 0:
                    horiz = (0 < x < W - 1 and (kind[y][x - 1] == O.TRAM or kind[y][x + 1] == O.TRAM))
                    d = 1 if horiz else 2
                out[y][x] = meta(("tram", d), A.tram(d == 2), A.PAL_STONE)
            elif k == O.RAILS:
                out[y][x] = meta("rails", A.rails(), A.PAL_STONE, SOLID)
            elif k == O.WATER:
                out[y][x] = meta("water", A.water(), A.PAL_WATER, SOLID)
            else:
                b = bid[y][x]
                n, s, w, e = is_b(x, y - 1), is_b(x, y + 1), is_b(x - 1, y), is_b(x + 1, y)
                if b == ballhaus:
                    if (x, y) == goal:
                        out[y][x] = meta("neon_door", A.neon_door(), A.PAL_NEON, SOLID | GOAL_EVENT)
                    else:
                        img = A.roof(not n, not w, not e, False)
                        out[y][x] = meta(("neon", n, w, e), img, A.PAL_NEON, SOLID)
                    continue
                if b == hbf and y == top and sign_x0 <= x < sign_x0 + sign_w:
                    i = x - sign_x0
                    img = [r[i * 16:i * 16 + 16] for r in sign]
                    out[y][x] = meta(("hbfsign", i), img, A.PAL_ROOF_GREY, SOLID)
                    continue
                if not s:
                    door = w and e and (x * 7 + y * 3) % 5 == 0
                    key = ("door",) if door else ("wall", w, e)
                    out[y][x] = meta(key, A.wall(not w, not e, door), A.PAL_WALL, SOLID)
                    continue
                pal = A.PAL_ROOF_GREY if (b == hbf or (comp[y][x] * 7) % 10 >= 7) else A.PAL_ROOF_RED
                eave = not is_b(x, y + 2)
                key = ("roof", pal, not n, not w, not e, eave)
                out[y][x] = meta(key, A.roof(not n, not w, not e, eave), pal, SOLID)

    border = meta("tree", A.TREE, A.PAL_GREEN, SOLID)

    # the goal must be reachable from the start
    from collections import deque
    sx, sy = m["start"]
    dist = {(sx, sy): 0}
    q = deque([(sx, sy)])
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            xx, yy = x + dx, y + dy
            if 0 <= xx < W and 0 <= yy < H and (xx, yy) not in dist and not metas[out[yy][xx]][2] & SOLID:
                dist[(xx, yy)] = dist[(x, y)] + 1
                q.append((xx, yy))
    gx, gy = goal
    reach = [dist[(gx + dx, gy + dy)] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)) if (gx + dx, gy + dy) in dist]
    assert reach, "Ballhaus West entrance not reachable from the Hauptbahnhof"
    route_len = min(reach) + 1
    return {"W": W, "H": H, "map": out, "metas": metas, "border": border, "start": m["start"],
            "goal": goal, "names": m["names"], "name_list": m["name_list"], "route_len": route_len}


def preview(res, path):
    from PIL import Image
    pal_rgb = [[((c & 31) * 8, ((c >> 5) & 31) * 8, ((c >> 10) & 31) * 8) for c in p] for p in A.OW_BG]
    W, H = res["W"], res["H"]
    img = Image.new("RGB", (W * 16, H * 16))
    px = img.load()
    for my in range(H):
        for mx in range(W):
            mimg, pals, _ = res["metas"][res["map"][my][mx]]
            for y in range(16):
                for x in range(16):
                    q = (y // 8) * 2 + x // 8
                    px[mx * 16 + x, my * 16 + y] = pal_rgb[pals[q]][mimg[y][x]]
    img.save(path)
