import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/starter_content_pack.dart';
import 'package:whetstone/models/content_pack.dart';
import 'package:whetstone/models/weapon.dart';
import 'package:whetstone/persistence/content_pack_repository.dart';
import 'package:whetstone/persistence/portable_content_pack_document.dart';

void main() {
  test('content packs survive a real repository round-trip', () async {
    final directory = await Directory.systemTemp.createTemp(
      'whetstone-content-pack-test-',
    );
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    Future<Directory> testDirectory() async => directory;
    final repository = FileContentPackRepository(directory: testDirectory);

    await repository.savePacks({starterContentPack.id: starterContentPack});
    final reopened = FileContentPackRepository(directory: testDirectory);
    final restored = await reopened.loadPacks();

    final pack = restored[starterContentPack.id]!;
    expect(pack.name, 'Whetstone d20 Starter');
    expect(pack.weapons.single.name, 'Training Sword');
    expect(pack.spells.single.name, 'Ember Bolt');
    expect(pack.resources.single.name, 'Heroic Effort');
    expect(pack.features.single.name, 'Rally');
    expect(pack.items.single.name, 'Healing Draught');
  });

  test('portable content pack validates and round-trips every entry type', () {
    final encoded = const PortableContentPackDocument(
      pack: starterContentPack,
    ).encode(pretty: true);

    final restored = PortableContentPackDocument.decode(encoded).pack;

    expect(restored.id, starterContentPack.id);
    expect(restored.entryCount, 5);
    expect(restored.weapons.single.damageFormula, '1d8 + 2');
    expect(restored.spells.single.damageType, 'fire');
  });

  test('portable content pack rejects duplicate IDs and invalid damage', () {
    final duplicateIds = ContentPack(
      id: 'invalid-duplicates',
      name: 'Duplicate Pack',
      gameSystem: 'Test',
      version: '1.0.0',
      author: 'Tester',
      description: 'Contains duplicate weapon IDs.',
      weapons: const [
        Weapon(
          id: 'same',
          name: 'One',
          attackModifier: 1,
          damage: '1d6',
          damageFormula: '1d6',
        ),
        Weapon(
          id: 'same',
          name: 'Two',
          attackModifier: 1,
          damage: '1d8',
          damageFormula: '1d8',
        ),
      ],
    );
    final invalidDamage = ContentPack(
      id: 'invalid-damage',
      name: 'Invalid Damage',
      gameSystem: 'Test',
      version: '1.0.0',
      author: 'Tester',
      description: 'Contains an invalid damage formula.',
      weapons: const [
        Weapon(
          id: 'odd-sword',
          name: 'Odd Sword',
          attackModifier: 1,
          damage: 'lots',
          damageFormula: 'lots',
        ),
      ],
    );

    expect(
      () => PortableContentPackDocument.fromJson(
        PortableContentPackDocument(pack: duplicateIds).toJson(),
      ),
      throwsFormatException,
    );
    expect(
      () => PortableContentPackDocument.fromJson(
        PortableContentPackDocument(pack: invalidDamage).toJson(),
      ),
      throwsFormatException,
    );
  });
}
