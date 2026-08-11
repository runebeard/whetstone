import 'package:flutter/material.dart';
import 'death_save_pip.dart';

class DeathSaveRow extends StatelessWidget {
  final String title;
  final int filledPips;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const DeathSaveRow({
    super.key,
    required this.title,
    required this.filledPips,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.fade,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 6),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (index) => DeathSavePip(isFilled: index < filledPips),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
