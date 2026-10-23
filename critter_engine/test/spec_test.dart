import 'package:critter_engine/critter_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parses the full payload', () {
    final s = CritterSpec.fromJson({
      'v': 1,
      'species': 'blip',
      'form': 1,
      'xp': 230,
      'attachments': {'hat': 'crown', 'eyes': 'goggles', 'neck': 'gold_chain', 'prop': 'gold_bar'},
      'behaviour': {'likesPets': false, 'gait': 'hop', 'state': 'walk'},
    });
    expect(s.species, 'blip');
    expect(s.form, 1);
    expect(s.xp, 230);
    expect(s.attachments, const CritterAttachments(hat: 'crown', eyes: 'goggles', neck: 'gold_chain', prop: 'gold_bar'));
    expect(s.behaviour, const CritterBehaviour(likesPets: false, gait: 'hop', state: 'walk'));
  });

  test('missing fields fall back to defaults instead of throwing', () {
    final s = CritterSpec.fromJson({'species': 'blip'});
    expect(s.form, 0);
    expect(s.xp, isNull);
    expect(s.attachments, const CritterAttachments());
    expect(s.behaviour, const CritterBehaviour());
  });

  test('round-trips through json and compares by value', () {
    const s = CritterSpec(species: 'tri', form: 2, xp: 12, attachments: CritterAttachments(hat: 'cap'));
    expect(CritterSpec.fromJson(s.toJson()), s);
    expect(s.copyWith(form: 1), isNot(s));
  });
}
