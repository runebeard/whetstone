import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/character.dart';

abstract class CharacterDefinitionRepository {
  Future<CharacterDefinitionCatalog> loadCatalog();

  Future<void> saveCatalog(CharacterDefinitionCatalog catalog);
}

class CharacterDefinitionCatalog {
  static const currentSchemaVersion = 4;

  final Map<String, Character> characters;
  final Set<String> deletedCharacterIds;
  final int schemaVersion;

  const CharacterDefinitionCatalog({
    required this.characters,
    this.deletedCharacterIds = const {},
    this.schemaVersion = currentSchemaVersion,
  });

  Map<String, Object> toJson() {
    return {
      'schemaVersion': currentSchemaVersion,
      'characters': characters.map(
        (id, character) => MapEntry(id, character.toJson()),
      ),
      'deletedCharacterIds': deletedCharacterIds.toList()..sort(),
    };
  }

  factory CharacterDefinitionCatalog.fromJson(Map<String, Object?> json) {
    final schemaVersion = json['schemaVersion'] as int;
    if (schemaVersion < 1 || schemaVersion > currentSchemaVersion) {
      throw const FormatException('Unsupported character definition version');
    }
    final characters = json['characters'] as Map<String, Object?>;
    return CharacterDefinitionCatalog(
      characters: characters.map(
        (id, value) =>
            MapEntry(id, Character.fromJson(value as Map<String, Object?>)),
      ),
      deletedCharacterIds:
          (json['deletedCharacterIds'] as List<Object?>?)
              ?.cast<String>()
              .toSet() ??
          {},
      schemaVersion: schemaVersion,
    );
  }
}

class FileCharacterDefinitionRepository
    implements CharacterDefinitionRepository {
  FileCharacterDefinitionRepository({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  static const _fileName = 'whetstone-characters.json';
  final Future<Directory> Function() _directory;
  Future<void> _pendingWrite = Future.value();

  Future<File> get _saveFile async {
    final directory = await _directory();
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  @override
  Future<CharacterDefinitionCatalog> loadCatalog() async {
    final file = await _saveFile;
    if (!await file.exists()) {
      return const CharacterDefinitionCatalog(characters: {});
    }
    final document =
        jsonDecode(await file.readAsString()) as Map<String, Object?>;
    return CharacterDefinitionCatalog.fromJson(document);
  }

  @override
  Future<void> saveCatalog(CharacterDefinitionCatalog catalog) {
    final snapshot = jsonEncode(catalog.toJson());
    _pendingWrite = _pendingWrite.then((_) async {
      final file = await _saveFile;
      await file.writeAsString(snapshot, flush: true);
    });
    return _pendingWrite;
  }
}

class InMemoryCharacterDefinitionRepository
    implements CharacterDefinitionRepository {
  String? _savedJson;

  @override
  Future<CharacterDefinitionCatalog> loadCatalog() async {
    if (_savedJson == null) {
      return const CharacterDefinitionCatalog(characters: {});
    }
    final document = jsonDecode(_savedJson!) as Map<String, Object?>;
    return CharacterDefinitionCatalog.fromJson(document);
  }

  @override
  Future<void> saveCatalog(CharacterDefinitionCatalog catalog) async {
    _savedJson = jsonEncode(catalog.toJson());
  }
}
