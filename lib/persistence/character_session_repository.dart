import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/character_session.dart';
import 'character_save_document.dart';

abstract class CharacterSessionRepository {
  Future<Map<String, CharacterSession>> loadSessions();

  Future<void> saveSessions(Map<String, CharacterSession> sessions);
}

class FileCharacterSessionRepository implements CharacterSessionRepository {
  FileCharacterSessionRepository({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  static const _fileName = 'whetstone-save.json';
  final Future<Directory> Function() _directory;
  Future<void> _pendingWrite = Future.value();

  Future<File> get _saveFile async {
    final directory = await _directory();
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  @override
  Future<Map<String, CharacterSession>> loadSessions() async {
    final file = await _saveFile;
    if (!await file.exists()) {
      return {};
    }

    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    return CharacterSaveDocument.fromJson(json).sessions;
  }

  @override
  Future<void> saveSessions(Map<String, CharacterSession> sessions) {
    final snapshot = jsonEncode(
      CharacterSaveDocument(sessions: sessions).toJson(),
    );
    _pendingWrite = _pendingWrite.then((_) async {
      final file = await _saveFile;
      await file.writeAsString(snapshot, flush: true);
    });
    return _pendingWrite;
  }
}

class InMemoryCharacterSessionRepository implements CharacterSessionRepository {
  String? _savedJson;

  @override
  Future<Map<String, CharacterSession>> loadSessions() async {
    if (_savedJson == null) {
      return {};
    }

    final json = jsonDecode(_savedJson!) as Map<String, Object?>;
    return CharacterSaveDocument.fromJson(json).sessions;
  }

  @override
  Future<void> saveSessions(Map<String, CharacterSession> sessions) async {
    _savedJson = jsonEncode(CharacterSaveDocument(sessions: sessions).toJson());
  }
}
