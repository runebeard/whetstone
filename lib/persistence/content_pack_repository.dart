import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/content_pack.dart';

abstract class ContentPackRepository {
  Future<Map<String, ContentPack>> loadPacks();

  Future<void> savePacks(Map<String, ContentPack> packs);
}

class ContentPackCatalog {
  static const currentSchemaVersion = 1;

  final Map<String, ContentPack> packs;

  const ContentPackCatalog({required this.packs});

  Map<String, Object> toJson() {
    return {
      'schemaVersion': currentSchemaVersion,
      'packs': packs.map((id, pack) => MapEntry(id, pack.toJson())),
    };
  }

  factory ContentPackCatalog.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != currentSchemaVersion) {
      throw const FormatException('Unsupported content-pack catalog version.');
    }
    final packs = json['packs'] as Map<String, Object?>;
    return ContentPackCatalog(
      packs: packs.map(
        (id, value) =>
            MapEntry(id, ContentPack.fromJson(value as Map<String, Object?>)),
      ),
    );
  }
}

class FileContentPackRepository implements ContentPackRepository {
  FileContentPackRepository({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  static const _fileName = 'whetstone-content-packs.json';
  final Future<Directory> Function() _directory;
  Future<void> _pendingWrite = Future.value();

  Future<File> get _saveFile async {
    final directory = await _directory();
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  @override
  Future<Map<String, ContentPack>> loadPacks() async {
    final file = await _saveFile;
    if (!await file.exists()) return {};
    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    return ContentPackCatalog.fromJson(json).packs;
  }

  @override
  Future<void> savePacks(Map<String, ContentPack> packs) {
    final snapshot = jsonEncode(ContentPackCatalog(packs: packs).toJson());
    _pendingWrite = _pendingWrite.then((_) async {
      final file = await _saveFile;
      await file.writeAsString(snapshot, flush: true);
    });
    return _pendingWrite;
  }
}

class InMemoryContentPackRepository implements ContentPackRepository {
  String? _savedJson;

  @override
  Future<Map<String, ContentPack>> loadPacks() async {
    if (_savedJson == null) return {};
    final json = jsonDecode(_savedJson!) as Map<String, Object?>;
    return ContentPackCatalog.fromJson(json).packs;
  }

  @override
  Future<void> savePacks(Map<String, ContentPack> packs) async {
    _savedJson = jsonEncode(ContentPackCatalog(packs: packs).toJson());
  }
}
