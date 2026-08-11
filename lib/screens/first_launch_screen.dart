import 'package:flutter/material.dart';

class FirstLaunchScreen extends StatelessWidget {
  final VoidCallback onCreateCharacter;
  final VoidCallback onUseSamples;

  const FirstLaunchScreen({
    super.key,
    required this.onCreateCharacter,
    required this.onUseSamples,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Whetstone')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.shield_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Your characters, ready for play',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Build your own character, or explore Whetstone with a '
                    'few ready-made adventurers first.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    key: const ValueKey('first-launch-create-character'),
                    onPressed: onCreateCharacter,
                    icon: const Icon(Icons.add),
                    label: const Text('Create My Character'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('first-launch-use-samples'),
                    onPressed: onUseSamples,
                    icon: const Icon(Icons.auto_stories_outlined),
                    label: const Text('Explore Sample Characters'),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Your character data stays on this device unless you '
                    'choose to export it.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
