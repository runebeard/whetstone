import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/persistence/portable_content_pack_document.dart';

void main() {
  for (final fileName in ['pack-template.json', 'example-pack.json']) {
    test('$fileName remains importable by Whetstone', () async {
      final source = await File('pack-authoring-kit/$fileName').readAsString();

      final document = PortableContentPackDocument.decode(source);

      expect(document.pack.entryCount, greaterThan(0));
    });
  }

  test(
    'the complete example demonstrates every supported entry type',
    () async {
      final source = await File(
        'pack-authoring-kit/example-pack.json',
      ).readAsString();
      final pack = PortableContentPackDocument.decode(source).pack;

      expect(pack.weapons, hasLength(1));
      expect(pack.spells, hasLength(1));
      expect(pack.resources, hasLength(1));
      expect(pack.features, hasLength(1));
      expect(pack.items, hasLength(1));
    },
  );

  test('the editor schema is valid JSON', () async {
    final source = await File(
      'pack-authoring-kit/whetstone-content-pack.schema.json',
    ).readAsString();

    expect(jsonDecode(source), isA<Map<String, Object?>>());
  });
}
