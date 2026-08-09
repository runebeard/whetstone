import 'package:flutter/material.dart';

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

  const ConditionsDialog({
    super.key,
    required this.activeConditions,
    required this.onChanged,
  });

  @override
  State<ConditionsDialog> createState() => _ConditionsDialogState();
}

class _ConditionsDialogState extends State<ConditionsDialog> {
  late final Set<String> selectedConditions;

  @override
  void initState() {
    super.initState();
    selectedConditions = {...widget.activeConditions};
  }

  void toggleCondition(String condition, bool isSelected) {
    setState(() {
      if (isSelected) {
        selectedConditions.add(condition);
      } else {
        selectedConditions.remove(condition);
      }
    });
    widget.onChanged({...selectedConditions});
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
              for (final condition in standardConditions)
                CheckboxListTile(
                  value: selectedConditions.contains(condition),
                  onChanged: (value) =>
                      toggleCondition(condition, value ?? false),
                  title: Text(condition),
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
