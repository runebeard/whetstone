import 'package:flutter/material.dart';

import '../models/rest.dart';

class RestSection extends StatelessWidget {
  final ValueChanged<RestType> onRestSelected;

  const RestSection({super.key, required this.onRestSelected});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.bedtime_outlined),
                SizedBox(width: 10),
                Text(
                  'Rest & Recovery',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Recover after the adventure pauses.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => onRestSelected(RestType.shortRest),
                    child: const Text('Short Rest'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => onRestSelected(RestType.longRest),
                    child: const Text('Long Rest'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
