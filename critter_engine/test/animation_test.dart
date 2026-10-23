import 'dart:io';

import 'package:critter_engine/critter_engine.dart';
import 'package:critter_engine/src/idle_animation.dart';
import 'package:critter_engine/src/mood.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final catalog = CritterCatalog.fromJsonString(File('assets/critter_catalog.json').readAsStringSync());

  group('idlePose', () {
    test('no mood: only breathing, feet stay on the ground', () {
      for (var t = 0.0; t < 6; t += .1) {
        final p = idlePose(null, t);
        expect(p.by, 0);
        expect(p.lean, 0);
        expect(p.sy, inInclusiveRange(.97, 1.03));
      }
    });

    test('happy bounces up, sad slumps and leans back, rich leans forward', () {
      final happy = [for (var t = 0.0; t < 2; t += .02) idlePose(moodStyles[CritterMood.happy]!.motion, t).by];
      expect(happy.reduce((a, b) => a < b ? a : b), lessThan(-6), reason: 'jumps ~7 up (negative y)');
      expect(happy.every((by) => by <= 0), isTrue, reason: 'never below the ground');
      final sad = idlePose(moodStyles[CritterMood.sad]!.motion, 0);
      expect(sad.sy, lessThan(.95));
      expect(sad.lean, lessThan(0));
      expect(idlePose(moodStyles[CritterMood.rich]!.motion, 0).lean, greaterThan(0));
    });
  });

  Widget app(CritterSpec spec, {bool animate = true, bool reduceMotion = false}) => MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(width: 300, child: CritterView(catalog: catalog, spec: spec, animate: animate)),
        ),
      );
  Iterable<Transform> transforms(WidgetTester t) =>
      t.widgetList<Transform>(find.descendant(of: find.byType(CritterView), matching: find.byType(Transform)));

  testWidgets('animate: the body moves frame to frame and mood particles are painted', (tester) async {
    await tester.pumpWidget(app(const CritterSpec(species: 'v6_pup', form: 4, mood: CritterMood.rich)));
    await tester.pump(const Duration(milliseconds: 100));
    final a = transforms(tester).first.transform.clone();
    await tester.pump(const Duration(milliseconds: 250));
    expect(transforms(tester).first.transform, isNot(a));
    expect(find.descendant(of: find.byType(CritterView), matching: find.byType(CustomPaint)), findsWidgets);
    await tester.pumpWidget(const SizedBox()); // stops the ticker
  });

  testWidgets('every mood animates without errors on every art set', (tester) async {
    for (final species in ['blip', 'tock', 'v6_bloop', 'v6_cute_puff']) {
      for (final mood in CritterMood.values) {
        await tester.pumpWidget(app(CritterSpec(species: species, form: 1, mood: mood)));
        for (var k = 0; k < 40; k++) {
          await tester.pump(const Duration(milliseconds: 100)); // 4 s: long enough for moths, dust and rain to spawn and die
        }
        expect(tester.takeException(), isNull, reason: '$species $mood');
      }
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('still by default and when the OS asks for reduced motion', (tester) async {
    for (final w in [app(const CritterSpec(species: 'blip', mood: CritterMood.happy), animate: false),
                     app(const CritterSpec(species: 'blip', mood: CritterMood.happy), reduceMotion: true)]) {
      await tester.pumpWidget(w);
      await tester.pump(const Duration(seconds: 1));
      expect(transforms(tester), isEmpty);
      expect(tester.hasRunningAnimations, isFalse);
    }
  });

  test('particles come and go', () {
    final c = catalog.characters['v6_bloop_3']!;
    final fx = MoodParticles(moodStyles[CritterMood.sad]!, c, scale: 1, hatWorn: false);
    for (var t = 0.0; t < 1; t += .05) {
      fx.tick(t);
    }
    expect(fx.isEmpty, isFalse, reason: 'rain falls every 160 ms');
  });
}
