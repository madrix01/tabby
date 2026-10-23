// v4 characters: ../shapes_v4/shape_NN.svg -> catalog characters. Port of v4/build_shapes.py + analyze() in v4/index.html.
// A v4 shape is: a body path, a texture group clipped to the body (closed eyes live there too), eye whites with a
// pupil clipped to each, and dark legs/spots. Legs are drawn in the body colour, a little thicker, as in the prototype.
import fs from 'node:fs';
import path from 'node:path';
import svgpath from 'svgpath';
import { svgPathProperties } from 'svg-path-properties';

const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
const r2 = n => Math.round(n * 100) / 100;
const attr = (a, k) => (new RegExp(`\\s${k}="([^"]*)"`).exec(a) || [])[1];
const translateOf = a => { const m = /translate\(([-\d.]+)[ ,]+([-\d.]+)\)/.exec(attr(a, 'transform') || ''); return m ? [+m[1], +m[2]] : [0, 0]; };
const LEG_STROKE = 7;     // source units, same as v4/index.html

// every drawable element as an absolute path (circles/ellipses become two arcs), so one normaliser handles all
function shape(markup){
  const [, tag, a] = /^<(\w+)\b([^>]*)/.exec(markup), [tx, ty] = translateOf(a);
  let d;
  if (tag === 'path') d = attr(a, 'd');
  else { const cx = +attr(a, 'cx'), cy = +attr(a, 'cy'), rx = +(attr(a, 'rx') ?? attr(a, 'r')), ry = +(attr(a, 'ry') ?? attr(a, 'r'));
    d = `M${cx - rx} ${cy}A${rx} ${ry} 0 1 0 ${cx + rx} ${cy}A${rx} ${ry} 0 1 0 ${cx - rx} ${cy}Z`; }
  return { tag, fill: attr(a, 'fill'), rule: attr(a, 'fill-rule'), d: svgpath(d).translate(tx, ty).abs().toString(),
           circle: tag === 'circle' ? { cx: +attr(a, 'cx') + tx, cy: +attr(a, 'cy') + ty, r: +attr(a, 'r') } : null };
}
const sample = (d, n) => { const p = new svgPathProperties(d), L = p.getTotalLength();
  return Array.from({ length: n }, (_, k) => { const q = p.getPointAtLength(L * k / n); return [q.x, q.y]; }); };
const bboxOf = pts => { const xs = pts.map(p => p[0]), ys = pts.map(p => p[1]);
  return { x0: Math.min(...xs), y0: Math.min(...ys), x1: Math.max(...xs), y1: Math.max(...ys) }; };
const boxOf = s => s.circle ? { x0: s.circle.cx - s.circle.r, y0: s.circle.cy - s.circle.r, x1: s.circle.cx + s.circle.r, y1: s.circle.cy + s.circle.r } : bboxOf(sample(s.d, 120));

// the file split the way build_shapes.py does it
function parse(file){
  const s = fs.readFileSync(file, 'utf8'), inner = s.slice(s.indexOf('>') + 1, s.lastIndexOf('</svg>')), parts = [];
  for (let i = 0; i < inner.length;) {
    let j;
    if (inner.startsWith('<clipPath', i)) { j = inner.indexOf('</clipPath>', i) + 11; j = inner.startsWith('<g', j) ? inner.indexOf('</g>', j) + 4 : inner.indexOf('/>', j) + 2; }
    else j = inner.indexOf('/>', i) + 2;
    parts.push(inner.slice(i, j)); i = j;
  }
  const c = { id: /shape_(\d+)/.exec(file)[1], body: shape(parts[0]), texClip: null, tex: [], whites: [], pupils: [], rest: [] };
  for (const p of parts.slice(1)) {
    const clip = /<clipPath[^>]*>(<[^>]+>)<\/clipPath>/.exec(p)?.[1], el = p.replace(/<clipPath.*?<\/clipPath>/, '');
    if (el.startsWith('<g')) { c.texClip = shape(clip); c.tex = [...el.matchAll(/<path\b[^>]*\/>/g)].map(m => shape(m[0])); }
    else if (/fill="#ffffff"/.test(el)) c.whites.push(shape(el));
    else if (/^<circle[^>]*fill="#1c1a1f"/.test(el)) c.pupils.push({ ...shape(el), clip: clip ? shape(clip) : null });
    else c.rest.push(shape(el));
  }
  return c;
}

function analyze(c){
  const body = bboxOf(sample(c.body.d, 400)), parts = [c.body, ...c.whites, ...c.pupils, ...c.rest];
  const boxes = new Map(parts.map(p => [p, p === c.body ? body : boxOf(p)]));
  const all = { x0: Math.min(...[...boxes.values()].map(b => b.x0)), y0: Math.min(...[...boxes.values()].map(b => b.y0)), y1: Math.max(...[...boxes.values()].map(b => b.y1)) };
  const s0 = Math.min(100 / (all.y1 - all.y0), 150 / (body.x1 - body.x0)), cx = (body.x0 + body.x1) / 2, bot = all.y1;   // feet on the ground, centred on the body
  const N = ([x, y]) => [(x - cx) * s0, (y - bot) * s0];
  const box = b => { const [x0, y0] = N([b.x0, b.y0]), [x1, y1] = N([b.x1, b.y1]); return { cx: (x0 + x1) / 2, cy: (y0 + y1) / 2, r: Math.max(x1 - x0, y1 - y0) / 2, w: x1 - x0, h: y1 - y0, x0, x1, y0, y1 }; };
  const pts = [sample(c.body.d, 400).map(N)], all_ = pts[0];
  const [bx0, bTop] = N([body.x0, body.y0]), [bx1, bBot] = N([body.x1, body.y1]), W = bx1 - bx0, H = -N([0, all.y0])[1];
  // eyes: the whites (each grouped with the pupil inside it); closed eyes are the darkest small marks in the texture
  let eyes = c.whites.map(w => box(boxes.get(w))), groups = [];
  if (eyes.length) {
    groups = eyes.map(() => []);
    c.pupils.forEach((p, k) => { const b = box(boxes.get(p)); let best = 0, bd = Infinity;
      eyes.forEach((e, j) => { const d = Math.hypot(b.cx - e.cx, b.cy - e.cy); if (d < bd) { bd = d; best = j; } }); groups[best].push(k); });
    eyes = eyes.map(e => ({ ...e, r: e.r * .55 }));   // lenses/brows sized like a dot eye, not the whole white
  } else {
    const lum = h => { const v = parseInt(h.slice(1), 16); return (v >> 16 & 255) * .3 + (v >> 8 & 255) * .59 + (v & 255) * .11; };
    const marks = c.tex.map(t => ({ ...box(boxOf(t)), l: lum(t.fill) })).filter(m => m.w < W * .4 && m.h < (bBot - bTop) * .4 && m.cy < bBot - (bBot - bTop) * .2);
    const dark = Math.min(...marks.map(m => m.l)), pick = marks.filter(m => m.l <= dark + 1);
    const xs = pick.map(m => m.cx).sort((p, q) => p - q), split = (xs[0] + xs[xs.length - 1]) / 2;
    eyes = [pick.filter(m => m.cx < split), pick.filter(m => m.cx >= split)].filter(s => s.length).map(s => {
      const x0 = Math.min(...s.map(m => m.x0)), x1 = Math.max(...s.map(m => m.x1)), y0 = Math.min(...s.map(m => m.y0)), y1 = Math.max(...s.map(m => m.y1));
      return { cx: (x0 + x1) / 2, cy: (y0 + y1) / 2, r: Math.max(x1 - x0, y1 - y0) * .3, w: x1 - x0, x0, x1, y0, y1 }; });
  }
  const legIdx = c.rest.map((p, k) => box(boxes.get(p)).y1 > bBot + 1 ? k : -1).filter(k => k >= 0);   // legs reach below the body (spots don't)
  const ec = eyes.length ? [eyes.reduce((a, e) => a + e.cx, 0) / eyes.length, eyes.reduce((a, e) => a + e.cy, 0) / eyes.length] : [0, bTop * .6 + bBot * .4];
  const xs = eyes.map(e => e.cx), span = eyes.length > 1 ? Math.max(...xs) - Math.min(...xs) : 0;
  const lr = [...eyes].sort((a, b) => a.cx - b.cx), angle = eyes.length === 2 ? clamp(Math.atan2(lr[1].cy - lr[0].cy, lr[1].cx - lr[0].cx) * 180 / Math.PI, -20, 20) : 0;
  const eyeR = eyes.length ? eyes.reduce((a, e) => a + e.r, 0) / eyes.length : 4, eyeBot = eyes.length ? Math.max(...eyes.map(e => e.y1)) : ec[1];
  const spanAt = (y, x) => { const iv = [];
    for (const ring of pts) { const X = [];
      for (let k = 0; k < ring.length; k++) { const a = ring[k], b = ring[(k + 1) % ring.length];
        if ((a[1] - y) * (b[1] - y) <= 0 && a[1] !== b[1]) X.push(a[0] + (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1])); }
      X.sort((p, q) => p - q); for (let k = 0; k + 1 < X.length; k += 2) iv.push([X[k], X[k + 1]]); }
    iv.sort((p, q) => p[0] - q[0]); const merged = [];
    for (const v of iv) { const m = merged[merged.length - 1]; if (m && v[0] <= m[1]) m[1] = Math.max(m[1], v[1]); else merged.push([...v]); }
    let best = null, bd = Infinity;
    for (const [l, r] of merged) { const d = x < l ? l - x : x > r ? x - r : 0; if (d < bd) { bd = d; best = [l, r]; } }
    return best || [x - W * .3, x + W * .3]; };
  const len = s => s[1] - s[0], mid = s => (s[0] + s[1]) / 2;
  const headW = len(spanAt(ec[1], ec[0]));
  // hat: walk down from the top until the body is wide enough to sit it on (skips spikes and peaks)
  const hatW = Math.min(W * .6, clamp(headW * .72, Math.max(18, span * 1.6), Math.max(30, span * 3.2)));
  const win = Math.max(span * .8, 8), head = all_.filter(p => Math.abs(p[0] - ec[0]) < win), topY = Math.min(...(head.length ? head : all_).map(p => p[1]));
  let seatY = topY, seat = spanAt(topY + 1, ec[0]);
  for (let y = topY + 1; y < ec[1] - eyeR * 1.6; y += 1) {
    const sp = spanAt(y, ec[0]); if (sp[0] > ec[0] + 2 || sp[1] < ec[0] - 2) continue;
    seat = sp; seatY = y; if (len(seat) >= hatW * .82) break; }
  const hat = { at: [clamp(mid(seat), ec[0] - hatW * .3, ec[0] + hatW * .3), seatY + 2], w: Math.min(hatW, len(seat) * 1.25) };
  // no drawn mouths: one is placed under the eyes, kept inside the body
  const mouthW = Math.max(span * .55, eyeR * 2.6, 10), mouthC = [ec[0], Math.min(eyeBot + Math.max(eyeR * 1.6, 6), bBot - mouthW * .45)];
  const neckY = clamp(mouthC[1] + mouthW * .5 + 3, bTop + (bBot - bTop) * .35, bBot - 4), neckS = spanAt(neckY, ec[0]);
  return { s0, cx, bot, W, H, bodyTop: bTop, bodyBot: bBot, eye: ec, eyes: eyes.map(e => [e.cx, e.cy]), groups, legIdx, span, angle, eyeR, mouthC, mouthW, topY, hat, headW,
           neck: [clamp(mid(neckS), ec[0] - headW * .2, ec[0] + headW * .2), neckY], neckW: len(neckS), side: [W / 2 - 4, 0] };
}

/// [{ id, A, character }] for every shape: character is the catalog entry minus `attach` (compile.mjs adds that).
export function buildV4(dir){
  return fs.readdirSync(dir).filter(f => /^shape_\d+\.svg$/.test(f)).sort().map(f => {
    const c = parse(path.join(dir, f)), A = analyze(c);
    const norm = d => svgpath(d).translate(-A.cx, -A.bot).scale(A.s0).round(1).toString();   // 0.1 unit is invisible at ~100 tall and keeps the texture specks small
    const clips = [], clipOf = s => { const d = norm(s.d), k = clips.indexOf(d); return k >= 0 ? k : clips.push(d) - 1; };
    const rule = s => s.rule ? { fillRule: s.rule } : {};
    const tex = c.tex.length ? clipOf(c.texClip) : -1;
    const skin = [{ d: norm(c.body.d), fill: c.body.fill, ...rule(c.body) },
      ...c.tex.map(t => ({ d: norm(t.d), fill: t.fill, ...rule(t), clip: tex })),
      ...c.rest.map((p, k) => A.legIdx.includes(k)
        ? { d: norm(p.d), fill: c.body.fill, ...rule(p), stroke: r2(LEG_STROKE * A.s0) }   // legs in the body colour, a touch thicker
        : { d: norm(p.d), fill: p.fill, ...rule(p) })];
    const dot = s => ({ cx: r2((s.circle.cx - A.cx) * A.s0), cy: r2((s.circle.cy - A.bot) * A.s0), r: r2(s.circle.r * A.s0) });
    const ink = A.groups.flatMap((ks, j) => { const w = c.whites[j];
      return [{ ...(w.circle ? dot(w) : { d: norm(w.d) }), fill: '#ffffff', eye: true },
              ...ks.map(k => { const p = c.pupils[k]; return { ...dot(p), ...(p.clip ? { clip: clipOf(p.clip) } : {}), eye: true }; })]; });
    return { id: c.id, A, character: {
      width: r2(A.W), height: r2(A.H), clips, skin, ink,
      anchors: { eye: A.eye.map(r2), eyes: A.eyes.map(p => p.map(r2)), mouth: { at: A.mouthC.map(r2), width: r2(A.mouthW) }, top: r2(A.topY), eyeSpan: r2(A.span), eyeAngle: r2(A.angle), eyeR: r2(A.eyeR), headWidth: r2(A.headW),
                 hat: { at: A.hat.at.map(r2), width: r2(A.hat.w) }, neck: A.neck.map(r2), neckWidth: r2(A.neckW), side: A.side.map(r2), body: [r2(A.bodyTop), r2(A.bodyBot)] },
    } };
  });
}
