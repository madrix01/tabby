// Attachment library: the source of truth for the catalog.
// Each item is drawn ~100 units wide around its marker `m`; placement rules live in the engine (and in compile.mjs for the gallery + parity oracle).
// Same shape as items sent as JSON at runtime: { slot, svg, anchor:m, fit?, height? } or, for eyewear, { lens, grow, bridge, strap? }.
// Kept flutter_svg-safe: no <text>, no 8-digit hex colours, no stroke-dasharray, no CSS variables.

// "$" drawn as a stroke instead of a <text> glyph (centre 0,0, ~16 tall)
const dollar = (x, y, s, color) =>
  `<path transform="translate(${x} ${y}) scale(${s})" d="M5 -5 Q5 -8 0 -8 Q-5 -8 -5 -4 Q-5 -1 0 0 Q5 1 5 4 Q5 8 0 8 Q-5 8 -5 5 M0 -11 V11" fill="none" stroke="${color}" stroke-width="2.6" stroke-linecap="round"/>`;

// beaded chain: dots along the quadratic curve that used to be a dashed stroke
const chainDots = () => {
  let out = '';
  for (let k = 0; k <= 16; k++) {
    const t = k / 16, x = (1-t)**2*2 + 2*(1-t)*t*50 + t*t*98, y = 2*(1-t)*t*46;
    out += `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="3" fill="#f6c945"/>`;
  }
  return out;
};

export const HATS = {
  top_hat: { m:[50,72], svg:`<rect x="24" y="8" width="52" height="58" rx="4" fill="#2b2a33"/><rect x="6" y="62" width="88" height="10" rx="5" fill="#2b2a33"/><rect x="24" y="48" width="52" height="9" fill="#e8494b"/>` },
  party:   { m:[50,72], svg:`<path d="M50 4 L84 72 H16 Z" fill="#f78fb3"/><path d="M33 52 H67 M40 32 H60" stroke="#f6c945" stroke-width="6"/><circle cx="50" cy="5" r="8" fill="#f6c945"/>` },
  crown:   { m:[50,62], svg:`<path d="M12 62 L6 14 L30 36 L50 6 L70 36 L94 14 L88 62 Z" fill="#f6c945" stroke="#e0a800" stroke-width="3" stroke-linejoin="round"/><circle cx="50" cy="46" r="6" fill="#e8494b"/><circle cx="26" cy="50" r="4" fill="#3a85f2"/><circle cx="74" cy="50" r="4" fill="#3a85f2"/>` },
  cap:     { m:[40,62], svg:`<path d="M6 62 Q6 12 40 12 Q74 12 74 62Z" fill="#e8494b"/><path d="M66 56 Q110 52 106 66 H64Z" fill="#c23638"/><circle cx="40" cy="12" r="5" fill="#c23638"/>` },
  beanie:  { m:[50,64], svg:`<path d="M12 62 Q12 10 50 10 Q88 10 88 62Z" fill="#3a85f2"/><rect x="8" y="52" width="84" height="16" rx="8" fill="#ffffff"/><circle cx="50" cy="8" r="9" fill="#ffffff"/>` },
  chef:    { m:[50,66], svg:`<path d="M26 66 V42 Q6 42 8 24 Q10 6 30 14 Q40 -2 58 12 Q82 6 90 24 Q94 42 74 42 V66Z" fill="#ffffff" stroke="#d7d3cc" stroke-width="3" stroke-linejoin="round"/><path d="M26 56 H74" stroke="#d7d3cc" stroke-width="3"/>` },
};

// fit = width as a fraction of the neck width; h = drawn height (used to keep it above the feet)
export const NECK = {
  bow_tie:    { fit:.42, h:28, m:[50,14], svg:`<path d="M50 14 L6 0 Q0 14 6 28 Z M50 14 L94 0 Q100 14 94 28 Z" fill="#e8494b"/><circle cx="50" cy="14" r="9" fill="#c23638"/>` },
  gold_chain: { fit:.72, h:48, m:[50,0],  svg:`${chainDots()}<circle cx="50" cy="34" r="13" fill="#f6c945" stroke="#e0a800" stroke-width="3"/>${dollar(50, 34, .62, '#b88600')}` },
  medal:      { fit:.5,  h:80, m:[50,0],  svg:`<path d="M30 0 L46 46 M70 0 L54 46" stroke="#3a85f2" stroke-width="12" stroke-linecap="round"/><circle cx="50" cy="58" r="20" fill="#f6c945" stroke="#e0a800" stroke-width="4"/><path d="M50 46 l4 8 9 1 -7 6 2 9 -8 -5 -8 5 2 -9 -7 -6 9 -1Z" fill="#e0a800"/>` },
};

export const PROPS = {
  gold_bar:   { m:[0,0], svg:`<path d="M0 0 H46 L38 -17 H8Z" fill="#f6c945"/><path d="M8 -17 H38 L34 -22 H12Z" fill="#ffe27a"/><path d="M12 -8 H34" stroke="#e0a800" stroke-width="2.5" stroke-linecap="round"/><path d="M44 -30 l2 5 5 2 -5 2 -2 5 -2 -5 -5 -2 5 -2Z" fill="#f6c945"/>` },
  gold_stack: { m:[0,0], svg:`<path d="M0 0 H40 L33 -14 H7Z" fill="#f6c945"/><path d="M7 -14 H33 L30 -18 H10Z" fill="#ffe27a"/><path d="M44 0 H84 L77 -14 H51Z" fill="#f2bd2c"/><path d="M51 -14 H77 L74 -18 H54Z" fill="#ffe27a"/><path d="M22 -18 H62 L55 -32 H29Z" fill="#f6c945"/><path d="M29 -32 H55 L52 -36 H32Z" fill="#ffe27a"/>` },
  money_bag:  { m:[0,0], svg:`<path d="M6 0 Q-4 -30 18 -40 L14 -48 H38 L34 -40 Q56 -30 46 0Z" fill="#c9a36b"/><path d="M14 -42 H38" stroke="#8a6a3b" stroke-width="3"/>${dollar(26, -17, .85, '#6b8f2e')}` },
  coffee:     { m:[0,0], svg:`<path d="M4 -30 H34 L30 0 H8Z" fill="#ffffff" stroke="#d7d3cc" stroke-width="2"/><path d="M5 -22 H33 L32 -12 H6Z" fill="#c9714e"/><path d="M34 -24 q10 2 0 12" stroke="#d7d3cc" stroke-width="3" fill="none"/><path d="M14 -36 q-3 -5 0 -9 M22 -36 q-3 -5 0 -9" stroke="#c8c4bc" stroke-width="2" fill="none" stroke-linecap="round"/>` },
};

// eyewear: one lens template per eye, drawn centred on (0,0) at radius 10; placed on each eye at a radius taken from the eye size.
// grow = lens size vs eye, bridge = colour of the bar between lenses, strap = optional band across the head, lensRight = optional different right lens.
// This declarative shape is what runtime (JSON) eyewear uses too, so no per-item code is needed.
export const EYEWEAR = {
  goggles: { grow:1.25, bridge:'#e8494b', strap:'#2b2a33',
    lens:`<circle r="10" fill="#8fd3ff" stroke="#e8494b" stroke-width="3.2"/><path d="M-4.5 -3.5 q3 -3 6.5 -2" stroke="#ffffff" stroke-width="1.8" stroke-linecap="round" fill="none"/>` },
  shades:  { grow:1.15, bridge:'#2b2a33',
    lens:`<rect x="-11" y="-7.5" width="22" height="15" rx="4.5" fill="#2b2a33"/><path d="M-6 -3 h5" stroke="#ffffff" stroke-opacity=".6" stroke-width="1.5" stroke-linecap="round"/>` },
  round:   { grow:1.05, bridge:'#2b2a33',
    lens:`<circle r="10" fill="#ffffff" fill-opacity=".33" stroke="#2b2a33" stroke-width="2.6"/>` },
  // 3D movie glasses: red left lens, blue right lens (lensRight = a different lens for the right eye)
  three_d: { grow:1.15, bridge:'#f4f1ea',
    lens:`<rect x="-11" y="-7.5" width="22" height="15" rx="3" fill="#e8494b" fill-opacity=".85" stroke="#f4f1ea" stroke-width="3"/>`,
    lensRight:`<rect x="-11" y="-7.5" width="22" height="15" rx="3" fill="#3a85f2" fill-opacity=".85" stroke="#f4f1ea" stroke-width="3"/>` },
  hearts:  { grow:1.2,  bridge:'#f2679b',
    lens:`<path transform="translate(0 -1.5) scale(0.5556)" d="M0 18 C-30 -2 -16 -22 0 -8 C16 -22 30 -2 0 18Z" fill="#f2679b"/>` },
};

// evolution lines built only from the supplied characters: [character id, form name]; first name doubles as the species id
export const LINES = [
  [['13','Blip'],    ['25','Cloudbert'], ['01','Blobfred']],
  [['34','Totem'],   ['11','Cubey'],     ['29','Jellyfin']],
  [['02','Sprig'],   ['17','Antenna'],   ['16','Broccolord']],
  [['32','Radish'],  ['36','Mossy']],
  [['28','Pip'],     ['03','Bean'],      ['15','Tri']],
  [['37','Ember'],   ['23','Twinny'],    ['08','Archie']],
  [['18','Pinky'],   ['04','Fluffpaw'],  ['39','Hornsby']],
  [['05','Bunbun'],  ['35','Kitto'],     ['21','Piggo']],
  [['30','Stamp'],   ['20','Longcat']],
  [['24','Squidge'], ['06','Beaky'],     ['10','Mush'],    ['27','Donut']],
  [['19','Snowy'],   ['07','Pebble']],
  [['09','Cactoo'],  ['14','Splotch'],   ['38','Teapot']],
  [['33','Drip'],    ['31','Chick'],     ['26','Ducko']],
  [['40','Lemon'],   ['12','Bunny'],     ['22','Sunny']],
  [['41','Mochi'],   ['43','Mochiko'],   ['44','Mochimaru']],
  [['42','Nimbo'],   ['45','Cumulo'],    ['46','Seraphluff']],
];
export const LEVELS = { 2:[1,6], 3:[1,4,8], 4:[1,3,6,10] };
export const SIZES  = { 2:[.75,1.15], 3:[.7,1,1.3], 4:[.65,.9,1.15,1.35] };
