import 'package:flutter/material.dart';

import 'stat_box.dart';

class AcBox extends StatelessWidget {
  final int armourClass;
  final VoidCallback? onLongPress;

  const AcBox({
    super.key,
    required this.armourClass,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onLongPress: onLongPress,
      child: StatBox(title: '🛡 AC', value: '$armourClass'),
    );
  }
}
