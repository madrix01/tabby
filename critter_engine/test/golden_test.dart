import 'dart:io';

import 'package:critter_engine/critter_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Goldens render through flutter_svg for real. Compare test/goldens/gallery.png with compiler/out/gallery.html:
// same characters, same items. Update with: flutter test --update-goldens test/golden_test.dart
void main() {
  final catalog = CritterCatalog.fromJsonString(File('assets/critter_catalog.json').readAsStringSync());
  // every character once, as the form of its species line it belongs to
  final specs = [
    for (final s in catalog.species.values)
      for (var f = 0; f < s.forms.length; f++) (id: s.forms[f].character, species: s.id, form: f),
  ]..sort((a, b) => a.id.compareTo(b.id));
  List<String> ids(String slot) => catalog.itemIds(slot).toList();

  // flutter_svg decodes off the test's fake clock: let real time pass, then repaint
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pumpAndSettle();
  }

  Widget board(List<Widget> cells, {int columns = 8}) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ColoredBox(
          color: const Color(0xfffbf8f2),
          child: GridView.count(crossAxisCount: columns, childAspectRatio: 4 / 3, padding: const EdgeInsets.all(8), children: cells),
        ),
      );

  testWidgets('gallery: all 40 characters with bundled items', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final hats = ids('hat'), eyes = ids('eyes'), necks = ids('neck'), props = ids('prop');
    await tester.pumpWidget(board([
      for (final (n, s) in specs.indexed)
        CritterView(
          catalog: catalog,
          // each at its own form's size, so babies render smaller than final forms
          spec: CritterSpec(species: s.species, form: s.form, attachments: CritterAttachments(
            hat: hats[(n + 2) % hats.length], eyes: eyes[n % eyes.length], neck: necks[(n + 1) % necks.length], prop: props[n % props.length])),
        ),
    ]));
    await settle(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/gallery.png'));
  });

  testWidgets('evolution line grows and items re-fit', (tester) async {
    tester.view.physicalSize = const Size(1200, 330);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const items = CritterAttachments(hat: 'crown', eyes: 'goggles', neck: 'gold_chain', prop: 'money_bag');
    await tester.pumpWidget(board(columns: 4, [
      for (var f = 0; f < 4; f++) CritterView(catalog: catalog, spec: CritterSpec(species: 'squidge', form: f, attachments: items)),
    ]));
    await settle(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/evolution.png'));
  });

  testWidgets('glow look on a dark stage', (tester) async {
    tester.view.physicalSize = const Size(1200, 330);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cells = [
      for (final (sp, f, items) in [
        ('blip', 0, const CritterAttachments()),
        ('pip', 2, const CritterAttachments(hat: 'crown', eyes: 'round')),
        ('squidge', 3, const CritterAttachments(neck: 'gold_chain', prop: 'gold_bar')),
        ('sprig', 1, const CritterAttachments(hat: 'party', eyes: 'goggles', prop: 'money_bag')),
      ])
        CritterView(catalog: catalog, look: CritterLook.glow, spec: CritterSpec(species: sp, form: f, attachments: items)),
    ];
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: DecoratedBox(
        // a spotlight from above, like the reference render; the stage is the host app's job, not the engine's
        decoration: const BoxDecoration(gradient: RadialGradient(center: Alignment(0, -1.1), radius: 1.3,
            colors: [Color(0xff6b5a48), Color(0xff221c18), Color(0xff0e0c0b)], stops: [0, .55, 1])),
        child: GridView.count(crossAxisCount: 4, childAspectRatio: 4 / 3, padding: const EdgeInsets.all(8), children: cells),
      ),
    ));
    await settle(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/glow.png'));
  });

  testWidgets('items sent as JSON', (tester) async {
    tester.view.physicalSize = const Size(1200, 330);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final items = [
      {'id': 'viking', 'slot': 'hat', 'anchor': [50, 60],
       'svg': '<path d="M10 60 Q10 20 50 20 Q90 20 90 60Z" fill="#9aa0a6"/><path d="M12 30 L2 6 L24 24Z M88 30 L98 6 L76 24Z" fill="#f2f0e6"/><rect x="8" y="54" width="84" height="10" rx="5" fill="#6b6f75"/>'},
      {'id': 'visor', 'slot': 'eyes', 'lens': '<rect x="-12" y="-6" width="24" height="12" rx="6" fill="#3a85f2"/>', 'grow': 1.3, 'bridge': '#3a85f2', 'strap': '#2b2a33'},
      {'id': 'scarf', 'slot': 'neck', 'anchor': [50, 0], 'fit': .8, 'height': 40,
       'svg': '<path d="M0 0 Q50 22 100 0 L100 12 Q50 34 0 12Z" fill="#e8494b"/><path d="M62 16 L70 40 L58 40 L54 18Z" fill="#c23638"/>'},
      {'id': 'rock', 'slot': 'prop', 'anchor': [0, 0], 'svg': '<path d="M0 0 Q4 -26 24 -28 Q46 -26 48 0Z" fill="#9aa0a6"/>'},
    ];
    await tester.pumpWidget(board(columns: 4, [
      for (final (sp, f) in [('pip', 2), ('blip', 2), ('sprig', 1), ('drip', 2)])
        CritterView(catalog: catalog, spec: CritterSpec.fromJson({
          'species': sp, 'form': f, 'items': items,
          'attachments': {'hat': 'viking', 'eyes': 'visor', 'neck': 'scarf', 'prop': 'rock'},
        })),
    ]));
    await settle(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/runtime_items.png'));
  });
}
