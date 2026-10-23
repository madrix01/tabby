import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'catalog.dart';
import 'item.dart';

// Where any item goes on any character, from the character's anchors. Mirrors attachments() / lenses()
// in compiler/compile.mjs; the parity test keeps the two in step.

String _n(double v) {
  final r = (v * 100).round() / 100;
  return r == r.truncateToDouble() ? '${r.toInt()}' : '$r';
}

/// Lands the item's [m] on [at], tilted by [angle] degrees and scaled by [k].
String place(Offset at, Offset m, double k, [double angle = 0]) =>
    'translate(${_n(at.dx)} ${_n(at.dy)}) rotate(${_n(angle)}) scale(${(k * 10000).round() / 10000}) translate(${_n(-m.dx)} ${_n(-m.dy)})';

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
      return '<g transform="translate(${_n(a.eye.dx)} ${_n(a.eye.dy)}) rotate(${_n(a.eyeAngle)})">${lenses(a, it)}</g>';
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
  if (it.strap != null) out.write('<path d="M${_n(-hw)} 0 H${_n(hw)}" stroke="${it.strap}" stroke-width="${_n(r * .4)}" stroke-linecap="round"/>');
  if (half > 0) out.write('<path d="M${_n(-half + r * .9)} 0 H${_n(half - r * .9)}" stroke="${it.bridge}" stroke-width="${_n(r * .26)}" stroke-linecap="round"/>');
  for (final x in half > 0 ? [-half, half] : [0.0]) {
    out.write('<g transform="translate(${_n(x)} 0) scale(${(r / 10 * 10000).round() / 10000})">${it.lens}</g>');
  }
  return out.toString();
}
