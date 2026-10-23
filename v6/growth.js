/*
 * growth.js: pure, DOM-free evolution + item placement. Works as <script> (window.Growth) or require().
 *
 * A species is a chain of FORMS, like Pokemon:  forms = [{ at:1, ...}, { at:4, ...}, { at:8, ...}]
 *   xp -> level      level = 1 + floor((xp / base)^(1/pow))        inverse: xp(level) = base * (level-1)^pow
 *   level -> form    form  = last form whose `at` <= level          (the evolution rule)
 *   within a form    q    = (xp - xp(form.at)) / (xp(next.at) - xp(form.at))   0..1, final form saturates
 *                    scale = lerp(form.size[0], form.size[1], q)    (small growth between evolutions)
 *   evolution event  fires when form(xp) > the form currently shown
 *
 * Item placement works on whichever form is shown, so items re-fit by themselves after an evolution:
 *   transform = translate(anchor) scale(k) translate(-marker)      k = fit * referenceWidth / itemWidth
 *
 * A form is { at, size:[lo,hi], eyeSize, eyeX, legLen, limbW, w, hat, eyes, arm, ...art }
 *   (w = half width, hat = y of head top, eyes = y of eye line, arm = y of shoulder; y is negative upwards)
 *
 * Integration: store { xp, form } per pet. Render forms[pet.form] inside <g transform="scale(t.scale)">.
 * After every xp change call evolutionDue(); if it returns an index, play your animation and set pet.form.
 */
const Growth = (() => {
  const CFG = {
    base: 30, pow: 1.5,                         // level 2 at 30 xp, 3 at ~85, 4 at ~156, 8 at ~556
    tau: 400,                                   // how fast the FINAL form saturates (xp)
    xp: { pet: 1, feed: 25, dance: 0.5, walk: 0.5 },   // xp per event; tune freely
    fit: { hat: { base: 'body', fit: 0.68 }, glasses: { base: 'eyes', fit: 1.9 } },
  };
  const DEFAULTS = { size: [1, 1], eyeSize: 1, eyeX: 11, legLen: 1, limbW: 3.5 };

  const lerp  = (a, b, t) => a + (b - a) * t;
  const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));

  const levelOf    = (xp, c = CFG) => 1 + Math.floor(Math.pow(Math.max(0, xp) / c.base, 1 / c.pow) + 1e-9); // epsilon: float error at exact thresholds
  const xpForLevel = (lv, c = CFG) => c.base * Math.pow(Math.max(0, lv - 1), c.pow);

  // which form a level maps to
  const formAt = (level, forms) => forms.reduce((best, f, i) => (f.at <= level ? i : best), 0);

  // everything the renderer needs. `shown` = the form index currently displayed (defaults to the earned one)
  function traits(xp, forms, shown, c = CFG) {
    const level = levelOf(xp, c), earned = formAt(level, forms);
    const idx = shown ?? earned, f = { ...DEFAULTS, ...forms[idx] }, next = forms[idx + 1];
    const lo = xpForLevel(f.at, c);
    const q = clamp(next ? (xp - lo) / (xpForLevel(next.at, c) - lo) : 1 - Math.exp(-(xp - lo) / c.tau));
    const lvLo = xpForLevel(level, c), lvHi = xpForLevel(level + 1, c);
    return {
      xp, level, idx, earned, q, form: f,
      scale: lerp(f.size[0], f.size[1], q),
      levelFrac: (xp - lvLo) / (lvHi - lvLo),
      nextLevelXp: Math.ceil(lvHi),
      nextForm: next ? { name: next.name, at: next.at, xp: Math.ceil(xpForLevel(next.at, c)) } : null,
    };
  }

  // returns the form index to evolve into, or -1
  const evolutionDue = (xp, forms, shown, c = CFG) => { const e = formAt(levelOf(xp, c), forms); return e > shown ? e : -1; };

  // named anchor points on a form
  const anchors = (f) => ({
    hat:   [0, f.hat + 4],
    eyes:  [0, f.eyes],
    handL: [-f.w, f.arm],
    handR: [ f.w, f.arm],
    side:  [ f.w + 18, 30],                      // ground beside the feet (toys)
  });

  // item size relative to the body (hats) or the eye span (glasses)
  const itemScale = (kind, f, itemWidth = 100, c = CFG) => {
    const r = c.fit[kind], ref = r.base === 'eyes' ? 2 * (f.eyeX ?? 11) : 2 * f.w;
    return r.fit * ref / itemWidth;
  };

  // the one placement formula: land the item's marker on the form's anchor
  const place = (anchor, marker, k = 1) =>
    `translate(${anchor[0]} ${anchor[1]}) scale(${k}) translate(${-marker[0]} ${-marker[1]})`;

  // kind 'hat' | 'glasses', f = form, item = { m:[x,y], w? }
  const itemTransform = (kind, f, item, c = CFG) => {
    const a = anchors(f);
    return place(kind === 'hat' ? a.hat : a.eyes, item.m, itemScale(kind, f, item.w || 100, c));
  };

  // add xp for an event name (see CFG.xp); returns { xp, leveledUp }
  const gain = (xp, event, amount = 1, c = CFG) => {
    const next = xp + (c.xp[event] || 0) * amount;
    return { xp: next, leveledUp: levelOf(next, c) > levelOf(xp, c) };
  };

  const api = { CFG, lerp, levelOf, xpForLevel, formAt, traits, evolutionDue, anchors, itemScale, place, itemTransform, gain };
  if (typeof module !== 'undefined') module.exports = api;
  return api;
})();

// self-check: node growth.js
if (typeof require !== 'undefined' && typeof module !== 'undefined' && require.main === module) {
  const assert = require('assert'), G = module.exports;
  const forms = [{ at: 1, w: 20, hat: -60, eyes: -40, arm: -30, size: [.9, 1] }, { at: 4, w: 40, hat: -110, eyes: -70, arm: -45, size: [.9, 1.1] }, { at: 8, w: 52, hat: -140, eyes: -90, arm: -55 }];
  assert.strictEqual(G.levelOf(0), 1);
  assert.strictEqual(G.levelOf(G.xpForLevel(5)), 5);
  assert.deepStrictEqual([0, 100, 160, 600].map(x => G.traits(x, forms).idx), [0, 0, 1, 2]);   // evolution thresholds
  assert.strictEqual(G.evolutionDue(160, forms, 0), 1);                                         // earned 1, showing 0
  assert.strictEqual(G.evolutionDue(160, forms, 1), -1);
  assert.strictEqual(G.evolutionDue(600, forms, 0), 2);                                         // skips straight to latest earned
  const a = G.traits(0, forms), b = G.traits(G.xpForLevel(4) - 1, forms);
  assert(a.scale < b.scale && b.scale <= 1.0 + 1e-9);                                           // grows inside a form
  assert(G.traits(1e9, forms).q <= 1);                                                          // final form saturates
  // same hat, bigger body -> bigger hat, same anchor logic
  const hat = { m: [50, 60] }, k = f => +/scale\(([\d.]+)\)/.exec(G.itemTransform('hat', f, hat))[1];
  assert(k({ ...forms[0], eyeX: 14 }) < k({ ...forms[1], eyeX: 14 }));
  assert(/^translate\(0 -56\) scale/.test(G.itemTransform('hat', forms[0], hat)));
  assert(G.gain(29, 'feed').leveledUp);
  console.log('growth ok');
}
