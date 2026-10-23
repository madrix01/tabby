import 'package:flutter/foundation.dart';

/// Tuning for [CritterLook.glow]. Knobs are multipliers on the base effect (0 = off); the defaults are the house look,
/// so `{"halo": 0}` keeps the shading but drops the halo, `{"shading": 0}` gives flat colour with a halo, etc.
///
/// ```json
/// "look": "glow",
/// "glow": { "halo": 0.35, "blur": 0.8, "brightness": 1, "shading": 1.5, "gloss": 0.45, "shadow": 1.5, "color": "#ff8a3d" }
/// ```
/// Values are clamped to sane ranges; anything missing keeps its default.
@immutable
class CritterGlow {
  const CritterGlow({
    this.halo = .35,
    this.blur = .8,
    this.brightness = 1,
    this.shading = 1.5,
    this.gloss = .45,
    this.shadow = 1.5,
    this.color,
  });

  /// Halo opacity, 0..1.
  final double halo;

  /// Halo size: multiplies the blur radius (3% of the widget width at 1), 0..3.
  final double blur;

  /// How much brighter than the critter the halo is, 1..2. Ignored when [color] is set.
  final double brightness;

  /// Light-to-dark body shading strength, 0..1.5.
  final double shading;

  /// Glossy highlight strength, 0..1.5.
  final double gloss;

  /// Contact shadow under the feet, 0..1.5.
  final double shadow;

  /// Paint the halo in one colour (#rrggbb) instead of the critter's own colours, e.g. a warm stage light.
  final String? color;

  bool get hasHalo => halo > 0 && blur > 0;

  factory CritterGlow.fromJson(Map<String, dynamic> j) {
    double v(String k, double def, double lo, double hi) => ((j[k] as num?)?.toDouble() ?? def).clamp(lo, hi);
    final c = j['color'];
    return CritterGlow(
      halo: v('halo', .35, 0, 1),
      blur: v('blur', .8, 0, 3),
      brightness: v('brightness', 1, 1, 2),
      shading: v('shading', 1.5, 0, 1.5),
      gloss: v('gloss', .45, 0, 1.5),
      shadow: v('shadow', 1.5, 0, 1.5),
      color: c is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(c) ? c : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'halo': halo, 'blur': blur, 'brightness': brightness,
        'shading': shading, 'gloss': gloss, 'shadow': shadow, 'color': ?color,
      };

  @override
  bool operator ==(Object other) =>
      other is CritterGlow && other.halo == halo && other.blur == blur && other.brightness == brightness &&
      other.shading == shading && other.gloss == gloss && other.shadow == shadow && other.color == color;

  @override
  int get hashCode => Object.hash(halo, blur, brightness, shading, gloss, shadow, color);
}
