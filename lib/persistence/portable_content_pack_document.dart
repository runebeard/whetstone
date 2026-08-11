import 'dart:convert';

import '../models/check_roll.dart';
import '../models/content_pack.dart';

class UnsupportedPortableContentPackVersion implements Exception {
  final int version;

  const UnsupportedPortableContentPackVersion(this.version);
}

class PortableContentPackDocument {
  static const format = 'whetstone-content-pack';
  static const currentSchemaVersion = 1;

  final ContentPack pack;

  const PortableContentPackDocument({required this.pack});

  Map<String, Object> toJson() {
    return {
      'format': format,
      'schemaVersion': currentSchemaVersion,
      'pack': pack.toJson(),
    };
  }

  String encode({bool pretty = false}) {
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(toJson())
        : jsonEncode(toJson());
  }

  factory PortableContentPackDocument.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('The pack must contain a JSON object.');
    }
    return PortableContentPackDocument.fromJson(decoded);
  }

  factory PortableContentPackDocument.fromJson(Map<String, Object?> json) {
    if (json['format'] != format) {
      throw const FormatException('This is not a Whetstone content pack.');
    }
    final version = json['schemaVersion'];
    if (version != currentSchemaVersion) {
      throw UnsupportedPortableContentPackVersion(
        version is int ? version : -1,
      );
    }
    final packJson = json['pack'];
    if (packJson is! Map<String, Object?>) {
      throw const FormatException('Content-pack data is missing.');
    }
    final pack = ContentPack.fromJson(packJson);
    validate(pack);
    return PortableContentPackDocument(pack: pack);
  }

  static void validate(ContentPack pack) {
    if ([
      pack.id,
      pack.name,
      pack.gameSystem,
      pack.version,
      pack.author,
      pack.description,
    ].any((value) => value.trim().isEmpty)) {
      throw const FormatException('Content-pack metadata is incomplete.');
    }
    if (pack.entryCount == 0) {
      throw const FormatException('A content pack must contain an entry.');
    }

    void uniqueIds(Iterable<String> ids) {
      final values = ids.toList();
      if (values.any((id) => id.trim().isEmpty) ||
          values.toSet().length != values.length) {
        throw const FormatException('Content entry identifiers are invalid.');
      }
    }

    uniqueIds(pack.weapons.map((entry) => entry.id));
    uniqueIds(pack.spells.map((entry) => entry.id));
    uniqueIds(pack.resources.map((entry) => entry.id));
    uniqueIds(pack.features.map((entry) => entry.id));

    final namedEntries = <String>[
      ...pack.weapons.map((entry) => entry.name),
      ...pack.spells.map((entry) => entry.name),
      ...pack.resources.map((entry) => entry.name),
      ...pack.features.map((entry) => entry.name),
      ...pack.items.map((entry) => entry.name),
    ];
    if (namedEntries.any((name) => name.trim().isEmpty)) {
      throw const FormatException('Content entries must have names.');
    }
    for (final formula in [
      ...pack.weapons.map((entry) => entry.damageFormula),
      ...pack.spells.map((entry) => entry.damageFormula),
    ].whereType<String>()) {
      if (DiceExpression.tryParse(formula) == null) {
        throw const FormatException('A damage formula is invalid.');
      }
    }
    if (pack.resources.any(
          (entry) =>
              entry.maximum < 1 ||
              entry.initialValue < 0 ||
              entry.initialValue > entry.maximum,
        ) ||
        pack.items.any(
          (entry) => entry.quantity < 0 || entry.weightPerItem < 0,
        )) {
      throw const FormatException('A content entry contains invalid values.');
    }
  }
}
