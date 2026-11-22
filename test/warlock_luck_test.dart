import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/models/skill.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/models/weapon.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'package:whetstone/widgets/hp_box.dart';
import 'package:whetstone/widgets/skill_tile.dart';
import 'support/sequence_dice_roller.dart';

const label = 'Dark One’s Own Luck · Last check or save';
Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'Own Luck uses Charisma minimum one and refreshes only on Long Rest',
    () {
      for (final charisma in [-3, 0, 3]) {
        final resources = BuiltInClass.warlock.classResources(
          6,
          charismaModifier: charisma,
          subclass: 'Fiend Patron',
        );
        expect(
          resources
              .singleWhere((r) => r.id == darkOnesOwnLuckResourceId)
              .maximum,
          charisma < 1 ? 1 : charisma,
        );
        final character = seedCharacters.first.copyWith(
          characterClass: 'Warlock',
          level: 6,
          resources: resources,
        );
        for (final rest in RestType.values) {
          final state = RestPlan.forCharacter(
            character: character,
            currentState: CharacterState.fromCharacter(
              character,
            ).copyWith(resourceValues: {darkOnesOwnLuckResourceId: 0}),
            type: rest,
          ).updatedState;
          expect(
            state.resourceValues[darkOnesOwnLuckResourceId],
            rest == RestType.longRest ? (charisma < 1 ? 1 : charisma) : 0,
          );
        }
      }
    },
  );
  for (final save in [false, true]) {
    testWidgets(
      'Own Luck save=$save spends one use once per roll and preserves natural d20 and actions',
      (tester) async {
        var character = seedCharacters.first.copyWith(
          characterClass: 'Warlock',
          level: 6,
          subclasses: {'Warlock': 'Fiend Patron'},
          abilityScores: {
            ...seedCharacters.first.abilityScores,
            Ability.charisma: 16,
          },
          skillProficiencies: {},
          resources: BuiltInClass.warlock.classResources(
            6,
            charismaModifier: 3,
          ),
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character).copyWith(
            currentHp: 22,
            resourceValues: {darkOnesOwnLuckResourceId: 2},
            activeConditions: save ? {'Stunned'} : {},
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: save,
          usedCombatActions: save ? CombatActionCost.values.toSet() : {},
        );
        var generation = 0;
        final dice = SequenceDiceRoller([3, 7]);
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(generation),
            character: character,
            initialSession: session,
            onCharacterChanged: (v) => character = v,
            onSessionChanged: (v) => session = v,
            diceRoller: dice,
          ),
        );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(
          character.resources
              .singleWhere((r) => r.id == darkOnesOwnLuckResourceId)
              .maximum,
          3,
        );
        final button = find.widgetWithText(OutlinedButton, label);
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        final skill = standardSkills.singleWhere((s) => s.id == 'acrobatics');
        await tap(
          tester,
          save
              ? find.byTooltip('Wisdom saving throw')
              : find.byWidgetPredicate(
                  (w) => w is SkillTile && w.check.skill.id == 'acrobatics',
                ),
        );
        final original =
            3 +
            (save
                ? character.savingThrowFor(Ability.wisdom).modifier
                : character.modifierFor(skill));
        await tap(tester, button);
        await tap(tester, find.text('Cancel'));
        expect(dice.index, 1);
        expect(
          session.characterState.resourceValues[darkOnesOwnLuckResourceId],
          2,
        );
        await tap(tester, button);
        await tap(tester, find.text('Spend use · Add 1d10'));
        expect(
          session.timeline.first.title,
          'Dark One’s Own Luck · ${save ? 'Wisdom Save' : 'Acrobatics'}: ${original + 7}',
        );
        expect(
          session.timeline.first.detail,
          contains('Original d20 3 unchanged'),
        );
        expect(
          session.characterState.resourceValues[darkOnesOwnLuckResourceId],
          1,
        );
        expect(session.characterState.currentHp, 22);
        expect(
          session.usedCombatActions,
          save ? CombatActionCost.values.toSet() : isEmpty,
        );
        expect(dice.index, 2);
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        session = CharacterSession.fromJson(session.toJson());
        generation++;
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        expect(
          session.characterState.resourceValues[darkOnesOwnLuckResourceId],
          1,
        );
      },
    );
  }
  testWidgets(
    'Attacks do not qualify and Next Turn clears an old save candidate',
    (tester) async {
      const blade = Weapon(
        id: 'luck-test',
        name: 'Luck blade',
        attackModifier: 5,
        damage: '1d6',
      );
      final character = seedCharacters.first.copyWith(
        characterClass: 'Warlock',
        level: 6,
        subclasses: {'Warlock': 'Fiend Patron'},
        weapons: [blade],
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(character),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      final dice = SequenceDiceRoller([5, 4]);
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
            diceRoller: dice,
          ),
        ),
      );
      final button = find.widgetWithText(OutlinedButton, label);
      await tap(
        tester,
        find.byKey(ValueKey('attack-attacks-${blade.actionKey}')),
      );
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      await tap(tester, find.byTooltip('Wisdom saving throw'));
      expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
      await tap(tester, find.text('Next Turn'));
      expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      expect(session.characterState.currentHp, character.currentHp);
    },
  );
  testWidgets('Own Luck requires Fiend six and an available use', (
    tester,
  ) async {
    for (final (level, subclass, uses) in [
      (5, 'Fiend Patron', 1),
      (6, 'Other', 1),
      (6, 'Fiend Patron', 0),
    ]) {
      final character = seedCharacters.first.copyWith(
        characterClass: 'Warlock',
        level: level,
        subclasses: {'Warlock': subclass},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            key: ValueKey('$level-$subclass-$uses'),
            character: character,
            initialSession: CharacterSession(
              characterState: CharacterState.fromCharacter(
                character,
              ).copyWith(resourceValues: {darkOnesOwnLuckResourceId: uses}),
              inventory: [],
              archivedInventory: [],
              isInCombat: false,
            ),
            onCharacterChanged: (_) {},
            onSessionChanged: (_) {},
            diceRoller: SequenceDiceRoller([4]),
          ),
        ),
      );
      await tap(
        tester,
        find.byWidgetPredicate(
          (w) => w is SkillTile && w.check.skill.id == 'acrobatics',
        ),
      );
      final button = find.widgetWithText(OutlinedButton, label);
      if (level < 6 || subclass == 'Other') {
        expect(button, findsNothing);
      } else {
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
      }
    }
  });
  testWidgets('Own Luck excludes already-resolved concentration saves', (
    tester,
  ) async {
    final character = seedCharacters.first.copyWith(
      characterClass: 'Warlock',
      level: 6,
      subclasses: {'Warlock': 'Fiend Patron'},
      spells: [
        const Spell(
          id: 'luck-concentration',
          name: 'Test Focus',
          level: 1,
          prepared: true,
          summary: 'Concentration',
          concentration: true,
        ),
      ],
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(
        character,
      ).copyWith(concentrationSpellId: 'luck-concentration'),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: character,
          initialSession: session,
          onCharacterChanged: (_) {},
          onSessionChanged: (v) => session = v,
          diceRoller: SequenceDiceRoller([2]),
        ),
      ),
    );
    await tap(tester, find.byType(HpBox));
    await tester.enterText(find.byType(TextField), '4');
    await tap(tester, find.text('🗡 Damage'));
    await tap(tester, find.text('Roll Save'));
    await tap(tester, find.text('Keep save result'));
    expect(session.characterState.concentrationSpellId, isNull);
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, label))
          .onPressed,
      isNull,
    );
  });
}
