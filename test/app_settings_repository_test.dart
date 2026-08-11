import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/app_settings.dart';
import 'package:whetstone/persistence/app_settings_repository.dart';

void main() {
  test('new installations begin without completed onboarding', () async {
    final repository = InMemoryAppSettingsRepository();

    final settings = await repository.loadSettings();

    expect(settings.onboardingComplete, isFalse);
    expect(settings.sampleCharactersEnabled, isFalse);
  });

  test('settings survive a real file repository round-trip', () async {
    final directory = await Directory.systemTemp.createTemp(
      'whetstone-settings-test-',
    );
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });
    Future<Directory> testDirectory() async => directory;
    final repository = FileAppSettingsRepository(directory: testDirectory);

    await repository.saveSettings(
      const AppSettings(
        onboardingComplete: true,
        sampleCharactersEnabled: true,
      ),
    );
    final reopened = FileAppSettingsRepository(directory: testDirectory);
    final restored = await reopened.loadSettings();

    expect(restored.onboardingComplete, isTrue);
    expect(restored.sampleCharactersEnabled, isTrue);
  });
}
