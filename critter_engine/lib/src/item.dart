import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

/// An attachment definition. Bundled ones come from the catalog; the backend can send more as JSON
/// (in a spec's `items`, or once via `CritterCatalog.registerItems`). Same shape either way:
///
/// ```json
/// { "id": "viking", "slot": "hat",  "svg": "<path d='…'/>", "anchor": [50, 62] }
/// { "id": "scarf",  "slot": "neck", "svg": "…", "anchor": [50, 0], "fit": 0.6, "height": 30 }
/// { "id": "rock",   "slot": "prop", "svg": "…", "anchor": [0, 0] }
/// { "id": "visor",  "slot": "eyes", "lens": "<circle r='10' …/>", "grow": 1.2, "bridge": "#2b2a33", "strap": "#2b2a33" }
/// ```
///
/// hat / neck / prop: draw ~100 units wide; `anchor` is the point that lands on the character
/// (bottom-centre of a hat, top-centre of a necklace, bottom-left of a prop).
/// eyes: one lens drawn centred on (0,0) at radius 10; it is copied onto every eye and scaled to it.
@immutable
class CritterItem {
  const CritterItem({
    required this.id,
    required this.slot,
    this.svg = '',
    this.anchor = Offset.zero,
    this.fit = .5,
    this.height = 40,
    this.lens = '',
    this.grow = 1.15,
    this.bridge = '#2b2a33',
    this.strap,
  });

  static const slots = ['hat', 'eyes', 'neck', 'prop'];

  final String id, slot;

  // hat / neck / prop
  final String svg;
  final Offset anchor;

  /// neck only: width as a fraction of the neck, and the drawn height (keeps it above the feet).
  final double fit, height;

  // eyes
  final String lens;
  final double grow;
  final String bridge;
  final String? strap;

  /// Throws [FormatException] for anything unusable or unsafe; callers skip the item.
  factory CritterItem.fromJson(Map<String, dynamic> j) {
    final id = j['id'], slot = j['slot'];
    if (id is! String || id.isEmpty) throw const FormatException('item needs an "id"');
    if (slot is! String || !slots.contains(slot)) throw FormatException('item "$id": "slot" must be one of $slots');
    double num_(String k, double fallback) => (j[k] as num?)?.toDouble() ?? fallback;
    if (slot == 'eyes') {
      return CritterItem(
        id: id, slot: slot,
        lens: checkSvgFragment(j['lens'], '$id.lens'),
        grow: num_('grow', 1.15).clamp(.3, 3),
        bridge: _color(j['bridge'] ?? '#2b2a33', '$id.bridge'),
        strap: j['strap'] == null ? null : _color(j['strap'], '$id.strap'),
      );
    }
    final a = j['anchor'];
    if (a is! List || a.length != 2 || a.any((v) => v is! num)) throw FormatException('item "$id": "anchor" must be [x, y]');
    return CritterItem(
      id: id, slot: slot,
      svg: checkSvgFragment(j['svg'], '$id.svg'),
      anchor: Offset((a[0] as num).toDouble(), (a[1] as num).toDouble()),
      fit: num_('fit', .5).clamp(.05, 2),
      height: num_('height', 40).clamp(1, 400),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'slot': slot,
        if (slot == 'eyes') ...{'lens': lens, 'grow': grow, 'bridge': bridge, 'strap': ?strap}
        else ...{'svg': svg, 'anchor': [anchor.dx, anchor.dy], if (slot == 'neck') ...{'fit': fit, 'height': height}},
      };

  @override
  bool operator ==(Object other) =>
      other is CritterItem && other.id == id && other.slot == slot && other.svg == svg && other.anchor == anchor &&
      other.fit == fit && other.height == height && other.lens == lens && other.grow == grow && other.bridge == bridge &&
      other.strap == strap;

  @override
  int get hashCode => Object.hash(id, slot, svg, anchor, fit, height, lens, grow, bridge, strap);
}

const _allowedTags = {'path', 'circle', 'ellipse', 'rect', 'polygon', 'polyline', 'line', 'g'};
const _maxLength = 50000;

/// Item SVG arrives from the network: only plain shapes are allowed, nothing that can reference
/// outside content (href, url(), entities), and nothing flutter_svg would drop (text).
String checkSvgFragment(Object? v, String what) {
  if (v is! String || v.trim().isEmpty) throw FormatException('$what: missing svg');
  if (v.length > _maxLength) throw FormatException('$what: svg longer than $_maxLength chars');
  final lower = v.toLowerCase();
  for (final bad in const ['href', 'url(', '<!', '<?', 'javascript:', 'style']) {
    if (lower.contains(bad)) throw FormatException('$what: "$bad" is not allowed');
  }
  for (final m in RegExp(r'<\s*/?\s*([a-zA-Z][\w:-]*)').allMatches(v)) {
    final tag = m.group(1)!.toLowerCase();
    if (!_allowedTags.contains(tag)) throw FormatException('$what: <$tag> is not allowed (use $_allowedTags)');
  }
  return v;
}

String _color(Object? v, String what) {
  if (v is String && RegExp(r'^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$').hasMatch(v)) return v;
  throw FormatException('$what: colour must be #rgb or #rrggbb');
}
