import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/screens/character_advancement.dart';

void main() {
  for (final (strength, constitution, expectedStrength, expectedConstitution)
      in [(18, 16, 22, 20), (24, 23, 25, 25), (26, 25, 26, 25)]) {
    testWidgets(
      'Primal Champion applies once with scores $strength/$constitution and adjusts maximum HP',
      (tester) async {
        var character = seedCharacters.first.copyWith(
          characterClass: 'Barbarian',
          level: 19,
          additionalClassLevels: {},
          subclasses: {'Barbarian': 'Path of the Berserker'},
          features: [],
          abilityScores: {
            ...seedCharacters.first.abilityScores,
            Ability.strength: strength,
            Ability.constitution: constitution,
          },
        );
        final originalHp = character.currentHp;
        final originalMax = character.maxHp;
        final modifierChange =
            ((expectedConstitution - 10) / 2).floor() -
            ((constitution - 10) / 2).floor();
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () async {
                    final result = await Navigator.push<Character>(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            CharacterAdvancement(character: character),
                      ),
                    );
                    if (result != null) character = result;
                  },
                  child: const Text('Open advancement'),
                ),
              ),
            ),
          ),
        );
        Future<void> advance(int level) async {
          await tester.tap(find.text('Open advancement'));
          await tester.pumpAndSettle();
          await tester.enterText(
            find.byKey(const ValueKey('advancement-level')),
            '$level',
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Save'));
          await tester.pumpAndSettle();
        }

        await advance(20);
        expect(character.scoreFor(Ability.strength), expectedStrength);
        expect(character.scoreFor(Ability.constitution), expectedConstitution);
        expect(character.maxHp, originalMax + modifierChange * 20);
        expect(character.currentHp, originalHp);
        expect(
          character.initiativeModifier,
          seedCharacters.first.initiativeModifier,
        );
        expect(
          character.features
              .where((f) => f.id == 'whetstone:class:primal-champion')
              .length,
          1,
        );
        character = Character.fromJson(character.toJson());
        await advance(20);
        await advance(19);
        await advance(20);
        expect(character.scoreFor(Ability.strength), expectedStrength);
        expect(character.scoreFor(Ability.constitution), expectedConstitution);
        expect(character.maxHp, originalMax + modifierChange * 20);
        expect(character.currentHp, originalHp);
        expect(
          character.features
              .where((f) => f.id == 'whetstone:class:primal-champion')
              .length,
          1,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Total level twenty does not grant Primal Champion to Barbarian nineteen',
    (tester) async {
      final original = seedCharacters.first.copyWith(
        characterClass: 'Barbarian',
        level: 19,
        additionalClassLevels: {'Fighter': 1},
        features: [],
      );
      Character? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.push<Character>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CharacterAdvancement(character: original),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('advancement-level')),
        '20',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result!.levelInClass('Barbarian'), 19);
      expect(
        result!.scoreFor(Ability.strength),
        original.scoreFor(Ability.strength),
      );
      expect(
        result!.scoreFor(Ability.constitution),
        original.scoreFor(Ability.constitution),
      );
      expect(result!.maxHp, original.maxHp);
      expect(
        result!.features.where(
          (f) => f.id == 'whetstone:class:primal-champion',
        ),
        isEmpty,
      );
    },
  );
}
