import 'package:flutter/material.dart';

import 'dialogue_action_button.dart';

class StatEditDialog extends StatefulWidget {
  final int initialValue;
  final bool allowNegative;
  final bool allowZero;

  const StatEditDialog({
    super.key,
    required this.initialValue,
    this.allowNegative = false,
    this.allowZero = false,
  });

  @override
  State<StatEditDialog> createState() => _StatEditDialogState();
}

class _StatEditDialogState extends State<StatEditDialog> {
  late final TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialValue.toString());
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void submit() {
    final value = int.tryParse(controller.text);
    final isValid =
        value != null &&
        (widget.allowNegative || value >= 0) &&
        (widget.allowZero || value != 0);

    if (!isValid) {
      return;
    }

    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      content: SizedBox(
        width: 230,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.numberWithOptions(
                  signed: widget.allowNegative,
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                onSubmitted: (_) => submit(),
              ),
            ),
            const SizedBox(height: 20),
            DialogueActionButton(label: 'Save', onTap: submit),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
