import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'package:whetstone/widgets/hp_box.dart';
import 'support/sequence_dice_roller.dart';

void main() {
  for (final scenario in [
    'boost',
    'failed-boost',
    'decline',
    'success',
    'empty',
    'massive',
    'nonfatal',
    'temporary',
  ]) {
    testWidgets('Own Luck resolves before Relentless Rage: $scenario', (
      tester,
    ) async {
      final temporary = scenario == 'temporary';
      final rolls = scenario == 'massive' || scenario == 'nonfatal'
          ? <int>[]
          : [
              scenario == 'success' ? 12 : 2,
              scenario == 'failed-boost' ? 1 : 8,
            ];
      final uses = scenario == 'empty' ? 0 : 2;
      final character = seedCharacters.first.copyWith(
        characterClass: 'Barbarian',
        level: 17,
        additionalClassLevels: {'Warlock': 6},
        subclasses: {'Warlock': 'Fiend Patron'},
        abilityScores: {
          ...seedCharacters.first.abilityScores,
          Ability.constitution: 10,
          Ability.charisma: 16,
        },
        savingThrowProficiencies: {},
        resources: BuiltInClass.warlock.classResources(
          6,
          charismaModifier: 3,
          subclass: 'Fiend Patron',
        ),
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(character).copyWith(
          currentHp: 10,
          maxHp: 42,
          temporaryHp: temporary ? 5 : 0,
          activeConditions: {ragingCondition},
          conditionTurns: {ragingCondition: 2},
          resourceValues: {darkOnesOwnLuckResourceId: uses},
        ),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
        usedCombatActions: CombatActionCost.values.toSet(),
      );
      final dice = SequenceDiceRoller(rolls);
      Widget app(int generation) => MaterialApp(
        home: CharacterOverview(
          key: ValueKey(generation),
          character: character,
          initialSession: session,
          onCharacterChanged: (_) {},
          onSessionChanged: (value) => session = value,
          diceRoller: dice,
        ),
      );
      await tester.pumpWidget(app(0));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(HpBox));
      await tester.pumpAndSettle();
      final damage = scenario == 'massive'
          ? 52
          : scenario == 'nonfatal'
          ? 4
          : temporary
          ? 15
          : 10;
      await tester.enterText(find.byType(TextField), '$damage');
      await tester.tap(find.text('🗡 Damage'));
      await tester.pumpAndSettle();
      final offered = [
        'boost',
        'failed-boost',
        'decline',
        'temporary',
      ].contains(scenario);
      final boosted = offered && scenario != 'decline';
      if (offered) {
        expect(find.text('Dark One’s Own Luck · Failed save'), findsOneWidget);
        expect(session.characterState.currentHp, 10);
        expect(session.characterState.isRaging, isTrue);
        expect(session.characterState.relentlessRageAttempts, 0);
        expect(
          session.characterState.resourceValues[darkOnesOwnLuckResourceId],
          uses,
        );
        await tester.tap(
          find.text(boosted ? 'Spend use · Boost save' : 'Keep save result'),
        );
        await tester.pumpAndSettle();
      } else {
        expect(find.text('Dark One’s Own Luck · Failed save'), findsNothing);
      }
      final survived =
          scenario == 'boost' || temporary || scenario == 'success';
      expect(
        session.characterState.currentHp,
        scenario == 'nonfatal'
            ? 6
            : survived
            ? 22
            : 0,
      );
      expect(session.characterState.temporaryHp, 0);
      expect(
        session.characterState.isRaging,
        survived || scenario == 'nonfatal',
      );
      expect(
        session.characterState.relentlessRageAttempts,
        scenario == 'massive' || scenario == 'nonfatal' ? 0 : 1,
      );
      expect(
        session.characterState.resourceValues[darkOnesOwnLuckResourceId],
        uses - (boosted ? 1 : 0),
      );
      expect(session.usedCombatActions, CombatActionCost.values.toSet());
      expect(
        dice.index,
        scenario == 'massive' || scenario == 'nonfatal'
            ? 0
            : boosted
            ? 2
            : 1,
      );
      session = CharacterSession.fromJson(session.toJson());
      await tester.pumpWidget(app(1));
      await tester.pumpAndSettle();
      expect(
        session.characterState.resourceValues[darkOnesOwnLuckResourceId],
        uses - (boosted ? 1 : 0),
      );
      expect(
        session.characterState.currentHp,
        scenario == 'nonfatal'
            ? 6
            : survived
            ? 22
            : 0,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
