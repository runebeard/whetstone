import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/class_spells.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'blessed_strikes_test.dart' as fixtures;
import 'draconic_spell_grants_test.dart' as helpers;
import 'support/sequence_dice_roller.dart';

const word = Spell(
  id: 'cleric-word',
  name: 'Radiant Word',
  level: 0,
  prepared: true,
  castingAbility: Ability.wisdom,
  castingTime: 'Action',
  damageFormula: '1d8',
  damageType: 'Radiant',
  rollEffectOnCast: true,
  savingThrowAbility: Ability.dexterity,
  summary: 'Test save cantrip',
);
const bolt = Spell(
  id: 'cleric-bolt',
  name: 'Radiant Bolt',
  level: 0,
  prepared: true,
  castingAbility: Ability.wisdom,
  castingTime: 'Action',
  damageFormula: '1d8',
  damageType: 'Radiant',
  rollModifier: 5,
  summary: 'Test attack cantrip',
);

class Scenario {
  late Character hero;
  late CharacterSession session;
  late SequenceDiceRoller dice;
  late String concentration;
  int generation = 0;
  Future<void> boot(
    WidgetTester tester, {
    Spell spell = word,
    int level = 14,
    int temp = 0,
    int wisdom = 16,
    bool marked = true,
    String? pending,
    List<int>? rolls,
  }) async {
    hero = withBuiltInSpellGrants(
      fixtures
          .cleric(level, BlessedStrikes.potentSpellcasting)
          .copyWith(
            spells: [spell],
            clericCantripIds: marked ? {spell.id} : {},
            initiallyPinnedActionKeys: {spell.actionKey},
            abilityScores: {Ability.wisdom: wisdom},
          ),
    );
    concentration = hero.spells.singleWhere((s) => s.name == 'Bless').id;
    session = CharacterSession(
      characterState: CharacterState.fromCharacter(hero).copyWith(
        currentHp: 13,
        temporaryHp: temp,
        concentrationSpellId: concentration,
        concentrationTurnsRemaining: 8,
        activeConditions: {'Poisoned'},
      ),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
      pendingClericVitalitySpellId: pending,
    );
    dice = SequenceDiceRoller(rolls ?? List.filled(20, 2));
    await reload(tester);
  }

  Future<void> reload(WidgetTester tester) async {
    session = CharacterSession.fromJson(session.toJson());
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          key: ValueKey(generation++),
          character: hero,
          initialSession: session,
          onCharacterChanged: (v) => hero = v,
          onSessionChanged: (v) => session = v,
          diceRoller: dice,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> castWord(WidgetTester tester, {bool succeeds = false}) async {
    await helpers.tap(tester, find.text(word.name).first);
    await helpers.tap(tester, find.text('Cast').last);
    await helpers.tap(
      tester,
      find.text(succeeds ? 'Successful save' : 'Failed save'),
    );
  }
}

void main() {
  for (final (level, wisdom, expected) in [
    (13, 16, 0),
    (14, 16, 6),
    (14, 8, 0),
    (20, 20, 10),
  ]) {
    test('Cleric cantrip vitality level $level Wisdom $wisdom', () {
      final hero = fixtures
          .cleric(level, BlessedStrikes.potentSpellcasting)
          .copyWith(
            clericCantripIds: {word.id},
            abilityScores: {Ability.wisdom: wisdom},
          );
      expect(hero.clericCantripVitalityFor(word), expected);
      expect(
        hero.copyWith(clericCantripIds: {}).clericCantripVitalityFor(word),
        0,
      );
      expect(
        hero
            .copyWith(blessedStrikes: BlessedStrikes.divineStrike)
            .clericCantripVitalityFor(word),
        0,
      );
    });
  }
  for (final temp in [0, 2, 10]) {
    testWidgets(
      'Fresh Cleric cantrip grants self vitality over existing $temp temporary HP',
      (tester) async {
        final s = Scenario();
        await s.boot(tester, temp: temp);
        final resources = {...s.session.characterState.resourceValues};
        await s.castWord(tester);
        expect(
          find.text('Improved Potent Spellcasting · Vitality'),
          findsOneWidget,
        );
        await helpers.tap(tester, find.text('Yourself'));
        expect(s.session.characterState.temporaryHp, temp > 6 ? temp : 6);
        expect(s.session.characterState.currentHp, 13);
        expect(s.session.characterState.activeConditions, {'Poisoned'});
        expect(s.session.characterState.concentrationSpellId, s.concentration);
        expect(s.session.characterState.resourceValues, resources);
        expect(s.session.usedCombatActions, {CombatActionCost.action});
        await s.reload(tester);
        expect(s.session.characterState.temporaryHp, temp > 6 ? temp : 6);
        final damage = find.byKey(
          const ValueKey('damage-attacks-spell:cleric-word'),
        );
        await helpers.tap(tester, damage);
        await helpers.tap(tester, find.text('Failed save'));
        expect(
          find.text('Improved Potent Spellcasting · Vitality'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final target in ['Skip', 'Another creature']) {
    testWidgets(
      'Cleric vitality target $target preserves the caster and cast costs',
      (tester) async {
        final s = Scenario();
        await s.boot(tester, temp: 2);
        await s.castWord(tester);
        await helpers.tap(tester, find.text(target));
        expect(s.session.characterState.temporaryHp, 2);
        expect(s.session.characterState.currentHp, 13);
        expect(s.session.usedCombatActions, {CombatActionCost.action});
        if (target == 'Another creature') {
          expect(
            s.session.timeline.first.detail,
            contains('within 60 feet at the table'),
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final gate in ['low', 'unmarked', 'negative-wisdom', 'saved']) {
    testWidgets('Cleric vitality cannot bypass the $gate gate', (tester) async {
      final s = Scenario();
      await s.boot(
        tester,
        level: gate == 'low' ? 13 : 14,
        marked: gate != 'unmarked',
        wisdom: gate == 'negative-wisdom' ? 8 : 16,
      );
      await s.castWord(tester, succeeds: gate == 'saved');
      expect(
        find.text('Improved Potent Spellcasting · Vitality'),
        findsNothing,
      );
      expect(s.session.characterState.temporaryHp, 0);
      expect(s.session.usedCombatActions, {CombatActionCost.action});
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Attack-cantrip vitality pending damage survives reload and is consumed once',
    (tester) async {
      final s = Scenario();
      await s.boot(tester, spell: bolt, rolls: [12, 3, 4]);
      final attack = find.byKey(
        const ValueKey('attack-attacks-spell:cleric-bolt'),
      );
      await helpers.tap(tester, attack);
      expect(s.session.pendingClericVitalitySpellId, bolt.id);
      await s.reload(tester);
      expect(s.session.pendingClericVitalitySpellId, bolt.id);
      final damage = find.byKey(
        const ValueKey('damage-attacks-spell:cleric-bolt'),
      );
      await helpers.tap(tester, damage);
      await helpers.tap(tester, find.text('Yourself'));
      expect(s.session.pendingClericVitalitySpellId, isNull);
      expect(s.session.characterState.temporaryHp, 6);
      await helpers.tap(tester, damage);
      expect(
        find.text('Improved Potent Spellcasting · Vitality'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
  for (final gate in ['natural-one', 'new-roll', 'next-turn']) {
    testWidgets('Attack-cantrip pending vitality is cleared by $gate', (
      tester,
    ) async {
      final s = Scenario();
      await s.boot(
        tester,
        spell: bolt,
        rolls: [gate == 'natural-one' ? 1 : 12, 12, 3],
      );
      await helpers.tap(
        tester,
        find.byKey(const ValueKey('attack-attacks-spell:cleric-bolt')),
      );
      if (gate == 'new-roll') {
        await helpers.tap(tester, find.byTooltip('Intelligence saving throw'));
      }
      if (gate == 'next-turn') {
        await helpers.tap(tester, find.text('Next Turn'));
      }
      expect(s.session.pendingClericVitalitySpellId, isNull);
      await helpers.tap(
        tester,
        find.byKey(const ValueKey('damage-attacks-spell:cleric-bolt')),
      );
      expect(
        find.text('Improved Potent Spellcasting · Vitality'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
