import 'package:flutter/material.dart';
import '../models/character_state.dart';
import 'hp_adjust_dialog.dart';
import 'stat_box.dart';

class HpBox extends StatelessWidget {
  final int currentHp;
  final int maxHp;
  final int temporaryHp;
  final void Function(int, IncomingDamageType) onDamage;
  final bool showDamageType;
  final void Function(int, IncomingDamageType)? onCriticalDamage;
  final ValueChanged<int> onHealing;
  final ValueChanged<int> onTemporaryHp;
  final VoidCallback onLongPress;

  const HpBox({
    super.key,
    required this.currentHp,
    required this.maxHp,
    required this.temporaryHp,
    required this.onDamage,
    this.showDamageType = false,
    this.onCriticalDamage,
    required this.onHealing,
    required this.onTemporaryHp,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final result = await showDialog<HpAdjustment>(
          context: context,
          builder: (context) => HpAdjustDialog(
            showDamageType: showDamageType,
            showCriticalDamage: currentHp == 0 && onCriticalDamage != null,
          ),
        );

        if (result == null) {
          return;
        }

        switch (result.type) {
          case HpAdjustmentType.damage:
            onDamage(result.amount, result.damageType);
            break;

          case HpAdjustmentType.criticalDamage:
            onCriticalDamage?.call(result.amount, result.damageType);
            break;

          case HpAdjustmentType.healing:
            onHealing(result.amount);
            break;

          case HpAdjustmentType.temporaryHp:
            onTemporaryHp(result.amount);
            break;
        }
      },
      onLongPress: onLongPress,
      child: StatBox(
        title: '❤️ HP',
        value: temporaryHp > 0
            ? '$currentHp / $maxHp\n+$temporaryHp Temp'
            : '$currentHp / $maxHp',
      ),
    );
  }
}
