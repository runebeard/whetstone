import 'package:flutter/material.dart';

class ContentAddButtons extends StatelessWidget {
  final String libraryKey;
  final String customKey;
  final VoidCallback onAddFromLibrary;
  final VoidCallback onCreateCustom;

  const ContentAddButtons({
    super.key,
    required this.libraryKey,
    required this.customKey,
    required this.onAddFromLibrary,
    required this.onCreateCustom,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.tonalIcon(
            key: ValueKey(libraryKey),
            onPressed: onAddFromLibrary,
            icon: const Icon(Icons.library_add_outlined, size: 18),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Add from Library'),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            key: ValueKey(customKey),
            onPressed: onCreateCustom,
            icon: const Icon(Icons.add, size: 18),
            label: const FittedBox(
              fit: BoxFit.scaleDown,
              child: Text('Create Custom'),
            ),
          ),
        ),
      ],
    );
  }
}
