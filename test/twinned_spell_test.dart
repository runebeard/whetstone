import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/class_spells.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_resource.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/metamagic.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'draconic_spell_grants_test.dart' as helpers;

void main() {
  test(
    'Twinned accepts verified target-scaling spells and caps effective levels',
    () {
      final spells = withDraconicSpells(helpers.draconic(9));
      for (final spell in spells) {
        final expected = [
          'Command',
          'Fly',
          'Charm Monster',
        ].contains(spell.name);
        expect(Metamagic.supportsTwinned(spell), expected);
        expect(
          Metamagic.twinnedEffectiveLevel(spell, spell.level),
          expected ? spell.level + 1 : null,
        );
        expect(Metamagic.twinnedEffectiveLevel(spell, 9), isNull);
      }
      expect(
        spells.singleWhere((s) => s.name == 'Command').duration,
        'Instantaneous',
      );
      const customDamage = Spell(
        id: 'custom',
        name: 'Fly',
        level: 3,
        prepared: true,
        damageFormula: '1d6',
        summary: 'An authored damage spell.',
      );
      expect(Metamagic.supportsTwinned(customDamage), isFalse);
    },
  );
  for (final (name, level, slot, slotsBefore, free) in [
    ('Fly', 5, 3, 2, false),
    ('Fly', 7, 4, 1, false),
    ('Command', 3, 1, 4, false),
    ('Charm Monster', 9, 4, 3, false),
    ('Fly', 5, 3, 2, true),
  ]) {
    testWidgets(
      'Twinned $name at slot $slot free=$free charges actual source and records targets',
      (tester) async {
        var character = withDraconicSpellGrants(
          helpers
              .draconic(level)
              .copyWith(metamagicOptions: {Metamagic.twinned}),
        );
        final spell = character.spells.singleWhere((s) => s.name == name);
        character = character.copyWith(
          initiallyPinnedActionKeys: {spell.actionKey},
          resources: [
            ...character.resources,
            if (free)
              CharacterResource(
                id: 'whetstone:free-cast:${spell.id}',
                name: 'Free cast',
                maximum: 1,
                initialValue: 1,
                rechargePeriod: RechargePeriod.longRest,
              ),
          ],
        );
        var session = CharacterSession(
          characterState: CharacterSession.fromCharacter(
            character,
          ).characterState,
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: character,
              initialSession: session,
              onCharacterChanged: (value) => character = value,
              onSessionChanged: (value) => session = value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> begin() async {
          await helpers.tap(tester, find.text(name).first);
          await helpers.tap(tester, find.text('Twinned Spell'));
        }

        await begin();
        await helpers.tap(tester, find.text('Cancel'));
        expect(session.usedCombatActions, isEmpty);
        if (!free) {
          await begin();
          await helpers.tap(tester, find.text('Cast with Metamagic'));
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(
            session.characterState.resourceValues[sorceryPointsResourceId] ??
                level,
            level,
          );
          expect(session.usedCombatActions, isEmpty);
        }
        await begin();
        await helpers.tap(
          tester,
          find.text(free ? 'Use Free Cast' : 'Cast with Metamagic'),
        );
        if (!free) {
          await helpers.tap(
            tester,
            find.text('Level $slot · $slotsBefore remaining'),
          );
        }
        if (spell.savingThrowAbility != null) {
          await helpers.tap(tester, find.text('Failed save'));
        }
        final actual = free ? spell.level : slot;
        final effective = actual + 1;
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId],
          level - 1,
        );
        expect(
          session.characterState.resourceValues[spellSlotId(slot)],
          free ? slotsBefore : slotsBefore - 1,
        );
        expect(session.usedCombatActions, {CombatActionCost.action});
        final event = session.timeline.singleWhere(
          (e) => e.title == 'Twinned Spell targets · $name',
        );
        expect(event.detail, contains('Effective level $effective'));
        expect(
          event.detail,
          contains('${1 + effective - spell.level} targets'),
        );
        if (spell.concentration) {
          expect(session.characterState.concentrationSlotLevel, effective);
          expect(
            CharacterSession.fromJson(
              session.toJson(),
            ).characterState.concentrationSlotLevel,
            effective,
          );
          expect(session.characterState.concentrationTurnsRemaining, 100);
        }
        expect(
          character.spells.singleWhere((s) => s.id == spell.id).level,
          spell.level,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Twinned does not spend ninth-level slot when no lower slots remain',
    (tester) async {
      var character = withDraconicSpellGrants(
        helpers.draconic(20).copyWith(metamagicOptions: {Metamagic.twinned}),
      );
      final spell = character.spells.singleWhere((s) => s.name == 'Fly');
      character = character.copyWith(
        initiallyPinnedActionKeys: {spell.actionKey},
      );
      var session = CharacterSession(
        characterState: CharacterSession.fromCharacter(character).characterState
            .copyWith(
              resourceValues: {
                for (var i = 1; i <= 9; i++) spellSlotId(i): i == 9 ? 1 : 0,
                sorceryPointsResourceId: 20,
              },
            ),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            onCharacterChanged: (value) => character = value,
            onSessionChanged: (value) => session = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text('Fly').first);
      await helpers.tap(tester, find.text('Twinned Spell'));
      await helpers.tap(tester, find.text('Cast with Metamagic'));
      expect(session.characterState.resourceValues[spellSlotId(9)], 1);
      expect(
        session.characterState.resourceValues[sorceryPointsResourceId],
        20,
      );
      expect(session.usedCombatActions, isEmpty);
      expect(session.characterState.concentrationSpellId, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
