import 'dart:convert';

import '../models/character.dart';
import '../models/character_session.dart';

class UnsupportedPortableCharacterVersion implements Exception {
  final int version;

  const UnsupportedPortableCharacterVersion(this.version);

  @override
  String toString() => 'Unsupported Whetstone character version: $version';
}

class PortableCharacterDocument {
  static const format = 'whetstone-character';
  static const currentSchemaVersion = 1;

  final Character character;
  final CharacterSession session;

  const PortableCharacterDocument({
    required this.character,
    required this.session,
  });

  Map<String, Object> toJson() {
    return {
      'format': format,
      'schemaVersion': currentSchemaVersion,
      'character': character.toJson(),
      'session': session.toJson(),
    };
  }

  String encode({bool pretty = false}) {
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(toJson())
        : jsonEncode(toJson());
  }

  factory PortableCharacterDocument.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('The package must contain a JSON object.');
    }
    return PortableCharacterDocument.fromJson(decoded);
  }

  factory PortableCharacterDocument.fromJson(Map<String, Object?> json) {
    if (json['format'] != format) {
      throw const FormatException('This is not a Whetstone character package.');
    }
    final version = json['schemaVersion'];
    if (version != currentSchemaVersion) {
      throw UnsupportedPortableCharacterVersion(version is int ? version : -1);
    }
    final characterJson = json['character'];
    final sessionJson = json['session'];
    if (characterJson is! Map<String, Object?> ||
        sessionJson is! Map<String, Object?>) {
      throw const FormatException('Character or session data is missing.');
    }

    final character = Character.fromJson(characterJson);
    final session = CharacterSession.fromJson(sessionJson);
    validate(character, session);
    return PortableCharacterDocument(character: character, session: session);
  }

  static void validate(Character character, CharacterSession session) {
    if (character.id.trim().isEmpty ||
        character.name.trim().isEmpty ||
        character.characterClass.trim().isEmpty ||
        character.level < 1) {
      throw const FormatException('The character identity is incomplete.');
    }
    final state = session.characterState;
    if (state.maxHp < 1 ||
        state.currentHp < 0 ||
        state.currentHp > state.maxHp ||
        state.temporaryHp < 0 ||
        state.deathSaveSuccesses < 0 ||
        state.deathSaveSuccesses > 3 ||
        state.deathSaveFailures < 0 ||
        state.deathSaveFailures > 3 ||
        state.resourceValues.values.any((value) => value < 0)) {
      throw const FormatException('The live character state is invalid.');
    }
    final inventory = [...session.inventory, ...session.archivedInventory];
    if (inventory.any(
      (item) =>
          item.name.trim().isEmpty ||
          item.quantity < 0 ||
          item.weightPerItem < 0,
    )) {
      throw const FormatException('The inventory contains invalid items.');
    }
  }
}
