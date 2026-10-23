import 'dart:math' as math;
import 'dart:ui' show ImageFilter, TileMode;

import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'catalog.dart';
import 'composer.dart';
import 'glow.dart';
import 'idle_animation.dart';
import 'mood.dart';
import 'spec.dart';

/// Draws one critter from a [spec].
///
/// Fills the width it is given at a fixed 4:3 aspect, feet near the bottom edge. Every critter shares
/// the same frame, so an evolved form renders bigger than a baby one at the same widget size.
/// Recomposes only when [spec] or [look] changes.
///
/// [look] / [glow] override the spec's. [CritterLook.glow] adds shading, gloss, a contact shadow and a colour
/// halo (a blurred copy of the critter behind it), each tunable through [CritterGlow]; it reads best on a dark background.
///
/// [animate] brings it to life: it breathes and blinks, and a mood adds its body language (happy bounces, sad slumps,
/// rich struts) and its floating effects (sparkles, notes, ₹ signs, rain from the cloud, moths out of an empty wallet).
/// Off by default so still renders, long lists and goldens stay cheap. The OS reduce-motion setting turns it off.
class CritterView extends StatefulWidget {
  const CritterView({super.key, required this.catalog, required this.spec, this.look, this.glow, this.animate = false});

  final CritterCatalog catalog;
  final CritterSpec spec;
  final CritterLook? look;
  final CritterGlow? glow;
  final bool animate;

  @override
  State<CritterView> createState() => _CritterViewState();
}

class _CritterViewState extends State<CritterView> with SingleTickerProviderStateMixin {
  late CritterComposition? _comp = _compose();
  late final Ticker _ticker = createTicker(_tick);
  final _clock = ValueNotifier<double>(0); // seconds since the animation started
  final _rnd = math.Random();
  late final double _phase = _rnd.nextDouble() * 2 * math.pi;
  MoodParticles? _fx;
  double _nextBlink = 0;

  CritterComposition? _compose() => compose(widget.catalog, widget.spec, look: widget.look, glow: widget.glow);

  bool get _moving => widget.animate && _comp != null && !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  MoodStyle? get _mood => widget.spec.mood == null ? null : moodStyles[widget.spec.mood];

  void _resetFx() {
    final comp = _comp, mood = _mood;
    _fx = comp == null || mood == null ? null : MoodParticles(mood, comp.character, scale: comp.scale, hatWorn: widget.spec.attachments.hat != null, random: _rnd);
  }

  void _syncTicker() {
    if (_moving && !_ticker.isActive) {
      _resetFx();
      _ticker.start();
    } else if (!_moving && _ticker.isActive) {
      _ticker.stop();
      _clock.value = 0;
    }
  }

  void _tick(Duration elapsed) {
    final t = elapsed.inMicroseconds / 1e6;
    _fx?.tick(t);
    _clock.value = t;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTicker();
  }

  @override
  void didUpdateWidget(CritterView old) {
    super.didUpdateWidget(old);
    if (old.spec != widget.spec || old.catalog != widget.catalog || old.look != widget.look || old.glow != widget.glow) {
      _comp = _compose();
      _resetFx();
    }
    _syncTicker();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _clock.dispose();
    super.dispose();
  }

  // eyes shut for 150 ms every 0.6-4.1 s
  bool _blinking(double t) {
    if (t > _nextBlink + .15) _nextBlink = t + .6 + _rnd.nextDouble() * 3.5;
    return t >= _nextBlink && t <= _nextBlink + .15;
  }

  @override
  Widget build(BuildContext context) {
    final vb = CritterComposition.viewBox;
    final comp = _comp;
    if (comp == null) return AspectRatio(aspectRatio: vb.width / vb.height);
    Widget layer(String svg) => SvgPicture.string(svg, fit: BoxFit.contain);
    final base = layer(comp.base), eyes = layer(comp.eyes), overlay = layer(comp.overlay), prop = comp.prop == null ? null : layer(comp.prop!);
    final moving = _moving;
    return AspectRatio(
      aspectRatio: vb.width / vb.height,
      child: LayoutBuilder(builder: (context, box) {
        final px = box.maxWidth / vb.width, feet = Offset(-vb.left * px, -vb.top * px);
        final halo = comp.look == CritterLook.glow && comp.glow.hasHalo
            // halo: the critter itself, blurred and brightened (or tinted), behind the sharp copy
            ? ImageFiltered(
                imageFilter: ImageFilter.blur(
                    sigmaX: box.maxWidth * .03 * comp.glow.blur, sigmaY: box.maxWidth * .03 * comp.glow.blur, tileMode: TileMode.decal),
                child: ColorFiltered(
                  colorFilter: ColorFilter.matrix(_haloMatrix(comp.glow)),
                  child: Stack(fit: StackFit.expand, children: [base, overlay]),
                ),
              )
            : null;
        if (!moving) return Stack(fit: StackFit.expand, children: [?halo, base, eyes, overlay, ?prop]);
        final eyeY = feet.dy + comp.eyeLineY * px;
        return ListenableBuilder(
          listenable: _clock,
          builder: (context, _) {
            final t = _clock.value, pose = idlePose(_mood?.motion, t, phase: _phase);
            // body layers move together around the feet; the prop layer (bubble, cloud, ground items) stays put
            final body = Matrix4.translationValues(feet.dx, feet.dy + pose.by * comp.scale * px, 0)
              ..rotateZ(pose.lean * math.pi / 180)
              ..scaleByDouble(pose.sx, pose.sy, 1, 1)
              ..translateByDouble(-feet.dx, -feet.dy, 0, 1);
            final blink = _blinking(t) ? (Matrix4.translationValues(0, eyeY, 0)..scaleByDouble(1, .1, 1, 1)..translateByDouble(0, -eyeY, 0, 1)) : null;
            return Stack(fit: StackFit.expand, clipBehavior: Clip.none, children: [
              Transform(
                transform: body,
                child: Stack(fit: StackFit.expand, children: [?halo, base, blink == null ? eyes : Transform(transform: blink, child: eyes), overlay]),
              ),
              ?prop,
              if (_fx != null) CustomPaint(painter: _FxPainter(_fx!, t, feet, px)),
            ]);
          },
        );
      }),
    );
  }
}

class _FxPainter extends CustomPainter {
  _FxPainter(this.fx, this.t, this.feet, this.px);
  final MoodParticles fx;
  final double t, px;
  final Offset feet;

  @override
  void paint(Canvas canvas, Size size) => fx.paint(canvas, t, (v) => feet + v * px, px);

  @override
  bool shouldRepaint(_FxPainter old) => true; // a new frame every tick
}

/// Brighten the critter's own colours, or paint everything in [CritterGlow.color]; alpha scaled by halo.
List<double> _haloMatrix(CritterGlow g) {
  final c = g.color;
  if (c != null) {
    final v = int.parse(c.substring(1), radix: 16);
    final r = ((v >> 16) & 255).toDouble(), gr = ((v >> 8) & 255).toDouble(), b = (v & 255).toDouble();
    return [0, 0, 0, 0, r, 0, 0, 0, 0, gr, 0, 0, 0, 0, b, 0, 0, 0, g.halo, 0];
  }
  final k = g.brightness, lift = (k - 1) * 51; // 1.35 -> +18, as before
  return [k, 0, 0, 0, lift, 0, k, 0, 0, lift, 0, 0, k, 0, lift, 0, 0, 0, g.halo, 0];
}
