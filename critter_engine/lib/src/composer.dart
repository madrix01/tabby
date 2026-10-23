import 'dart:ui' show Rect;

import 'catalog.dart';
import 'growth.dart';
import 'item.dart';
import 'placement.dart';
import 'spec.dart';

/// One critter as stacked SVG layers that all share [viewBox], so they line up when
/// drawn on top of each other. Split so the animation layer can move them separately:
///
/// * [base]    skin + mouth
/// * [eyes]    the blinking eyes (scale Y around [eyeLineY])
/// * [overlay] neck item, eyewear, hat (above the eyes, moves with the body)
/// * [prop]    ground prop (not tilted with the body); null when empty
class CritterComposition {
  const CritterComposition({
    required this.base,
    required this.eyes,
    required this.overlay,
    required this.prop,
    required this.character,
    required this.form,
    required this.scale,
    required this.eyeLineY,
    required this.look,
  });

  /// Shared by every critter so sizes stay comparable (a final form is visibly bigger than a first one).
  /// Origin = the feet, which sit near the bottom edge.
  static const viewBox = Rect.fromLTWH(-150, -215, 300, 225);

  final String base, eyes, overlay;
  final String? prop;
  final CritterCharacter character;
  final CritterForm form;
  final double scale;

  /// The eyes' horizontal line in viewBox units (already scaled).
  final double eyeLineY;

  /// The look these layers were built for; the widget adds the halo for [CritterLook.glow].
  final CritterLook look;
}

/// Spec -> layers. Returns null when the species is unknown (callers render nothing).
/// Item ids resolve against the spec's own items, then the catalog; unknown ids are skipped. Forms are clamped.
/// [look] overrides the spec's look.
CritterComposition? compose(CritterCatalog catalog, CritterSpec spec, {CritterLook? look}) {
  final species = catalog.species[spec.species];
  if (species == null) return null;
  final formIndex = spec.form.clamp(0, species.forms.length - 1);
  final form = species.forms[formIndex];
  final c = catalog.characters[form.character];
  if (c == null) return null;
  final scale = formScale(species, formIndex, spec.xp);
  final ink = catalog.inkColor, a = spec.attachments, glow = (look ?? spec.look) == CritterLook.glow;

  String rule(String? r) => r == null ? '' : ' fill-rule="$r"';
  String mark(InkPart p) => p.d != null
      ? '<path d="${p.d}" fill="$ink"${rule(p.fillRule)}/>'
      : '<circle cx="${p.cx}" cy="${p.cy}" r="${p.r}" fill="$ink"/>';
  String placed(String slot, String? id) {
    if (id == null) return '';
    final CritterItem? it = spec.items.where((i) => i.slot == slot && i.id == id).firstOrNull ?? catalog.item(slot, id);
    return it == null ? '' : placeItem(c.anchors, it);
  }

  final base = StringBuffer();
  if (glow) {
    base.write(_glowBody(c));
  } else {
    base.writeAll(c.skin.map((p) => '<path d="${p.d}" fill="${p.fill}"${rule(p.fillRule)}/>'));
  }
  base.writeAll(c.ink.where((p) => !p.eye).map(mark));
  // glossy eyes: a small glint on round eyes
  String eye(InkPart p) => mark(p) + (glow && p.d == null ? '<circle cx="${n2(p.cx + p.r * .32)}" cy="${n2(p.cy - p.r * .32)}" r="${n2(p.r * .32)}" fill="#ffffff"/>' : '');
  final overlay = placed('neck', a.neck) + placed('eyes', a.eyes) + placed('hat', a.hat);
  final prop = placed('prop', a.prop);

  final vb = CritterComposition.viewBox;
  String svg(String body) =>
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="${vb.left} ${vb.top} ${vb.width} ${vb.height}">'
      '<g transform="scale($scale)">$body</g></svg>';

  return CritterComposition(
    base: svg(base.toString()),
    eyes: svg(c.ink.where((p) => p.eye).map(eye).join()),
    overlay: svg(overlay),
    prop: prop.isEmpty ? null : svg(prop),
    character: c,
    form: form,
    scale: scale,
    eyeLineY: c.anchors.eye.dy * scale,
    look: glow ? CritterLook.glow : CritterLook.flat,
  );
}

/// Lit body: each part shaded light top-left to dark bottom-right, a glossy highlight clipped to the body,
/// and a soft contact shadow under the feet. Gradients only; the halo is a Flutter blur in CritterView.
String _glowBody(CritterCharacter c) {
  final w = c.width, h = c.height, out = StringBuffer('<defs>');
  for (final (k, p) in c.skin.indexed) {
    out.write('<radialGradient id="g$k" cx="0.36" cy="0.28" r="0.95">'
        '<stop offset="0" stop-color="${_shade(p.fill, .38)}"/><stop offset="0.5" stop-color="${p.fill}"/>'
        '<stop offset="1" stop-color="${_shade(p.fill, -.35)}"/></radialGradient>');
  }
  out
    ..write('<radialGradient id="sh"><stop offset="0" stop-color="#000000" stop-opacity="0.55"/><stop offset="1" stop-color="#000000" stop-opacity="0"/></radialGradient>')
    ..write('<radialGradient id="hl"><stop offset="0" stop-color="#ffffff" stop-opacity="0.6"/><stop offset="1" stop-color="#ffffff" stop-opacity="0"/></radialGradient>')
    ..write('<clipPath id="body">${c.skin.map((p) => '<path d="${p.d}"/>').join()}</clipPath></defs>')
    ..write('<ellipse cx="0" cy="1" rx="${n2(w * .55)}" ry="${n2(5 + w * .03)}" fill="url(#sh)"/>');
  for (final (k, p) in c.skin.indexed) {
    out.write('<path d="${p.d}" fill="url(#g$k)"${p.fillRule == null ? '' : ' fill-rule="${p.fillRule}"'}/>');
  }
  final hx = -w * .2, hy = -h * .72;
  out.write('<g clip-path="url(#body)"><ellipse cx="${n2(hx)}" cy="${n2(hy)}" rx="${n2(w * .15)}" ry="${n2(h * .12)}" '
      'transform="rotate(-25 ${n2(hx)} ${n2(hy)})" fill="url(#hl)"/></g>');
  return out.toString();
}

/// Mix a #rrggbb colour towards white (t > 0) or black (t < 0). Anything else is returned unchanged.
String _shade(String hex, double t) {
  final m = RegExp(r'^#([0-9a-fA-F]{6})$').firstMatch(hex);
  if (m == null) return hex;
  final v = int.parse(m[1]!, radix: 16), target = t > 0 ? 255 : 0, f = t.abs();
  String ch(int shift) {
    final x = (v >> shift) & 0xff;
    return (x + (target - x) * f).round().toRadixString(16).padLeft(2, '0');
  }
  return '#${ch(16)}${ch(8)}${ch(0)}';
}
