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
  test(
    'Disciplined Survivor grants all six save proficiencies at Monk fourteen without stacking',
    () {
      final base = seedCharacters.first;
      for (final level in [13, 14]) {
        final monk = base.copyWith(characterClass: 'Monk', level: level);
        for (final ability in Ability.values) {
          final proficient =
              level >= 14 || base.savingThrowProficiencies.contains(ability);
          expect(monk.savingThrowFor(ability).proficient, proficient);
          expect(
            monk.savingThrowFor(ability).modifier,
            monk.abilityModifierFor(ability) +
                (proficient ? monk.proficiencyBonus : 0),
          );
        }
      }
      expect(
        base
            .copyWith(
              characterClass: 'Fighter',
              level: 20,
              additionalClassLevels: {'Monk': 13},
            )
            .savingThrowFor(Ability.charisma)
            .proficient,
        isFalse,
      );
    },
  );
  for (final accept in [false, true]) {
    testWidgets(
      'Ability save reroll accept=$accept keeps lower replacement and spends only Focus',
      (tester) async {
        final monk = seedCharacters.first.copyWith(
          characterClass: 'Monk',
          level: 14,
          resources: BuiltInClass.monk.classResources(14, charismaModifier: 0),
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(monk),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final dice = SequenceDiceRoller([2, 1]);
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: monk,
              initialSession: session,
              onSessionChanged: (value) => session = value,
              onCharacterChanged: (_) {},
              diceRoller: dice,
            ),
          ),
        );
        final save = find.byTooltip('Intelligence saving throw');
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(
            accept ? 'Spend 1 Focus · Reroll Failed Save' : 'Keep Result',
          ),
        );
        await tester.pumpAndSettle();
        expect(
          session.characterState.resourceValues[focusResourceId],
          accept ? 13 : 14,
        );
        expect(
          session.timeline.first.title,
          accept
              ? 'Intelligence Save · Disciplined Survivor: 8'
              : 'Intelligence Save: 9',
        );
        expect(session.usedCombatActions, isEmpty);
        expect(dice.index, accept ? 2 : 1);
      },
    );
  }
  for (final (first, second, accept, successes, failures, hp) in [
    (6, 7, true, 1, 0, 0),
    (6, 1, true, 0, 2, 0),
    (1, 20, true, 0, 0, 1),
    (7, 0, false, 1, 0, 0),
    (1, 0, false, 0, 2, 0),
  ]) {
    testWidgets(
      'Monk death save $first replacement=$second accept=$accept resolves only final result',
      (tester) async {
        final monk = seedCharacters.first.copyWith(
          characterClass: 'Monk',
          level: 14,
          resources: BuiltInClass.monk.classResources(14, charismaModifier: 0),
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            monk,
          ).copyWith(currentHp: 0),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final dice = SequenceDiceRoller([first, second]);
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: monk,
              initialSession: session,
              onSessionChanged: (value) => session = value,
              onCharacterChanged: (_) {},
              diceRoller: dice,
            ),
          ),
        );
        final save = find.byKey(const ValueKey('roll-death-save'));
        await tester.ensureVisible(save);
        await tester.tap(save);
        await tester.pumpAndSettle();
        if (first == 1 || first + 3 < 10) {
          await tester.tap(
            find.text(
              accept ? 'Spend 1 Focus · Reroll Failed Save' : 'Keep Result',
            ),
          );
          await tester.pumpAndSettle();
        } else {
          expect(find.text('Spend 1 Focus · Reroll Failed Save'), findsNothing);
        }
        expect(session.characterState.currentHp, hp);
        expect(session.characterState.deathSaveSuccesses, successes);
        expect(session.characterState.deathSaveFailures, failures);
        expect(
          session.characterState.resourceValues[focusResourceId],
          accept ? 13 : 14,
        );
        expect(session.usedCombatActions, isEmpty);
        expect(dice.index, accept ? 2 : 1);
      },
    );
  }
  for (final second in [1, 12]) {
    testWidgets(
      'Concentration uses Survivor replacement $second before ending the spell',
      (tester) async {
        final monk = seedCharacters.first.copyWith(
          characterClass: 'Monk',
          level: 14,
          resources: BuiltInClass.monk.classResources(14, charismaModifier: 0),
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            monk,
          ).copyWith(concentrationSpellId: 'detect_magic'),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final dice = SequenceDiceRoller([1, second]);
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: monk,
              initialSession: session,
              onSessionChanged: (value) => session = value,
              onCharacterChanged: (_) {},
              diceRoller: dice,
            ),
          ),
        );
        await tester.tap(find.byType(HpBox));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), '4');
        await tester.tap(find.text('🗡 Damage'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Apply damage'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Roll Save'));
        await tester.pumpAndSettle();
        expect(session.characterState.concentrationSpellId, 'detect_magic');
        await tester.tap(find.text('Spend 1 Focus · Reroll Failed Save'));
        await tester.pumpAndSettle();
        expect(
          session.characterState.concentrationSpellId,
          second == 12 ? 'detect_magic' : null,
        );
        expect(session.characterState.resourceValues[focusResourceId], 13);
        expect(session.characterState.currentHp, 30);
        expect(dice.index, 2);
      },
    );
  }
}
