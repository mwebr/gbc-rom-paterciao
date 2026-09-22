"""Rasterise the OpenStreetMap extract (Karlsruhe Hbf -> Ballhaus West) into a grid of
16x16 metatile cells, one cell = CELL_M metres, with straightened streets.

Result: grid of cell kinds + building ids + street-name ids + tram routes + start / goal.
Map data (c) OpenStreetMap contributors, ODbL.
"""
import json
import math
import os

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "osm", "karlsruhe_hbf_europaplatz.json")

LAT0, LON0 = 49.0112, 8.3895
LAT1, LON1 = 48.9918, 8.4052
CELL_M = 20
SUB = 10                              # raster pixels per cell (2 m per pixel)
M_PER_LAT = 111210.0
M_PER_LON = 111320.0 * math.cos(math.radians(49.0))

W = int((LON1 - LON0) * M_PER_LON / CELL_M)
H = int((LAT0 - LAT1) * M_PER_LAT / CELL_M)

BALLHAUS = (49.00937, 8.39152)        # Hirschstrasse 18

GRASS, TREE, PAVE, PLAZA, ROAD, TRAM, RAILS, WATER, BUILDING, FENCE = range(10)

ROAD_W = {"motorway": 2, "trunk": 2, "primary": 2, "secondary": 1, "tertiary": 1,
          "residential": 1, "unclassified": 1, "living_street": 1, "service": 1}
GREEN_LANDUSE = {"grass", "forest", "meadow", "recreation_ground", "village_green", "cemetery", "allotments"}
GREEN_LEISURE = {"park", "garden", "playground", "pitch", "dog_park"}
GREEN_NATURAL = {"wood", "scrub", "grassland", "heath"}
SNAP = math.tan(math.radians(24))


def to_px(lat, lon):
    return ((lon - LON0) * M_PER_LON / CELL_M * SUB, (LAT0 - lat) * M_PER_LAT / CELL_M * SUB)


def to_cellf(lat, lon):
    x, y = to_px(lat, lon)
    return x / SUB, y / SUB


def to_cell(lat, lon):
    x, y = to_cellf(lat, lon)
    return int(x), int(y)


def ascii_name(n):
    rep = {"ß": "SS", "ä": "AE", "ö": "OE", "ü": "UE", "Ä": "AE", "Ö": "OE", "Ü": "UE", "é": "E"}
    s = "".join(rep.get(c, c) for c in n).upper()
    s = s.replace("STRASSE", "STR.") if len(s) > 18 else s
    return "".join(c for c in s if c.isalnum() or c in " .-")[:18]


def simplify(pts, eps):
    """Douglas-Peucker"""
    if len(pts) < 3:
        return pts
    (x0, y0), (x1, y1) = pts[0], pts[-1]
    dx, dy = x1 - x0, y1 - y0
    ln = math.hypot(dx, dy) or 1e-9
    best, bi = -1, 0
    for i, (x, y) in enumerate(pts[1:-1], 1):
        d = abs(dy * (x - x0) - dx * (y - y0)) / ln
        if d > best:
            best, bi = d, i
    if best <= eps:
        return [pts[0], pts[-1]]
    return simplify(pts[:bi + 1], eps)[:-1] + simplify(pts[bi:], eps)


class Piece:
    """a straight street segment on the cell grid"""

    def __init__(self, orient, a0, a1, c, width, name, kind):
        self.orient, self.a0, self.a1, self.c = orient, min(a0, a1), max(a0, a1), c
        self.width, self.name, self.kind = width, name, kind
        self.line = None


def pieces_of(g, width, name, kind):
    pts = simplify([to_cellf(la, lo) for la, lo in g], 0.6)
    out = []
    for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
        dx, dy = x1 - x0, y1 - y0
        if abs(dy) <= SNAP * abs(dx):
            out.append(Piece("h", x0, x1, (y0 + y1) / 2, width, name, kind))
        elif abs(dx) <= SNAP * abs(dy):
            out.append(Piece("v", y0, y1, (x0 + x1) / 2, width, name, kind))
        else:
            p = Piece("d", 0, 0, 0, width, name, kind)
            p.line = (x0, y0, x1, y1)
            out.append(p)
    return out


def align(pieces):
    """give collinear, touching pieces (one street chopped into parts) a common line"""
    for orient in "hv":
        ps = [p for p in pieces if p.orient == orient]
        parent = list(range(len(ps)))

        def find(i):
            while parent[i] != i:
                parent[i] = parent[parent[i]]
                i = parent[i]
            return i

        for i, p in enumerate(ps):
            for j in range(i + 1, len(ps)):
                q = ps[j]
                same = p.name and p.name == q.name
                if abs(p.c - q.c) <= (1.6 if same else 1.0) and p.a0 - 1.5 <= q.a1 and q.a0 - 1.5 <= p.a1:
                    parent[find(i)] = find(j)
        groups = {}
        for i, p in enumerate(ps):
            groups.setdefault(find(i), []).append(p)
        for g in groups.values():
            total = sum(max(0.5, p.a1 - p.a0) for p in g)
            c = sum(p.c * max(0.5, p.a1 - p.a0) for p in g) / total
            wide = max(p.width for p in g)
            for p in g:
                p.c = c
                p.width = wide


def build():
    data = json.load(open(SRC))["layers"]
    size = (W * SUB, H * SUB)
    lay = {k: Image.new("L", size, 0) for k in ("green", "water", "ped", "rail", "zoo")}
    draw = {k: ImageDraw.Draw(v) for k, v in lay.items()}
    bld = Image.new("I", size, 0)
    dbld = ImageDraw.Draw(bld)

    def pts(g):
        return [to_px(la, lo) for la, lo in g]

    def poly(g):
        return len(g) >= 3 and g[0] == g[-1]

    for part in ("landuse", "leisure", "natural", "water"):
        for e in data.get(part, []):
            t, g = e["tags"], e["g"]
            if not poly(g):
                continue
            if (t.get("landuse") in GREEN_LANDUSE or t.get("leisure") in GREEN_LEISURE
                    or t.get("natural") in GREEN_NATURAL):
                draw["green"].polygon(pts(g), fill=255)
            if t.get("natural") == "water" or "water" in t or t.get("landuse") == "basin":
                draw["water"].polygon(pts(g), fill=255)
            if t.get("landuse") == "railway":
                draw["rail"].polygon(pts(g), fill=255)
    for e in data.get("zoo", []):
        draw["zoo"].polygon(pts(e["g"]), fill=255)
    for e in data.get("railway", []):
        t = e["tags"]
        if t.get("railway") == "rail" and t.get("tunnel") != "yes":
            draw["rail"].line(pts(e["g"]), fill=255, width=6)

    buildings = {}
    for e in data.get("building", []):
        g = e["g"]
        if not poly(g) or e["tags"].get("building") in ("roof", "carport"):
            continue
        bid = len(buildings) + 1
        buildings[bid] = e
        dbld.polygon(pts(g), fill=bid)
    for e in data.get("relations", []):
        t = e["tags"]
        if "building" in t:
            bid = len(buildings) + 1
            buildings[bid] = e
            for ring in e["outer"]:
                dbld.polygon(pts(ring), fill=bid)
            for ring in e["inner"]:
                dbld.polygon(pts(ring), fill=0)
            continue
        layer = None
        if t.get("natural") == "water" or "water" in t:
            layer = "water"
        elif (t.get("landuse") in GREEN_LANDUSE or t.get("leisure") in GREEN_LEISURE
              or t.get("natural") in GREEN_NATURAL):
            layer = "green"
        elif t.get("highway") == "pedestrian":
            layer = "ped"
        if layer:
            for ring in e["outer"]:
                draw[layer].polygon(pts(ring), fill=255)
            for ring in e["inner"]:
                draw[layer].polygon(pts(ring), fill=0)
    for e in data.get("highway", []):
        t, g = e["tags"], e["g"]
        if t["highway"] == "pedestrian" and poly(g) and t.get("area") == "yes":
            draw["ped"].polygon(pts(g), fill=255)

    def frac(img, cx, cy):
        box = img.crop((cx * SUB, cy * SUB, cx * SUB + SUB, cy * SUB + SUB))
        return sum(1 for v in box.getdata() if v >= 128) / (SUB * SUB)

    def majority(img, cx, cy):
        box = img.crop((cx * SUB, cy * SUB, cx * SUB + SUB, cy * SUB + SUB))
        cnt = {}
        for v in box.getdata():
            if v:
                cnt[v] = cnt.get(v, 0) + 1
        if not cnt:
            return 0, 0
        v, n = max(cnt.items(), key=lambda kv: kv[1])
        return v, n / (SUB * SUB)

    # --- base layer: everything except streets -----------------------------------
    kind = [[PAVE] * W for _ in range(H)]
    bid_grid = [[0] * W for _ in range(H)]
    zoo = [[False] * W for _ in range(H)]
    for cy in range(H):
        for cx in range(W):
            b, bf = majority(bld, cx, cy)
            zoo[cy][cx] = frac(lay["zoo"], cx, cy) >= 0.5
            if bf >= 0.3:
                k = BUILDING
                bid_grid[cy][cx] = b
            elif frac(lay["water"], cx, cy) >= 0.5:
                k = WATER
            elif frac(lay["rail"], cx, cy) >= 0.3:
                k = RAILS
            elif frac(lay["ped"], cx, cy) >= 0.4:
                k = PLAZA
            elif frac(lay["green"], cx, cy) >= 0.4 or zoo[cy][cx]:
                k = GRASS
            else:
                k = PAVE
            kind[cy][cx] = k

    # --- the Hauptbahnhof as one clean block, tracks behind it ----------------------
    hbf_id = next(b for b, e in buildings.items() if e["tags"].get("name") == "Karlsruhe Hauptbahnhof")
    hcells = [(x, y) for y in range(H) for x in range(W) if bid_grid[y][x] == hbf_id]
    hx0, hx1 = min(x for x, _ in hcells), max(x for x, _ in hcells)
    hy0 = min(y for _, y in hcells)
    hy1 = hy0 + 2
    for y in range(H):
        for x in range(W):
            if bid_grid[y][x] == hbf_id:
                kind[y][x] = PAVE
                bid_grid[y][x] = 0
    for y in range(hy0, hy1 + 1):
        for x in range(hx0, hx1 + 1):
            kind[y][x] = BUILDING
            bid_grid[y][x] = hbf_id
    for y in range(hy1 + 1, H):         # everything behind the station: tracks
        for x in range(W):
            if kind[y][x] in (PAVE, GRASS, PLAZA, BUILDING, RAILS, TREE):
                kind[y][x] = RAILS
                bid_grid[y][x] = 0
    rail_rows = [y for y in range(hy1 + 1, H) if sum(kind[y][x] == RAILS for x in range(W)) > W // 2]

    # --- streets: straight pieces, aligned, drawn on top ---------------------------
    names = [""]
    name_idx = {}
    pieces = []
    for e in data.get("highway", []):
        t, g = e["tags"], e["g"]
        hw = t["highway"]
        if t.get("tunnel") == "yes" or t.get("covered") == "yes" or (hw == "service" and not t.get("name")):
            continue
        if hw not in ROAD_W and hw != "pedestrian":
            continue
        if hw == "pedestrian" and poly(g) and t.get("area") == "yes":
            continue
        nid = 0
        if t.get("name"):
            n = ascii_name(t["name"])
            if n not in name_idx:
                name_idx[n] = len(names)
                names.append(n)
            nid = name_idx[n]
        pieces += pieces_of(g, ROAD_W.get(hw, 1), nid, PLAZA if hw == "pedestrian" else ROAD)
    tram_pieces = []
    for e in data.get("railway", []):
        t = e["tags"]
        if t.get("railway") == "tram" and t.get("tunnel") != "yes":
            tram_pieces += pieces_of(e["g"], 1, 0, TRAM)
    align(pieces + tram_pieces)

    name_grid = [[0] * W for _ in range(H)]
    placed = set()
    ext = set()

    def put(x, y, k, nid, extension=False):
        if not (0 <= x < W and 0 <= y < H) or kind[y][x] == WATER or y > hy1 - 1 and hx0 - 1 <= x <= hx1 + 1:
            return
        if kind[y][x] == RAILS or (extension and (x, y) in placed):
            return
        if (x, y) in placed and kind[y][x] == ROAD and k == PLAZA:
            return
        kind[y][x] = k
        bid_grid[y][x] = 0
        zoo[y][x] = False
        if nid:
            name_grid[y][x] = nid
        placed.add((x, y))
        if extension:
            ext.add((x, y))

    for p in pieces:
        if p.orient == "d":
            # diagonal streets become a clean Z: straight, one turn, straight
            x0, y0, x1, y1 = (int(math.floor(v)) for v in p.line)
            if abs(x1 - x0) >= abs(y1 - y0):
                xm = (x0 + x1) // 2
                legs = [(x0, y0, xm, y0), (xm, y0, xm, y1), (xm, y1, x1, y1)]
            else:
                ym = (y0 + y1) // 2
                legs = [(x0, y0, x0, ym), (x0, ym, x1, ym), (x1, ym, x1, y1)]
            for ax, ay, bx, by in legs:
                for cx in range(min(ax, bx), max(ax, bx) + 1):
                    for cy in range(min(ay, by), max(ay, by) + 1):
                        put(cx, cy, p.kind, p.name)
            continue
        c0 = int(math.floor(p.c - (p.width - 1) / 2))
        a0, a1 = int(math.floor(p.a0)), int(math.floor(p.a1))
        for a in range(a0 - 1, a1 + 2):
            for wofs in range(p.width):
                x, y = (a, c0 + wofs) if p.orient == "h" else (c0 + wofs, a)
                put(x, y, p.kind, p.name, extension=a in (a0 - 1, a1 + 1))

    def road_like(x, y):
        return 0 <= x < W and 0 <= y < H and kind[y][x] in (ROAD, TRAM, PLAZA)

    for _ in range(3):                  # remove dead-end stubs left by the extensions
        for (x, y) in list(ext):
            nb = sum(road_like(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if nb <= 1 and kind[y][x] in (ROAD, PLAZA):
                kind[y][x] = PAVE
                name_grid[y][x] = 0
                ext.discard((x, y))

    # trams: tracks on the aligned street cells; long straight pieces become tram routes
    routes = []
    for p in tram_pieces:
        if p.orient == "d":
            continue
        c = int(math.floor(p.c))
        a0, a1 = int(math.floor(p.a0)), int(math.floor(p.a1))
        cells = [(a, c) if p.orient == "h" else (c, a) for a in range(a0, a1 + 1)]
        cells = [(x, y) for x, y in cells if 0 <= x < W and 0 <= y < H and kind[y][x] in (ROAD, PLAZA, TRAM)]
        for x, y in cells:
            kind[y][x] = TRAM
        if cells:
            lo = min(x if p.orient == "h" else y for x, y in cells)
            hi = max(x if p.orient == "h" else y for x, y in cells)
            routes.append((p.orient, c, lo, hi))
    routes.sort()
    merged = []
    for r in routes:
        if merged and merged[-1][:2] == r[:2] and r[2] <= merged[-1][3] + 1:
            merged[-1] = (r[0], r[1], merged[-1][2], max(merged[-1][3], r[3]))
        else:
            merged.append(r)
    tram_routes = [r for r in sorted(merged, key=lambda r: r[2] - r[3]) if r[3] - r[2] >= 10][:4]

    # --- tidy blocks -------------------------------------------------------------
    def neighbours(x, y, diag=False):
        d = ((1, 0), (-1, 0), (0, 1), (0, -1))
        if diag:
            d += ((1, 1), (-1, 1), (1, -1), (-1, -1))
        return [(x + dx, y + dy) for dx, dy in d if 0 <= x + dx < W and 0 <= y + dy < H]

    for _ in range(2):
        for cy in range(H):
            for cx in range(W):
                if kind[cy][cx] not in (PAVE, BUILDING) or bid_grid[cy][cx] == hbf_id:
                    continue
                nb = neighbours(cx, cy)
                nbld = [bid_grid[y][x] for x, y in nb if kind[y][x] == BUILDING and bid_grid[y][x] != hbf_id]
                street = any(kind[y][x] in (ROAD, TRAM, PLAZA) for x, y in nb)
                if kind[cy][cx] == PAVE and (len(nbld) >= 3 or (len(nbld) >= 2 and not street)):
                    kind[cy][cx] = BUILDING
                    bid_grid[cy][cx] = nbld[0]
                elif kind[cy][cx] == BUILDING and not nbld:
                    kind[cy][cx] = PAVE
                    bid_grid[cy][cx] = 0

    # parks get trees; the zoo is fenced off
    for cy in range(H):
        for cx in range(W):
            if kind[cy][cx] == GRASS:
                open_nb = any(kind[y][x] in (PAVE, PLAZA, ROAD, TRAM) for x, y in neighbours(cx, cy, True))
                if (zoo[cy][cx] or not open_nb) and (cx * 3 + cy * 5) % 7 < 4:
                    kind[cy][cx] = TREE
    for cy in range(H):
        for cx in range(W):
            if zoo[cy][cx] and kind[cy][cx] not in (ROAD, TRAM, PLAZA, BUILDING, RAILS):
                if any(not zoo[y][x] for x, y in neighbours(cx, cy)):
                    kind[cy][cx] = FENCE

    # --- start and goal -----------------------------------------------------------
    walk = {PAVE, PLAZA, ROAD, TRAM, GRASS}

    def nearest(cell, ok):
        sx, sy = cell
        best, bd = None, 1e9
        for cy in range(H):
            for cx in range(W):
                if ok(cx, cy):
                    d = (cx - sx) ** 2 + (cy - sy) ** 2
                    if d < bd:
                        best, bd = (cx, cy), d
        return best

    start = nearest(((hx0 + hx1) // 2, hy0 - 1),
                    lambda x, y: kind[y][x] in walk and not zoo[y][x] and y < hy0)

    ballhaus_id = -1
    goal = nearest(to_cell(*BALLHAUS), lambda x, y: kind[y][x] == BUILDING and bid_grid[y][x] != hbf_id and any(
        kind[yy][xx] in (ROAD, TRAM, PLAZA, PAVE) for xx, yy in neighbours(x, y)))
    gx, gy = goal
    for x, y in [(gx, gy)] + neighbours(gx, gy):
        if kind[y][x] == BUILDING:
            bid_grid[y][x] = ballhaus_id

    return {
        "W": W, "H": H, "kind": kind, "bid": bid_grid, "names": name_grid, "name_list": names,
        "zoo": zoo, "hbf_id": hbf_id, "hbf_rect": (hx0, hy0, hx1, hy1), "ballhaus_id": ballhaus_id,
        "start": start, "goal": goal, "tram_routes": tram_routes, "rail_rows": rail_rows,
    }


if __name__ == "__main__":
    m = build()
    print(m["W"], m["H"], "start", m["start"], "goal", m["goal"], "trams", m["tram_routes"],
          "rails", m["rail_rows"], "hbf", m["hbf_rect"])
