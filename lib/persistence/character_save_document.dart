import '../models/character_session.dart';

class UnsupportedSaveVersion implements Exception {
  final int version;

  const UnsupportedSaveVersion(this.version);

  @override
  String toString() => 'Unsupported Whetstone save version: $version';
}

class CharacterSaveDocument {
  static const currentSchemaVersion = 1;

  final Map<String, CharacterSession> sessions;

  const CharacterSaveDocument({required this.sessions});

  Map<String, Object> toJson() {
    return {
      'schemaVersion': currentSchemaVersion,
      'characters': sessions.map(
        (characterId, session) => MapEntry(characterId, session.toJson()),
      ),
    };
  }

  factory CharacterSaveDocument.fromJson(Map<String, Object?> json) {
    final version = json['schemaVersion'];
    if (version != currentSchemaVersion) {
      throw UnsupportedSaveVersion(version is int ? version : -1);
    }

    final characters = json['characters'] as Map<String, Object?>;
    return CharacterSaveDocument(
      sessions: characters.map(
        (characterId, session) => MapEntry(
          characterId,
          CharacterSession.fromJson(session as Map<String, Object?>),
        ),
      ),
    );
  }
}
