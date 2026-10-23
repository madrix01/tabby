import 'dart:io';

import 'package:critter_engine/critter_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = CritterCatalog.fromJsonString(File('assets/critter_catalog.json').readAsStringSync());
  const from = CritterSpec(species: 'blip', form: 2, mood: CritterMood.sad), to = CritterSpec(species: 'drip', form: 2, attachments: CritterAttachments(hat: 'cap'));

  Widget app(Widget child, {bool reduceMotion = false}) => MaterialApp(
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion, size: const Size(800, 600)),
          child: ColoredBox(color: const Color(0xfffbf8f2), child: Center(child: SizedBox(width: 640, child: child))),
        ),
      );
  List<CritterMood?> moods(WidgetTester t) => t.widgetList<CritterView>(find.byType(CritterView)).map((v) => v.spec.mood).toList();

  test('indian digit grouping', () {
    expect(formatIndian(500), '500');
    expect(formatIndian(5000), '5,000');
    expect(formatIndian(100000), '1,00,000');
    expect(formatIndian(12345678), '1,23,45,678');
    expect(formatIndian(1999.5), '1,999.50');
    expect(formatIndian(1.999), '2', reason: 'rounds to paise without a 100-paise glitch');
    expect(formatIndian(-250), '-250');
  });

  testWidgets('normal faces while sending, every note lands, then both are happy', (tester) async {
    final landed = <int>[];
    var completed = 0;
    await tester.pumpWidget(app(MoneyTransferView(catalog: catalog, from: from, to: to, amount: 5000, noteCount: 6,
        onNoteLanded: (i, n) => landed.add(i), onComplete: () => completed++)));
    expect(moods(tester), [null, null], reason: 'spec moods are ignored until the money lands');
    expect(find.text('-₹5,000'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2000));       // mid-stream: first lands at 540 + 1150 ms
    expect(landed.length, inInclusiveRange(1, 5));
    expect(moods(tester), [null, null]);

    await tester.pump(const Duration(milliseconds: 1000));       // all landed (last at ~2640 ms)
    expect(landed, [1, 2, 3, 4, 5, 6]);
    expect(moods(tester), [CritterMood.happy, CritterMood.happy]);
    expect(find.text('+₹5,000'), findsOneWidget);
    expect(completed, 0, reason: 'still celebrating');

    await tester.pumpAndSettle();
    expect(completed, 1);
    expect(moods(tester), [CritterMood.happy, CritterMood.happy], reason: 'stays happy');
  });

  testWidgets('more money, more notes', (tester) async {
    var small = 0, big = 0;
    await tester.pumpWidget(app(MoneyTransferView(key: const ValueKey(1), catalog: catalog, from: from, to: to, amount: 50, onNoteLanded: (_, n) => small = n)));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(MoneyTransferView(key: const ValueKey(2), catalog: catalog, from: from, to: to, amount: 10000000, onNoteLanded: (_, n) => big = n)));
    await tester.pumpAndSettle();
    expect(small, 5);
    expect(big, 16);
  });

  testWidgets('reduce motion jumps to the happy ending', (tester) async {
    var completed = 0;
    await tester.pumpWidget(app(reduceMotion: true,
        MoneyTransferView(catalog: catalog, from: from, to: to, amount: 500, onComplete: () => completed++)));
    await tester.pump();
    expect(moods(tester), [CritterMood.happy, CritterMood.happy]);
    expect(completed, 1);
  });

  testWidgets('unknown species renders nothing', (tester) async {
    await tester.pumpWidget(app(MoneyTransferView(catalog: catalog, from: const CritterSpec(species: 'nope'), to: to, amount: 1)));
    expect(find.byType(CritterView), findsNothing);
  });

  testWidgets('golden: notes mid-flight', (tester) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app(MoneyTransferView(catalog: catalog, from: from, to: to, amount: 5000)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));   // let flutter_svg decode
    await tester.pump(const Duration(milliseconds: 1700));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/money_transfer_flight.png'));
    await tester.pump(const Duration(milliseconds: 2400));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));   // happy faces recompose
    await tester.pump();
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/money_transfer_done.png'));
    await tester.pumpAndSettle();
  });
}
