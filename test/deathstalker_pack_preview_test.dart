import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/authored_class.dart';
import 'package:whetstone/persistence/content_pack_repository.dart';
import 'package:whetstone/persistence/portable_content_pack_document.dart';

void main() {
  test(
    'Deathstalker survives preview import, catalog reload and export',
    () async {
      final source = await File(
        'recovery/pack-builder/deathstalker.pack.json',
      ).readAsString();
      final document = PortableContentPackDocument.decode(source);

      expect(document.pack.isClassPackPreview, isTrue);
      expect(document.pack.classNames, ['Deathstalker']);
      expect(document.pack.features, isEmpty);
      final payload = document.pack.classPackPayload!;
      final rules = (payload['classes'] as List).single as Map<String, Object?>;
      final authored = AuthoredClass(payload, rules);
      expect(authored.supportsFirstLevels, isTrue);
      expect(authored.hitDie, 8);
      expect(authored.saves, {Ability.strength, Ability.wisdom});
      expect(authored.skillCount, 2);
      expect(authored.grants(1).single.name, 'Silent hunter');
      expect(authored.grants(2).single.name, 'Shadow step');
      expect(authored.featureNamesAt(3), ['Mark prey']);
      expect(authored.resourcesAt(2), isEmpty);
      expect(authored.resourcesAt(3).single.maximum, 3);
      expect(authored.resourcesAt(4).single.maximum, 3);
      expect(authored.resourcesAt(5).single.maximum, 4);
      expect(authored.startingEquipment().first.name, 'Deathblade');
      expect(authored.startingEquipment().last.quantity, 50);

      final repository = InMemoryContentPackRepository();
      await repository.savePacks({document.pack.id: document.pack});
      final packs = await repository.loadPacks();
      final restored = PortableContentPackDocument(
        pack: packs[document.pack.id]!,
      );
      expect(jsonDecode(restored.encode()), jsonDecode(source));
    },
  );

  test('early resource grants apply the latest eligible maximum', () async {
    final source = await File(
      'recovery/pack-builder/deathstalker.pack.json',
    ).readAsString();
    final pack = PortableContentPackDocument.decode(
      source,
    ).pack.classPackPayload!;
    final rules = (pack['classes'] as List).single as Map<String, Object?>;
    final resource = (pack['resources'] as List).single as Map<String, Object?>;
    final id = resource['id'] as String;
    final authored = AuthoredClass(pack, {
      ...rules,
      'resources': {
        'grantLevels': {id: 1},
        'scaling': [
          {
            'resourceId': id,
            'baseByLevel': {'2': 4, '1': 3},
            'minimum': 1,
          },
        ],
      },
    });

    expect(authored.supportsFirstLevels, isTrue);
    expect(authored.resourcesAt(1).single.maximum, 3);
    expect(authored.resourcesAt(2).single.maximum, 4);
  });

  test('starting equipment applies only the chosen option', () async {
    final source = await File(
      'recovery/pack-builder/deathstalker.pack.json',
    ).readAsString();
    final pack = PortableContentPackDocument.decode(
      source,
    ).pack.classPackPayload!;
    final rules = (pack['classes'] as List).single as Map<String, Object?>;
    final entryRules = rules['entryRules'] as Map<String, Object?>;
    final authored = AuthoredClass(pack, {
      ...rules,
      'entryRules': {
        ...entryRules,
        'equipmentOptions': [
          ...(entryRules['equipmentOptions'] as List),
          {'id': 'gold', 'label': 'Gold only', 'items': <String, Object?>{}, 'gold': 75},
        ],
      },
    });

    expect(authored.supportsFirstLevels, isTrue);
    expect(authored.startingEquipment('starting').first.name, 'Deathblade');
    final gold = authored.startingEquipment('gold').single;
    expect(gold.name, 'Gold (gp)');
    expect(gold.quantity, 75);
  });

  test('schema 3 rejects a pack without class definitions', () async {
    final source = await File(
      'recovery/pack-builder/deathstalker.pack.json',
    ).readAsString();
    final document = jsonDecode(source) as Map<String, Object?>;
    final pack = document['pack'] as Map<String, Object?>;
    pack.remove('classes');

    expect(
      () => PortableContentPackDocument.fromJson(document),
      throwsFormatException,
    );
  });
}
