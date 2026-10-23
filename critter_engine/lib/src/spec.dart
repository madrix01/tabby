import 'package:flutter/foundation.dart';

import 'item.dart';

/// What the backend sends to describe one critter. Tolerant by design: unknown or
/// missing values fall back to defaults instead of throwing, so older apps keep rendering.
///
/// ```json
/// {
///   "v": 1,
///   "species": "blip", "form": 1, "xp": 230,
///   "look": "glow",
///   "attachments": { "hat": "crown", "eyes": "goggles", "neck": "gold_chain", "prop": "gold_bar" },
///   "behaviour": { "likesPets": true, "gait": "waddle", "state": "idle" },
///   "items": [ { "id": "viking", "slot": "hat", "svg": "…", "anchor": [50, 62] } ]
/// }
/// ```
/// `attachments` are item ids. They resolve against this spec's `items` first, then the catalog
/// (bundled + `registerItems`). See [CritterItem] for the item format.
@immutable
class CritterSpec {
  const CritterSpec({
    required this.species,
    this.form = 0,
    this.xp,
    this.attachments = const CritterAttachments(),
    this.behaviour = const CritterBehaviour(),
    this.items = const [],
    this.look = CritterLook.flat,
  });

  final String species;

  /// Index into the species' evolution line. The server decides it; the engine clamps it.
  final int form;

  /// Optional; only used to grow the critter a little inside its current form.
  final double? xp;
  final CritterAttachments attachments;
  final CritterBehaviour behaviour;

  /// Items defined inline by the backend. Invalid ones are dropped while parsing.
  final List<CritterItem> items;

  /// How the critter is lit. `CritterView(look: …)` overrides it.
  final CritterLook look;

  factory CritterSpec.fromJson(Map<String, dynamic> j) => CritterSpec(
        species: j['species'] as String? ?? '',
        form: (j['form'] as num?)?.toInt() ?? 0,
        xp: (j['xp'] as num?)?.toDouble(),
        attachments: CritterAttachments.fromJson(j['attachments'] as Map<String, dynamic>? ?? const {}),
        behaviour: CritterBehaviour.fromJson(j['behaviour'] as Map<String, dynamic>? ?? const {}),
        items: [
          for (final raw in j['items'] as List? ?? const []) ?_tryItem(raw),
        ],
        look: CritterLook.parse(j['look']),
      );

  static CritterItem? _tryItem(Object? raw) {
    try {
      return CritterItem.fromJson(raw as Map<String, dynamic>);
    } on Object catch (e) {
      debugPrint('critter_engine: skipping item: $e');
      return null;
    }
  }

  Map<String, dynamic> toJson() => {
        'v': 1,
        'species': species,
        'form': form,
        if (xp != null) 'xp': xp,
        'attachments': attachments.toJson(),
        'behaviour': behaviour.toJson(),
        if (items.isNotEmpty) 'items': items.map((i) => i.toJson()).toList(),
        if (look != CritterLook.flat) 'look': look.name,
      };

  CritterSpec copyWith({String? species, int? form, double? xp, CritterAttachments? attachments, CritterBehaviour? behaviour, List<CritterItem>? items, CritterLook? look}) =>
      CritterSpec(
        species: species ?? this.species,
        form: form ?? this.form,
        xp: xp ?? this.xp,
        attachments: attachments ?? this.attachments,
        behaviour: behaviour ?? this.behaviour,
        items: items ?? this.items,
        look: look ?? this.look,
      );

  @override
  bool operator ==(Object other) =>
      other is CritterSpec && other.species == species && other.form == form && other.xp == xp &&
      other.attachments == attachments && other.behaviour == behaviour && listEquals(other.items, items) && other.look == look;

  @override
  int get hashCode => Object.hash(species, form, xp, attachments, behaviour, Object.hashAll(items), look);
}

/// Item id per slot; null means nothing in that slot. Ids that the catalog doesn't know are skipped at render time.
@immutable
class CritterAttachments {
  const CritterAttachments({this.hat, this.eyes, this.neck, this.prop});
  final String? hat, eyes, neck, prop;

  factory CritterAttachments.fromJson(Map<String, dynamic> j) => CritterAttachments(
        hat: j['hat'] as String?,
        eyes: j['eyes'] as String?,
        neck: j['neck'] as String?,
        prop: j['prop'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (hat != null) 'hat': hat,
        if (eyes != null) 'eyes': eyes,
        if (neck != null) 'neck': neck,
        if (prop != null) 'prop': prop,
      };

  @override
  bool operator ==(Object other) =>
      other is CritterAttachments && other.hat == hat && other.eyes == eyes && other.neck == neck && other.prop == prop;

  @override
  int get hashCode => Object.hash(hat, eyes, neck, prop);
}

/// Read by the animation layer (phase 3); carried through untouched for now.
@immutable
class CritterBehaviour {
  const CritterBehaviour({this.likesPets = true, this.gait = 'waddle', this.state = 'idle'});
  final bool likesPets;
  final String gait, state;

  factory CritterBehaviour.fromJson(Map<String, dynamic> j) => CritterBehaviour(
        likesPets: j['likesPets'] as bool? ?? true,
        gait: j['gait'] as String? ?? 'waddle',
        state: j['state'] as String? ?? 'idle',
      );

  Map<String, dynamic> toJson() => {'likesPets': likesPets, 'gait': gait, 'state': state};

  @override
  bool operator ==(Object other) =>
      other is CritterBehaviour && other.likesPets == likesPets && other.gait == gait && other.state == state;

  @override
  int get hashCode => Object.hash(likesPets, gait, state);
}

/// `flat`: plain print colours. `glow`: shaded, glossy bodies, eye glints, a soft contact shadow and a
/// colour halo behind the critter (looks best on a dark background). Unknown values mean `flat`.
enum CritterLook {
  flat,
  glow;

  static CritterLook parse(Object? v) => values.firstWhere((l) => l.name == v, orElse: () => flat);
}
