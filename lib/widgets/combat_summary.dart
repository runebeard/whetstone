import 'dart:math';

import 'package:flutter/material.dart';

import '../models/character.dart';
import 'ac_box.dart';
import 'conditions_box.dart';
import 'conditions_dialog.dart';
import 'death_save_box.dart';
import 'hp_box.dart';
import 'initiative_box.dart';
import 'initiative_roll_dialog.dart';
import 'stat_edit_dialog.dart';

class CombatSummary extends StatefulWidget {
  final Character character;
  final int Function()? rollD20;

  const CombatSummary({super.key, required this.character, this.rollD20});

  @override
  State<CombatSummary> createState() => _CombatSummaryState();
}

class _CombatSummaryState extends State<CombatSummary> {
  final Random random = Random();
  late int maxHp;
  late int currentHp;
  late int armourClass;
  late int initiativeModifier;
  int temporaryHp = 0;
  int deathSaveSuccesses = 0;
  int deathSaveFailures = 0;
  Set<String> activeConditions = {};

  @override
  void initState() {
    super.initState();
    currentHp = widget.character.currentHp;
    maxHp = widget.character.maxHp;
    armourClass = widget.character.armourClass;
    initiativeModifier = widget.character.initiativeModifier;
  }

  void changeHp(int newHp) {
    setState(() {
      currentHp = newHp.clamp(0, maxHp);
    });
  }

  void addSuccess() {
    if (deathSaveSuccesses < 3) {
      setState(() {
        deathSaveSuccesses++;
      });
    }
  }

  void addFailure() {
    if (deathSaveFailures < 3) {
      setState(() {
        deathSaveFailures++;
      });
    }
  }

  void removeDeathSaveSuccess() {
    setState(() {
      if (deathSaveSuccesses > 0) {
        deathSaveSuccesses--;
      }
    });
  }

  void removeDeathSaveFailure() {
    setState(() {
      if (deathSaveFailures > 0) {
        deathSaveFailures--;
      }
    });
  }

  void applyDamage(int damage) {
    if (damage <= 0) return;

    setState(() {
      final damageAbsorbedByTempHp = damage > temporaryHp
          ? temporaryHp
          : damage;

      temporaryHp -= damageAbsorbedByTempHp;

      final remainingDamage = damage - damageAbsorbedByTempHp;

      currentHp = (currentHp - remainingDamage).clamp(0, maxHp);
    });
  }

  void applyHealing(int healing) {
    if (healing <= 0) return;

    setState(() {
      currentHp = (currentHp + healing).clamp(0, maxHp);

      if (currentHp > 0) {
      deathSaveSuccesses = 0;
      deathSaveFailures = 0;
      }
    });
  }

  void applyTemporaryHp(int newTemporaryHp) {
    if (newTemporaryHp <= temporaryHp) return;

    setState(() {
      temporaryHp = newTemporaryHp;
    });
  }

  void changeMaxHp(int newMaxHp) {
    if (newMaxHp <= 0) {
      return;
    }

    setState(() {
      maxHp = newMaxHp;
      currentHp = currentHp.clamp(0, maxHp);
    });
  }

  Future<void> editMaxHp(BuildContext context) async {
    final newMaxHp = await showDialog<int>(
      context: context,
      builder: (context) => StatEditDialog(initialValue: maxHp),
    );

    if (newMaxHp != null) {
      changeMaxHp(newMaxHp);
    }
  }

  Future<void> editArmourClass(BuildContext context) async {
    final newArmourClass = await showDialog<int>(
      context: context,
      builder: (context) => StatEditDialog(initialValue: armourClass),
    );

    if (newArmourClass != null) {
      setState(() {
        armourClass = newArmourClass;
      });
    }
  }

  Future<void> editInitiativeModifier(BuildContext context) async {
    final newInitiativeModifier = await showDialog<int>(
      context: context,
      builder: (context) => StatEditDialog(
        initialValue: initiativeModifier,
        allowNegative: true,
        allowZero: true,
      ),
    );

    if (newInitiativeModifier != null) {
      setState(() {
        initiativeModifier = newInitiativeModifier;
      });
    }
  }

  int rollD20() => widget.rollD20?.call() ?? random.nextInt(20) + 1;

  Future<void> showInitiativeRoll(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => InitiativeRollDialog(
        initiativeModifier: initiativeModifier,
        rollD20: rollD20,
      ),
    );
  }

  Future<void> editConditions(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => ConditionsDialog(
        activeConditions: activeConditions,
        onChanged: (conditions) {
          setState(() {
            activeConditions = conditions;
          });
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
                    currentHp: currentHp,
                    maxHp: maxHp,
                    temporaryHp: temporaryHp,
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
                    armourClass: armourClass,
                    onLongPress: () => editArmourClass(context),
                  ),
                ),
                Expanded(
                  child: InitiativeBox(
                    initiativeModifier: initiativeModifier,
                    onTap: () => showInitiativeRoll(context),
                    onLongPress: () => editInitiativeModifier(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: DeathSaveBox(
                      successes: deathSaveSuccesses,
                      failures: deathSaveFailures,
                      isActive: currentHp == 0,
                      onSuccessTap: addSuccess,
                      onFailureTap: addFailure,
                      onSuccessLongPress: removeDeathSaveSuccess,
                      onFailureLongPress: removeDeathSaveFailure,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ConditionsBox(
                      activeConditions: activeConditions,
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
