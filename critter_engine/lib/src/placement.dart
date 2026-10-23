import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'catalog.dart';
import 'item.dart';

// Where any item goes on any character, from the character's anchors. Mirrors attachments() / lenses()
// in compiler/compile.mjs; the parity test keeps the two in step.

/// Number formatting shared by everything that writes SVG: at most 2 decimals, no trailing ".0".
String n2(double v) {
  final r = (v * 100).round() / 100;
  return r == r.truncateToDouble() ? '${r.toInt()}' : '$r';
}

/// Lands the item's [m] on [at], tilted by [angle] degrees and scaled by [k].
String place(Offset at, Offset m, double k, [double angle = 0]) =>
    'translate(${n2(at.dx)} ${n2(at.dy)}) rotate(${n2(angle)}) scale(${(k * 10000).round() / 10000}) translate(${n2(-m.dx)} ${n2(-m.dy)})';

/// The item as markup in character space, or '' when it doesn't apply.
String placeItem(CritterAnchors a, CritterItem it) {
  switch (it.slot) {
    case 'hat':
      return '<g transform="${place(a.hatAt, it.anchor, a.hatWidth / 100, a.eyeAngle)}">${it.svg}</g>';
    case 'neck':
      final k = (a.neckWidth * it.fit).clamp(18, 70) / 100;
      final at = Offset(a.neck.dx, math.min(a.neck.dy, -2 - it.height * k)); // lifted if it would hang below the feet
      return '<g transform="${place(at, it.anchor, k)}">${it.svg}</g>';
    case 'prop':
      return '<g transform="${place(a.side, it.anchor, .8)}">${it.svg}</g>';
    case 'eyes':
      return '<g transform="translate(${n2(a.eye.dx)} ${n2(a.eye.dy)}) rotate(${n2(a.eyeAngle)})">${lenses(a, it)}</g>';
  }
  return '';
}

/// One lens per eye, sized from the eye (never so big the two overlap), a bridge between them,
/// and an optional strap across the head. Centred on the eye midpoint.
String lenses(CritterAnchors a, CritterItem it) {
  final half = a.eyeSpan / 2;
  final r = (a.eyeR * 2.3 * it.grow).clamp(5.0, half > 0 ? half * .9 : 99.0);
  final hw = math.min(a.headWidth / 2 + 2, half + r * 2.4); // strap wraps the head, not a long body
  final out = StringBuffer();
  if (it.strap != null) out.write('<path d="M${n2(-hw)} 0 H${n2(hw)}" stroke="${it.strap}" stroke-width="${n2(r * .4)}" stroke-linecap="round"/>');
  if (half > 0) out.write('<path d="M${n2(-half + r * .9)} 0 H${n2(half - r * .9)}" stroke="${it.bridge}" stroke-width="${n2(r * .26)}" stroke-linecap="round"/>');
  for (final x in half > 0 ? [-half, half] : [0.0]) {
    out.write('<g transform="translate(${n2(x)} 0) scale(${(r / 10 * 10000).round() / 10000})">${x > 0 && it.lensRight != null ? it.lensRight : it.lens}</g>');
  }
  return out.toString();
}
