import 'package:flutter/material.dart';

import '../models/character.dart';
import '../widgets/character_card.dart';

class CharacterVault extends StatelessWidget {
  const CharacterVault({super.key});

  @override
  Widget build(BuildContext context) {
    final characters = [
  Character(
    name: 'Eldrin',
    characterClass: 'Wizard',
    level: 6,
    currentHp: 34,
    maxHp: 42,
    ac: 15,
    status: 'Exploring',
  ),
  Character(
    name: 'Rowan',
    characterClass: 'Ranger',
    level: 5,
    currentHp: 41,
    maxHp: 44,
    ac: 16,
    status: 'In Combat',
  ),
  Character(
    name: 'Viktor',
    characterClass: 'Blood Hunter',
    level: 8,
    currentHp: 62,
    maxHp: 70,
    ac: 17,
    status: 'Resting',
  ),
];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Whetstone'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: characters.length,
        itemBuilder: (context, index) {
          return CharacterCard(
            character: characters[index],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}