import 'package:flutter/material.dart';

import '../models/ability.dart';
import '../models/character.dart';
import 'saving_throw_tile.dart';

class SavingThrowGrid extends StatelessWidget {
  final Character character;
  final ValueChanged<SavingThrowCheck> onSavingThrowTap;

  const SavingThrowGrid({
    super.key,
    required this.character,
    required this.onSavingThrowTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      crossAxisSpacing: 6,
      mainAxisSpacing: 6,
      childAspectRatio: 2.15,
      children: [
        for (final ability in Ability.values)
          SavingThrowTile(
            check: character.savingThrowFor(ability),
            onTap: () => onSavingThrowTap(character.savingThrowFor(ability)),
          ),
      ],
    );
  }
}
