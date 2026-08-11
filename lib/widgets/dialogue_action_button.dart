import 'package:flutter/material.dart';

class DialogueActionButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback? onTap;

  const DialogueActionButton({
    super.key,
    this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final foregroundColour = enabled
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 195,
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: foregroundColour),
          borderRadius: BorderRadius.circular(12),
        ),
        child: icon == null
            ? Text(
                label,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: foregroundColour,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const SizedBox(width: 16),

                  Icon(icon, color: foregroundColour),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: foregroundColour,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
