import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_resource.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';

import 'support/sequence_dice_roller.dart';

void main() {
  final character = Character(
    name: 'Rest Tester',
    characterClass: 'Adventurer',
    level: 1,
    currentHp: 5,
    maxHp: 20,
    armourClass: 12,
    initiativeModifier: 0,
    status: 'Exploring',
    resources: const [
      CharacterResource(
        id: 'short',
        name: 'Short Resource',
        maximum: 2,
        initialValue: 2,
        rechargePeriod: RechargePeriod.shortRest,
      ),
      CharacterResource(
        id: 'long',
        name: 'Long Resource',
        maximum: 3,
        initialValue: 3,
        rechargePeriod: RechargePeriod.longRest,
      ),
      CharacterResource(
        id: 'manual',
        name: 'Manual Resource',
        maximum: 1,
        initialValue: 1,
        rechargePeriod: RechargePeriod.manual,
      ),
    ],
  );
  const state = CharacterState(
    currentHp: 5,
    maxHp: 20,
    temporaryHp: 3,
    armourClass: 12,
    initiativeModifier: 0,
    deathSaveSuccesses: 2,
    deathSaveFailures: 1,
    activeConditions: {'Poisoned'},
    pinnedActionKeys: {},
    resourceValues: {'short': 0, 'long': 1, 'manual': 0},
  );

  test('hit dice heal, survive a save, and recover on a long rest', () {
    final short =
        RestPlan.forCharacter(
          type: RestType.shortRest,
          character: character,
          currentState: state,
        ).spendHitDice(
          character: character,
          count: 3,
          roller: SequenceDiceRoller([6]),
        );
    expect(short.updatedState.currentHp, 11);
    expect(short.updatedState.hitDiceSpent, 1);
    final restored = CharacterState.fromJson(short.updatedState.toJson());
    expect(RestPlan.availableHitDice(character, restored), 0);

    final long = RestPlan.forCharacter(
      type: RestType.longRest,
      character: character,
      currentState: restored,
    );
    expect(long.updatedState.hitDiceSpent, 0);
    expect(RestPlan.availableHitDice(character, long.updatedState), 1);
  });

  test('short rest only refills short-rest resources', () {
    final plan = RestPlan.forCharacter(
      type: RestType.shortRest,
      character: character,
      currentState: state,
    );

    expect(plan.updatedState.resourceValues, {
      'short': 2,
      'long': 1,
      'manual': 0,
    });
    expect(plan.updatedState.currentHp, 5);
    expect(plan.updatedState.temporaryHp, 3);
    expect(plan.updatedState.deathSaveSuccesses, 2);
    expect(plan.updatedState.activeConditions, {'Poisoned'});
    expect(plan.changes, ['Short Resource: 0 → 2']);
  });

  test('long rest restores health, saves, and eligible resources', () {
    final plan = RestPlan.forCharacter(
      type: RestType.longRest,
      character: character,
      currentState: state,
    );

    expect(plan.updatedState.resourceValues, {
      'short': 2,
      'long': 3,
      'manual': 0,
    });
    expect(plan.updatedState.currentHp, 20);
    expect(plan.updatedState.temporaryHp, 0);
    expect(plan.updatedState.deathSaveSuccesses, 0);
    expect(plan.updatedState.deathSaveFailures, 0);
    expect(plan.updatedState.activeConditions, {'Poisoned'});
    expect(plan.changes, contains('Death saves cleared'));
  });
}
