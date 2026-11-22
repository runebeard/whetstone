import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'support/sequence_dice_roller.dart';

const ray = Spell(
  id: 'sorc-ray',
  name: 'Sorcerer Ray',
  level: 0,
  prepared: true,
  summary: 'A ray.',
  rollModifier: 5,
  castingAbility: Ability.charisma,
);
const otherRay = Spell(
  id: 'other-ray',
  name: 'Other Ray',
  level: 0,
  prepared: true,
  summary: 'Another class ray.',
  rollModifier: 5,
  castingAbility: Ability.charisma,
);
const burst = Spell(
  id: 'sorc-burst',
  name: 'Sorcerer Burst',
  level: 0,
  prepared: true,
  summary: 'A burst.',
  castingAbility: Ability.charisma,
  savingThrowAbility: Ability.dexterity,
);

Future<void> tap(WidgetTester tester, String text) async {
  final finder = text == 'Innate Sorcery'
      ? find.widgetWithText(OutlinedButton, text)
      : find.text(text);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  for (final stunned in [false, true]) {
    testWidgets(
      'Innate activation rejects stunned=$stunned or spent Bonus Action',
      (tester) async {
        final character = seedCharacters.first.copyWith(
          characterClass: 'Sorcerer',
          level: 7,
        );
        final session = CharacterSession(
          characterState: CharacterState.fromCharacter(character).copyWith(
            activeConditions: stunned ? {'Stunned'} : {},
            resourceValues: {innateSorceryResourceId: 2},
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
          usedCombatActions: stunned ? {} : {CombatActionCost.bonusAction},
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: character,
              initialSession: session,
              onCharacterChanged: (_) {},
              onSessionChanged: (_) {},
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Innate Sorcery'),
              )
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Innate DC bonus reaches the target damage-save prompt', (
    tester,
  ) async {
    const spell = Spell(
      id: 'innate-save',
      name: 'Innate Save Burst',
      level: 0,
      prepared: true,
      summary: 'A saving throw burst.',
      castingAbility: Ability.charisma,
      savingThrowAbility: Ability.dexterity,
      rollEffectOnCast: true,
      damageFormula: '1d6',
    );
    final character = seedCharacters.first.copyWith(
      characterClass: 'Sorcerer',
      level: 7,
      proficiencyBonus: 4,
      abilityScores: {
        ...seedCharacters.first.abilityScores,
        Ability.charisma: 16,
      },
      sorcererSpellIds: {spell.id},
      spells: [spell],
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(character).copyWith(
        activeConditions: {innateSorceryCondition},
        conditionTurns: {innateSorceryCondition: 10},
      ),
      inventory: [],
      archivedInventory: [],
    );
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
    await tap(tester, 'Spellbook');
    await tap(tester, spell.name);
    await tap(tester, 'Cast');
    expect(find.textContaining('DC 16 Dexterity save'), findsOneWidget);
    await tap(tester, 'Failed save');
    expect(session.timeline.first.title, 'Innate Save Burst Damage: 4');
    expect(tester.takeException(), isNull);
  });
  test(
    'Spell ownership persists; the live DC bonus never enters saved character definitions',
    () {
      final character = seedCharacters.first.copyWith(
        characterClass: 'Sorcerer',
        level: 7,
        proficiencyBonus: 4,
        abilityScores: {
          ...seedCharacters.first.abilityScores,
          Ability.charisma: 16,
        },
        sorcererSpellIds: {burst.id},
        innateSorceryActive: true,
      );
      expect(character.spellSaveDc(burst), 16);
      expect(character.copyWith(sorcererSpellIds: {}).spellSaveDc(burst), 15);
      final decoded = Character.fromJson(character.toJson());
      expect(decoded.sorcererSpellIds, {burst.id});
      expect(decoded.innateSorceryActive, isFalse);
      expect(decoded.spellSaveDc(burst), 15);
      expect(
        character
            .copyWith(characterClass: 'Warlock')
            .benefitsFromInnateSorcery(burst),
        isFalse,
      );
    },
  );
  test(
    'Innate Sorcery expires after ten turns and rests end it without a Short Rest refill',
    () {
      final character = seedCharacters.first.copyWith(
        characterClass: 'Sorcerer',
        level: 1,
        resources: BuiltInClass.sorcerer.classResources(1, charismaModifier: 0),
      );
      var state = CharacterState.fromCharacter(character).copyWith(
        activeConditions: {innateSorceryCondition},
        conditionTurns: {innateSorceryCondition: 10},
        resourceValues: {innateSorceryResourceId: 0},
      );
      for (var turn = 0; turn < 9; turn++) {
        state = state.advanceConditionTurn();
      }
      expect(state.activeConditions, contains(innateSorceryCondition));
      expect(
        state.advanceConditionTurn().activeConditions,
        isNot(contains(innateSorceryCondition)),
      );
      for (final type in RestType.values) {
        final result = RestPlan.forCharacter(
          type: type,
          character: character,
          currentState: state,
        ).updatedState;
        expect(
          result.activeConditions,
          isNot(contains(innateSorceryCondition)),
        );
        expect(
          result.resourceValues[innateSorceryResourceId],
          type == RestType.longRest ? 2 : 0,
        );
      }
    },
  );
  for (final (level, uses, points, combat, blocked) in [
    (1, 2, 0, false, false),
    (1, 2, 0, true, false),
    (7, 0, 2, true, false),
    (7, 2, 2, true, false),
    (6, 0, 10, true, true),
    (7, 0, 1, true, true),
  ]) {
    testWidgets(
      'Innate Sorcerer $level uses=$uses points=$points combat=$combat',
      (tester) async {
        var character = seedCharacters.first.copyWith(
          characterClass: 'Sorcerer',
          level: level,
          resources: [],
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character).copyWith(
            currentHp: 22,
            resourceValues: {
              innateSorceryResourceId: uses,
              sorceryPointsResourceId: points,
            },
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: combat,
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
        final button = find.widgetWithText(OutlinedButton, 'Innate Sorcery');
        if (blocked) {
          expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
          return;
        }
        await tap(tester, 'Innate Sorcery');
        await tap(tester, 'Cancel');
        expect(
          session.characterState.resourceValues[innateSorceryResourceId],
          uses,
        );
        expect(session.usedCombatActions, isEmpty);
        await tap(tester, 'Innate Sorcery');
        await tap(tester, 'Activate effect');
        expect(
          session.characterState.activeConditions,
          contains(innateSorceryCondition),
        );
        expect(
          session.characterState.conditionTurns[innateSorceryCondition],
          10,
        );
        expect(
          session.characterState.resourceValues[innateSorceryResourceId],
          uses > 0 ? uses - 1 : 0,
        );
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId],
          uses > 0 ? points : points - 2,
        );
        expect(
          session.usedCombatActions,
          combat ? {CombatActionCost.bonusAction} : isEmpty,
        );
        expect(session.characterState.currentHp, 22);
        session = CharacterSession.fromJson(session.toJson());
        generation++;
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(find.text('End Innate Sorcery'), findsOneWidget);
        if (combat) {
          await tap(tester, 'Next Turn');
          expect(
            session.characterState.conditionTurns[innateSorceryCondition],
            9,
          );
        }
        await tap(tester, 'End Innate Sorcery');
        await tap(tester, 'End effect');
        expect(
          session.characterState.activeConditions,
          isNot(contains(innateSorceryCondition)),
        );
        expect(
          session.characterState.conditionTurns.containsKey(
            innateSorceryCondition,
          ),
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Innate attack Advantage applies only to marked spells and cancels Disadvantage',
    (tester) async {
      final character = seedCharacters.first.copyWith(
        characterClass: 'Sorcerer',
        level: 7,
        spells: [ray, otherRay],
        sorcererSpellIds: {ray.id},
        initiallyPinnedActionKeys: {ray.actionKey, otherRay.actionKey},
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(character).copyWith(
          activeConditions: {innateSorceryCondition},
          conditionTurns: {innateSorceryCondition: 10},
        ),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      final dice = SequenceDiceRoller([3, 17, 8, 9]);
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
      Future<void> attack(Spell spell) async {
        final button = find.byKey(
          ValueKey('attack-attacks-${spell.actionKey}'),
        );
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
      }

      await attack(ray);
      expect(dice.index, 2);
      expect(session.timeline.first.detail, contains('Advantage: 3, 17'));
      await tap(tester, 'Next Turn');
      await attack(otherRay);
      expect(dice.index, 3);
      expect(session.timeline.first.detail, isNot(contains('Advantage')));
      await tap(tester, 'Next Turn');
      await tester.tap(find.byTooltip('Next d20 roll: Normal'));
      await tester.pumpAndSettle();
      await tap(tester, 'Disadvantage');
      await attack(ray);
      expect(dice.index, 4);
      expect(session.timeline.first.title, 'Sorcerer Ray Attack: 14');
      expect(session.timeline.first.detail, isNot(contains('Advantage')));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Marking a Sorcerer spell updates only its active save DC and survives reloads',
    (tester) async {
      var character = seedCharacters.first.copyWith(
        characterClass: 'Sorcerer',
        level: 7,
        proficiencyBonus: 4,
        abilityScores: {
          ...seedCharacters.first.abilityScores,
          Ability.charisma: 16,
        },
        spells: [burst],
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(character).copyWith(
          activeConditions: {innateSorceryCondition},
          conditionTurns: {innateSorceryCondition: 10},
        ),
        inventory: [],
        archivedInventory: [],
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
      await tap(tester, 'Spellbook');
      await tap(tester, burst.name);
      expect(find.text('DC 15 Dexterity saving throw'), findsOneWidget);
      await tap(tester, 'Done');
      await tester.longPress(find.text(burst.name));
      await tester.pumpAndSettle();
      await tap(tester, 'Mark as Sorcerer Spell');
      expect(character.sorcererSpellIds, {burst.id});
      await tap(tester, burst.name);
      expect(find.text('DC 16 Dexterity saving throw'), findsOneWidget);
      await tap(tester, 'Done');
      character = Character.fromJson(character.toJson());
      session = CharacterSession.fromJson(session.toJson());
      generation++;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await tap(tester, 'Spellbook');
      await tap(tester, burst.name);
      expect(find.text('DC 16 Dexterity saving throw'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
