import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/metamagic.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'draconic_spell_grants_test.dart' as helpers;
import 'metamagic_test.dart' as base;

void main() {
  test('Twinned catalog uses verified base levels and target counts', () {
    for (final (name, level, baseTargets) in [
      ('Charm Person', 1, 1),
      ('Hold Person', 2, 1),
      ('Hold Monster', 5, 1),
      ('Invisibility', 2, 1),
      ('Bless', 1, 3),
    ]) {
      final spell = Spell(
        id: name,
        name: name,
        level: level,
        prepared: true,
        summary: 'A spell.',
      );
      expect(Metamagic.supportsTwinned(spell), isTrue);
      expect(Metamagic.twinnedTargetCount(spell, level), baseTargets + 1);
      expect(Metamagic.twinnedTargetCount(spell, level + 1), baseTargets + 2);
      expect(Metamagic.twinnedTargetCount(spell, 9), isNull);
      final wrongLevel = Spell(
        id: name,
        name: name,
        level: level + 1,
        prepared: true,
        summary: 'A changed definition.',
      );
      expect(Metamagic.supportsTwinned(wrongLevel), isFalse);
    }
    for (final name in ['Cure Wounds', 'Fireball', 'Shield', 'Aid']) {
      expect(
        Metamagic.supportsTwinned(
          Spell(
            id: name,
            name: name,
            level: 1,
            prepared: true,
            summary: 'Unsupported spell.',
          ),
        ),
        isFalse,
      );
    }
    expect(Metamagic.durationTurns('Concentration, up to 20 hours'), 12000);
    expect(Metamagic.extendedTurns('Concentration, up to 20 hours'), 14400);
  });
  for (final (name, level, slot, duration, targets, turns) in [
    ('Bless', 1, 1, 'Concentration, up to 1 minute', 4, 10),
    ('Bless', 1, 3, 'Concentration, up to 1 minute', 6, 10),
    ('Invisibility', 2, 3, 'Concentration, up to 1 hour', 3, 600),
    ('Hold Person', 2, 2, 'Concentration, up to 1 minute', 2, 10),
    ('Hold Monster', 5, 5, 'Concentration, up to 1 minute', 2, 10),
  ]) {
    testWidgets(
      'Twinned $name slot=$slot charges original slot and saves $targets target capacity',
      (tester) async {
        final spell = Spell(
          id: name,
          name: name,
          level: level,
          prepared: true,
          concentration: true,
          castingTime: 'Action',
          duration: duration,
          summary: 'A supported spell.',
        );
        var character = base
            .sorcerer(level: 9)
            .copyWith(
              spells: [spell],
              metamagicOptions: {Metamagic.twinned},
              initiallyPinnedActionKeys: {spell.actionKey},
            );
        var session = CharacterSession(
          characterState: CharacterSession.fromCharacter(
            character,
          ).characterState,
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final initialSlots =
            session.characterState.resourceValues[spellSlotId(slot)]!;
        Widget app(int generation) => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(generation),
            character: character,
            initialSession: session,
            onCharacterChanged: (value) => character = value,
            onSessionChanged: (value) => session = value,
          ),
        );
        await tester.pumpWidget(app(0));
        await tester.pumpAndSettle();
        await helpers.tap(tester, find.text(name).first);
        await helpers.tap(tester, find.text('Twinned Spell'));
        await helpers.tap(tester, find.text('Cast with Metamagic'));
        await helpers.tap(
          tester,
          find.text('Level $slot · $initialSlots remaining'),
        );
        expect(
          session.characterState.resourceValues[spellSlotId(slot)],
          initialSlots - 1,
        );
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId],
          8,
        );
        expect(session.usedCombatActions, {CombatActionCost.action});
        expect(session.characterState.concentrationSlotLevel, slot + 1);
        expect(session.characterState.concentrationTurnsRemaining, turns);
        expect(
          session.timeline
              .singleWhere((e) => e.title == 'Twinned Spell targets · $name')
              .detail,
          contains('$targets targets'),
        );
        session = CharacterSession.fromJson(session.toJson());
        await tester.pumpWidget(app(1));
        await tester.pumpAndSettle();
        expect(session.characterState.concentrationSlotLevel, slot + 1);
        expect(session.characterState.concentrationTurnsRemaining, turns);
        expect(character.spells.single.level, level);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
