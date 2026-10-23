import 'dart:math' as math;

import 'package:flutter/animation.dart' show Curves;
import 'package:flutter/painting.dart';

import 'catalog.dart';
import 'mood.dart';

/// The body's pose at one instant, in viewBox units around the feet: lifted by [by] (negative = up),
/// tilted by [lean] degrees, stretched by [sx] / [sy]. Same maths as the v3/v6 prototypes standing still.
typedef CritterPose = ({double by, double lean, double sx, double sy});

/// Breathing for every critter, plus the mood's body language. [t] is seconds since the animation started,
/// [phase] keeps critters side by side from breathing in step.
CritterPose idlePose(MoodMotion? m, double t, {double phase = 0}) {
  const tau = 2 * math.pi;
  final br = math.sin(tau * t / 3 + phase);
  var by = 0.0, lean = 0.0, sx = 1 - .012 * br, sy = 1 + .025 * br;
  if (m != null) {
    final ph = t * m.freq, step = math.sin(tau * ph).abs(), land = math.pow(1 - step, 6) * m.squash; // squash right at touch-down
    by -= m.jump * step;
    lean += m.sway * math.sin(tau * ph) + m.lean;
    sy *= 1 - land + m.squash * .5 * step;
    sx *= 1 + land * .8;
    if (m.slump > 0) {
      sy *= 1 - m.slump;
      sx *= 1 + m.slump * .6;
    }
  }
  return (by: by, lean: lean, sx: sx, sy: sy);
}

Color _hex(String s) => Color(0xff000000 | int.parse(s.substring(1), radix: 16)); // #rrggbb

enum _Kind { glyph, rain, dust, moth }

class _Particle {
  _Particle(this.kind, this.at, this.born, {this.dx = 0, this.text = '', this.color = const Color(0xff000000), this.r = 0});
  final _Kind kind;
  final Offset at; // viewBox units
  final double born, dx, r;
  final String text;
  final Color color;

  // delay before showing up, then how long it lives (seconds), as in the prototype's CSS animations
  double get delay => kind == _Kind.dust || kind == _Kind.moth ? .9 : 0;
  double get life => switch (kind) { _Kind.glyph => 1.6, _Kind.rain => .7, _Kind.dust => .9, _Kind.moth => 2.4 };
  bool deadAt(double t) => t > born + delay + life;
}

/// The mood's floating effects: glyphs rising off the head, rain from the cloud, dust and moths out of the wallet.
/// Call [tick] every frame with the time in seconds; paint with [MoodFxPainter].
class MoodParticles {
  MoodParticles(this.mood, this.character, {required this.scale, required this.hatWorn, math.Random? random}) : _rnd = random ?? math.Random();

  final MoodStyle mood;
  final CritterCharacter character;
  final double scale;
  final bool hatWorn;
  final math.Random _rnd;
  final List<_Particle> _live = [];
  double _last = 0, _clock = 0;

  bool get isEmpty => _live.isEmpty;

  void tick(double t) {
    _clock += t - _last;
    _last = t;
    final every = mood.fx.every.inMicroseconds / 1e6;
    if (_clock >= every) {
      _clock = 0;
      _spawn(t);
    }
    _live.removeWhere((p) => p.deadAt(t));
  }

  void _spawn(double t) {
    final fx = mood.fx, spots = moodSpots(character, hatWorn: hatWorn);
    Offset at(Offset charSpace, [double dx = 0, double dy = 0]) => Offset(charSpace.dx * scale + dx, charSpace.dy * scale + dy);
    if (fx.rain) {
      _live.add(_Particle(_Kind.rain, at(spots.cloud, (_rnd.nextDouble() * 28 - 14) * scale, 10 * scale), t));
      return;
    }
    if (fx.wallet) {
      final w = at(spots.wallet, 0, 10 * scale);
      for (var d = 0; d < 3; d++) {
        _live.add(_Particle(_Kind.dust, w + Offset(_rnd.nextDouble() * 16 - 8, 0), t + d * .08, r: 1.2 + _rnd.nextDouble() * 1.6));
      }
      if (_rnd.nextDouble() < .65) {
        _live.add(_Particle(_Kind.moth, w + const Offset(0, -4), t, dx: _rnd.nextDouble() * 36 - 18));
        return;
      }
    }
    if (fx.glyphs.isEmpty) return;
    final k = _rnd.nextInt(fx.glyphs.length);
    _live.add(_Particle(_Kind.glyph, at(spots.top, (_rnd.nextDouble() * .6 - .3) * character.width * scale), t,
        dx: _rnd.nextDouble() * 30 - 15, text: fx.glyphs[k], color: _hex(fx.colors[k % fx.colors.length])));
  }

  /// Paints the live particles; [toPixels] maps viewBox units to the canvas.
  void paint(Canvas canvas, double t, Offset Function(Offset) toPixels, double px) {
    for (final p in _live) {
      final age = t - p.born - p.delay;
      if (age < 0) continue;
      final q = (age / p.life).clamp(0.0, 1.0);
      switch (p.kind) {
        case _Kind.glyph:
          final e = Curves.easeOut.transform(q), o = q < .15 ? q / .15 : 1 - (q - .15) / .85;
          final tp = TextPainter(
            text: TextSpan(text: p.text, style: TextStyle(fontSize: 15 * px * (.6 + .5 * e), fontWeight: FontWeight.w800, color: p.color.withValues(alpha: o.clamp(0, 1)))),
            textDirection: TextDirection.ltr,
          )..layout();
          final c = toPixels(p.at + Offset(p.dx * e, -55 * e));
          tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
        case _Kind.rain:
          final a = toPixels(p.at + Offset(0, 34 * q));
          canvas.drawLine(a, a + Offset(0, 6 * px),
              Paint()..color = const Color(0xff7fb6e8).withValues(alpha: 1 - q)..strokeWidth = 2 * px..strokeCap = StrokeCap.round);
        case _Kind.dust:
          final e = Curves.easeIn.transform(q);
          canvas.drawCircle(toPixels(p.at + Offset(0, 26 * e)), p.r * px, Paint()..color = const Color(0xffb9b2a6).withValues(alpha: 1 - q));
        case _Kind.moth:
          _paintMoth(canvas, p, age, q, toPixels, px);
      }
    }
  }

  // keyframes: 0% (0,0) .6 hidden · 10% shown · 40% (dx,-28) 1 · 70% (-dx/2,-54) 1 · 100% (dx,-84) .9 hidden
  void _paintMoth(Canvas canvas, _Particle p, double age, double q, Offset Function(Offset) toPixels, double px) {
    double lerp(double a, double b, double f) => a + (b - a) * f;
    final (Offset off, double s) = q < .4
        ? (Offset(p.dx * q / .4, -28 * q / .4), lerp(.6, 1, q / .4))
        : q < .7
            ? (Offset(lerp(p.dx, -p.dx * .5, (q - .4) / .3), lerp(-28, -54, (q - .4) / .3)), 1.0)
            : (Offset(lerp(-p.dx * .5, p.dx, (q - .7) / .3), lerp(-54, -84, (q - .7) / .3)), lerp(1, .9, (q - .7) / .3));
    final o = q < .1 ? q / .1 : q < .7 ? 1.0 : 1 - (q - .7) / .3;
    final flap = 1 - .75 * (((age / .12) % 2) < 1 ? (age / .12) % 1 : 1 - (age / .12) % 1); // wings 1 -> .25 -> 1
    final c = toPixels(p.at + off), k = s * px;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(k);
    final wing = Paint()..color = const Color(0xffcfc8bc).withValues(alpha: o);
    for (final x in [-4.5, 4.5]) {
      canvas.drawOval(Rect.fromCenter(center: Offset(x, 0), width: 10, height: 7.2 * flap), wing);
    }
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 3.2, height: 6.8), Paint()..color = const Color(0xff8d877d).withValues(alpha: o));
    canvas.restore();
  }
}
