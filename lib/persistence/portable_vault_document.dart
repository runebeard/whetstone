import 'dart:convert';

import '../models/character.dart';
import '../models/character_session.dart';
import 'portable_character_document.dart';

class UnsupportedPortableVaultVersion implements Exception {
  final int version;

  const UnsupportedPortableVaultVersion(this.version);

  @override
  String toString() => 'Unsupported Whetstone Vault version: $version';
}

class PortableVaultDocument {
  static const format = 'whetstone-vault';
  static const currentSchemaVersion = 1;

  final DateTime createdAt;
  final Map<String, Character> characters;
  final Map<String, CharacterSession> sessions;

  const PortableVaultDocument({
    required this.createdAt,
    required this.characters,
    required this.sessions,
  });

  Map<String, Object> toJson() {
    return {
      'format': format,
      'schemaVersion': currentSchemaVersion,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'characters': characters.map(
        (id, character) => MapEntry(id, character.toJson()),
      ),
      'sessions': sessions.map((id, session) => MapEntry(id, session.toJson())),
    };
  }

  String encode({bool pretty = false}) {
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(toJson())
        : jsonEncode(toJson());
  }

  factory PortableVaultDocument.decode(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?>) {
      throw const FormatException('The backup must contain a JSON object.');
    }
    return PortableVaultDocument.fromJson(decoded);
  }

  factory PortableVaultDocument.fromJson(Map<String, Object?> json) {
    if (json['format'] != format) {
      throw const FormatException('This is not a Whetstone Vault backup.');
    }
    final version = json['schemaVersion'];
    if (version != currentSchemaVersion) {
      throw UnsupportedPortableVaultVersion(version is int ? version : -1);
    }
    final createdAtSource = json['createdAt'];
    final charactersJson = json['characters'];
    final sessionsJson = json['sessions'];
    if (createdAtSource is! String ||
        charactersJson is! Map<String, Object?> ||
        sessionsJson is! Map<String, Object?>) {
      throw const FormatException('The Vault backup is incomplete.');
    }

    final characters = charactersJson.map(
      (id, value) =>
          MapEntry(id, Character.fromJson(value as Map<String, Object?>)),
    );
    final sessions = sessionsJson.map(
      (id, value) => MapEntry(
        id,
        CharacterSession.fromJson(value as Map<String, Object?>),
      ),
    );
    validate(characters, sessions);
    return PortableVaultDocument(
      createdAt: DateTime.parse(createdAtSource),
      characters: characters,
      sessions: sessions,
    );
  }

  static void validate(
    Map<String, Character> characters,
    Map<String, CharacterSession> sessions,
  ) {
    if (characters.keys.toSet().difference(sessions.keys.toSet()).isNotEmpty ||
        sessions.keys.toSet().difference(characters.keys.toSet()).isNotEmpty) {
      throw const FormatException(
        'Every backed-up character must have matching live session data.',
      );
    }
    for (final entry in characters.entries) {
      if (entry.key != entry.value.id) {
        throw const FormatException('A character backup identity is invalid.');
      }
      PortableCharacterDocument.validate(entry.value, sessions[entry.key]!);
    }
  }
}
