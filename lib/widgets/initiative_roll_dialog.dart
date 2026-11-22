import 'package:flutter/material.dart';

import '../models/check_roll.dart';
import 'dialogue_action_button.dart';

class InitiativeRollDialog extends StatefulWidget {
  final int initiativeModifier;
  final int Function() rollD20;
  final bool canRecord;
  final D20Mode initialMode;
  final Future<int?> Function(CheckRoll)? beforeRecord;

  const InitiativeRollDialog({
    super.key,
    required this.initiativeModifier,
    required this.rollD20,
    this.canRecord = false,
    this.initialMode = D20Mode.normal,
    this.beforeRecord,
  });

  @override
  State<InitiativeRollDialog> createState() => _InitiativeRollDialogState();
}

class _InitiativeRollDialogState extends State<InitiativeRollDialog> {
  late int firstDie;
  int? secondDie;
  late D20Mode mode;
  bool recording = false;

  int get dieResult => mode.select(firstDie, secondDie);

  int get total => dieResult + widget.initiativeModifier;

  String get displayModifier => widget.initiativeModifier > 0
      ? '+${widget.initiativeModifier}'
      : '${widget.initiativeModifier}';

  @override
  void initState() {
    super.initState();
    mode = widget.initialMode;
    rollDice();
  }

  void rollDice() {
    firstDie = widget.rollD20();
    secondDie = mode == D20Mode.normal ? null : widget.rollD20();
  }

  void rollAgain() {
    setState(() {
      rollDice();
    });
  }

  Future<void> record() async {
    if (recording) return;
    if (widget.beforeRecord == null) {
      Navigator.pop(context, total);
      return;
    }
    setState(() => recording = true);
    final adjusted = await widget.beforeRecord!(
      CheckRoll(
        label: 'Initiative',
        naturalRoll: dieResult,
        modifier: widget.initiativeModifier,
      ),
    );
    if (!mounted) return;
    if (adjusted == null) {
      setState(() => recording = false);
    } else {
      Navigator.pop(context, adjusted);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Initiative Roll', textAlign: TextAlign.center),
      scrollable: true,
      content: SizedBox(
        width: 230,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<D20Mode>(
              value: mode,
              items: const [
                DropdownMenuItem(value: D20Mode.normal, child: Text('Normal')),
                DropdownMenuItem(
                  value: D20Mode.advantage,
                  child: Text('Advantage'),
                ),
                DropdownMenuItem(
                  value: D20Mode.disadvantage,
                  child: Text('Disadvantage'),
                ),
              ],
              onChanged: (value) {
                if (value == null || value == mode) return;
                setState(() {
                  mode = value;
                  rollDice();
                });
              },
            ),
            if (secondDie != null) Text('Rolled $firstDie and $secondDie'),
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
            if (widget.canRecord)
              FilledButton(
                onPressed: recording ? null : record,
                child: const Text('Record Initiative'),
              ),
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
