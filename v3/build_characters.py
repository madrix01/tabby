"""Pack ../characters/*.svg into characters.js (window.CHAR_SVGS) so the page works from file:// with no fetch.
The traced outlines wobble, so every path is redrawn smooth: resample, low-pass (corners kept crisp), refit as few cubics.
Run again after adding or editing a character: python3 build_characters.py   (needs numpy)"""
import glob, json, math, os, re
import numpy as np

H = 1.0              # resample spacing (svg units)
CUT = (0.08, 8, 40)  # low-pass cutoff wavelength = clamp(CUT[0]*sqrt(bbox area), CUT[1], CUT[2])
CORNER = 50          # degrees of turn within +-6 units that counts as an intended corner
TOL = (0.01, 0.6, 3) # max refit error = clamp(TOL[0]*sqrt(bbox area), ...): a loose fit irons out the slow lumps too
POLY = (6, 0.5)      # cutoff, tol for all-straight-line paths (41-46 from make_extra.py): clean geometry, the refit alone irons the facets

def parse(d):
    """absolute M/L/C/Z only (all the traces use) -> list of rings of flattened points"""
    tok = re.findall(r'[MLCZ]|-?(?:\d+\.?\d*|\.\d+)(?:e-?\d+)?', d); rings, cur, i, cmd = [], None, 0, None
    while i < len(tok):
        if tok[i] in 'MLCZ': cmd = tok[i]; i += 1
        if cmd == 'Z': rings.append(np.array(cur)); cur = None; continue
        n = 6 if cmd == 'C' else 2; v = [float(x) for x in tok[i:i+n]]; i += n
        if cmd == 'M': cur = [v]; cmd = 'L'; continue
        if cmd == 'L': cur.append(v); continue
        p0, p1, p2, p3 = np.array(cur[-1]), np.array(v[:2]), np.array(v[2:4]), np.array(v[4:])
        t = np.linspace(0, 1, max(4, int(np.linalg.norm(p1-p0) + np.linalg.norm(p2-p1) + np.linalg.norm(p3-p2)) * 2))[1:, None]
        cur.extend(((1-t)**3*p0 + 3*(1-t)**2*t*p1 + 3*(1-t)*t*t*p2 + t**3*p3).tolist())
    if cur: rings.append(np.array(cur))
    return rings

def resample(p, closed=True):
    q = np.vstack([p, p[:1]]) if closed else p
    s = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(q, axis=0), axis=1))])
    n = max(8, int(s[-1] / H)); u = np.linspace(0, s[-1], n, endpoint=not closed)
    return np.column_stack([np.interp(u, s, q[:, 0]), np.interp(u, s, q[:, 1])])

def turn(p, k):
    a, b = p - np.roll(p, k, 0), np.roll(p, -k, 0) - p
    return np.degrees(np.abs(np.arctan2(a[:, 0]*b[:, 1] - a[:, 1]*b[:, 0], (a*b).sum(1))))

def corners(p):
    """sharp turns concentrated in a short stretch (a circle's turn shrinks with the window, a corner's doesn't; small round caps fail the 2-unit test)"""
    k = max(2, int(6 / H)); t6, t3, t2 = turn(p, k), turn(p, k // 2), turn(p, max(1, k // 3))
    c = np.where((t6 > CORNER) & (t3 > .7*t6) & (t2 > .4*t6))[0]
    return [i for i in c if t6[i] == max(t6[(i + j) % len(p)] for j in range(-k, k + 1))]

def lowpass(z, cut, step):
    f = np.fft.fftfreq(len(z), step); return np.fft.ifft(np.fft.fft(z) * np.exp(-math.log(2) * (np.abs(f) * cut)**4))

def smooth_open(p, cut):
    """ends pinned: remove the chord, odd-extend so it is periodic, low-pass, add the chord back"""
    z = p[:, 0] + 1j*p[:, 1]; t = np.linspace(0, 1, len(z)); ch = z[0] + (z[-1] - z[0])*t; q = z - ch
    w = lowpass(np.concatenate([q, -q[-2:0:-1]]), cut, H)[:len(z)] + ch
    return np.column_stack([w.real, w.imag])

# ---- Schneider's cubic fit ----
def bez(b, t):
    t = t[:, None]; return (1-t)**3*b[0] + 3*(1-t)**2*t*b[1] + 3*(1-t)*t*t*b[2] + t**3*b[3]

def gen(p, u, t1, t2):
    a1, a2 = np.outer(3*(1-u)**2*u, t1), np.outer(3*(1-u)*u*u, t2)
    tmp = p - bez(np.array([p[0], p[0], p[-1], p[-1]]), u)
    C = [[(a1*a1).sum(), (a1*a2).sum()], [(a1*a2).sum(), (a2*a2).sum()]]; X = [(a1*tmp).sum(), (a2*tmp).sum()]
    det = C[0][0]*C[1][1] - C[0][1]*C[1][0]; L = np.linalg.norm(p[-1] - p[0])
    al, ar = ((X[0]*C[1][1] - X[1]*C[0][1]) / det, (C[0][0]*X[1] - C[1][0]*X[0]) / det) if abs(det) > 1e-12 else (0, 0)
    if al < 1e-6*L or ar < 1e-6*L: al = ar = L / 3
    return np.array([p[0], p[0] + t1*al, p[-1] + t2*ar, p[-1]])

def fit(p, t1, t2, tol):
    if len(p) < 3: L = np.linalg.norm(p[-1] - p[0]) / 3; return [np.array([p[0], p[0] + t1*L, p[-1] + t2*L, p[-1]])]
    u = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(p, axis=0), axis=1))]); u /= u[-1]
    for it in range(8):
        b = gen(p, u, t1, t2); e = ((bez(b, u) - p)**2).sum(1); i = int(e.argmax())
        if e[i] < tol*tol: return [b]
        if e[i] > 16*tol*tol: break
        d1, d2 = 3*np.diff(b, axis=0), 6*np.diff(b, 2, axis=0)        # newton step on u
        q, q1 = bez(b, u) - p, ((1-u)**2)[:, None]*d1[0] + (2*(1-u)*u)[:, None]*d1[1] + (u*u)[:, None]*d1[2]
        q2 = (1-u)[:, None]*d2[0] + u[:, None]*d2[1]; den = (q1*q1 + q*q2).sum(1)
        u = np.clip(u - np.where(np.abs(den) > 1e-12, (q*q1).sum(1) / np.where(den == 0, 1, den), 0), 0, 1)
    i = min(max(i, 1), len(p) - 2); tc = p[i-1] - p[i+1]; tc /= np.linalg.norm(tc) or 1
    return fit(p[:i+1], t1, tc, tol) + fit(p[i:], -tc, t2, tol)

def unit(v): return v / (np.linalg.norm(v) or 1)

def smooth_ring(r, poly):
    p = resample(r); w, h = np.ptp(p, axis=0); sz = math.sqrt(w*h); cut, tol = POLY if poly else (min(max(CUT[0]*sz, CUT[1]), CUT[2]), min(max(TOL[0]*sz, TOL[1]), TOL[2]))
    z = lowpass(p[:, 0] + 1j*p[:, 1], 2, H); pre = np.column_stack([z.real, z.imag])   # de-jag before looking for corners
    cs = corners(pre)
    if not cs:
        z = lowpass(p[:, 0] + 1j*p[:, 1], cut, H); q = np.column_stack([z.real, z.imag]); q = np.vstack([q, q[:1]])
        t = unit(q[1] - q[-2]); return fit(q, t, -t, tol)
    p = np.roll(p, -cs[0], 0); cs = [c - cs[0] for c in cs] + [len(p)]; p = np.vstack([p, p[:1]]); out = []
    for a, b in zip(cs, cs[1:]):
        q = smooth_open(p[a:b+1], cut) if b - a > 6 else p[a:b+1]; k = min(3, len(q) - 1)
        out += fit(q, unit(q[k] - q[0]), unit(q[-1-k] - q[-1]), tol)
    return out

def smooth_d(d):
    def f(v): s = f'{v:.1f}'.rstrip('0').rstrip('.'); return '0' if s == '-0' else s
    out = []
    for r in parse(d):
        bs = smooth_ring(r, 'C' not in d); out.append(f'M{f(bs[0][0][0])} {f(bs[0][0][1])}' + ''.join('C' + ' '.join(f(x) for x in b[1:].ravel()) for b in bs) + 'Z')
    return ''.join(out)

here = os.path.dirname(os.path.abspath(__file__))
out = []
for f in sorted(glob.glob(os.path.join(here, '..', 'characters', 'character_*.svg'))):
    s = open(f).read()
    els = [f'<{t}{a.rstrip("/")}/>' for t, a in re.findall(r'<(path|circle)\b([^>]*?)/?>', s)]
    els = [re.sub(r' d="([^"]*)"', lambda m: f' d="{smooth_d(m.group(1))}"', e) for e in els]
    out.append({
        'id': re.search(r'character_(\d+)', f).group(1),
        'viewBox': re.search(r'viewBox="([^"]+)"', s).group(1),
        # coloured body parts; a few traces carry a duplicate path with no fill, which would render black
        'skin': [e for e in els if 'fill="#2b2a33"' not in e and 'fill="' in e],
        'ink':  [e for e in els if 'fill="#2b2a33"' in e],       # eyes + mouth
    })
open(os.path.join(here, 'characters.js'), 'w').write('window.CHAR_SVGS = ' + json.dumps(out) + ';\n')
print(len(out), 'characters')
