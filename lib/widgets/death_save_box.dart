import 'package:flutter/material.dart';
import 'death_save_row.dart';

class DeathSaveBox extends StatelessWidget {
  final int successes;
  final int failures;
  final bool isActive;
  final VoidCallback onSuccessTap;
  final VoidCallback onFailureTap;
  final VoidCallback onSuccessLongPress;
  final VoidCallback onFailureLongPress;

  const DeathSaveBox({
    super.key,
    required this.successes,
    required this.failures,
    required this.isActive,
    required this.onSuccessTap,
    required this.onFailureTap,
    required this.onSuccessLongPress,
    required this.onFailureLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '☠ Death Saves',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Opacity(
              opacity: isActive ? 1.0 : 0.4,
              child: IgnorePointer(
                ignoring: !isActive,
                child: Column(
                  children: [
                    DeathSaveRow(
                      title: 'Successes',
                      filledPips: successes,
                      onTap: onSuccessTap,
                      onLongPress: onSuccessLongPress,
                    ),
                    const SizedBox(height: 2),
                    DeathSaveRow(
                      title: 'Failures',
                      filledPips: failures,
                      onTap: onFailureTap,
                      onLongPress: onFailureLongPress,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
