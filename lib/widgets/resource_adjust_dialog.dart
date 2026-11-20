import 'package:flutter/material.dart';

import '../models/character_resource.dart';
import 'dialogue_action_button.dart';

enum ResourceAdjustment {
  spend,
  restore,
  refill,
  convertSlot,
  tacticalMind,
  createWildResurgenceSlot,
}

class ResourceAdjustDialog extends StatelessWidget {
  final CharacterResource resource;
  final int currentValue;
  final bool canConvertSlot;
  final bool canUseTacticalMind;
  final bool canCreateWildResurgenceSlot;

  const ResourceAdjustDialog({
    super.key,
    required this.resource,
    required this.currentValue,
    this.canConvertSlot = false,
    this.canUseTacticalMind = false,
    this.canCreateWildResurgenceSlot = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(resource.name, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$currentValue / ${resource.maximum}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          DialogueActionButton(
            icon: Icons.remove_circle_outline,
            label: 'Spend One',
            onTap: currentValue > 0
                ? () => Navigator.pop(context, ResourceAdjustment.spend)
                : null,
          ),
          const SizedBox(height: 10),
          DialogueActionButton(
            icon: Icons.add_circle_outline,
            label: 'Restore One',
            onTap: currentValue < resource.maximum
                ? () => Navigator.pop(context, ResourceAdjustment.restore)
                : null,
          ),
          const SizedBox(height: 10),
          DialogueActionButton(
            icon: Icons.refresh,
            label: 'Refill',
            onTap: currentValue < resource.maximum
                ? () => Navigator.pop(context, ResourceAdjustment.refill)
                : null,
          ),
          if (canConvertSlot) ...[
            const SizedBox(height: 10),
            DialogueActionButton(
              icon: Icons.auto_awesome,
              label: 'Spend a Slot to Restore One',
              onTap: () =>
                  Navigator.pop(context, ResourceAdjustment.convertSlot),
            ),
          ],
          if (canCreateWildResurgenceSlot) ...[
            const SizedBox(height: 10),
            DialogueActionButton(
              icon: Icons.auto_awesome,
              label: 'Spend a Use to Create a Level 1 Slot',
              onTap: () => Navigator.pop(
                context,
                ResourceAdjustment.createWildResurgenceSlot,
              ),
            ),
          ],
          if (canUseTacticalMind) ...[
            const SizedBox(height: 10),
            DialogueActionButton(
              icon: Icons.psychology_outlined,
              label: 'Tactical Mind',
              onTap: () =>
                  Navigator.pop(context, ResourceAdjustment.tacticalMind),
            ),
          ],
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
