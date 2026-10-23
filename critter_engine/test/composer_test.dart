import 'dart:io';

import 'package:critter_engine/critter_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart' as vg;

CritterCatalog loadCatalog() => CritterCatalog.fromJsonString(File('assets/critter_catalog.json').readAsStringSync());

void main() {
  final catalog = loadCatalog();

  test('catalog has every character placed in a species line', () {
    expect(catalog.characters, hasLength(40));
    final used = catalog.species.values.expand((s) => s.forms.map((f) => f.character)).toSet();
    expect(used, catalog.characters.keys.toSet());
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
    expect(checked, 40 * 13);
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
    expect(count, 40 * 17);
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
