import 'package:flutter/material.dart';
import '../models/character.dart';

class CharacterCard extends StatelessWidget {
  final Character character;

  const CharacterCard({
    super.key,
    required this.character,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(character.name),
            Text(
              'Level ${character.level} ${character.characterClass}',
            ),
            Text(
              '❤️ ${character.currentHp} / ${character.maxHp}',
            ),
            Text(
              '🛡 AC ${character.ac}',
            ),
            Text(
              character.status,
            ),
          ],
        ),
      ),
    );
  }
}