import 'package:flutter/material.dart';

import '../models/character_action.dart';

class ActionCard extends StatelessWidget {
  final CharacterAction action;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const ActionCard({
    super.key,
    required this.action,
    required this.isPinned,
    required this.onTap,
    this.onLongPress,
  });

  IconData get actionIcon => switch (action.type) {
    CharacterActionType.weapon => Icons.gavel_outlined,
    CharacterActionType.spell => Icons.auto_awesome_outlined,
    CharacterActionType.feature => Icons.bolt_outlined,
    CharacterActionType.item => Icons.backpack_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: Icon(actionIcon),
          title: Text(
            action.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            action.summary,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: isPinned
              ? const Tooltip(
                  message: 'Pinned to Combat',
                  child: Icon(Icons.push_pin, size: 18),
                )
              : null,
        ),
      ),
    );
  }
}
