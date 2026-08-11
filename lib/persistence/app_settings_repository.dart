import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/app_settings.dart';

abstract class AppSettingsRepository {
  Future<AppSettings> loadSettings();

  Future<void> saveSettings(AppSettings settings);
}

class FileAppSettingsRepository implements AppSettingsRepository {
  FileAppSettingsRepository({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationDocumentsDirectory;

  static const _fileName = 'whetstone-settings.json';
  final Future<Directory> Function() _directory;
  Future<void> _pendingWrite = Future.value();

  Future<File> get _saveFile async {
    final directory = await _directory();
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  @override
  Future<AppSettings> loadSettings() async {
    final file = await _saveFile;
    if (!await file.exists()) return const AppSettings();
    final json = jsonDecode(await file.readAsString()) as Map<String, Object?>;
    return AppSettings.fromJson(json);
  }

  @override
  Future<void> saveSettings(AppSettings settings) {
    final snapshot = jsonEncode(settings.toJson());
    _pendingWrite = _pendingWrite.then((_) async {
      final file = await _saveFile;
      await file.writeAsString(snapshot, flush: true);
    });
    return _pendingWrite;
  }
}

class InMemoryAppSettingsRepository implements AppSettingsRepository {
  AppSettings settings;

  InMemoryAppSettingsRepository({this.settings = const AppSettings()});

  @override
  Future<AppSettings> loadSettings() async => settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    this.settings = AppSettings.fromJson(settings.toJson());
  }
}
