import 'dart:convert';

import 'package:flutter/services.dart';

import 'item.dart';

/// Everything needed to compose critters, produced by `../compiler` (`npm run build`).
///
/// Coordinates are in *character space*: origin at the feet (bottom centre), y grows
/// downwards, characters ~100 tall. Nothing here is measured at runtime.
class CritterCatalog {
  CritterCatalog._(this.version, this.inkColor, this.characters, this._items, this.species);

  static const assetKey = 'packages/critter_engine/assets/critter_catalog.json';
  static const supportedVersion = 1;

  final int version;
  final String inkColor;
  final Map<String, CritterCharacter> characters;

  /// slot -> item id -> item. Bundled items plus anything added with [registerItems].
  final Map<String, Map<String, CritterItem>> _items;
  final Map<String, CritterSpecies> species;

  static Future<CritterCatalog> load({AssetBundle? bundle}) async =>
      CritterCatalog.fromJsonString(await (bundle ?? rootBundle).loadString(assetKey));

  factory CritterCatalog.fromJsonString(String source) =>
      CritterCatalog.fromJson(jsonDecode(source) as Map<String, dynamic>);

  factory CritterCatalog.fromJson(Map<String, dynamic> j) {
    final version = j['version'] as int;
    if (version > supportedVersion) {
      throw FormatException('critter catalog v$version is newer than this engine (v$supportedVersion)');
    }
    final items = <String, Map<String, CritterItem>>{for (final slot in CritterItem.slots) slot: {}};
    (j['items'] as Map<String, dynamic>).forEach((slot, byId) {
      (byId as Map<String, dynamic>).forEach((id, def) => items[slot]![id] = CritterItem.fromJson({...def as Map<String, dynamic>, 'id': id, 'slot': slot}));
    });
    return CritterCatalog._(
      version,
      j['inkColor'] as String,
      {
        for (final e in (j['characters'] as Map<String, dynamic>).entries)
          e.key: CritterCharacter.fromJson(e.key, e.value as Map<String, dynamic>),
      },
      items,
      {
        for (final s in (j['species'] as List).cast<Map<String, dynamic>>())
          s['id'] as String: CritterSpecies.fromJson(s),
      },
    );
  }

  CritterItem? item(String slot, String id) => _items[slot]?[id];

  /// Item ids available for a slot ('hat' | 'eyes' | 'neck' | 'prop').
  Iterable<String> itemIds(String slot) => _items[slot]?.keys ?? const [];

  /// Adds (or replaces) items sent by the backend, e.g. once at startup from an item store.
  /// Invalid entries are skipped and returned with the reason, so one bad item never breaks the rest.
  Map<Object?, String> registerItems(List<dynamic> json) {
    final rejected = <Object?, String>{};
    for (final raw in json) {
      try {
        final it = CritterItem.fromJson(raw as Map<String, dynamic>);
        _items[it.slot]![it.id] = it;
      } on Object catch (e) {
        rejected[raw is Map ? raw['id'] : raw] = '$e';
      }
    }
    return rejected;
  }
}

class CritterCharacter {
  CritterCharacter._(this.id, this.width, this.height, this.skin, this.ink, this.anchors, this.bakedPlacements);

  final String id;
  final double width, height;
  final List<SkinPart> skin;
  final List<InkPart> ink;

  /// Measured points every item is placed from (see placement.dart).
  final CritterAnchors anchors;

  /// The compiler's own placements of the bundled items (slot -> id -> transform). Not used for rendering;
  /// tests compare the engine's maths against them.
  final Map<String, Map<String, String>> bakedPlacements;

  factory CritterCharacter.fromJson(String id, Map<String, dynamic> j) {
    final attach = j['attach'] as Map<String, dynamic>;
    return CritterCharacter._(
      id,
      (j['width'] as num).toDouble(),
      (j['height'] as num).toDouble(),
      [for (final p in (j['skin'] as List).cast<Map<String, dynamic>>()) SkinPart(p['d'] as String, p['fill'] as String, p['fillRule'] as String?)],
      [for (final p in (j['ink'] as List).cast<Map<String, dynamic>>()) InkPart.fromJson(p)],
      CritterAnchors.fromJson(j['anchors'] as Map<String, dynamic>),
      {
        for (final slot in const ['hat', 'neck', 'prop'])
          slot: (attach[slot] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as String)),
      },
    );
  }
}

/// Points measured on a character by the compiler, in character space.
class CritterAnchors {
  const CritterAnchors({
    required this.eye, required this.eyeSpan, required this.eyeAngle, required this.eyeR, required this.headWidth,
    required this.hatAt, required this.hatWidth, required this.neck, required this.neckWidth, required this.side,
  });

  /// Midpoint between the eyes; [eyeSpan] = distance between them (0 for one-eyed critters).
  final Offset eye;
  final double eyeSpan, eyeAngle, eyeR, headWidth;

  /// Where a hat sits (bottom-centre of the hat) and how wide it should be.
  final Offset hatAt;
  final double hatWidth;
  final Offset neck;
  final double neckWidth;

  /// Ground point beside the feet for props.
  final Offset side;

  factory CritterAnchors.fromJson(Map<String, dynamic> j) {
    Offset o(dynamic v) => Offset(((v as List)[0] as num).toDouble(), (v[1] as num).toDouble());
    double d(String k) => (j[k] as num).toDouble();
    final hat = j['hat'] as Map<String, dynamic>;
    return CritterAnchors(
      eye: o(j['eye']), eyeSpan: d('eyeSpan'), eyeAngle: d('eyeAngle'), eyeR: d('eyeR'), headWidth: d('headWidth'),
      hatAt: o(hat['at']), hatWidth: (hat['width'] as num).toDouble(), neck: o(j['neck']), neckWidth: d('neckWidth'), side: o(j['side']),
    );
  }
}

class SkinPart {
  const SkinPart(this.d, this.fill, this.fillRule);
  final String d, fill;
  final String? fillRule;
}

/// A face mark in the ink colour: a path or a circle. [eye] marks the ones that blink.
class InkPart {
  const InkPart({this.d, this.cx = 0, this.cy = 0, this.r = 0, this.fillRule, required this.eye});
  final String? d;
  final double cx, cy, r;
  final String? fillRule;
  final bool eye;

  factory InkPart.fromJson(Map<String, dynamic> j) => InkPart(
        d: j['d'] as String?,
        cx: (j['cx'] as num?)?.toDouble() ?? 0,
        cy: (j['cy'] as num?)?.toDouble() ?? 0,
        r: (j['r'] as num?)?.toDouble() ?? 0,
        fillRule: j['fillRule'] as String?,
        eye: j['eye'] as bool,
      );
}

/// An evolution line: one character per form, unlocked at [CritterForm.atLevel].
class CritterSpecies {
  CritterSpecies(this.id, this.forms);
  final String id;
  final List<CritterForm> forms;

  factory CritterSpecies.fromJson(Map<String, dynamic> j) => CritterSpecies(j['id'] as String, [
        for (final f in (j['forms'] as List).cast<Map<String, dynamic>>())
          CritterForm(f['character'] as String, f['name'] as String, f['atLevel'] as int,
              ((f['size'] as List)[0] as num).toDouble(), ((f['size'] as List)[1] as num).toDouble()),
      ]);
}

class CritterForm {
  const CritterForm(this.character, this.name, this.atLevel, this.minScale, this.maxScale);
  final String character, name;
  final int atLevel;

  /// Scale while growing inside this form, from first unlock to just before the next evolution.
  final double minScale, maxScale;
}
