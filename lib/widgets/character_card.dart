import 'package:flutter/material.dart';
import '../models/character.dart';

class CharacterCard extends StatelessWidget {
  final Character character;
  final VoidCallback onTap;

  const CharacterCard({
    super.key,
    required this.character,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                character.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Level ${character.level} ${character.characterClass}',
              ),
              Text(
                '❤️ HP ${character.currentHp} / ${character.maxHp}',
              ),
              Text(
                '🛡 AC ${character.armourClass}',
              ),
              Text(
                character.status,
              ),
            ],
          ),
        ),
      ),
    );
  }
}