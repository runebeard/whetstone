import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'package:whetstone/widgets/hp_box.dart';
import 'support/sequence_dice_roller.dart';

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final half in [false, true]) {
    testWidgets(
      'Cold affinity adds only to Ice Storm cold component before half=$half',
      (tester) async {
        final character = seedCharacters.first.copyWith(
          characterClass: 'Sorcerer',
          level: 13,
          additionalClassLevels: {'Druid': 7},
          subclasses: {
            'Sorcerer': 'Draconic Sorcery',
            'Druid': 'Circle of the Land',
          },
          elementalAffinity: DraconicAffinity.cold,
          resources: fullCasterSlots(7),
          abilityScores: {
            ...seedCharacters.first.abilityScores,
            Ability.charisma: 16,
          },
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            character,
          ).copyWith(druidLand: DruidLand.polar),
          inventory: [],
          archivedInventory: [],
        );
        final dice = SequenceDiceRoller([3, 4, 1, 2, 3, 4]);
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: character,
              initialSession: session,
              onCharacterChanged: (_) {},
              onSessionChanged: (value) => session = value,
              diceRoller: dice,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tap(tester, find.text('Spellbook'));
        await tap(tester, find.text('Ice Storm'));
        await tap(tester, find.text('Cast'));
        await tap(tester, find.text('Level 4 · 1 remaining'));
        await tap(tester, find.text(half ? 'Successful save' : 'Failed save'));
        await tap(tester, find.text('Apply Charisma bonus'));
        expect(
          session.timeline.first.title,
          'Ice Storm Damage: ${half ? 9 : 20}',
        );
        expect(
          session.timeline.first.detail,
          contains(half ? '3 bludgeoning + 6 cold' : '7 bludgeoning + 13 cold'),
        );
        expect(session.characterState.resourceValues[spellSlotId(4)], 0);
        expect(dice.index, 6);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Nonmatching spell damage receives no affinity prompt or bonus', (
    tester,
  ) async {
    const spell = Spell(
      id: 'cold-burst',
      name: 'Cold Burst',
      level: 0,
      prepared: true,
      summary: 'Cold.',
      damageFormula: '1d6',
      damageType: 'cold',
      rollEffectOnCast: true,
    );
    final character = seedCharacters.first.copyWith(
      characterClass: 'Sorcerer',
      level: 6,
      subclasses: {'Sorcerer': 'Draconic Sorcery'},
      elementalAffinity: DraconicAffinity.fire,
      spells: [spell],
    );
    var session = CharacterSession.fromCharacter(character);
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: character,
          initialSession: session,
          onCharacterChanged: (_) {},
          onSessionChanged: (value) => session = value,
          diceRoller: SequenceDiceRoller([4]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, find.text('Spellbook'));
    await tap(tester, find.text(spell.name));
    await tap(tester, find.text('Cast'));
    expect(find.text('Apply Charisma bonus'), findsNothing);
    expect(session.timeline.first.title, 'Cold Burst Damage: 4');
    expect(session.elementalAffinityUsedSpellIds, isEmpty);
    expect(tester.takeException(), isNull);
  });
  test(
    'Affinity choice decodes safely and multiple passive resistances halve only once',
    () {
      final character = seedCharacters.first.copyWith(
        characterClass: 'Sorcerer',
        level: 16,
        additionalClassLevels: {'Druid': 10},
        subclasses: {
          'Sorcerer': 'Draconic Sorcery',
          'Druid': 'Circle of the Land',
        },
        elementalAffinity: DraconicAffinity.fire,
      );
      expect(
        Character.fromJson(character.toJson()).elementalAffinity,
        DraconicAffinity.fire,
      );
      expect(
        Character.fromJson({
          ...character.toJson(),
          'elementalAffinity': 'force',
        }).elementalAffinity,
        isNull,
      );
      final state = CharacterState.fromCharacter(character).copyWith(
        druidLand: DruidLand.polar,
        fiendishResistance: IncomingDamageType.fire,
        activeConditions: {'Stunned'},
      );
      final types = state.classResistancesFor(character);
      expect(types, {IncomingDamageType.fire, IncomingDamageType.cold});
      for (final type in IncomingDamageType.values) {
        expect(
          state.damageAfterResistance(15, type, additionalResistances: types),
          types.contains(type) ? 7 : 15,
        );
      }
      expect(state.classResistancesFor(character.copyWith(level: 15)), {
        IncomingDamageType.cold,
      });
      expect(
        state.classResistancesFor(
          character.copyWith(subclasses: {'Sorcerer': 'Other'}),
        ),
        isEmpty,
      );
    },
  );
  for (final affinity in DraconicAffinity.values) {
    testWidgets(
      'Choose ${affinity.label}, retain choice and apply typed HP resistance',
      (tester) async {
        var character = seedCharacters.first.copyWith(
          characterClass: 'Sorcerer',
          level: 6,
          subclasses: {'Sorcerer': 'Draconic Sorcery'},
        );
        final combat = affinity == DraconicAffinity.fire;
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            character,
          ).copyWith(currentHp: 42),
          inventory: [],
          archivedInventory: [],
          isInCombat: combat,
          usedCombatActions: combat ? CombatActionCost.values.toSet() : {},
        );
        var generation = 0;
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(generation),
            character: character,
            initialSession: session,
            onCharacterChanged: (value) => character = value,
            onSessionChanged: (value) => session = value,
          ),
        );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        final choose = find.widgetWithText(
          OutlinedButton,
          'Elemental Affinity · Choose damage type',
        );
        await tap(tester, choose);
        await tap(tester, find.text('Cancel'));
        expect(character.elementalAffinity, isNull);
        await tap(tester, choose);
        await tap(
          tester,
          find.widgetWithText(SimpleDialogOption, affinity.label),
        );
        expect(character.elementalAffinity, affinity);
        expect(
          session.usedCombatActions,
          combat ? CombatActionCost.values.toSet() : isEmpty,
        );
        character = Character.fromJson(character.toJson());
        session = CharacterSession.fromJson(session.toJson());
        generation++;
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await tap(
          tester,
          find.widgetWithText(
            OutlinedButton,
            'Elemental Affinity · ${affinity.label}',
          ),
        );
        expect(find.byType(SimpleDialogOption), findsNothing);
        await tap(tester, find.text('Done'));
        await tap(tester, find.byType(HpBox));
        await tester.enterText(find.byType(TextField), '9');
        await tap(
          tester,
          find.byType(DropdownButtonFormField<IncomingDamageType>),
        );
        await tap(tester, find.text(affinity.label).last);
        await tap(tester, find.text('🗡 Damage'));
        expect(session.characterState.currentHp, 38);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final (half, accept, charisma) in [
    (false, true, 16),
    (true, true, 16),
    (false, false, 16),
    (false, true, 6),
  ]) {
    testWidgets(
      'Affinity bonus before half=$half accepted=$accept Charisma=$charisma persists once per cast',
      (tester) async {
        const spell = Spell(
          id: 'affinity-burst',
          name: 'Affinity Burst',
          level: 0,
          prepared: true,
          summary: 'Fire burst.',
          damageFormula: '1d6',
          damageType: 'fire',
          rollEffectOnCast: true,
          savingThrowAbility: Ability.dexterity,
          halfDamageOnSave: true,
        );
        var character = seedCharacters.first.copyWith(
          characterClass: 'Sorcerer',
          level: 6,
          subclasses: {'Sorcerer': 'Draconic Sorcery'},
          elementalAffinity: DraconicAffinity.fire,
          abilityScores: {
            ...seedCharacters.first.abilityScores,
            Ability.charisma: charisma,
          },
          spells: [spell],
        );
        var session = CharacterSession.fromCharacter(character);
        final dice = SequenceDiceRoller([charisma == 6 ? 1 : 6, 5, 4]);
        var generation = 0;
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(generation),
            character: character,
            initialSession: session,
            onCharacterChanged: (value) => character = value,
            onSessionChanged: (value) => session = value,
            diceRoller: dice,
          ),
        );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await tap(tester, find.text('Spellbook'));
        Future<void> damage(bool cast) async {
          await tap(tester, find.text(spell.name));
          await tap(tester, find.text(cast ? 'Cast' : 'Roll Damage'));
          await tap(
            tester,
            find.text(half ? 'Successful save' : 'Failed save'),
          );
        }

        await damage(true);
        await tap(
          tester,
          find.text(accept ? 'Apply Charisma bonus' : 'Keep for another roll'),
        );
        expect(
          session.timeline.first.title,
          'Affinity Burst Damage: ${charisma == 6
              ? 0
              : half
              ? 4
              : accept
              ? 9
              : 6}',
        );
        expect(
          session.elementalAffinityUsedSpellIds.contains(spell.id),
          accept,
        );
        character = Character.fromJson(character.toJson());
        session = CharacterSession.fromJson(session.toJson());
        generation++;
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await tap(tester, find.text('Spellbook'));
        await damage(false);
        if (!accept) {
          await tap(tester, find.text('Apply Charisma bonus'));
        } else {
          expect(find.text('Apply Charisma bonus'), findsNothing);
        }
        expect(
          session.timeline.first.title,
          'Affinity Burst Damage: ${half
              ? 2
              : accept
              ? 5
              : 8}',
        );
        await damage(true);
        await tap(tester, find.text('Apply Charisma bonus'));
        expect(
          session.timeline.first.title,
          'Affinity Burst Damage: ${charisma == 6
              ? 2
              : half
              ? 3
              : 7}',
        );
        expect(dice.index, 3);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Critical affinity adds Charisma once without doubling its flat bonus',
    (tester) async {
      const spell = Spell(
        id: 'affinity-ray',
        name: 'Affinity Ray',
        level: 0,
        prepared: true,
        summary: 'A fiery ray.',
        damageFormula: '1d6',
        damageType: 'fire',
        rollModifier: 5,
        castingTime: '1 action',
      );
      final character = seedCharacters.first.copyWith(
        characterClass: 'Sorcerer',
        level: 6,
        subclasses: {'Sorcerer': 'Draconic Sorcery'},
        elementalAffinity: DraconicAffinity.fire,
        abilityScores: {
          ...seedCharacters.first.abilityScores,
          Ability.charisma: 16,
        },
        spells: [spell],
        initiallyPinnedActionKeys: {spell.actionKey},
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(character),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      final dice = SequenceDiceRoller([20, 2, 3]);
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (value) => session = value,
            diceRoller: dice,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(
        tester,
        find.byKey(ValueKey('attack-attacks-${spell.actionKey}')),
      );
      await tap(
        tester,
        find.byKey(ValueKey('damage-attacks-${spell.actionKey}')),
      );
      await tap(tester, find.text('Apply Charisma bonus'));
      expect(session.timeline.first.title, 'Affinity Ray Critical Damage: 8');
      expect(dice.index, 3);
      expect(session.usedCombatActions, {CombatActionCost.action});
      expect(tester.takeException(), isNull);
    },
  );
}
