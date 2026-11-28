import 'package:flutter/material.dart';

import 'stat_edit_dialog.dart';

const standardConditions = [
  'Blinded',
  'Charmed',
  'Deafened',
  'Frightened',
  'Grappled',
  'Incapacitated',
  'Invisible',
  'Paralyzed',
  'Petrified',
  'Poisoned',
  'Prone',
  'Restrained',
  'Stunned',
  'Unconscious',
];

class ConditionsDialog extends StatefulWidget {
  final Set<String> activeConditions;
  final ValueChanged<Set<String>> onChanged;
  final Map<String, int> conditionTurns;
  final ValueChanged<Map<String, int>>? onTimersChanged;

  const ConditionsDialog({
    super.key,
    required this.activeConditions,
    required this.onChanged,
    this.conditionTurns = const {},
    this.onTimersChanged,
  });

  @override
  State<ConditionsDialog> createState() => _ConditionsDialogState();
}

class _ConditionsDialogState extends State<ConditionsDialog> {
  late final Set<String> selectedConditions;
  late final Map<String, int> timers;

  @override
  void initState() {
    super.initState();
    selectedConditions = {...widget.activeConditions};
    timers = {...widget.conditionTurns};
  }

  void toggleCondition(String condition, bool isSelected) {
    setState(() {
      if (isSelected) {
        selectedConditions.add(condition);
      } else {
        selectedConditions.remove(condition);
        timers.remove(condition);
      }
    });
    widget.onChanged({...selectedConditions});
  }

  Future<void> editTimer(String condition) async {
    final turns = await showDialog<int>(
      context: context,
      builder: (context) => StatEditDialog(
        title: '$condition turns remaining (0 for no limit)',
        initialValue: timers[condition] ?? 0,
        allowZero: true,
      ),
    );
    if (!mounted || turns == null || !selectedConditions.contains(condition)) {
      return;
    }
    setState(() {
      if (turns == 0) {
        timers.remove(condition);
      } else {
        timers[condition] = turns;
      }
    });
    widget.onTimersChanged?.call({...timers});
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Conditions', textAlign: TextAlign.center),
      content: SizedBox(
        width: 280,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 420),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final condition in {
                ...standardConditions,
                ...widget.activeConditions,
              })
                CheckboxListTile(
                  value: selectedConditions.contains(condition),
                  onChanged: (value) =>
                      toggleCondition(condition, value ?? false),
                  title: Text(condition),
                  subtitle: timers.containsKey(condition)
                      ? Text('${timers[condition]} turns remaining')
                      : null,
                  secondary:
                      widget.onTimersChanged != null &&
                          selectedConditions.contains(condition)
                      ? IconButton(
                          tooltip: 'Set $condition turn limit',
                          onPressed: () => editTimer(condition),
                          icon: const Icon(Icons.timer_outlined),
                        )
                      : null,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
            ],
          ),
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close', style: TextStyle(fontSize: 16)),
        ),
      ],
    );
  }
}
