import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_resource.dart';
import 'package:whetstone/models/feature.dart';
import 'package:whetstone/models/inventory_item.dart';
import 'package:whetstone/models/journal_entry.dart';
import 'package:whetstone/models/skill.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/models/weapon.dart';
import 'package:whetstone/persistence/character_definition_repository.dart';

void main() {
  test('character definitions survive a real file round-trip', () async {
    final directory = await Directory.systemTemp.createTemp(
      'whetstone-character-test-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    Future<Directory> testDirectory() async => directory;
    final character = Character(
      id: 'test-hero',
      name: 'Aurelia',
      characterClass: 'Paladin',
      level: 3,
      currentHp: 28,
      maxHp: 28,
      armourClass: 18,
      initiativeModifier: 1,
      status: 'Exploring',
      abilityScores: const {Ability.strength: 16, Ability.charisma: 15},
      proficiencyBonus: 2,
      savingThrowProficiencies: const {Ability.wisdom, Ability.charisma},
      skillProficiencies: const {'persuasion': SkillProficiency.proficient},
      weapons: const [
        Weapon(
          id: 'longsword',
          name: 'Longsword',
          attackModifier: 5,
          damage: '1d8 + 3 slashing',
          damageFormula: '1d8 + 3',
          damageType: 'slashing',
        ),
      ],
      spells: const [
        Spell(
          id: 'bless',
          name: 'Bless',
          level: 1,
          prepared: true,
          rollModifier: 6,
          damageFormula: '2d6',
          damageType: 'radiant',
          summary: 'Bolster three allies',
        ),
      ],
      resources: const [
        CharacterResource(
          id: 'lay_on_hands',
          name: 'Lay on Hands',
          maximum: 15,
          initialValue: 15,
          rechargePeriod: RechargePeriod.longRest,
        ),
      ],
      initialInventory: const [
        InventoryItem(
          name: 'Holy Symbol',
          quantity: 1,
          weightPerItem: 1,
          category: ItemCategory.equipment,
        ),
      ],
      features: const [
        Feature(
          id: 'second_wind',
          name: 'Second Wind',
          rollModifier: 4,
          summary: 'Bonus action • Recover HP',
        ),
      ],
      journalEntries: const [
        JournalEntry(
          id: 'lost-reliquary',
          title: 'Find the Lost Reliquary',
          notes: 'Speak to Sister Aveline at the old chapel.',
        ),
        JournalEntry(
          id: 'goblin-road',
          title: 'Clear the Goblin Road',
          notes: 'The eastern road is safe again.',
          isCompleted: true,
        ),
      ],
    );
    final repository = FileCharacterDefinitionRepository(
      directory: testDirectory,
    );

    await repository.saveCatalog(
      CharacterDefinitionCatalog(
        characters: {character.id: character},
        deletedCharacterIds: const {'retired-hero'},
      ),
    );
    final reopened = FileCharacterDefinitionRepository(
      directory: testDirectory,
    );
    final catalog = await reopened.loadCatalog();
    final restored = catalog.characters['test-hero']!;

    expect(restored.name, 'Aurelia');
    expect(restored.scoreFor(Ability.strength), 16);
    expect(restored.savingThrowProficiencies, contains(Ability.charisma));
    expect(restored.skillProficiencies['persuasion'], isNotNull);
    expect(restored.weapons.single.name, 'Longsword');
    expect(restored.weapons.single.damageFormula, '1d8 + 3');
    expect(restored.weapons.single.damageType, 'slashing');
    expect(restored.spells.single.name, 'Bless');
    expect(restored.spells.single.rollModifier, 6);
    expect(restored.spells.single.damageFormula, '2d6');
    expect(restored.spells.single.damageType, 'radiant');
    expect(restored.resources.single.maximum, 15);
    expect(restored.initialInventory.single.name, 'Holy Symbol');
    expect(restored.features.single.name, 'Second Wind');
    expect(restored.features.single.rollModifier, 4);
    expect(restored.journalEntries.first.title, 'Find the Lost Reliquary');
    expect(restored.journalEntries.last.isCompleted, isTrue);
    expect(catalog.deletedCharacterIds, contains('retired-hero'));
  });

  test('older catalogs without deletion records remain compatible', () {
    final catalog = CharacterDefinitionCatalog.fromJson({
      'schemaVersion': 1,
      'characters': <String, Object?>{},
    });

    expect(catalog.deletedCharacterIds, isEmpty);
  });

  test('older character definitions begin with an empty journal', () {
    final character = Character(
      name: 'Legacy Hero',
      characterClass: 'Adventurer',
      level: 1,
      currentHp: 10,
      maxHp: 10,
      armourClass: 10,
      initiativeModifier: 0,
      status: 'Exploring',
    );
    final json = character.toJson()..remove('journalEntries');

    final restored = Character.fromJson(json);

    expect(restored.journalEntries, isEmpty);
  });
}
