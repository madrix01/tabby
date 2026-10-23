import 'dart:io';

import 'package:critter_engine/critter_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

CritterCatalog loadCatalog() => CritterCatalog.fromJsonString(File('assets/critter_catalog.json').readAsStringSync());

void main() {
  final catalog = loadCatalog();

  test('catalog has every character placed in a species line, in two collections', () {
    expect(catalog.characters, hasLength(198));
    expect(catalog.speciesIn('v3'), hasLength(16));
    expect(catalog.speciesIn('v4'), hasLength(13));
    expect(catalog.speciesIn('v6'), hasLength(8));
    expect(catalog.speciesIn('v6_cute'), hasLength(8));
    expect(catalog.species, hasLength(45));
    final used = catalog.species.values.expand((s) => s.forms.map((f) => f.character)).toSet();
    expect(used, catalog.characters.keys.toSet());
    expect(catalog.speciesIn('v4').expand((s) => s.forms).every((f) => f.character.startsWith('v4_')), isTrue);
    expect(catalog.speciesIn('v3').expand((s) => s.forms).any((f) => f.character.startsWith('v4_')), isFalse);
  });

  group('v6 frens', () {
    test('eight frens per set, seven stages from egg to legend, unlocked at 1, 2, 3, 5, 7, 10, 14', () {
      for (final set in ['v6', 'v6_cute']) {
        for (final s in catalog.speciesIn(set)) {
          expect(s.id, startsWith('${set}_'));
          expect(s.forms.map((f) => f.atLevel), [1, 2, 3, 5, 7, 10, 14]);
          expect(s.forms.first.name, endsWith(' Egg'));
          expect(s.forms.last.name, endsWith(' Legend'));
        }
      }
      expect(catalog.species['v6_mochi']!.forms[3].name, 'Mochi Kid', reason: 'no clash with the v3 mochi line');
      expect(catalog.species['mochi']!.collection, 'v3');
    });

    test('a fren keeps its stage item and its face: eyes blink, a mood replaces the mouth', () {
      final kid = compose(catalog, const CritterSpec(species: 'v6_bloop', form: 3))!;
      expect(kid.character.ink.where((p) => p.eye), isNotEmpty);
      final mouth = kid.character.ink.firstWhere((p) => p.mouth);
      final happy = compose(catalog, const CritterSpec(species: 'v6_bloop', form: 3, mood: CritterMood.happy))!;
      expect(happy.base, isNot(contains(mouth.d!)));
      expect(kid.character.height, closeTo(115, 1), reason: 'drawn at the art\'s own scale, like v6/index.html');
    });
  });

  group('v4 set', () {
    test('textures and pupils are clipped, legs are stroked in the body colour, whites blink with the pupils', () {
      final comp = compose(catalog, const CritterSpec(species: 'tock', form: 3))!, c = comp.character;   // Stripeling: striped texture, two eyes
      expect(c.id, 'v4_05');
      expect(c.clips, isNotEmpty);
      for (final (k, _) in c.clips.indexed) {
        expect(comp.base.contains('url(#k$k)') || comp.eyes.contains('url(#k$k)'), isTrue, reason: 'clip $k used');
      }
      final body = c.skin.first;
      expect(RegExp('fill="${body.fill}"[^>]* stroke="${body.fill}" stroke-width=').hasMatch(comp.base), isTrue, reason: 'legs');
      expect(comp.eyes, contains('fill="#ffffff"'), reason: 'eye whites on the blinking layer');
      expect(comp.eyes, contains('clip-path="url(#k'), reason: 'pupils stay inside their whites');
      expect(comp.eyes, contains('<clipPath'), reason: 'the eye layer carries its own clip shapes');
      expect(c.anchors.bodyTop, isNotNull);
      expect(c.anchors.bodyBottom!, lessThan(0), reason: 'the body ends above the feet');
    });

    test('closed-eye shapes still get eye anchors, no eye layer marks', () {
      final c = compose(catalog, const CritterSpec(species: 'hexo'))!.character;   // Hexo: eyes are arcs in the texture
      expect(c.ink, isEmpty);
      expect(c.anchors.eyes, hasLength(2));
      expect(c.anchors.eyeSpan, greaterThan(10));
    });

    test('glow: textures stay clipped, legs pick up the shading, no glint on the whites', () {
      final glow = compose(catalog, const CritterSpec(species: 'tock', form: 3, look: CritterLook.glow))!;
      vg.parseWithoutOptimizers(glow.base, warningsAsErrors: true);
      expect(glow.base, contains('stroke="url(#g'));
      expect(RegExp(r'<g clip-path="url\(#k\d+\)"><path d="[^"]+" fill="url\(#g').hasMatch(glow.base), isTrue);
      final whites = compose(catalog, const CritterSpec(species: 'pebblet', look: CritterLook.glow))!.eyes;   // Pebblet: circle whites
      expect('fill="#ffffff"/>'.allMatches(whites).length, greaterThanOrEqualTo(2));
      expect('r="'.allMatches(whites).length, lessThanOrEqualTo(6), reason: 'glints only on the two pupils');
    });

    test('v3 and v4 critters mix in one view tree', () {
      final a = compose(catalog, const CritterSpec(species: 'blip', mood: CritterMood.happy))!, b = compose(catalog, const CritterSpec(species: 'dewdrop', mood: CritterMood.happy))!;
      expect(a.character.clips, isEmpty);
      expect(b.character.id, startsWith('v4_'));
      expect(CritterComposition.viewBox, isNotNull, reason: 'same viewBox for both sets, so sizes stay comparable');
    });
  });

  test('engine placement matches the compiler for every character x bundled item', () {
    final nums = RegExp(r'-?\d+(\.\d+)?');
    List<double> numbers(String s) => nums.allMatches(s).map((m) => double.parse(m[0]!)).toList();
    var checked = 0;
    for (final c in catalog.characters.values) {
      for (final slot in const ['hat', 'neck', 'prop']) {
        for (final id in catalog.itemIds(slot)) {
          final ours = RegExp(r'transform="([^"]+)"').firstMatch(placeItem(c.anchors, catalog.item(slot, id)!))![1]!;
          final theirs = c.bakedPlacements[slot]![id]!;
          final a = numbers(ours), b = numbers(theirs);
          expect(a.length, b.length, reason: '${c.id} $slot/$id');
          for (var k = 0; k < a.length; k++) {
            expect(a[k], closeTo(b[k], .02), reason: '${c.id} $slot/$id: $ours vs $theirs');
          }
          checked++;
        }
      }
    }
    expect(checked, catalog.characters.length * 13);
  });

  test('every species x form x item composes and parses cleanly in flutter_svg\'s parser', () {
    var count = 0;
    for (final species in catalog.species.values) {
      for (var form = 0; form < species.forms.length; form++) {
        for (final slot in CritterItem.slots) {
          for (final item in catalog.itemIds(slot)) {
            final comp = compose(catalog, CritterSpec(species: species.id, form: form, attachments: _only(slot, item)))!;
            for (final layer in [comp.base, comp.eyes, comp.overlay, ?comp.prop]) {
              // warningsAsErrors: anything flutter_svg would silently drop (text, unsupported attributes) fails here
              vg.parseWithoutOptimizers(layer, key: '${species.id}/$form/$slot/$item', warningsAsErrors: true);
            }
            count++;
          }
        }
      }
    }
    expect(count, catalog.characters.length * CritterItem.slots.map((s) => catalog.itemIds(s).length).reduce((a, b) => a + b));
  });

  test('glow look: every species x form composes, parses and only adds lighting', () {
    for (final species in catalog.species.values) {
      for (var form = 0; form < species.forms.length; form++) {
        final spec = CritterSpec(species: species.id, form: form, attachments: const CritterAttachments(hat: 'crown', eyes: 'goggles'));
        final glow = compose(catalog, spec, look: CritterLook.glow)!, flat = compose(catalog, spec)!;
        expect(glow.look, CritterLook.glow);
        for (final layer in [glow.base, glow.eyes, glow.overlay]) {
          vg.parseWithoutOptimizers(layer, key: '${species.id}/$form/glow', warningsAsErrors: true);
        }
        expect(glow.base, contains('url(#g0)'));
        expect(glow.overlay, flat.overlay, reason: 'items are unchanged');
      }
    }
    expect(CritterSpec.fromJson({'species': 'blip', 'look': 'glow'}).look, CritterLook.glow);
    expect(CritterSpec.fromJson({'species': 'blip', 'look': 'neon'}).look, CritterLook.flat, reason: 'unknown look falls back');
  });

  test('glow knobs: parsed with defaults and clamps, and each one switches its effect', () {
    final g = CritterSpec.fromJson({'species': 'blip', 'look': 'glow', 'glow': {'halo': 3, 'blur': -1, 'shadow': 0, 'color': 'orange'}}).glow;
    expect(g.halo, 1, reason: 'clamped');
    expect(g.blur, 0, reason: 'clamped');
    expect(g.hasHalo, isFalse);
    expect(g.color, isNull, reason: 'only #rrggbb accepted');
    expect(g.gloss, const CritterGlow().gloss, reason: 'missing keeps default');
    const spec = CritterSpec(species: 'pip', form: 2, look: CritterLook.glow);
    expect(CritterSpec.fromJson(spec.copyWith(glow: const CritterGlow(halo: .4, color: '#ff8a3d')).toJson()).glow,
        const CritterGlow(halo: .4, color: '#ff8a3d'));
    String base(CritterGlow g) => compose(catalog, spec, glow: g)!.base;
    expect(base(const CritterGlow()), contains('fill="url(#sh)"'));
    expect(base(const CritterGlow(shadow: 0)), isNot(contains('fill="url(#sh)"')));
    expect(base(const CritterGlow()), contains('fill="url(#hl)"'));
    expect(base(const CritterGlow(gloss: 0)), isNot(contains('fill="url(#hl)"')));
    final fill = catalog.characters['15']!.skin.first.fill;
    expect(base(const CritterGlow(shading: 0)), contains('<stop offset="0" stop-color="$fill"/>'), reason: 'no shading = flat colour');
    expect(compose(catalog, spec, glow: const CritterGlow(gloss: 0))!.eyes, isNot(contains('#ffffff')), reason: 'no eye glints without gloss');
  });

  test('items land in the right layer, neck under eyewear under hat', () {
    final comp = compose(catalog, const CritterSpec(species: 'pip', form: 2,
        attachments: CritterAttachments(hat: 'crown', eyes: 'round', neck: 'bow_tie', prop: 'gold_bar')))!;
    expect(comp.form.name, 'Tri');
    final o = comp.overlay;
    expect(o.indexOf('#e8494b"/><circle cx="50" cy="14"'), greaterThan(0), reason: 'bow tie present');
    expect(o.indexOf('fill-opacity=".33"'), greaterThan(o.indexOf('cy="14"')), reason: 'eyewear above neck');
    expect(o.indexOf('L50 6 L70 36'), greaterThan(o.indexOf('fill-opacity=".33"')), reason: 'hat above eyewear');
    expect(comp.prop, contains('H46 L38 -17'));
    expect(comp.base, isNot(contains('L50 6 L70 36')));
  });

  test('eyes are on their own layer', () {
    final comp = compose(catalog, const CritterSpec(species: 'blip'))!;
    final eyeCount = comp.character.ink.where((p) => p.eye).length;
    expect('<circle'.allMatches(comp.eyes).length + '<path'.allMatches(comp.eyes).length, eyeCount);
  });

  test('tolerant: unknown species renders nothing, unknown items are skipped, forms are clamped', () {
    expect(compose(catalog, const CritterSpec(species: 'nope')), isNull);
    final comp = compose(catalog, const CritterSpec(species: 'blip', form: 99, attachments: CritterAttachments(hat: 'sombrero')))!;
    expect(comp.form.name, 'Blobfred');
    expect(comp.overlay, isNot(contains('<g transform="translate')));
  });

  test('critters grow inside a form and jump at evolution', () {
    final blip = catalog.species['blip']!;
    final early = formScale(blip, 0, 0), late = formScale(blip, 0, xpForLevel(4) - 1), evolved = formScale(blip, 1, xpForLevel(4));
    expect(early, lessThan(late));
    expect(late, lessThan(evolved));
    expect(formScale(blip, 0, null), blip.forms[0].minScale);
  });

  group('moods', () {
    test('parsed from json, unknown means none', () {
      expect(CritterSpec.fromJson({'species': 'blip', 'mood': 'travel'}).mood, CritterMood.travel);
      expect(CritterSpec.fromJson({'species': 'blip', 'mood': 'empty_wallet'}).mood, CritterMood.emptyWallet);
      expect(const CritterSpec(species: 'blip', mood: CritterMood.emptyWallet).toJson()['mood'], 'empty_wallet');
      expect(CritterSpec.fromJson({'species': 'blip', 'mood': 'grumpy'}).mood, isNull);
      const s = CritterSpec(species: 'blip', mood: CritterMood.sad);
      expect(CritterSpec.fromJson(s.toJson()), s);
      expect(s.copyWith(clearMood: true).mood, isNull);
    });

    test('every species x form x mood composes and parses cleanly', () {
      for (final species in catalog.species.values) {
        for (var form = 0; form < species.forms.length; form++) {
          for (final mood in CritterMood.values) {
            final comp = compose(catalog, CritterSpec(species: species.id, form: form, mood: mood, attachments: const CritterAttachments(hat: 'cap')))!;
            for (final layer in [comp.base, comp.eyes, comp.overlay, ?comp.prop]) {
              vg.parseWithoutOptimizers(layer, key: '${species.id}/$form/${mood.name}', warningsAsErrors: true);
            }
          }
        }
      }
    });

    test('a mood swaps the mouth, adds its extras, and entertainment wears 3D glasses', () {
      const spec = CritterSpec(species: 'pip', form: 2, attachments: CritterAttachments(eyes: 'round'));
      final plain = compose(catalog, spec)!, tri = catalog.characters['15']!;
      final mouthD = tri.ink.firstWhere((p) => p.mouth).d!;
      expect(plain.base, contains(mouthD));
      final sad = compose(catalog, spec.copyWith(mood: CritterMood.sad))!;
      expect(sad.base, isNot(contains(mouthD)), reason: 'own mouth replaced');
      expect(sad.prop, contains('#9aa3ad'), reason: 'rain cloud');
      final fun = compose(catalog, spec.copyWith(mood: CritterMood.entertainment))!;
      expect(fun.overlay, allOf(contains('#e8494b'), contains('#3a85f2')), reason: 'red + blue lenses');
      expect(fun.overlay, isNot(contains('fill-opacity=".33"')), reason: 'replaces the round glasses');
      expect(compose(catalog, spec.copyWith(mood: CritterMood.shopping))!.prop, contains('#c94d7f'), reason: 'bags');
      final broke = compose(catalog, spec.copyWith(mood: CritterMood.emptyWallet))!;
      expect(broke.base, isNot(contains(mouthD)), reason: 'sad mouth instead');
      expect(broke.prop, allOf(contains('#8a5a3a'), contains('#e8494b')), reason: 'wallet + ₹0 bubble');
      expect(broke.prop, isNot(contains('#9aa3ad')), reason: 'no rain cloud');
    });
  });

  group('items sent as JSON', () {
    const viking = {'id': 'viking', 'slot': 'hat', 'anchor': [50, 60],
        'svg': '<path d="M10 60 Q10 20 50 20 Q90 20 90 60Z" fill="#9aa0a6"/><path d="M12 30 L2 6 L24 24Z M88 30 L98 6 L76 24Z" fill="#f2f0e6"/>'};
    const visor = {'id': 'visor', 'slot': 'eyes', 'lens': '<rect x="-12" y="-6" width="24" height="12" rx="6" fill="#3a85f2"/>', 'grow': 1.3, 'bridge': '#3a85f2'};

    test('inline items in a spec are placed like bundled ones', () {
      final spec = CritterSpec.fromJson({
        'species': 'pip', 'form': 2,
        'attachments': {'hat': 'viking', 'eyes': 'visor'},
        'items': [viking, visor],
      });
      final comp = compose(catalog, spec)!;
      final tri = catalog.characters['15']!;
      expect(comp.overlay, contains('<g transform="${place(tri.anchors.hatAt, const Offset(50, 60), tri.anchors.hatWidth / 100, tri.anchors.eyeAngle)}">'));
      expect('fill="#3a85f2"/>'.allMatches(comp.overlay).length, 2, reason: 'one lens per eye');
      vg.parseWithoutOptimizers(comp.overlay, warningsAsErrors: true);
      expect(CritterSpec.fromJson(spec.toJson()), spec);
    });

    test('inline items win over catalog items with the same id', () {
      final spec = CritterSpec.fromJson({
        'species': 'blip', 'attachments': {'hat': 'crown'},
        'items': [{...viking, 'id': 'crown'}],
      });
      expect(compose(catalog, spec)!.overlay, contains('#9aa0a6'));
    });

    test('registerItems makes items available to every spec and reports bad ones', () {
      final cat = loadCatalog();
      final rejected = cat.registerItems([viking, {'id': 'bad', 'slot': 'hat'}, {'id': 'x', 'slot': 'tail', 'svg': '<path/>'}]);
      expect(rejected.keys, unorderedEquals(['bad', 'x']));
      expect(compose(cat, const CritterSpec(species: 'blip', attachments: CritterAttachments(hat: 'viking')))!.overlay, contains('#9aa0a6'));
    });

    test('unsafe or unsupported svg is rejected at the boundary', () {
      for (final svg in [
        '<image href="https://example.com/x.png"/>',
        '<path d="M0 0" fill="url(#g)"/>',
        '<text>hi</text>',
        '<script>alert(1)</script>',
        '<!DOCTYPE x [<!ENTITY a "b">]><path/>',
        '<path style="fill:red"/>',
        '',
      ]) {
        expect(() => CritterItem.fromJson({'id': 'x', 'slot': 'hat', 'anchor': [0, 0], 'svg': svg}), throwsFormatException, reason: svg);
      }
      expect(() => CritterItem.fromJson({'id': 'x', 'slot': 'eyes', 'lens': '<circle r="10"/>', 'bridge': 'red'}), throwsFormatException);
      final spec = CritterSpec.fromJson({'species': 'blip', 'items': [{'id': 'x', 'slot': 'hat', 'anchor': [0, 0], 'svg': '<text>a</text>'}, viking]});
      expect(spec.items.map((i) => i.id), ['viking'], reason: 'bad inline items are dropped, good ones kept');
    });
  });
}

CritterAttachments _only(String slot, String id) => switch (slot) {
      'hat' => CritterAttachments(hat: id),
      'eyes' => CritterAttachments(eyes: id),
      'neck' => CritterAttachments(neck: id),
      _ => CritterAttachments(prop: id),
    };
