import 'package:flutter/material.dart';
import 'hp_adjust_dialog.dart';
import 'stat_box.dart';

class HpBox extends StatelessWidget {
  final int currentHp;
  final int maxHp;
  final int temporaryHp;
  final ValueChanged<int> onDamage;
  final ValueChanged<int> onHealing;
  final ValueChanged<int> onTemporaryHp;
  final VoidCallback onLongPress;

  const HpBox({
    super.key,
    required this.currentHp,
    required this.maxHp,
    required this.temporaryHp,
    required this.onDamage,
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
          builder: (context) => const HpAdjustDialog(),
        );

        if (result == null) {
          return;
        }

        switch (result.type) {
          case HpAdjustmentType.damage:
            onDamage(result.amount);
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
