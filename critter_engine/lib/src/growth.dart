import 'dart:math' as math;

import 'catalog.dart';

// Same curve as growth.js: level = 1 + floor((xp / base)^(1/pow)), xp(level) = base * (level-1)^pow.
const _base = 30.0, _pow = 1.5, _tau = 400.0;

int levelOf(double xp) => 1 + (math.pow(math.max(0, xp) / _base, 1 / _pow) + 1e-9).floor();
double xpForLevel(int level) => _base * math.pow(math.max(0, level - 1), _pow);

/// Scale for [form] at [xp]: grows from minScale to maxScale between this form's unlock
/// and the next one (the final form eases towards maxScale). No xp -> minScale.
double formScale(CritterSpecies species, int form, double? xp) {
  final f = species.forms[form];
  if (xp == null) return f.minScale;
  final lo = xpForLevel(f.atLevel);
  final next = form + 1 < species.forms.length ? species.forms[form + 1] : null;
  final q = next != null ? (xp - lo) / (xpForLevel(next.atLevel) - lo) : 1 - math.exp(-(xp - lo) / _tau);
  return f.minScale + (f.maxScale - f.minScale) * q.clamp(0.0, 1.0);
}
