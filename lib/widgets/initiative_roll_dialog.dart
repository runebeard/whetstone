import 'package:flutter/material.dart';

import 'dialogue_action_button.dart';

class InitiativeRollDialog extends StatefulWidget {
  final int initiativeModifier;
  final int Function() rollD20;

  const InitiativeRollDialog({
    super.key,
    required this.initiativeModifier,
    required this.rollD20,
  });

  @override
  State<InitiativeRollDialog> createState() => _InitiativeRollDialogState();
}

class _InitiativeRollDialogState extends State<InitiativeRollDialog> {
  late int dieResult;

  int get total => dieResult + widget.initiativeModifier;

  String get displayModifier => widget.initiativeModifier > 0
      ? '+${widget.initiativeModifier}'
      : '${widget.initiativeModifier}';

  @override
  void initState() {
    super.initState();
    dieResult = widget.rollD20();
  }

  void rollAgain() {
    setState(() {
      dieResult = widget.rollD20();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Initiative Roll', textAlign: TextAlign.center),
      content: SizedBox(
        width: 230,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RollValue(
              label: 'd20',
              value: '$dieResult',
              valueKey: const ValueKey('initiative-die-result'),
            ),
            const SizedBox(height: 8),
            _RollValue(
              label: 'Modifier',
              value: displayModifier,
              valueKey: const ValueKey('initiative-roll-modifier'),
            ),
            const Divider(height: 24),
            _RollValue(
              label: 'Total',
              value: '$total',
              valueKey: const ValueKey('initiative-roll-total'),
              emphasize: true,
            ),
            const SizedBox(height: 20),
            DialogueActionButton(label: 'Roll Again', onTap: rollAgain),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}

class _RollValue extends StatelessWidget {
  final String label;
  final String value;
  final Key valueKey;
  final bool emphasize;

  const _RollValue({
    required this.label,
    required this.value,
    required this.valueKey,
    this.emphasize = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label),
        const Spacer(),
        Text(
          value,
          key: valueKey,
          style: TextStyle(
            fontSize: emphasize ? 28 : 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
