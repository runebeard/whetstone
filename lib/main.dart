import 'package:flutter/material.dart';
import 'app_info.dart';
import 'models/check_roll.dart';
import 'persistence/character_session_repository.dart';
import 'persistence/character_definition_repository.dart';
import 'persistence/content_pack_repository.dart';
import 'persistence/app_settings_repository.dart';
import 'screens/character_vault.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    WhetstoneApp(
      repository: FileCharacterSessionRepository(),
      definitionRepository: FileCharacterDefinitionRepository(),
      contentPackRepository: FileContentPackRepository(),
      settingsRepository: FileAppSettingsRepository(),
    ),
  );
}

class WhetstoneApp extends StatelessWidget {
  final CharacterSessionRepository? repository;
  final CharacterDefinitionRepository? definitionRepository;
  final DiceRoller? diceRoller;
  final ContentPackRepository? contentPackRepository;
  final AppSettingsRepository? settingsRepository;

  const WhetstoneApp({
    super.key,
    this.repository,
    this.definitionRepository,
    this.diceRoller,
    this.contentPackRepository,
    this.settingsRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: CharacterVault(
        repository: repository,
        definitionRepository: definitionRepository,
        diceRoller: diceRoller,
        contentPackRepository: contentPackRepository,
        settingsRepository: settingsRepository,
      ),
    );
  }
}
