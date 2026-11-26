"""Menyederhanakan GeoJSON SK Jalan untuk tampilan peta web.
Pemakaian: python3 sederhanakan_sk.py SK_Jalan_Kotim_2026.geojson sk_kab.json K
           python3 sederhanakan_sk.py SK-Jalan-Desa-2026.geojson sk_desa.json D
Toleransi 3 m (Douglas-Peucker), koordinat 5 desimal, hanya kolom: ID_GIS, nama, kecamatan, desa."""
import json, math, sys

TOL = 3.0  # meter

def dp(pts, tol):
    n = len(pts)
    if n < 3: return pts
    k = math.cos(math.radians(sum(p[1] for p in pts) / n)) * 111320.0
    xy = [(p[0] * k, p[1] * 110540.0) for p in pts]
    keep = [False] * n; keep[0] = keep[-1] = True
    st = [(0, n - 1)]
    while st:
        a, b = st.pop()
        ax, ay = xy[a]; bx, by = xy[b]
        dx, dy = bx - ax, by - ay; L = dx * dx + dy * dy
        mx, mi = -1.0, -1
        for i in range(a + 1, b):
            px, py = xy[i]
            if L == 0: d = math.hypot(px - ax, py - ay)
            else:
                t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / L))
                d = math.hypot(px - (ax + t * dx), py - (ay + t * dy))
            if d > mx: mx, mi = d, i
        if mx > tol:
            keep[mi] = True; st.append((a, mi)); st.append((mi, b))
    return [p for p, kp in zip(pts, keep) if kp]

def teks(v):
    return '' if v is None else str(v).strip()

def main(src, dst, jenis):
    g = json.load(open(src, encoding='utf-8'))
    out = []; t0 = t1 = 0
    for f in g['features']:
        p = f['properties']
        idg = teks(p.get('ID_GIS')); nama = teks(p.get('NAMA_JL'))
        kec = teks(p.get('kecamatan')); desa = teks(p.get('Desa_Kel') or p.get('DESA_KELUR'))
        garis = []
        for ln in f['geometry']['coordinates']:
            t0 += len(ln)
            s = dp([(c[0], c[1]) for c in ln], TOL)
            s2 = []
            for x, y in s:
                q = [round(x, 5), round(y, 5)]
                if not s2 or s2[-1] != q: s2.append(q)
            if len(s2) >= 2: garis.append(s2); t1 += len(s2)
        if not garis: continue
        pr = {'i': idg, 'n': nama, 'k': kec, 'd': desa, 'j': jenis}
        out.append({'type': 'Feature', 'properties': pr,
                    'geometry': {'type': 'MultiLineString', 'coordinates': garis}})
    json.dump({'type': 'FeatureCollection', 'features': out}, open(dst, 'w', encoding='utf-8'),
              separators=(',', ':'), ensure_ascii=False)
    print(f'{src}: {len(out)} fitur, titik {t0} -> {t1}')

if __name__ == '__main__':
    main(sys.argv[1], sys.argv[2], sys.argv[3])
