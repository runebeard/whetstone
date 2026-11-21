import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/screens/character_advancement.dart';

void main() {
  for (final (dex, wis, expectedDex, expectedWis) in [
    (14, 12, 18, 16),
    (24, 23, 25, 25),
    (26, 25, 26, 25),
  ]) {
    testWidgets('Body and Mind applies once with scores $dex/$wis', (
      tester,
    ) async {
      var character = seedCharacters.first.copyWith(
        characterClass: 'Monk',
        level: 19,
        additionalClassLevels: {},
        subclasses: {'Monk': 'Warrior of the Open Hand'},
        features: [],
        abilityScores: {
          ...seedCharacters.first.abilityScores,
          Ability.dexterity: dex,
          Ability.wisdom: wis,
        },
      );
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
      expect(character.scoreFor(Ability.dexterity), expectedDex);
      expect(character.scoreFor(Ability.wisdom), expectedWis);
      expect(
        character.initiativeModifier,
        2 + ((expectedDex - 10) / 2).floor() - ((dex - 10) / 2).floor(),
      );
      expect(character.currentHp, 34);
      expect(
        character.features
            .where((f) => f.id == 'whetstone:class:body-and-mind')
            .length,
        1,
      );
      expect(
        character.resources
            .singleWhere((r) => r.id == wholenessOfBodyResourceId)
            .maximum,
        ((expectedWis - 10) / 2).floor().clamp(1, 10),
      );
      character = Character.fromJson(character.toJson());
      await advance(20);
      expect(character.scoreFor(Ability.dexterity), expectedDex);
      await advance(19);
      await advance(20);
      expect(character.scoreFor(Ability.dexterity), expectedDex);
      expect(character.scoreFor(Ability.wisdom), expectedWis);
      expect(
        character.features
            .where((f) => f.id == 'whetstone:class:body-and-mind')
            .length,
        1,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Total level twenty does not grant Body and Mind to Monk nineteen',
    (tester) async {
      final original = seedCharacters.first.copyWith(
        characterClass: 'Monk',
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
      expect(result!.levelInClass('Monk'), 19);
      expect(
        result!.scoreFor(Ability.dexterity),
        original.scoreFor(Ability.dexterity),
      );
      expect(
        result!.features.where((f) => f.id == 'whetstone:class:body-and-mind'),
        isEmpty,
      );
    },
  );
}
