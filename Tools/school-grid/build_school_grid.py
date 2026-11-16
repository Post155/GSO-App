#!/usr/bin/env python3
"""
Builds GSO.app/Model/SchoolGrid.bin — the walkability grid used by SchoolGridRouter.swift.

Input:  the CAD floor plan PDF (LS3.1_M01_GSO_Westerwaldstr_EG.pdf, layers "Wand", "Türen",
        "Fenster", "Stütze", ...) plus the GPS data (outdoor paths, Hof pit, entrance nodes)
        that already lives in IndoorNavView.swift.
Output: a 0.25 m grid (ground floor + upper floor) where every cell is either blocked or
        tagged with a zone (Hof, corridor B, forum, ...). The app runs A* on it, so routes
        can never cross a wall.

Usage:  python3 Tools/school-grid/build_school_grid.py path/to/plan.pdf

Pure standard library (no PIL/numpy needed). Takes ~1 min.

How it works
1. Parse the PDF content stream -> line segments + bezier arcs per CAD layer.
2. Georeference: similarity transform plan -> GPS fitted on four outer building corners of
   the user-traced wall line (residuals < 0.5 m).
3. Rasterize walls/windows/columns. Dashed lines (opening/header marks) are skipped.
4. Doors: every quarter-circle swing arc (r 0.5–1.4 m) opens its swing area and doorway.
5. Allowed area = buildings + Hof + the GPS outdoor paths. Grass behind the buildings is
   excluded, the Hof pit is blocked.
6. Facades are sealed except for the entrances confirmed by the school:
   Mensa entrance (forum), Sporthalle direct entrance, Aula foyer door, the four stair
   houses and the middle exits of B and C. Classroom emergency exits stay closed.
7. Upper floor (no plan available): assumed identical to the ground floor for the indoor
   zones; floors are linked at the four round staircases.
"""
import json, math, re, struct, sys, zlib, collections, os

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, '..', '..'))
SWIFT_SRC = os.path.join(REPO, 'GSO.app', 'Views', 'Campus', 'IndoorNavView.swift')
OUT_BIN = os.path.join(REPO, 'GSO.app', 'Model', 'SchoolGrid.bin')

CELL_M = 0.25
ZONES = dict(hof=1, outdoor=2, corrB=3, midB=4, corrC=5, midC=6, forum=7, stAB=8, stAC=9,
             stBS=10, stCA=11, sport=12, aula=13, roomB=14, roomC=15, roomA=16, parking=17, bike=18)
# CAD layer ids in this PDF: MC0 Wand, MC2 Türen, MC6 Fenster, MC7 Wand Trockenbau, MC9 Stütze
WALL_LAYERS = ('MC0', 'MC7', 'MC6', 'MC9')
DOOR_LAYERS = ('MC0', 'MC2', 'MC6', 'MC7')


# ---------------------------------------------------------------- PDF parsing
def parse_pdf(path):
    data = open(path, 'rb').read()
    content = None
    for m in re.finditer(rb'(\d+) 0 obj\s*<<(.*?)>>\s*stream\r?\n', data, re.S):
        body = data[m.end():]
        raw = body[:body.find(b'endstream')]
        if b'FlateDecode' not in m.group(2) or b'Subtype' in m.group(2):
            continue
        try:
            dec = zlib.decompress(raw)
        except zlib.error:
            continue
        if content is None or len(dec) > len(content):
            content = dec
    src = content.decode('latin1')
    tok_re = re.compile(r'/[^\s/\[\]()<>]+|\((?:\\.|[^\\)])*\)|<[0-9A-Fa-f\s]*>|\[|\]|-?\d*\.?\d+|[A-Za-z\'"*]+')
    paths = collections.defaultdict(list)
    bez = collections.defaultdict(list)
    layer = None; nums = []; cur = []; sub = []
    def flush():
        nonlocal sub
        if len(sub) >= 2: cur.append(sub)
        sub = []
    for t in tok_re.findall(src):
        c = t[0]
        if c.isdigit() or c in '-.':
            nums.append(float(t)); continue
        if c in '/([<]':
            nums.append(t); continue
        op = t
        if op == 'BDC': layer = nums[-1][1:]
        elif op == 'EMC': layer = None
        elif op == 'm': flush(); sub = [(nums[-2], nums[-1])]
        elif op == 'l': sub.append((nums[-2], nums[-1]))
        elif op == 'c':
            x0, y0 = sub[-1]; x1, y1, x2, y2, x3, y3 = nums[-6:]
            bez[layer].append((x0, y0, x1, y1, x2, y2, x3, y3))
            for k in range(1, 7):
                s = k / 6; A = (1-s)**3; B = 3*(1-s)**2*s; C = 3*(1-s)*s*s; D = s**3
                sub.append((A*x0+B*x1+C*x2+D*x3, A*y0+B*y1+C*y2+D*y3))
        elif op == 'h':
            if sub: sub.append(sub[0])
        elif op == 're':
            flush(); x, y, w, h = nums[-4:]; sub = [(x, y), (x+w, y), (x+w, y+h), (x, y+h), (x, y)]
        elif op in ('S', 's', 'f', 'F', 'f*', 'B', 'B*', 'b', 'n', 'W'):
            flush()
            if op != 'n' and cur: paths[layer].extend(cur)
            cur = []
        nums = []
    return paths, bez


# ---------------------------------------------------------------- Swift data
def swift_data():
    src = open(SWIFT_SRC).read()
    def polys(a, b):
        s = src[src.index(a):src.index(b)]
        return {m.group(1): [(float(x), float(y)) for x, y in re.findall(r'lat: ([\d.]+),\s*lon: ([\d.]+)', m.group(2))]
                for m in re.finditer(r'AreaPolygon\(id: "(\w+)", corners: \[(.*?)\]', s, re.S)}
    outdoor = polys('static let outdoorAreas', 'static let forbiddenAreas')
    forbidden = polys('static let forbiddenAreas', 'static let buildingOutlines')
    nodes = {}
    for m in re.finditer(r'NavNode\(id: "([\w-]+)",\s*displayNameKey: "[^"]+",\s*block: "[^"]*",\s*floor: \d,\s*'
                         r'(?://[^\n]*\n\s*)*coordinate: GeoCoord\(lat: ([\d.]+), lon: ([\d.]+)\)', src):
        nodes[m.group(1)] = (float(m.group(2)), float(m.group(3)))
    return outdoor, forbidden, nodes


# ---------------------------------------------------------------- georeference
LAT0, LON0 = 50.927609, 6.995676
KN = 111132.92 - 559.82*math.cos(2*math.radians(LAT0)) + 1.175*math.cos(4*math.radians(LAT0))
KE = 111412.84*math.cos(math.radians(LAT0)) - 93.5*math.cos(3*math.radians(LAT0))

# Outer building corners: plan (PDF units) <-> physicalWallLine GPS points.
CONTROL = [((181.67307, 745.76031), (50.927315308262735, 6.994597843014191)),   # A/B outer corner
           ((181.67307, 55.89137), (50.926874053924394, 6.995887)),             # A/C outer corner
           ((903.66071, 55.89137), (50.92772137609089, 6.996614404477441)),     # Aula east corner
           ((1053.76733, 745.76031), (50.92833305485223, 6.995471398538427))]   # Sport north corner

def fit_similarity():
    rows = []; rhs = []
    for (x, y), (lat, lon) in CONTROL:
        e, n = (lon-LON0)*KE, (lat-LAT0)*KN
        rows += [[x, -y, 1, 0], [y, x, 0, 1]]; rhs += [e, n]
    M = [[sum(r[i]*r[j] for r in rows) for j in range(4)] for i in range(4)]
    v = [sum(r[i]*b for r, b in zip(rows, rhs)) for i in range(4)]
    for i in range(4):
        p = max(range(i, 4), key=lambda r: abs(M[r][i])); M[i], M[p] = M[p], M[i]; v[i], v[p] = v[p], v[i]
        for r in range(4):
            if r != i:
                f = M[r][i]/M[i][i]; M[r] = [M[r][j]-f*M[i][j] for j in range(4)]; v[r] -= f*v[i]
    return [v[i]/M[i][i] for i in range(4)]


class Grid:
    def __init__(s, x0, y0, x1, y1, res):
        s.x0, s.y0, s.res = x0, y0, res
        s.w = int((x1-x0)/res)+1; s.h = int((y1-y0)/res)+1
        s.ytop = y0+(s.h-1)*res
    def idx(s, x, y): return int((x-s.x0)/s.res), int((s.ytop-y)/s.res)
    def new(s): return bytearray(s.w*s.h)
    def line(s, a, p, q):
        (x0, y0), (x1, y1) = p, q
        n = int(max(abs(x1-x0), abs(y1-y0))/(s.res*0.5))+1
        for i in range(n+1):
            t = i/n; cx, cy = s.idx(x0+(x1-x0)*t, y0+(y1-y0)*t)
            if 0 <= cx < s.w and 0 <= cy < s.h: a[cy*s.w+cx] = 1
    def fill(s, a, poly, v=1):
        ys = [p[1] for p in poly]
        _, r0 = s.idx(0, max(ys)); _, r1 = s.idx(0, min(ys))
        for r in range(max(0, r0), min(s.h-1, r1)+1):
            yc = s.ytop-r*s.res-s.res/2
            xs = sorted(x1+(yc-y1)*(x2-x1)/(y2-y1) for (x1, y1), (x2, y2) in zip(poly[-1:]+poly[:-1], poly)
                        if (y1 > yc) != (y2 > yc))
            for k in range(0, len(xs)-1, 2):
                c0 = max(0, int((xs[k]-s.x0)/s.res+0.5)); c1 = min(s.w-1, int((xs[k+1]-s.x0)/s.res-0.5))
                for c in range(c0, c1+1): a[r*s.w+c] = v


def rect(x0, y0, x1, y1): return [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]


def build(pdf, debug_dir=None):
    paths, bez = parse_pdf(pdf)
    outdoor, forbidden, nodes = swift_data()
    a, b, tx, ty = fit_similarity()
    s2 = a*a+b*b
    def ll2plan(lat, lon):
        e = (lon-LON0)*KE-tx; n = (lat-LAT0)*KN-ty
        return ((a*e+b*n)/s2, (-b*e+a*n)/s2)
    res = CELL_M/math.sqrt(s2)
    G = Grid(170, -575, 1640, 760, res); W, H = G.w, G.h; N = W*H
    print(f'grid {W}x{H}, scale {math.sqrt(s2):.4f} m/unit')

    # walls (skip short axis-aligned dashes = opening/header marks, keep diagonal hatch)
    WALL = G.new()
    for lay in WALL_LAYERS:
        for pl in paths.get(lay, []):
            for p, q in zip(pl, pl[1:]):
                dx, dy = abs(q[0]-p[0]), abs(q[1]-p[1])
                if math.hypot(dx, dy) < 1.0 and not (lay == 'MC0' and dx > 0.05 and dy > 0.05):
                    continue
                G.line(WALL, p, q)

    # doors
    seg_at = collections.defaultdict(list)
    for lay in DOOR_LAYERS:
        for pl in paths.get(lay, []):
            for p, q in zip(pl, pl[1:]):
                for e in (p, q): seg_at[(round(e[0]), round(e[1]))].append((p, q))
    carve = G.new(); ndoors = 0
    for lay in DOOR_LAYERS:
        for (x0, y0, x1, y1, x2, y2, x3, y3) in bez.get(lay, []):
            n0 = (-(y1-y0), x1-x0); n1 = (-(y3-y2), x3-x2)
            det = n0[0]*(-n1[1])-n0[1]*(-n1[0])
            if abs(det) < 1e-9: continue
            sc = ((x3-x0)*(-n1[1])-(y3-y0)*(-n1[0]))/det
            cx, cy = x0+n0[0]*sc, y0+n0[1]*sc
            r = math.hypot(x0-cx, y0-cy)
            if not 3.5 < r < 9.5 or abs(math.hypot(x3-cx, y3-cy)-r) > 0.3: continue
            ang = abs(math.degrees(math.atan2((x0-cx)*(y3-cy)-(y0-cy)*(x3-cx), (x0-cx)*(x3-cx)+(y0-cy)*(y3-cy))))
            if not 80 < ang < 100: continue
            ndoors += 1
            e0, e1 = (x0, y0), (x3, y3)
            open_end = None   # the leaf is drawn hinge -> open end; the other end is the doorway
            for k in ((round(cx)+ox, round(cy)+oy) for ox in (-1, 0, 1) for oy in (-1, 0, 1)):
                for p, q in seg_at.get(k, []):
                    for hp, op in ((p, q), (q, p)):
                        if math.hypot(hp[0]-cx, hp[1]-cy) < 0.4:
                            for e in (e0, e1):
                                if math.hypot(op[0]-e[0], op[1]-e[1]) < 0.6: open_end = e
            # swing quadrant
            a0 = math.atan2(e0[1]-cy, e0[0]-cx); a1 = math.atan2(e1[1]-cy, e1[0]-cx)
            da = (a1-a0+math.pi) % (2*math.pi)-math.pi
            G.fill(carve, [(cx, cy)]+[(cx+(r+1.2)*math.cos(a0+da*k/10), cy+(r+1.2)*math.sin(a0+da*k/10)) for k in range(11)])
            # doorway through the wall
            for c in ([e1 if open_end == e0 else e0] if open_end else [e0, e1]):
                ux, uy = (c[0]-cx)/r, (c[1]-cy)/r; px, py = -uy*3.4, ux*3.4
                A = (cx+ux*0.4, cy+uy*0.4); B = (c[0]-ux*0.1, c[1]-uy*0.1)
                G.fill(carve, [(A[0]+px, A[1]+py), (B[0]+px, B[1]+py), (B[0]-px, B[1]-py), (A[0]-px, A[1]-py)])
    print('doors', ndoors)
    # Mensa entrance: door in the forum glass facade (not drawn as a door in the CAD)
    mx, my = ll2plan(*nodes['Door-Mensa-EG'])
    G.fill(carve, rect(340, my-5, 358, my+5))
    for i in range(N):
        if carve[i]: WALL[i] = 0

    # allowed areas
    allowed = G.new(); G.fill(allowed, rect(181.6, 55.8, 1053.8, 745.8))
    excl = G.new()
    G.fill(excl, rect(170, 181, 201, 622))        # grass behind forum / stair houses
    G.fill(excl, rect(904, 40, 1060, 364))        # behind Aula
    G.fill(excl, rect(1040, 441, 1060, 760))      # behind Sport
    pit = G.new()
    for pl in forbidden.values(): G.fill(pit, [ll2plan(*p) for p in pl])
    out = G.new(); park = G.new(); bike = G.new()
    for k, pl in outdoor.items():
        if k != 'HofWalkable': G.fill(out, [ll2plan(*p) for p in pl])
    G.fill(out, [(917, 72), (966, 72), (972, -25), (917, -25)])   # car park -> path along the Aula wall
    G.fill(park, [ll2plan(*p) for p in outdoor['CarParking']])
    G.fill(bike, [ll2plan(*p) for p in outdoor['BikeParking']])

    zone_rects = [  # later entries win
        ('roomB', rect(181.6, 623, 680, 745.8)), ('roomC', rect(181.6, 55.8, 680, 177)),
        ('corrB', rect(245, 672, 680, 698)), ('corrB', rect(245, 620, 264, 698)), ('midB', rect(405, 623, 457, 676)),
        ('corrC', rect(245, 104, 680, 130)), ('corrC', rect(245, 104, 264, 180)), ('midC', rect(405, 127, 457, 180)),
        ('forum', rect(201, 256, 348, 548)), ('roomA', rect(285, 281, 343, 424)),
        ('stAB', rect(201, 548, 305, 623.8)), ('stAC', rect(201, 178.5, 305, 256)),
        ('stBS', rect(680, 623, 741, 745.8)), ('stCA', rect(680, 55.8, 741, 180)),
        ('sport', rect(756, 440, 1047, 745.8)), ('aula', rect(756, 55.8, 904, 364)),
    ]
    zmaps = []
    for name, poly in zone_rects:
        m = G.new(); G.fill(m, poly); zmaps.append((ZONES[name], m))
    CELL = G.new()
    for i in range(N):
        if WALL[i] or pit[i]: continue
        if allowed[i] and not excl[i]:
            z = ZONES['hof']
            for zid, m in zmaps:
                if m[i]: z = zid
            CELL[i] = z
        elif out[i]:
            CELL[i] = ZONES['parking'] if park[i] else ZONES['bike'] if bike[i] else ZONES['outdoor']

    # seal facades except confirmed entrances
    out_z = {ZONES[k] for k in ('hof', 'outdoor', 'bike', 'parking')}
    open_z = {ZONES[k] for k in ('stAB', 'stAC', 'stBS', 'stCA', 'midB', 'midC')}
    sx, sy = ll2plan(*nodes['Door-Sporthalle'])
    whitelist = [(G.idx(mx, my), 8), (G.idx(sx, sy), 26), (G.idx(752.5, 122.5), 8)]  # Mensa, Sport, Aula foyer
    for _ in range(3):
        for i in range(N):
            if CELL[i] not in out_z: continue
            x = i % W
            for j in (i-1 if x > 0 else -1, i+1 if x < W-1 else -1, i-W, i+W):
                if 0 <= j < N and CELL[j] and CELL[j] not in out_z and CELL[j] not in open_z:
                    if not any(abs(j % W-wx) <= r and abs(j//W-wy) <= r for (wx, wy), r in whitelist):
                        CELL[j] = 0

    # floors
    indoor_z = {ZONES[k] for k in ('corrB', 'midB', 'corrC', 'midC', 'forum', 'stAB', 'stAC', 'stBS', 'stCA', 'roomB', 'roomC', 'roomA')}
    floors = [bytearray(CELL), bytearray(c if c in indoor_z else 0 for c in CELL)]

    # room components (routes may only use the start/end room, not other rooms as shortcut)
    room_z = {ZONES[k] for k in ('roomB', 'roomC', 'roomA', 'sport', 'aula')}
    COMP = G.new(); ncomp = 0
    for s0 in range(N):
        if CELL[s0] in room_z and not COMP[s0]:
            ncomp = ncomp % 254 + 1
            z = CELL[s0]; st = [s0]; COMP[s0] = ncomp
            while st:
                i = st.pop(); x = i % W
                for j in (i-1 if x > 0 else -1, i+1 if x < W-1 else -1, i-W, i+W):
                    if 0 <= j < N and not COMP[j] and CELL[j] == z: COMP[j] = ncomp; st.append(j)

    # clearance (distance to nearest blocked cell, 1..3) packed into bits 5-6
    packed = []
    for F in floors:
        clr = bytearray([3])*N; q = [i for i in range(N) if not F[i]]
        for i in q: clr[i] = 0
        for d in (1, 2):
            nq = []
            for i in q:
                x = i % W
                for j in (i-1 if x > 0 else -1, i+1 if x < W-1 else -1, i-W, i+W):
                    if 0 <= j < N and clr[j] == 3: clr[j] = d; nq.append(j)
            q = nq
        packed.append(bytes((F[i] | (clr[i] << 5)) if F[i] else 0 for i in range(N)))

    # stair links at the four round staircases
    def nearest(F, x, y, zid):
        cx, cy = G.idx(x, y)
        for r in range(60):
            best = None
            for dx in range(-r, r+1):
                for dy in ((-r, r) if abs(dx) != r else range(-r, r+1)):
                    i = (cy+dy)*W+cx+dx
                    if 0 <= i < N and F[i] == zid and (best is None or dx*dx+dy*dy < best[0]): best = (dx*dx+dy*dy, i)
            if best: return best[1]
    links = [(nearest(floors[0], x, y, ZONES[z]), nearest(floors[1], x, y, ZONES[z]), ZONES[z])
             for z, x, y in (('stAB', 277.5, 587.5), ('stAC', 277.5, 217.5), ('stBS', 717.5, 662.5), ('stCA', 717.5, 145))]

    hdr = b'GSOG' + struct.pack('<III', 1, W, H)
    hdr += struct.pack('<' + 'd'*11, res, G.x0, G.ytop, a, b, tx, ty, LAT0, LON0, KN, KE)
    hdr += struct.pack('<I', len(links)) + b''.join(struct.pack('<IIB3x', l0, l1, z) for l0, l1, z in links)
    co = zlib.compressobj(9, zlib.DEFLATED, -15)   # raw deflate (Apple's .zlib algorithm)
    payload = co.compress(packed[0] + packed[1] + bytes(COMP)) + co.flush()
    blob = hdr + struct.pack('<I', len(payload)) + payload
    open(OUT_BIN, 'wb').write(blob)
    print(f'wrote {OUT_BIN} ({len(blob)//1024} KB)')


if __name__ == '__main__':
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    build(sys.argv[1])
