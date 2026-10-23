import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'catalog.dart';
import 'placement.dart' show n2;

/// What the critter is feeling or up to. Sent as `"mood"` in the spec; unknown values mean none.
///
/// Each mood replaces the critter's own mouth, can add brows / cheeks / a tear, and puts something
/// around it: a thought bubble, a rain cloud or an item on the ground. Moving effects (bouncing,
/// floating notes, rain) are played by `CritterView(animate: true)`, from [MoodStyle.motion] and [MoodStyle.fx].
enum CritterMood {
  happy,
  sad,
  food,
  entertainment,
  travel,
  shopping,
  emptyWallet,

  /// The opposite of [emptyWallet]: a smug smirk behind shades, a money bag and coins.
  rich;

  /// The value used in JSON (`empty_wallet` for [emptyWallet]).
  String get wire => this == emptyWallet ? 'empty_wallet' : name;

  static CritterMood? parse(Object? v) => values.where((m) => m.wire == v).firstOrNull;
}

/// How a mood moves the body while the critter stands (same numbers as the v3/v6 prototypes).
/// [jump] is a bounce height, [sway] and [lean] are degrees, [squash] and [slump] are fractions, [freq] is beats per second.
class MoodMotion {
  const MoodMotion({this.jump = 0, this.freq = 1, this.sway = 0, this.lean = 0, this.squash = 0, this.slump = 0});
  final double jump, freq, sway, lean, squash, slump;
}

/// What floats off a mood: [glyphs] rising every [every], or rain from the cloud, or dust and moths from the wallet.
class MoodFx {
  const MoodFx({required this.every, this.glyphs = const [], this.colors = const [], this.rain = false, this.wallet = false});
  final Duration every;
  final List<String> glyphs, colors;
  final bool rain, wallet;
}

/// The look of each mood. `eyewear` is put on instead of the spec's eyewear (bundled item id).
class MoodStyle {
  const MoodStyle({required this.mouth, this.brows = false, this.tear = false, this.cheeks = false, this.cloud = false, this.wallet = false, this.bubble, this.ground, this.eyewear,
      this.motion = const MoodMotion(), required this.fx});
  final String mouth;
  final bool brows, tear, cheeks, cloud, wallet;
  final String? bubble, ground, eyewear;
  final MoodMotion motion;
  final MoodFx fx;
}

const moodStyles = {
  CritterMood.happy: MoodStyle(mouth: 'grin', cheeks: true,
      motion: MoodMotion(jump: 7, freq: 1.8, sway: 3, squash: .08), fx: MoodFx(every: Duration(milliseconds: 500), glyphs: ['✦', '♥', '✦'], colors: ['#f6c945', '#f2679b', '#ffb800'])),
  CritterMood.sad: MoodStyle(mouth: 'frown', brows: true, tear: true, cloud: true,
      motion: MoodMotion(slump: .07, lean: -3, freq: .5, sway: 1.5), fx: MoodFx(every: Duration(milliseconds: 160), rain: true)),
  CritterMood.food: MoodStyle(mouth: 'chew', bubble: 'burger',
      motion: MoodMotion(jump: 1.5, freq: 1.4, sway: 2, squash: .03), fx: MoodFx(every: Duration(milliseconds: 900), glyphs: ['nom', 'yum'], colors: ['#c9714e', '#e8494b'])),
  CritterMood.entertainment: MoodStyle(mouth: 'grin', bubble: 'popcorn', eyewear: 'three_d',
      motion: MoodMotion(jump: 6, freq: 1.1, sway: 11, squash: .06), fx: MoodFx(every: Duration(milliseconds: 420), glyphs: ['♪', '♫'], colors: ['#3a85f2', '#e8494b', '#16b79d', '#8c6fd6'])),
  CritterMood.travel: MoodStyle(mouth: 'smile', bubble: 'plane', ground: 'suitcase',
      motion: MoodMotion(jump: 3, freq: 1.3, sway: 4, lean: 3, squash: .03), fx: MoodFx(every: Duration(milliseconds: 1400), glyphs: ['✈'], colors: ['#3a85f2'])),
  CritterMood.shopping: MoodStyle(mouth: 'open', bubble: 'bag', ground: 'bags',
      motion: MoodMotion(jump: 5, freq: 2.2, sway: 2, squash: .06), fx: MoodFx(every: Duration(milliseconds: 520), glyphs: ['\$', '%', '\$'], colors: ['#2f9e44', '#e8494b', '#e0a800'])),
  // sad face, an empty wallet held upside down, and a "₹0" thought bubble; animated, dust and moths come out of the wallet
  CritterMood.emptyWallet: MoodStyle(mouth: 'frown', brows: true, tear: true, wallet: true, bubble: 'zero',
      motion: MoodMotion(slump: .09, lean: -2, freq: .45, sway: 1.2, squash: .05), fx: MoodFx(every: Duration(milliseconds: 1400), wallet: true, glyphs: ['₹0'], colors: ['#9a9184'])),
  // smug smirk behind shades, a gold coin bubble, a money bag and a coin stack on the ground
  CritterMood.rich: MoodStyle(mouth: 'smirk', bubble: 'coin', ground: 'riches', eyewear: 'shades',
      motion: MoodMotion(jump: 3, freq: 1, sway: 2.5, lean: 2, squash: .04), fx: MoodFx(every: Duration(milliseconds: 380), glyphs: ['₹', '✦', '₹'], colors: ['#e0a800', '#f6c945', '#2f9e44'])),
};

const _ink = '#2b2a33';

// ~24 units, centred on (0,0); shown inside the thought bubble
const _icons = {
  // gold coin with a "₹" drawn as strokes
  'coin': '<circle r="11" fill="#f6c945" stroke="#e0a800" stroke-width="2.4"/>'
      '<path d="M-4.5 -6 H4.5 M-4.5 -2.5 H4.5 M-3 -6 Q2.5 -6 2.5 -2.5 Q2.5 1 -3 1 L3 6.5" stroke="#b07d00" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" fill="none"/>',
  // "₹0" drawn as strokes (no <text>)
  'zero': '<path d="M-12 -7 H-2 M-12 -3 H-2 M-10 -7 Q-3 -7 -3 -3 Q-3 1 -10 1 L-3 8" stroke="#e8494b" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" fill="none"/>'
      '<ellipse cx="6" cy="0.5" rx="4.2" ry="6.8" stroke="#e8494b" stroke-width="2.6" fill="none"/>',
  'burger': '<path d="M-11 -1 Q-11 -11 0 -11 Q11 -11 11 -1Z" fill="#f0a64a"/><circle cx="-4" cy="-7" r=".9" fill="#fff4d6"/><circle cx="3" cy="-8" r=".9" fill="#fff4d6"/><rect x="-12" y="-1" width="24" height="3" rx="1.5" fill="#7cc23c"/><rect x="-11" y="2" width="22" height="4" rx="2" fill="#8a4b2f"/><path d="M-11 6 H11 Q11 10 0 10 Q-11 10 -11 6Z" fill="#f0a64a"/>',
  'popcorn': '<circle cx="-5" cy="-5" r="4" fill="#fff1b8"/><circle cx="1" cy="-7" r="4.4" fill="#fffbe6"/><circle cx="6" cy="-4" r="3.8" fill="#fff1b8"/><path d="M-9 -2 L9 -2 L6 12 L-6 12Z" fill="#ffffff"/><path d="M-5 -2 L-4 12 M0 -2 V12 M5 -2 L4 12" stroke="#e8494b" stroke-width="2.4"/>',
  'plane': '<path d="M-12 3 L11 -3 Q15 -4 14 -1 L-9 6Z" fill="#3a85f2"/><path d="M-1 1 L-7 -9 L-3 -9 L5 -1Z" fill="#2f6fd0"/><path d="M-9 4 L-13 -2 L-11 -2 L-6 3Z" fill="#2f6fd0"/>',
  'bag': '<path d="M-9 -4 H9 L10 11 H-10Z" fill="#f2679b"/><path d="M-5 -4 Q-5 -11 0 -11 Q5 -11 5 -4" stroke="#c94d7f" stroke-width="2" fill="none"/>',
};

// stand on the ground left of the critter, drawn leftwards from (0,0)
const _groundItems = {
  // money bag with a drawn "₹", and a stack of coins
  'riches': '<path d="M-44 0 Q-52 -24 -36 -32 L-39 -38 H-25 L-28 -32 Q-12 -24 -20 0Z" fill="#c9a36b"/>'
      '<path d="M-37 -33 H-27" stroke="#8a6a3b" stroke-width="2.5" stroke-linecap="round"/>'
      '<path d="M-36 -19 H-28 M-36 -16 H-28 M-34.6 -19 Q-29.8 -19 -29.8 -16 Q-29.8 -13 -34.6 -13 L-29.4 -8.5" stroke="#8a6a3b" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" fill="none"/>'
      '<ellipse cx="-9" cy="-2.5" rx="7" ry="2.6" fill="#f6c945" stroke="#e0a800" stroke-width="1.4"/><ellipse cx="-9" cy="-6.5" rx="7" ry="2.6" fill="#f6c945" stroke="#e0a800" stroke-width="1.4"/>'
      '<ellipse cx="-8" cy="-10.5" rx="7" ry="2.6" fill="#f6c945" stroke="#e0a800" stroke-width="1.4"/><ellipse cx="-9" cy="-14.5" rx="7" ry="2.6" fill="#ffe27a" stroke="#e0a800" stroke-width="1.4"/>',
  'suitcase': '<rect x="-32" y="-24" width="32" height="22" rx="4" fill="#c9714e"/><path d="M-21 -24 V-29 H-11 V-24" stroke="#8a4b2f" stroke-width="2.5" fill="none"/><path d="M-32 -14 H0" stroke="#8a4b2f" stroke-width="2"/><rect x="-14" y="-21" width="8" height="5" rx="1" fill="#f6c945"/><circle cx="-27" cy="-1" r="2.5" fill="#555555"/><circle cx="-5" cy="-1" r="2.5" fill="#555555"/>',
  'bags': '<path d="M-38 -24 H-20 L-18 0 H-40Z" fill="#3a85f2"/><path d="M-34 -24 Q-34 -32 -29 -32 Q-24 -32 -24 -24" stroke="#2f6fd0" stroke-width="2" fill="none"/><path d="M-22 -18 H-2 L0 0 H-24Z" fill="#f2679b"/><path d="M-17 -18 Q-17 -26 -12 -26 Q-7 -26 -7 -18" stroke="#c94d7f" stroke-width="2" fill="none"/>'
      // "%" drawn, not text
      '<circle cx="-15" cy="-11" r="1.6" fill="#ffffff"/><circle cx="-9" cy="-5" r="1.6" fill="#ffffff"/><path d="M-8 -12 L-16 -4" stroke="#ffffff" stroke-width="1.6" stroke-linecap="round"/>',
};

/// Face parts in character space: the mood's mouth, plus brows / tear / cheeks.
String moodFace(MoodStyle m, CritterAnchors a) {
  // sized from the art's own mouth, but never small next to the eyes (the cute frens draw tiny mouths);
  // headWidth can under-measure on multi-part bodies, hence the 14 floor
  final w = math.max(a.mouthWidth * 1.1, math.max(a.eyeSpan * .4, a.eyeR * 2.2)).clamp(9.0, math.max(14.0, a.headWidth * .42)), h = w / 2, sw = n2(math.max(2, w * .13));
  final mouth = switch (m.mouth) {
    'grin' => '<path d="M${n2(-h)} ${n2(-w * .1)} Q0 ${n2(w * .75)} ${n2(h)} ${n2(-w * .1)}Z" fill="$_ink"/>'
        '<path d="M${n2(-h * .6)} ${n2(-w * .02)} H${n2(h * .6)}" stroke="#ffffff" stroke-width="${n2(w * .1)}" stroke-linecap="round"/>'
        '<ellipse cx="0" cy="${n2(w * .3)}" rx="${n2(w * .2)}" ry="${n2(w * .1)}" fill="#f0788e"/>',
    'smirk' => '<path d="M${n2(-h * .8)} ${n2(w * .06)} Q${n2(h * .15)} ${n2(w * .42)} ${n2(h * .85)} ${n2(-w * .16)}" stroke="$_ink" stroke-width="$sw" stroke-linecap="round" fill="none"/>'
        '<path d="M${n2(h * .7)} ${n2(-w * .26)} L${n2(h * .98)} ${n2(-w * .06)}" stroke="$_ink" stroke-width="${n2(math.max(2, w * .13) * .8)}" stroke-linecap="round"/>',
    'smile' => '<path d="M${n2(-h * .8)} 0 Q0 ${n2(w * .5)} ${n2(h * .8)} 0" stroke="$_ink" stroke-width="$sw" stroke-linecap="round" fill="none"/>',
    'frown' => '<path d="M${n2(-h * .75)} ${n2(w * .22)} Q0 ${n2(-w * .2)} ${n2(h * .75)} ${n2(w * .22)}" stroke="$_ink" stroke-width="$sw" stroke-linecap="round" fill="none"/>',
    'open' => '<ellipse cx="0" cy="${n2(w * .08)}" rx="${n2(w * .3)}" ry="${n2(w * .36)}" fill="$_ink"/><ellipse cx="0" cy="${n2(w * .28)}" rx="${n2(w * .18)}" ry="${n2(w * .1)}" fill="#f0788e"/>',
    _ => '<ellipse cx="0" cy="0" rx="${n2(w * .34)}" ry="${n2(w * .24)}" fill="$_ink"/>', // chew
  };
  final out = StringBuffer('<g transform="translate(${n2(a.mouthAt.dx)} ${n2(a.mouthAt.dy)})">$mouth</g>');
  final r = a.eyeR;
  if (m.brows) {
    for (final e in a.eyes) {
      final s = e.dx >= a.eye.dx ? 1 : -1; // worried brows: inner ends raised
      out.write('<path d="M${n2(e.dx + s * r * 1.6)} ${n2(e.dy - r * 2)} L${n2(e.dx - s * r * 1.2)} ${n2(e.dy - r * 3.2)}" '
          'stroke="$_ink" stroke-width="${n2(math.max(1.8, r * .7))}" stroke-linecap="round"/>');
    }
  }
  if (m.tear && a.eyes.isNotEmpty) {
    final e = a.eyes.last;
    out.write('<path d="M${n2(e.dx)} ${n2(e.dy + r * 1.4)} q${n2(-r * .9)} ${n2(r * 1.6)} 0 ${n2(r * 2.2)} q${n2(r * .9)} ${n2(-r * .6)} 0 ${n2(-r * 2.2)}Z" fill="#6cc4ff"/>');
  }
  if (m.cheeks) {
    for (final e in a.eyes) {
      out.write('<ellipse cx="${n2(e.dx + (e.dx - a.eye.dx) * .25)}" cy="${n2(e.dy + r * 2.3)}" rx="${n2(r * 1.5)}" ry="${n2(r * .85)}" fill="#ff7fa5" fill-opacity=".45"/>');
    }
  }
  return out.toString();
}

/// Where the bubble, cloud and wallet sit (character space), and [top] where floating glyphs start. [hatWorn] lifts the cloud clear of a hat.
({Offset bubble, Offset cloud, Offset wallet, Offset top}) moodSpots(CritterCharacter c, {required bool hatWorn}) {
  final a = c.anchors, lift = hatWorn ? a.hatWidth * .7 : 0.0;
  final head = math.min(a.hatAt.dy, a.top + 6); // above top-knots and antennae too, not just the hat seat
  return (bubble: Offset(c.width * .42 + 12, a.hatAt.dy - 12), cloud: Offset(a.eye.dx, head - 34 - lift), wallet: Offset(c.width / 2 + 2, a.bodyTop == null ? -c.height * .36 : (a.bodyTop! + a.bodyBottom!) / 2),   // v4: beside the body, not the legs
      top: Offset(a.eye.dx, head - 8 - lift));
}

/// Thought bubble, rain cloud and ground item in character space. They don't tilt with the body.
String moodExtras(MoodStyle m, CritterCharacter c, {required bool hatWorn}) {
  final spots = moodSpots(c, hatWorn: hatWorn), out = StringBuffer();
  if (m.bubble != null) {
    final b = spots.bubble;
    out.write('<g transform="translate(${n2(b.dx)} ${n2(b.dy)})">'
        '<circle cx="-14" cy="20" r="2.5" fill="#ffffff" stroke="#d7d3cc" stroke-width="1.5"/>'
        '<circle cx="-8" cy="13" r="3.5" fill="#ffffff" stroke="#d7d3cc" stroke-width="1.5"/>'
        '<circle r="17" fill="#ffffff" stroke="#d7d3cc" stroke-width="2"/>${_icons[m.bubble]}</g>');
  }
  if (m.cloud) {
    final k = spots.cloud;
    out.write('<g transform="translate(${n2(k.dx)} ${n2(k.dy)})">'
        '<circle cx="-10" cy="2" r="8" fill="#9aa3ad"/><circle cx="0" cy="-3" r="10" fill="#9aa3ad"/><circle cx="11" cy="2" r="8" fill="#9aa3ad"/>'
        '<rect x="-18" y="2" width="37" height="8" rx="4" fill="#9aa3ad"/>'
        // a few frozen raindrops; the animation layer can make them fall
        '<path d="M-9 14 v5 M1 17 v5 M10 13 v5" stroke="#7fb6e8" stroke-width="2" stroke-linecap="round"/></g>');
  }
  if (m.wallet) {
    // open wallet held upside down at the right side, ~36 wide; the animation layer shakes it and lets moths out
    final w = spots.wallet;
    out.write('<g transform="translate(${n2(w.dx)} ${n2(w.dy)}) rotate(168)">'
        '<path d="M-18 0 L-16 -15 Q0 -20 16 -15 L18 0Z" fill="#8a5a3a"/><path d="M-18 0 H18 L16 15 Q0 19 -16 15Z" fill="#a8703f"/>'
        '<path d="M-13 0 H13" stroke="#5e3a22" stroke-width="1.6" stroke-linecap="round"/><path d="M-12 -10 H12 L11 -4 H-11Z" fill="#c99a6b"/>'
        '<rect x="9" y="4" width="8" height="6" rx="2" fill="#f6c945"/></g>');
  }
  if (m.ground != null) out.write('<g transform="translate(${n2(-c.width / 2 + 2)} 0)">${_groundItems[m.ground]}</g>');
  return out.toString();
}
