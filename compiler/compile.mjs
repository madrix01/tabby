// Catalog compiler: ../characters/*.svg + items.mjs -> out/critter_catalog.json (+ out/gallery.html for eyeballing).
// All geometry is measured here once, so the app only composes strings and animates. Port of analyze() in v3/index.html.
//   node compile.mjs
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import svgpath from 'svgpath';
import { svgPathProperties } from 'svg-path-properties';
import { HATS, NECK, PROPS, EYEWEAR, LINES, LEVELS, SIZES } from './items.mjs';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const SRC = path.join(HERE, '..', 'characters'), OUT = path.join(HERE, 'out');
const INK = '#2b2a33', VERSION = 1;
const clamp = (v, a, b) => Math.min(b, Math.max(a, v));
const r2 = n => Math.round(n * 100) / 100;

// ---------- parse the traced SVGs (flat: <path> / <circle> with fill + optional translate) ----------
const attr = (a, k) => (new RegExp(`\\b${k}="([^"]*)"`).exec(a) || [])[1];
const translateOf = a => { const m = /translate\(([-\d.]+)[ ,]+([-\d.]+)\)/.exec(attr(a, 'transform') || ''); return m ? [+m[1], +m[2]] : [0, 0]; };
function parse(file){
  const s = fs.readFileSync(file, 'utf8'), els = [];
  for (const [, tag, a] of s.matchAll(/<(path|circle)\b([^>]*?)\/?>/g)) {
    const fill = attr(a, 'fill');
    if (!fill) continue;                         // a few traces carry a duplicate unfilled path that would render black
    els.push(tag === 'path'
      ? { tag, fill, d: attr(a, 'd'), t: translateOf(a), rule: attr(a, 'fill-rule') }
      : { tag, fill, cx: +attr(a, 'cx'), cy: +attr(a, 'cy'), r: +attr(a, 'r') });
  }
  return { id: /character_(\d+)/.exec(file)[1], skin: els.filter(e => e.fill !== INK), ink: els.filter(e => e.fill === INK) };
}
const sample = (e, n) => { const p = new svgPathProperties(e.d), L = p.getTotalLength();
  return Array.from({ length: n }, (_, k) => { const q = p.getPointAtLength(L * k / n); return [q.x + e.t[0], q.y + e.t[1]]; }); };
const bboxOf = pts => { const xs = pts.map(p => p[0]), ys = pts.map(p => p[1]);
  return { x0: Math.min(...xs), y0: Math.min(...ys), x1: Math.max(...xs), y1: Math.max(...ys) }; };

// ---------- measure one character: normalise (feet at origin, ~100 tall) and find eyes, hat seat, neck, side ----------
function analyze(c){
  const raw = c.skin.filter(e => e.tag === 'path').map(e => sample(e, 600));
  const bb = bboxOf(raw.flat()), bw = bb.x1 - bb.x0, bh = bb.y1 - bb.y0;
  const s0 = Math.min(100 / bh, 150 / bw), cx = (bb.x0 + bb.x1) / 2, bot = bb.y1;
  const N = ([x, y]) => [(x - cx) * s0, (y - bot) * s0];
  const pts = raw.map(ring => ring.map(N)), all = pts.flat();
  // ink parts: eyes are the upper ones, mouth the lower ones
  const ink = c.ink.map((e, idx) => {
    const b = e.tag === 'circle' ? { x0: e.cx - e.r, y0: e.cy - e.r, x1: e.cx + e.r, y1: e.cy + e.r } : bboxOf(sample(e, 200));
    const [x0, y0] = N([b.x0, b.y0]), [x1, y1] = N([b.x1, b.y1]);
    return { idx, cx: (x0 + x1) / 2, cy: (y0 + y1) / 2, r: Math.max(x1 - x0, y1 - y0) / 2, bottom: y1, w: x1 - x0 };
  });
  let eyes = ink, mouth = [];
  if (ink.length === 2 && Math.abs(ink[0].cy - ink[1].cy) > Math.abs(ink[0].cx - ink[1].cx) * .8) { const [a, b] = [...ink].sort((p, q) => p.cy - q.cy); eyes = [a]; mouth = [b]; }
  else if (ink.length >= 3) { const ys = ink.map(e => e.cy), mid = (Math.min(...ys) + Math.max(...ys)) / 2; eyes = ink.filter(e => e.cy < mid); mouth = ink.filter(e => e.cy >= mid); }
  const W = bw * s0, H = bh * s0;
  const ec = eyes.length ? [eyes.reduce((a, e) => a + e.cx, 0) / eyes.length, eyes.reduce((a, e) => a + e.cy, 0) / eyes.length] : [0, -H * .7];
  const xs = eyes.map(e => e.cx), span = eyes.length > 1 ? Math.max(...xs) - Math.min(...xs) : 0;
  const lr = [...eyes].sort((a, b) => a.cx - b.cx), angle = eyes.length === 2 ? clamp(Math.atan2(lr[1].cy - lr[0].cy, lr[1].cx - lr[0].cx) * 180 / Math.PI, -20, 20) : 0;
  const eyeR = eyes.length ? eyes.reduce((a, e) => a + e.r, 0) / eyes.length : 4;
  // the stretch of body crossed by a horizontal line at y: the interval containing x, else the nearest one
  const spanAt = (y, x) => { const X = [];
    for (const ring of pts) for (let k = 0; k < ring.length; k++) { const a = ring[k], b = ring[(k + 1) % ring.length];
      if ((a[1] - y) * (b[1] - y) <= 0 && a[1] !== b[1]) X.push(a[0] + (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1])); }
    X.sort((p, q) => p - q); let best = null, bd = Infinity;
    for (let k = 0; k + 1 < X.length; k += 2) { const l = X[k], r = X[k + 1], d = x < l ? l - x : x > r ? x - r : 0; if (d < bd) { bd = d; best = [l, r]; } }
    return best || [x - W * .3, x + W * .3]; };
  const len = s => s[1] - s[0], mid = s => (s[0] + s[1]) / 2;
  const headW = len(spanAt(ec[1], ec[0]));
  // hat: wanted width from the head, then walk down from the top until the body is wide enough to sit it on
  const hatW = Math.min(W * .6, clamp(headW * .72, Math.max(18, span * 1.6), Math.max(30, span * 3.2)));
  const win = Math.max(span * .8, 8), head = all.filter(p => Math.abs(p[0] - ec[0]) < win), topY = Math.min(...(head.length ? head : all).map(p => p[1]));
  let seatY = topY, seat = spanAt(topY + 1, ec[0]);
  for (let y = topY + 1; y < ec[1] - eyeR * 1.6; y += 1) { seat = spanAt(y, ec[0]); seatY = y; if (len(seat) >= hatW * .82) break; }
  const hat = { at: [clamp(mid(seat), ec[0] - hatW * .3, ec[0] + hatW * .3), seatY + 2], w: Math.min(hatW, len(seat) * 1.25) };
  // neck: under the mouth (or well under a lone eye), centred on the body there
  const mouthBottom = mouth.length ? Math.max(...mouth.map(m => m.bottom)) : ec[1] + Math.max(eyeR * 4, H * .12);
  const neckY = Math.min(mouthBottom + Math.max(4, eyeR * 1.3), -H * .15), neckS = spanAt(neckY, ec[0]);
  // mouth (moods draw their own here); characters without one get a spot under the eye
  const mouthC = mouth.length ? [mouth.reduce((a, m) => a + m.cx, 0) / mouth.length, mouth.reduce((a, m) => a + m.cy, 0) / mouth.length] : [ec[0], ec[1] + Math.max(eyeR * 3.2, 9)];
  const mouthW = mouth.length ? Math.max(...mouth.map(m => m.w)) : Math.max(span * .5, 10);
  return { s0, cx, bot, W, H, eye: ec, eyes: eyes.map(e => [e.cx, e.cy]), span, angle, eyeR, eyeIdx: eyes.map(e => e.idx), mouthIdx: mouth.map(m => m.idx), mouthC, mouthW, hat, headW,
           neck: [clamp(mid(neckS), ec[0] - headW * .2, ec[0] + headW * .2), neckY], neckW: len(neckS), side: [W / 2 - 4, 0] };
}

// ---------- placement: one transform per character x item, so the app never re-derives geometry ----------
const place = (at, m, k, ang = 0) => `translate(${r2(at[0])} ${r2(at[1])}) rotate(${r2(ang)}) scale(${+k.toFixed(4)}) translate(${-m[0]} ${-m[1]})`;
function lenses(A, it){
  const half = A.span / 2, r = clamp(A.eyeR * 2.3 * it.grow, 5, half ? half * .9 : 99), xs = half ? [-half, half] : [0];
  const hw = Math.min(A.headW / 2 + 2, half + r * 2.4);       // strap wraps the head, not a long body
  return (it.strap ? `<path d="M${r2(-hw)} 0 H${r2(hw)}" stroke="${it.strap}" stroke-width="${r2(r * .4)}" stroke-linecap="round"/>` : '')
       + (half ? `<path d="M${r2(-half + r * .9)} 0 H${r2(half - r * .9)}" stroke="${it.bridge}" stroke-width="${r2(r * .26)}" stroke-linecap="round"/>` : '')
       + xs.map(x => `<g transform="translate(${r2(x)} 0) scale(${+(r / 10).toFixed(4)})">${x > 0 && it.lensRight ? it.lensRight : it.lens}</g>`).join('');
}
function attachments(A){
  const out = { hat: {}, eyes: {}, neck: {}, prop: {} };
  for (const [id, it] of Object.entries(HATS)) out.hat[id] = place(A.hat.at, it.m, A.hat.w / 100, A.angle);
  for (const [id, it] of Object.entries(NECK)) { const k = clamp(A.neckW * it.fit, 18, 70) / 100;
    out.neck[id] = place([A.neck[0], Math.min(A.neck[1], -2 - it.h * k)], it.m, k); }          // lifted if it would hang below the feet
  for (const [id, it] of Object.entries(PROPS)) out.prop[id] = place(A.side, it.m, .8);
  for (const [id, it] of Object.entries(EYEWEAR)) out.eyes[id] = { transform: `translate(${r2(A.eye[0])} ${r2(A.eye[1])}) rotate(${r2(A.angle)})`, svg: lenses(A, it) };
  return out;
}

// ---------- build ----------
const files = fs.readdirSync(SRC).filter(f => /^character_\d+\.svg$/.test(f)).sort();
const characters = {};
for (const file of files) {
  const c = parse(path.join(SRC, file)), A = analyze(c);
  const norm = e => svgpath(e.d).translate(e.t[0], e.t[1]).translate(-A.cx, -A.bot).scale(A.s0).round(2).toString();
  characters[c.id] = {
    width: r2(A.W), height: r2(A.H),
    skin: c.skin.map(e => ({ d: norm(e), fill: e.fill, ...(e.rule ? { fillRule: e.rule } : {}) })),
    ink: c.ink.map((e, k) => ({
      ...(e.tag === 'path' ? { d: norm(e) } : { cx: r2((e.cx - A.cx) * A.s0), cy: r2((e.cy - A.bot) * A.s0), r: r2(e.r * A.s0) }),
      ...(e.rule ? { fillRule: e.rule } : {}), eye: A.eyeIdx.includes(k), mouth: A.mouthIdx.includes(k) })),
    // everything the engine needs to place any item, including ones it only receives at runtime
    anchors: { eye: A.eye.map(r2), eyes: A.eyes.map(p => p.map(r2)), mouth: { at: A.mouthC.map(r2), width: r2(A.mouthW) }, eyeSpan: r2(A.span), eyeAngle: r2(A.angle), eyeR: r2(A.eyeR), headWidth: r2(A.headW),
               hat: { at: A.hat.at.map(r2), width: r2(A.hat.w) }, neck: A.neck.map(r2), neckWidth: r2(A.neckW), side: A.side.map(r2) },
    attach: attachments(A),   // pre-computed placements of the bundled items: used by the gallery and as a parity oracle for the engine's maths
  };
}
const slug = s => s.toLowerCase().replace(/[^a-z0-9]+/g, '_');
const species = LINES.map(line => ({ id: slug(line[0][1]),
  forms: line.map(([id, name], k) => ({ character: id, name, atLevel: LEVELS[line.length][k], size: [r2(SIZES[line.length][k] * .92), r2(SIZES[line.length][k] * 1.04)] })) }));
const used = new Set(species.flatMap(s => s.forms.map(f => f.character)));
const missing = Object.keys(characters).filter(id => !used.has(id));
if (missing.length) console.warn('characters not in any species line:', missing.join(', '));

const catalog = {
  version: VERSION,
  units: 'Character space: origin at the feet (bottom centre), y grows downwards, characters ~100 tall and at most 150 wide. Item transforms are in this space.',
  inkColor: INK,
  characters,
  // same shape the app accepts for items sent at runtime
  items: {
    hat:  Object.fromEntries(Object.entries(HATS).map(([k, v]) => [k, { svg: v.svg, anchor: v.m }])),
    neck: Object.fromEntries(Object.entries(NECK).map(([k, v]) => [k, { svg: v.svg, anchor: v.m, fit: v.fit, height: v.h }])),
    prop: Object.fromEntries(Object.entries(PROPS).map(([k, v]) => [k, { svg: v.svg, anchor: v.m }])),
    eyes: Object.fromEntries(Object.entries(EYEWEAR).map(([k, v]) => [k, { lens: v.lens, ...(v.lensRight ? { lensRight: v.lensRight } : {}), grow: v.grow, bridge: v.bridge, ...(v.strap ? { strap: v.strap } : {}) }])),
  },
  species,
};
fs.mkdirSync(OUT, { recursive: true });
fs.writeFileSync(path.join(OUT, 'critter_catalog.json'), JSON.stringify(catalog));

// ---------- gallery: rendered from the catalog alone, the same way the app will compose it ----------
const svgOf = (id, pick) => { const c = characters[id], a = c.attach;
  const ink = c.ink.map(e => e.d ? `<path d="${e.d}" fill="${INK}"/>` : `<circle cx="${e.cx}" cy="${e.cy}" r="${e.r}" fill="${INK}"/>`).join('');
  return c.skin.map(e => `<path d="${e.d}" fill="${e.fill}"${e.fillRule ? ` fill-rule="${e.fillRule}"` : ''}/>`).join('') + ink
    + (pick.neck ? `<g transform="${a.neck[pick.neck]}">${NECK[pick.neck].svg}</g>` : '')
    + (pick.eyes ? `<g transform="${a.eyes[pick.eyes].transform}">${a.eyes[pick.eyes].svg}</g>` : '')
    + (pick.hat  ? `<g transform="${a.hat[pick.hat]}">${HATS[pick.hat].svg}</g>` : '')
    + (pick.prop ? `<g transform="${a.prop[pick.prop]}">${PROPS[pick.prop].svg}</g>` : ''); };
const K = { hat: Object.keys(HATS), eyes: Object.keys(EYEWEAR), neck: Object.keys(NECK), prop: Object.keys(PROPS) };
const cells = Object.keys(characters).sort().map((id, n) => `<g transform="translate(${100 + (n % 8) * 190} ${170 + Math.floor(n / 8) * 225})">${
  svgOf(id, { hat: K.hat[(n + 2) % K.hat.length], eyes: K.eyes[n % K.eyes.length], neck: K.neck[(n + 1) % K.neck.length], prop: K.prop[n % K.prop.length] })
}<text y="22" text-anchor="middle" font-family="sans-serif" font-size="11">${id}</text></g>`).join('');
fs.writeFileSync(path.join(OUT, 'gallery.html'), `<!doctype html><meta charset="utf-8"><title>Catalog gallery</title><body style="margin:0;background:#fbf8f2"><svg viewBox="0 0 1600 1150" width="1600">${cells}</svg>`);

// ---------- evolution sheet: every species line, stage by stage, drawn at its stage size ----------
{
  const esc = t => t.replace(/&/g, '&amp;').replace(/</g, '&lt;');
  const body = id => { const c = characters[id];
    return c.skin.map(e => `<path d="${e.d}" fill="${e.fill}"${e.fillRule ? ` fill-rule="${e.fillRule}"` : ''}/>`).join('')
         + c.ink.map(e => e.d ? `<path d="${e.d}" fill="${INK}"${e.fillRule ? ` fill-rule="${e.fillRule}"` : ''}/>` : `<circle cx="${e.cx}" cy="${e.cy}" r="${e.r}" fill="${INK}"/>`).join(''); };
  const LEFT = 150, CELL = 220, ROW = 190, TOP = 110, cols = Math.max(...species.map(s => s.forms.length));
  const W = LEFT + cols * CELL + 30, H = TOP + species.length * ROW + 30, font = `font-family="Avenir Next, Futura, Helvetica, sans-serif"`;
  const rows = species.map((sp, r) => {
    const y = TOP + r * ROW, base = y + ROW - 50;
    const cells = sp.forms.map((f, k) => {
      const x = LEFT + k * CELL + CELL / 2, sc = (f.size[0] + f.size[1]) / 2;
      const arrow = k ? `<g transform="translate(${x - CELL / 2} ${base - 45})"><path d="M-22 0 H16 M8 -7 L17 0 L8 7" stroke="#b9b2a6" stroke-width="3" fill="none" stroke-linecap="round" stroke-linejoin="round"/>`
        + `<text y="-12" text-anchor="middle" font-size="11" font-weight="700" fill="#9a9184" ${font}>Lv ${f.atLevel}</text></g>` : '';
      return `${arrow}<g transform="translate(${x} ${base}) scale(${sc})">${body(f.character)}</g>`
        + `<ellipse cx="${x}" cy="${base + 2}" rx="${(characters[f.character].width * sc * .42).toFixed(1)}" ry="4" fill="#000" opacity=".07"/>`
        + `<text x="${x}" y="${base + 24}" text-anchor="middle" font-size="13" font-weight="800" letter-spacing="1.5" fill="#2b2a33" ${font}>${esc(f.name.toUpperCase())}</text>`
        + `<text x="${x}" y="${base + 40}" text-anchor="middle" font-size="10.5" fill="#9a9184" ${font}>stage ${k + 1} · #${f.character}</text>`;
    }).join('');
    return `<rect x="16" y="${y + 6}" width="${W - 32}" height="${ROW - 12}" rx="18" fill="${r % 2 ? '#f4efe6' : '#f8f4ec'}"/>`
      + `<text x="40" y="${y + ROW / 2 - 4}" font-size="16" font-weight="800" letter-spacing="2" fill="#2b2a33" ${font}>${esc(sp.id.toUpperCase())}</text>`
      + `<text x="40" y="${y + ROW / 2 + 16}" font-size="11" fill="#9a9184" ${font}>${sp.forms.length} stages</text>${cells}`;
  }).join('');
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" width="${W}" height="${H}">`
    + `<rect width="${W}" height="${H}" fill="#fbf8f2"/>`
    + `<text x="${W / 2}" y="56" text-anchor="middle" font-size="28" font-weight="800" letter-spacing="6" fill="#2b2a33" ${font}>EVOLUTION STAGES</text>`
    + `<text x="${W / 2}" y="82" text-anchor="middle" font-size="12" fill="#9a9184" ${font}>${species.length} species · ${Object.keys(characters).length} characters · each stage drawn at its size, arrows show the level it unlocks at</text>`
    + rows + '</svg>';
  fs.writeFileSync(path.join(OUT, 'evolution_sheet.svg'), svg);
  fs.mkdirSync(path.join(HERE, '..', 'docs'), { recursive: true });
  fs.writeFileSync(path.join(HERE, '..', 'docs', 'evolution_sheet.svg'), svg);
}

const kb = (fs.statSync(path.join(OUT, 'critter_catalog.json')).size / 1024).toFixed(0);
console.log(`${Object.keys(characters).length} characters, ${species.length} species, ${Object.values(K).flat().length} items -> out/critter_catalog.json (${kb} KB), out/gallery.html, docs/evolution_sheet.svg`);
