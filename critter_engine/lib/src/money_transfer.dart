import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'catalog.dart';
import 'composer.dart';
import 'critter_view.dart';
import 'mood.dart';
import 'spec.dart';

/// Two critters side by side; banknotes stream from [from] to [to] like the papers in the
/// Windows XP copy dialog, then both turn happy.
///
/// Timeline: the sender winds up (leans back, lunges), notes fly one after another along the
/// same arc while flipping end over end, the receiver squashes on every catch, then both
/// switch to the happy mood and the receiver hops. Before that both show their normal face
/// (any `mood` in the specs is ignored until the money has landed).
///
/// Plays once on mount. To play again, give it a new [Key]. With the OS "reduce motion"
/// setting on, it jumps straight to the end state.
class MoneyTransferView extends StatefulWidget {
  const MoneyTransferView({
    super.key,
    required this.catalog,
    required this.from,
    required this.to,
    required this.amount,
    this.currencySymbol = '₹',
    this.noteCount,
    this.noteInterval = const Duration(milliseconds: 190),
    this.flightDuration = const Duration(milliseconds: 1150),
    this.onNoteLanded,
    this.onComplete,
  });

  final CritterCatalog catalog;
  final CritterSpec from, to;

  /// Shown as `-₹5,000` / `+₹5,000` (Indian digit grouping) and sets how many notes fly.
  final num amount;
  final String currencySymbol;

  /// Notes in the stream; default grows with the amount (5 for small sums, up to 16).
  final int? noteCount;

  /// Gap between notes, and how long each one is in the air.
  final Duration noteInterval, flightDuration;

  /// Called after each catch with (landed, total), e.g. for a haptic tick.
  final void Function(int landed, int total)? onNoteLanded;

  /// Called once the receiver has finished celebrating.
  final VoidCallback? onComplete;

  @override
  State<MoneyTransferView> createState() => _MoneyTransferViewState();
}

// phase lengths (ms)
const _windBack = 380, _lunge = 160, _windUp = _windBack + _lunge, _hold = 1300, _squash = 220, _hop = 600;

class _MoneyTransferViewState extends State<MoneyTransferView> with SingleTickerProviderStateMixin {
  late final int _n = widget.noteCount?.clamp(1, 60) ?? (math.log(widget.amount.abs() + 1) / math.ln10 * 3).round().clamp(5, 16);
  late final int _interval = widget.noteInterval.inMilliseconds, _flight = widget.flightDuration.inMilliseconds;
  late final int _lastLanding = _windUp + (_n - 1) * _interval + _flight;
  late final AnimationController _c = AnimationController(vsync: this, duration: Duration(milliseconds: _lastLanding + _hold))
    ..addListener(_onTick)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onComplete?.call();
    });
  int _landed = 0;
  bool _started = false;

  double get _ms => _c.value * _c.duration!.inMilliseconds;
  int _landingOf(int k) => _windUp + k * _interval + _flight;

  void _onTick() {
    final landed = List.generate(_n, _landingOf).where((t) => t <= _ms).length;
    while (_landed < landed) {
      _landed++; // not inside ?.call(): its arguments are skipped when there's no callback
      widget.onNoteLanded?.call(_landed, _n);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _c.value = 1; // reduce motion: straight to the happy ending
    } else {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final from = compose(widget.catalog, widget.from.copyWith(clearMood: true)), to = compose(widget.catalog, widget.to.copyWith(clearMood: true));
    if (from == null || to == null) return const SizedBox.shrink();
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth, cw = w / 2, vb = CritterComposition.viewBox, s = cw / vb.width, ch = cw * vb.height / vb.width;
      final h = ch + cw * .45, footY = h - vb.bottom * s;
      final a = (x: cw / 2, wi: from.character.width * from.scale * s, hi: from.character.height * from.scale * s);
      final b = (x: w - cw / 2, wi: to.character.width * to.scale * s, hi: to.character.height * to.scale * s);
      final start = Offset(a.x + a.wi * .42, footY - a.hi * .55), end = Offset(b.x - b.wi * .1, footY - b.hi * .5);
      final money = '${widget.currencySymbol}${formatIndian(widget.amount)}';
      return AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _ms, done = t >= _lastLanding;
          // sender: lean back, then lunge forward with a little hop
          final lean = t < _windBack ? -9 * t / _windBack : t < _windUp ? 7.0 : 0.0;
          final senderHop = t >= _windBack && t < _windUp ? math.sin(math.pi * (t - _windBack) / _lunge) * 10 * s : 0.0;
          // receiver: squash on every catch, hop when it's all in
          var c = 0.0;
          for (var k = 0; k < _n; k++) {
            final dt = t - _landingOf(k);
            if (dt >= 0 && dt < _squash) c = math.max(c, 1 - dt / _squash);
          }
          final hopP = (t - _lastLanding) / _hop, receiverHop = hopP > 0 && hopP < 1 ? math.sin(math.pi * hopP) * 26 * s : 0.0;
          CritterSpec face(CritterSpec spec) => done ? spec.copyWith(mood: CritterMood.happy) : spec.copyWith(clearMood: true);
          return SizedBox(
            width: w,
            height: h,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(left: 0, bottom: 0, width: cw, child: Transform.translate(
                offset: Offset(0, -senderHop),
                child: Transform.rotate(angle: lean * math.pi / 180, alignment: Alignment.bottomCenter,
                    child: CritterView(catalog: widget.catalog, spec: face(widget.from))),
              )),
              Positioned(right: 0, bottom: 0, width: cw, child: Transform.translate(
                offset: Offset(0, -receiverHop),
                child: Transform(alignment: Alignment.bottomCenter, transform: Matrix4.diagonal3Values(1 + .09 * c, 1 - .12 * c, 1),
                    child: CritterView(catalog: widget.catalog, spec: face(widget.to))),
              )),
              Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _NotesPainter(
                  t: t, n: _n, interval: _interval, flight: _flight, start: start, end: end, arc: 95 * s, unit: s)))),
              // -amount over the sender while it winds up and throws, +amount over the receiver at the end
              _label(context, '-$money', const Color(0xffe8494b), a.x, footY - a.hi - 34 * s, t, 0, 1900, s),
              _label(context, '+$money', const Color(0xff2f9e44), b.x, footY - b.hi - 40 * s, t, _lastLanding.toDouble(), _hold + 1000, s, big: true),
            ]),
          );
        },
      );
    });
  }

  Widget _label(BuildContext context, String text, Color color, double x, double y, double t, double from, int life, double s, {bool big = false}) {
    final p = (t - from) / life;
    if (p < 0) return const SizedBox.shrink();
    final shown = p >= 1 ? (big ? 1.0 : 0.0) : p < .15 ? p / .15 : p > .8 && !big ? (1 - p) / .2 : 1.0; // the +amount stays
    return Positioned(
      left: x - 150, width: 300, top: y - math.min(p, 1) * 20 * s,
      child: IgnorePointer(child: Opacity(opacity: shown.clamp(0, 1),
          child: Text(text, textAlign: TextAlign.center, maxLines: 1,
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: (big ? 22 : 18) * s * 2.2)))),
    );
  }
}

/// The note stream: every note follows the same arc at the same pace, flipping end over end
/// (scaleY = cos(turn); the back shows while it's negative), nose up then down, a bit bigger mid-flight.
class _NotesPainter extends CustomPainter {
  _NotesPainter({required this.t, required this.n, required this.interval, required this.flight,
      required this.start, required this.end, required this.arc, required this.unit});
  final double t, arc, unit;
  final int n, interval, flight;
  final Offset start, end;

  static const _turns = 1.5;
  static final _symbol = TextPainter(
    text: const TextSpan(text: '₹', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: Color(0xff2f6b2b), height: 1)),
    textDirection: TextDirection.ltr,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final dir = (end.dx - start.dx).sign;
    for (var k = 0; k < n; k++) {
      final u = (t - _windUp - k * interval) / flight;
      if (u <= 0 || u >= 1) continue;
      final x = start.dx + (end.dx - start.dx) * u, y = start.dy + (end.dy - start.dy) * u - arc * 4 * u * (1 - u);
      final turn = 2 * math.pi * _turns * u, flip = math.cos(turn), lift = 1 + .18 * math.sin(math.pi * u);
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(dir * (-25 + 50 * u) * math.pi / 180)
        ..skew(math.tan(12 * math.sin(turn) * math.pi / 180), 0)
        ..scale(unit * lift, unit * lift * math.max(.08, flip.abs()));
      flip >= 0 ? _front(canvas) : _back(canvas);
      canvas.restore();
    }
  }

  void _front(Canvas c) {
    final ink = Paint()..color = const Color(0xff4e9a49)..style = PaintingStyle.stroke;
    c.drawRRect(RRect.fromLTRBR(-16, -9, 16, 9, const Radius.circular(2.5)), Paint()..color = const Color(0xff8fd18a));
    c.drawRRect(RRect.fromLTRBR(-16, -9, 16, 9, const Radius.circular(2.5)), ink..strokeWidth = 1.5);
    c.drawRRect(RRect.fromLTRBR(-12.5, -5.5, 12.5, 5.5, const Radius.circular(1.5)), Paint()..color = const Color(0x994e9a49)..style = PaintingStyle.stroke..strokeWidth = 1);
    c.drawCircle(Offset.zero, 4.2, Paint()..color = const Color(0xffc8ecc4));
    c.drawCircle(Offset.zero, 4.2, ink..strokeWidth = 1.2);
    _symbol.paint(c, Offset(-_symbol.width / 2, -_symbol.height / 2));
  }

  void _back(Canvas c) {
    final ink = Paint()..color = const Color(0xff3f8a3a)..style = PaintingStyle.stroke..strokeWidth = 1.5;
    c.drawRRect(RRect.fromLTRBR(-16, -9, 16, 9, const Radius.circular(2.5)), Paint()..color = const Color(0xff6fb469));
    c.drawRRect(RRect.fromLTRBR(-16, -9, 16, 9, const Radius.circular(2.5)), ink);
    final lines = Paint()..color = const Color(0x8c3f8a3a)..strokeWidth = 1;
    for (final (y, x1) in const [(-3.0, 11.0), (1.0, 11.0), (5.0, 4.0)]) {
      c.drawLine(Offset(-11, y), Offset(x1, y), lines);
    }
  }

  @override
  bool shouldRepaint(_NotesPainter old) => old.t != t || old.start != start || old.end != end;
}

/// 1234567.5 -> "12,34,567.50" (Indian digit grouping; decimals only when there are any).
String formatIndian(num amount) {
  final neg = amount < 0, total = (amount.abs() * 100).round(), whole = total ~/ 100, cents = total % 100;
  var digits = '$whole';
  if (digits.length > 3) {
    final head = digits.substring(0, digits.length - 3), tail = digits.substring(digits.length - 3);
    final groups = <String>[];
    for (var i = head.length; i > 0; i -= 2) {
      groups.insert(0, head.substring(math.max(0, i - 2), i));
    }
    digits = '${groups.join(',')},$tail';
  }
  return '${neg ? '-' : ''}$digits${cents > 0 ? '.${'$cents'.padLeft(2, '0')}' : ''}';
}
