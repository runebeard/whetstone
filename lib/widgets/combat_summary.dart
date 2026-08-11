import 'dart:math';

import 'package:flutter/material.dart';

import '../models/character_state.dart';
import 'ac_box.dart';
import 'conditions_box.dart';
import 'conditions_dialog.dart';
import 'death_save_box.dart';
import 'hp_box.dart';
import 'initiative_box.dart';
import 'initiative_roll_dialog.dart';
import 'stat_edit_dialog.dart';

class CombatSummary extends StatefulWidget {
  final CharacterState characterState;
  final ValueChanged<CharacterState> onChanged;
  final int Function()? rollD20;

  const CombatSummary({
    super.key,
    required this.characterState,
    required this.onChanged,
    this.rollD20,
  });

  @override
  State<CombatSummary> createState() => _CombatSummaryState();
}

class _CombatSummaryState extends State<CombatSummary> {
  final Random random = Random();

  CharacterState get characterState => widget.characterState;

  void changeHp(int newHp) {
    widget.onChanged(
      characterState.copyWith(currentHp: newHp.clamp(0, characterState.maxHp)),
    );
  }

  void addSuccess() {
    if (characterState.deathSaveSuccesses < 3) {
      widget.onChanged(
        characterState.copyWith(
          deathSaveSuccesses: characterState.deathSaveSuccesses + 1,
        ),
      );
    }
  }

  void addFailure() {
    if (characterState.deathSaveFailures < 3) {
      widget.onChanged(
        characterState.copyWith(
          deathSaveFailures: characterState.deathSaveFailures + 1,
        ),
      );
    }
  }

  void removeDeathSaveSuccess() {
    if (characterState.deathSaveSuccesses > 0) {
      widget.onChanged(
        characterState.copyWith(
          deathSaveSuccesses: characterState.deathSaveSuccesses - 1,
        ),
      );
    }
  }

  void removeDeathSaveFailure() {
    if (characterState.deathSaveFailures > 0) {
      widget.onChanged(
        characterState.copyWith(
          deathSaveFailures: characterState.deathSaveFailures - 1,
        ),
      );
    }
  }

  void applyDamage(int damage) {
    if (damage <= 0) return;

    final damageAbsorbedByTempHp = damage > characterState.temporaryHp
        ? characterState.temporaryHp
        : damage;
    final remainingDamage = damage - damageAbsorbedByTempHp;

    widget.onChanged(
      characterState.copyWith(
        temporaryHp: characterState.temporaryHp - damageAbsorbedByTempHp,
        currentHp: (characterState.currentHp - remainingDamage).clamp(
          0,
          characterState.maxHp,
        ),
      ),
    );
  }

  void applyHealing(int healing) {
    if (healing <= 0) return;

    final currentHp = (characterState.currentHp + healing).clamp(
      0,
      characterState.maxHp,
    );

    widget.onChanged(
      characterState.copyWith(
        currentHp: currentHp,
        deathSaveSuccesses: currentHp > 0
            ? 0
            : characterState.deathSaveSuccesses,
        deathSaveFailures: currentHp > 0 ? 0 : characterState.deathSaveFailures,
      ),
    );
  }

  void applyTemporaryHp(int newTemporaryHp) {
    if (newTemporaryHp <= characterState.temporaryHp) return;

    widget.onChanged(characterState.copyWith(temporaryHp: newTemporaryHp));
  }

  void changeMaxHp(int newMaxHp) {
    if (newMaxHp <= 0) {
      return;
    }

    widget.onChanged(
      characterState.copyWith(
        maxHp: newMaxHp,
        currentHp: characterState.currentHp.clamp(0, newMaxHp),
      ),
    );
  }

  Future<void> editMaxHp(BuildContext context) async {
    final newMaxHp = await showDialog<int>(
      context: context,
      builder: (context) => StatEditDialog(initialValue: characterState.maxHp),
    );

    if (newMaxHp != null) {
      changeMaxHp(newMaxHp);
    }
  }

  Future<void> editArmourClass(BuildContext context) async {
    final newArmourClass = await showDialog<int>(
      context: context,
      builder: (context) =>
          StatEditDialog(initialValue: characterState.armourClass),
    );

    if (newArmourClass != null) {
      widget.onChanged(characterState.copyWith(armourClass: newArmourClass));
    }
  }

  Future<void> editInitiativeModifier(BuildContext context) async {
    final newInitiativeModifier = await showDialog<int>(
      context: context,
      builder: (context) => StatEditDialog(
        initialValue: characterState.initiativeModifier,
        allowNegative: true,
        allowZero: true,
      ),
    );

    if (newInitiativeModifier != null) {
      widget.onChanged(
        characterState.copyWith(initiativeModifier: newInitiativeModifier),
      );
    }
  }

  int rollD20() => widget.rollD20?.call() ?? random.nextInt(20) + 1;

  Future<void> showInitiativeRoll(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => InitiativeRollDialog(
        initiativeModifier: characterState.initiativeModifier,
        rollD20: rollD20,
      ),
    );
  }

  Future<void> editConditions(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => ConditionsDialog(
        activeConditions: characterState.activeConditions,
        onChanged: (conditions) {
          widget.onChanged(
            characterState.copyWith(activeConditions: conditions),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Combat Summary',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: HpBox(
                    currentHp: characterState.currentHp,
                    maxHp: characterState.maxHp,
                    temporaryHp: characterState.temporaryHp,
                    onDamage: applyDamage,
                    onHealing: applyHealing,
                    onTemporaryHp: applyTemporaryHp,
                    onLongPress: () {
                      editMaxHp(context);
                    },
                  ),
                ),
                Expanded(
                  child: AcBox(
                    armourClass: characterState.armourClass,
                    onLongPress: () => editArmourClass(context),
                  ),
                ),
                Expanded(
                  child: InitiativeBox(
                    initiativeModifier: characterState.initiativeModifier,
                    onTap: () => showInitiativeRoll(context),
                    onLongPress: () => editInitiativeModifier(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 150,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: DeathSaveBox(
                      successes: characterState.deathSaveSuccesses,
                      failures: characterState.deathSaveFailures,
                      isActive: characterState.currentHp == 0,
                      onSuccessTap: addSuccess,
                      onFailureTap: addFailure,
                      onSuccessLongPress: removeDeathSaveSuccess,
                      onFailureLongPress: removeDeathSaveFailure,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ConditionsBox(
                      activeConditions: characterState.activeConditions,
                      onTap: () => editConditions(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
