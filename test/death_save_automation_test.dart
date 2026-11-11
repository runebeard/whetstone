import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/character_state.dart';

void main() {
  const downed = CharacterState(
    currentHp: 0,
    maxHp: 10,
    temporaryHp: 2,
    armourClass: 10,
    initiativeModifier: 0,
    deathSaveSuccesses: 2,
    deathSaveFailures: 0,
    activeConditions: {},
    pinnedActionKeys: {},
    resourceValues: {},
  );

  test('death saves handle ordinary rolls and natural extremes', () {
    expect(downed.applyDeathSave(9).deathSaveFailures, 1);
    expect(downed.applyDeathSave(1).deathSaveFailures, 2);
    final stable = downed.applyDeathSave(10);
    expect(stable.deathSaveSuccesses, 3);
    expect(stable.applyDeathSave(20), same(stable));
    final revived = downed.applyDeathSave(20);
    expect(revived.currentHp, 1);
    expect(revived.deathSaveSuccesses, 0);
    expect(revived.deathSaveFailures, 0);
  });

  test('damage applies failed saves only after reaching zero HP', () {
    expect(downed.takeDamage(2).deathSaveFailures, 0);
    expect(downed.takeDamage(3).deathSaveFailures, 1);
    expect(downed.takeDamage(3, critical: true).deathSaveFailures, 2);
    expect(downed.copyWith(currentHp: 1).takeDamage(3).deathSaveFailures, 0);
    final stable = downed.applyDeathSave(10);
    final hit = stable.takeDamage(3);
    expect(hit.deathSaveSuccesses, 0);
    expect(hit.canRollDeathSave, isTrue);
  });
}
