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
}

/// Spec -> layers. Returns null when the species is unknown (callers render nothing).
/// Item ids resolve against the spec's own items, then the catalog; unknown ids are skipped. Forms are clamped.
CritterComposition? compose(CritterCatalog catalog, CritterSpec spec) {
  final species = catalog.species[spec.species];
  if (species == null) return null;
  final formIndex = spec.form.clamp(0, species.forms.length - 1);
  final form = species.forms[formIndex];
  final c = catalog.characters[form.character];
  if (c == null) return null;
  final scale = formScale(species, formIndex, spec.xp);
  final ink = catalog.inkColor, a = spec.attachments;

  String rule(String? r) => r == null ? '' : ' fill-rule="$r"';
  String mark(InkPart p) => p.d != null
      ? '<path d="${p.d}" fill="$ink"${rule(p.fillRule)}/>'
      : '<circle cx="${p.cx}" cy="${p.cy}" r="${p.r}" fill="$ink"/>';
  String placed(String slot, String? id) {
    if (id == null) return '';
    final CritterItem? it = spec.items.where((i) => i.slot == slot && i.id == id).firstOrNull ?? catalog.item(slot, id);
    return it == null ? '' : placeItem(c.anchors, it);
  }

  final base = StringBuffer()
    ..writeAll(c.skin.map((p) => '<path d="${p.d}" fill="${p.fill}"${rule(p.fillRule)}/>'))
    ..writeAll(c.ink.where((p) => !p.eye).map(mark));
  final overlay = placed('neck', a.neck) + placed('eyes', a.eyes) + placed('hat', a.hat);
  final prop = placed('prop', a.prop);

  final vb = CritterComposition.viewBox;
  String svg(String body) =>
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="${vb.left} ${vb.top} ${vb.width} ${vb.height}">'
      '<g transform="scale($scale)">$body</g></svg>';

  return CritterComposition(
    base: svg(base.toString()),
    eyes: svg(c.ink.where((p) => p.eye).map(mark).join()),
    overlay: svg(overlay),
    prop: prop.isEmpty ? null : svg(prop),
    character: c,
    form: form,
    scale: scale,
    eyeLineY: c.anchors.eye.dy * scale,
  );
}
