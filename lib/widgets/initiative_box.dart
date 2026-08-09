import 'package:flutter/material.dart';

import 'stat_box.dart';

class InitiativeBox extends StatelessWidget {
  final int initiativeModifier;
  final VoidCallback onLongPress;
  final VoidCallback? onTap;

  const InitiativeBox({
    super.key,
    required this.initiativeModifier,
    required this.onLongPress,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final displayValue = initiativeModifier > 0
        ? '+$initiativeModifier'
        : '$initiativeModifier';

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: StatBox(title: '⚡ Init', value: displayValue),
    );
  }
}
