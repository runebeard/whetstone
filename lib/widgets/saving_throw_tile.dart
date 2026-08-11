import 'package:flutter/material.dart';

import '../models/ability.dart';

class SavingThrowTile extends StatelessWidget {
  final SavingThrowCheck check;
  final VoidCallback onTap;

  const SavingThrowTile({super.key, required this.check, required this.onTap});

  String get displayModifier {
    return check.modifier > 0 ? '+${check.modifier}' : '${check.modifier}';
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${check.ability.label} saving throw',
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (check.proficient) ...[
                    const Tooltip(
                      message: 'Proficient',
                      child: Icon(Icons.circle, size: 8),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    check.ability.shortLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    displayModifier,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
