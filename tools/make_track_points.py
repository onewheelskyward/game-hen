"""Circuit GeoJSON (bacinger/f1-circuits format) -> evenly spaced, gently smoothed
control points in game pixels, printed as GDScript Vector2 lines.

Usage: python3 tools/make_track_points.py it-1922.geojson
"""
import json, math, sys
SCALE = 4.0        # px per meter
FINE = 10.0        # px, resample spacing before smoothing
SIGMA = 35.0       # px, gaussian smoothing radius (rounds off chicane kinks)
OUT = 60.0         # px, spacing of emitted control points

c = json.load(open(sys.argv[1]))["features"][0]["geometry"]["coordinates"]
lon0, lat0 = c[0]
kx = math.cos(math.radians(lat0)) * 111320; ky = 110540
pts = [((lon-lon0)*kx*SCALE, -(lat-lat0)*ky*SCALE) for lon, lat in c]
if math.dist(pts[0], pts[-1]) < 1e-6: pts.pop()

def resample(p, step):
    n = len(p); segs = [(p[i], p[(i+1)%n]) for i in range(n)]
    total = sum(math.dist(a,b) for a,b in segs)
    count = round(total/step); step = total/count
    out=[]; d=0.0; si=0; acc=0.0
    for k in range(count):
        target = k*step
        while acc + math.dist(*segs[si]) < target:
            acc += math.dist(*segs[si]); si += 1
        a,b = segs[si]; L = math.dist(a,b); t = (target-acc)/L if L else 0
        out.append((a[0]+(b[0]-a[0])*t, a[1]+(b[1]-a[1])*t))
    return out, total

fine, total = resample(pts, FINE)
n = len(fine); r = int(3*SIGMA/FINE)
w = [math.exp(-0.5*(k*FINE/SIGMA)**2) for k in range(-r, r+1)]; ws = sum(w)
smooth = [(sum(w[k+r]*fine[(i+k)%n][0] for k in range(-r,r+1))/ws,
           sum(w[k+r]*fine[(i+k)%n][1] for k in range(-r,r+1))/ws) for i in range(n)]
out, _ = resample(smooth, OUT)
print(f"# {len(out)} points, lap {total:.0f}px", file=sys.stderr)
lines = [f"\tVector2({x:.0f}, {y:.0f})," for x,y in out]
print("\n".join(lines))
