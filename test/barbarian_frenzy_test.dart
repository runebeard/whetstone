import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/main.dart';
import 'package:whetstone/persistence/character_definition_repository.dart';
import 'package:whetstone/persistence/character_session_repository.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/weapon.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'support/sequence_dice_roller.dart';

const blade = Weapon(
  id: 'frenzy-blade',
  name: 'Frenzy blade',
  attackModifier: 5,
  damage: '1d6 + 4',
  damageFormula: '1d6+4',
  damageType: 'slashing',
  usesStrength: true,
  category: WeaponCategory.martialMelee,
);
Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Vault edits preserve pending Reckless declarations and spent Frenzy flags',
    (tester) async {
      for (final pending in [false, true]) {
        final character = seedCharacters.first.copyWith(
          characterClass: 'Barbarian',
          level: 10,
          subclasses: {'Barbarian': 'Path of the Berserker'},
        );
        final definitions = InMemoryCharacterDefinitionRepository();
        await definitions.saveCatalog(
          CharacterDefinitionCatalog(characters: {character.id: character}),
        );
        final sessions = InMemoryCharacterSessionRepository();
        await sessions.saveSessions({
          character.id: CharacterSession(
            characterState: CharacterState.fromCharacter(
              character,
            ).copyWith(currentHp: 22),
            inventory: character.initialInventory,
            archivedInventory: [],
            isInCombat: true,
            attackRollMadeThisTurn: !pending,
            recklessAttackArmed: pending,
            frenzyUsedThisTurn: !pending,
          ),
        });
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          WhetstoneApp(repository: sessions, definitionRepository: definitions),
        );
        await tester.pumpAndSettle();
        await tester.longPress(find.text(character.name));
        await tester.pumpAndSettle();
        await tap(tester, find.text('Edit Character'));
        for (var step = 0; step < 8; step++) {
          await tap(tester, find.byKey(ValueKey('creator-continue-$step')));
        }
        await tap(tester, find.byKey(const ValueKey('creator-save')));
        final saved = (await sessions.loadSessions())[character.id]!;
        expect(saved.recklessAttackArmed, pending);
        expect(saved.attackRollMadeThisTurn, !pending);
        expect(saved.frenzyUsedThisTurn, !pending);
        expect(saved.characterState.currentHp, 22);
      }
    },
  );
  for (final (level, critical, count) in [
    (3, false, 2),
    (9, false, 3),
    (16, false, 4),
    (16, true, 8),
  ]) {
    testWidgets(
      'Frenzy Barbarian $level critical=$critical rolls $count d6 once and persists',
      (tester) async {
        final character = seedCharacters.first.copyWith(
          characterClass: 'Barbarian',
          level: level,
          subclasses: {'Barbarian': 'Path of the Berserker'},
          weapons: [blade],
          resources: BuiltInClass.barbarian.classResources(
            level,
            charismaModifier: 0,
          ),
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character).copyWith(
            currentHp: 22,
            activeConditions: {ragingCondition, recklessAttackCondition},
            conditionTurns: {ragingCondition: 2, recklessAttackCondition: 1},
            resourceValues: {rageResourceId: 1},
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
          attackRollMadeThisTurn: true,
          usedCombatActions: critical ? {} : CombatActionCost.values.toSet(),
        );
        var generation = 0;
        final dice = SequenceDiceRoller([
          if (critical) ...[20, 3, 4, 5] else ...[3, 3],
          ...List.filled(count, 1),
          3,
        ]);
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(generation),
            character: character,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
            diceRoller: dice,
          ),
        );
        await tester.pumpWidget(app());
        final damage = find.byKey(
          ValueKey('damage-attacks-${blade.actionKey}'),
        );
        if (critical) {
          await tap(
            tester,
            find.byKey(ValueKey('attack-attacks-${blade.actionKey}')),
          );
        } else {
          await tap(tester, damage);
          await tap(tester, find.text('Resolve at table'));
          expect(session.frenzyUsedThisTurn, false);
        }
        final originalCosts = {...session.usedCombatActions};
        final originalRemaining = session.attackActionAttacksRemaining;
        await tap(tester, damage);
        expect(find.textContaining('${count}d6 extra damage'), findsOneWidget);
        await tap(tester, find.text('Apply Frenzy damage'));
        expect(session.timeline.first.title, 'Frenzy Damage: $count');
        expect(session.timeline.first.detail, contains('slashing'));
        expect(session.frenzyUsedThisTurn, true);
        expect(session.usedCombatActions, originalCosts);
        expect(session.attackActionAttacksRemaining, originalRemaining);
        expect(session.characterState.currentHp, 22);
        expect(session.characterState.resourceValues[rageResourceId], 1);
        session = CharacterSession.fromJson(session.toJson());
        generation++;
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await tap(tester, damage);
        expect(find.text('Apply Frenzy damage'), findsNothing);
        expect(dice.index, count + (critical ? 5 : 3));
        await tap(tester, find.text('Next Turn'));
        expect(session.frenzyUsedThisTurn, false);
        expect(
          session.characterState.activeConditions.contains(
            recklessAttackCondition,
          ),
          false,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Frenzy applies to confirmed Strength Unarmed Strike damage', (
    tester,
  ) async {
    final character = seedCharacters.first.copyWith(
      characterClass: 'Barbarian',
      level: 3,
      subclasses: {'Barbarian': 'Path of the Berserker'},
      abilityScores: {
        ...seedCharacters.first.abilityScores,
        Ability.strength: 18,
      },
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(
        character,
      ).copyWith(activeConditions: {ragingCondition, recklessAttackCondition}),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    final dice = SequenceDiceRoller([2, 10, 1, 1]);
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
    await tap(tester, find.widgetWithText(OutlinedButton, 'Unarmed Strike'));
    await tap(tester, find.text('Damage').last);
    await tap(tester, find.text('Hit · Apply unarmed damage'));
    await tap(tester, find.text('Apply Frenzy damage'));
    expect(session.timeline.first.title, 'Frenzy Damage: 2');
    expect(session.frenzyUsedThisTurn, true);
    expect(session.usedCombatActions, {CombatActionCost.action});
    expect(dice.index, 4);
  });
  testWidgets(
    'Frenzy requires Berserker three, Rage, Reckless and Strength damage',
    (tester) async {
      for (final (level, subclass, rage, reckless, strength) in [
        (2, 'Path of the Berserker', true, true, true),
        (3, 'Other', true, true, true),
        (3, 'Path of the Berserker', false, true, true),
        (3, 'Path of the Berserker', true, false, true),
        (3, 'Path of the Berserker', true, true, false),
      ]) {
        final weapon = Weapon(
          id: 'frenzy-gate',
          name: 'Gate blade',
          attackModifier: 5,
          damage: '1d6',
          damageFormula: '1d6',
          usesStrength: strength,
        );
        final character = seedCharacters.first.copyWith(
          characterClass: 'Barbarian',
          level: level,
          subclasses: {'Barbarian': subclass},
          weapons: [weapon],
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character).copyWith(
            activeConditions: {
              if (rage) ragingCondition,
              if (reckless) recklessAttackCondition,
            },
          ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        final dice = SequenceDiceRoller([3]);
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              key: ValueKey('$level-$subclass-$rage-$reckless-$strength'),
              character: character,
              initialSession: session,
              onCharacterChanged: (_) {},
              onSessionChanged: (v) => session = v,
              diceRoller: dice,
            ),
          ),
        );
        await tap(
          tester,
          find.byKey(ValueKey('damage-attacks-${weapon.actionKey}')),
        );
        expect(find.text('Apply Frenzy damage'), findsNothing);
        expect(session.frenzyUsedThisTurn, false);
        expect(dice.index, 1);
      }
    },
  );
}
