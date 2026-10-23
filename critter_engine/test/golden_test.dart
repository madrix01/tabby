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
    for (final s in catalog.speciesIn('v3'))
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

  testWidgets('gallery: every character with bundled items', (tester) async {
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

  testWidgets('gallery: the v4 set, flat and glow', (tester) async {
    tester.view.physicalSize = const Size(1600, 790);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final v4 = [
      for (final s in catalog.speciesIn('v4'))
        for (var f = 0; f < s.forms.length; f++) (species: s.id, form: f),
    ];
    final hats = ids('hat'), eyes = ids('eyes');
    await tester.pumpWidget(board([
      for (final (n, s) in v4.indexed)
        CritterView(catalog: catalog, look: n.isOdd ? CritterLook.glow : CritterLook.flat,
            spec: CritterSpec(species: s.species, form: s.form, attachments: CritterAttachments(hat: n % 3 == 0 ? hats[n % hats.length] : null, eyes: n % 4 == 1 ? eyes[n % eyes.length] : null))),
    ]));
    await settle(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/gallery_v4.png'));
  });

  testWidgets('gallery: v6 frens, unisex flat and cute glow', (tester) async {
    tester.view.physicalSize = const Size(1400, 1650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    Widget fren(String species, int form, CritterLook look) => CritterView(catalog: catalog, look: look, spec: CritterSpec(species: species, form: form));
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Column(children: [
        Expanded(child: ColoredBox(color: const Color(0xfffbf8f2), child: GridView.count(crossAxisCount: 7, childAspectRatio: 4 / 3, padding: const EdgeInsets.all(4),
            children: [for (final s in catalog.speciesIn('v6').take(4)) for (var f = 0; f < 7; f++) fren(s.id, f, CritterLook.flat)]))),
        Expanded(child: ColoredBox(color: const Color(0xff1a1512), child: GridView.count(crossAxisCount: 7, childAspectRatio: 4 / 3, padding: const EdgeInsets.all(4),
            children: [for (final s in catalog.speciesIn('v6_cute').skip(4)) for (var f = 0; f < 7; f++) fren(s.id, f, CritterLook.glow)]))),
      ]),
    ));
    await settle(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/gallery_v6.png'));
  });

  testWidgets('v4 moods', (tester) async {
    tester.view.physicalSize = const Size(1750, 330);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(board(columns: 7, [
      for (final (sp, f, mood) in [('dewdrop', 2, 'happy'), ('tock', 2, 'sad'), ('pea', 1, 'food'),
                                   ('wiggle', 2, 'entertainment'), ('mound', 2, 'travel'), ('stilts', 1, 'shopping'), ('pebblet', 2, 'empty_wallet')])
        CritterView(catalog: catalog, spec: CritterSpec.fromJson({'species': sp, 'form': f, 'mood': mood})),
    ]));
    await settle(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/moods_v4.png'));
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

  testWidgets('glow knobs', (tester) async {
    tester.view.physicalSize = const Size(1200, 330);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const spec = CritterSpec(species: 'pip', form: 2, look: CritterLook.glow, attachments: CritterAttachments(hat: 'crown'));
    final cells = [
      for (final g in const [
        CritterGlow(),                                              // default
        CritterGlow(halo: 0),                                       // shading + gloss + shadow only
        CritterGlow(halo: 1, blur: 2.2, color: '#ffb347'),          // big warm stage light
        CritterGlow(shading: 0, gloss: 0, shadow: 0, blur: .6),     // flat colours, tight halo
      ])
        CritterView(catalog: catalog, spec: spec, glow: g),
    ];
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ColoredBox(color: const Color(0xff1a1512),
          child: GridView.count(crossAxisCount: 4, childAspectRatio: 4 / 3, padding: const EdgeInsets.all(8), children: cells)),
    ));
    await settle(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/glow_knobs.png'));
  });

  testWidgets('moods', (tester) async {
    tester.view.physicalSize = const Size(1750, 330);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(board(columns: 7, [
      for (final (sp, f, mood) in [('blip', 1, 'happy'), ('pinky', 1, 'sad'), ('squidge', 2, 'food'),
                                   ('pip', 2, 'entertainment'), ('lemon', 1, 'travel'), ('drip', 2, 'shopping'), ('mochi', 1, 'empty_wallet')])
        CritterView(catalog: catalog, spec: CritterSpec.fromJson({'species': sp, 'form': f, 'mood': mood,
            if (mood == 'sad') 'attachments': {'hat': 'beanie'}})),
    ]));
    await settle(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/moods.png'));
  });

  testWidgets('moods on the v6 frens, unisex flat and cute glow', (tester) async {
    tester.view.physicalSize = const Size(1600, 340);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const moods = ['happy', 'sad', 'food', 'entertainment', 'travel', 'shopping', 'empty_wallet', 'rich'];
    const frens = ['bloop', 'mochi', 'puff', 'pup', 'berry', 'pickle', 'chiku', 'bun'];
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Column(children: [
        for (final (set, look, bg) in [('v6', 'flat', const Color(0xfffbf8f2)), ('v6_cute', 'glow', const Color(0xff2a2522))])
          Expanded(
            child: ColoredBox(
              color: bg,
              child: GridView.count(crossAxisCount: 8, childAspectRatio: 4 / 3, padding: const EdgeInsets.all(8), children: [
                for (final (k, mood) in moods.indexed)
                  CritterView(catalog: catalog, spec: CritterSpec.fromJson({'species': '${set}_${frens[k]}', 'form': 3 + k % 3, 'mood': mood, 'look': look})),
              ]),
            ),
          ),
      ]),
    ));
    await settle(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/moods_v6.png'));
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
