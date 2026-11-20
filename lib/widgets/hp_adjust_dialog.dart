import 'package:flutter/material.dart';
import '../models/character_state.dart';
import 'dialogue_action_button.dart';

enum HpAdjustmentType { damage, criticalDamage, healing, temporaryHp }

class HpAdjustment {
  final HpAdjustmentType type;
  final int amount;

  final IncomingDamageType damageType;

  const HpAdjustment({
    required this.type,
    required this.amount,
    this.damageType = IncomingDamageType.other,
  });
}

class HpAdjustDialog extends StatefulWidget {
  final bool showCriticalDamage;

  final bool showDamageType;

  const HpAdjustDialog({
    super.key,
    this.showCriticalDamage = false,
    this.showDamageType = false,
  });

  @override
  State<HpAdjustDialog> createState() => _HpAdjustDialogState();
}

class _HpAdjustDialogState extends State<HpAdjustDialog> {
  late final TextEditingController amountController;
  IncomingDamageType damageType = IncomingDamageType.other;

  @override
  void initState() {
    super.initState();

    amountController = TextEditingController(text: '0');

    amountController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: amountController.text.length,
    );
  }

  @override
  void dispose() {
    amountController.dispose();
    super.dispose();
  }

  void _submitAdjustment(HpAdjustmentType type) {
    final amount = int.tryParse(amountController.text);

    if (amount == null || amount <= 0) {
      return;
    }

    Navigator.pop(
      context,
      HpAdjustment(type: type, amount: amount, damageType: damageType),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      content: Column(
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
              controller: amountController,
              autofocus: true,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          if (widget.showDamageType)
            DropdownButtonFormField<IncomingDamageType>(
              initialValue: damageType,
              decoration: const InputDecoration(labelText: 'Damage type'),
              items: [
                for (final type in IncomingDamageType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: (type) {
                if (type != null) setState(() => damageType = type);
              },
            ),
          const SizedBox(height: 10),
          DialogueActionButton(
            label: '🗡 Damage',
            onTap: () {
              _submitAdjustment(HpAdjustmentType.damage);
            },
          ),

          const SizedBox(height: 10),

          if (widget.showCriticalDamage) ...[
            DialogueActionButton(
              label: 'Critical hit',
              onTap: () => _submitAdjustment(HpAdjustmentType.criticalDamage),
            ),
            const SizedBox(height: 10),
          ],
          DialogueActionButton(
            label: '✨ Heal',
            onTap: () {
              _submitAdjustment(HpAdjustmentType.healing);
            },
          ),

          const SizedBox(height: 10),

          DialogueActionButton(
            label: '🛡 Gain Temp HP',
            onTap: () {
              _submitAdjustment(HpAdjustmentType.temporaryHp);
            },
          ),

          const SizedBox(height: 12),

          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              'Cancel',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
