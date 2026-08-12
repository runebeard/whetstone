import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/main.dart';
import 'package:whetstone/models/app_settings.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/persistence/app_settings_repository.dart';
import 'package:whetstone/persistence/character_definition_repository.dart';
import 'package:whetstone/persistence/character_session_repository.dart';
import 'package:whetstone/persistence/content_pack_repository.dart';

void main() {
  testWidgets('fresh users can deliberately explore sample characters', (
    tester,
  ) async {
    final settings = InMemoryAppSettingsRepository();
    final sessions = InMemoryCharacterSessionRepository();
    final definitions = InMemoryCharacterDefinitionRepository();

    Future<void> pumpApp() async {
      await tester.pumpWidget(
        WhetstoneApp(
          settingsRepository: settings,
          repository: sessions,
          definitionRepository: definitions,
          contentPackRepository: InMemoryContentPackRepository(),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpApp();
    expect(find.text('Your characters, ready for play'), findsOneWidget);
    expect(find.text('Friend Test Alpha 0.1.0'), findsOneWidget);
    expect(find.byKey(const ValueKey('alpha-release-badge')), findsOneWidget);
    expect(find.text('Eldrin'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('first-launch-use-samples')));
    await tester.pumpAndSettle();
    expect(find.text('Eldrin'), findsOneWidget);
    expect(settings.settings.onboardingComplete, isTrue);
    expect(settings.settings.sampleCharactersEnabled, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp();
    expect(find.text('Your characters, ready for play'), findsNothing);
    expect(find.text('Eldrin'), findsOneWidget);
  });

  testWidgets('cancelled creation leads to a recoverable empty Vault', (
    tester,
  ) async {
    final settings = InMemoryAppSettingsRepository();
    final sessions = InMemoryCharacterSessionRepository();
    final definitions = InMemoryCharacterDefinitionRepository();

    Future<void> pumpApp() async {
      await tester.pumpWidget(
        WhetstoneApp(
          settingsRepository: settings,
          repository: sessions,
          definitionRepository: definitions,
          contentPackRepository: InMemoryContentPackRepository(),
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpApp();
    await tester.tap(
      find.byKey(const ValueKey('first-launch-create-character')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Class & Essentials'), findsOneWidget);
    expect(settings.settings.sampleCharactersEnabled, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp();
    expect(find.text('Your Vault is empty'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('empty-vault-create-character')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('empty-vault-add-samples')));
    await tester.pumpAndSettle();
    expect(find.text('Eldrin'), findsOneWidget);
  });

  testWidgets('existing saved data bypasses first-launch onboarding', (
    tester,
  ) async {
    final settings = InMemoryAppSettingsRepository();
    final sessions = InMemoryCharacterSessionRepository();
    final definitions = InMemoryCharacterDefinitionRepository();
    final eldrin = seedCharacters.first;
    await definitions.saveCatalog(
      CharacterDefinitionCatalog(characters: {eldrin.id: eldrin}),
    );
    await sessions.saveSessions({
      eldrin.id: CharacterSession.fromCharacter(eldrin),
    });

    await tester.pumpWidget(
      WhetstoneApp(
        settingsRepository: settings,
        repository: sessions,
        definitionRepository: definitions,
        contentPackRepository: InMemoryContentPackRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your characters, ready for play'), findsNothing);
    expect(find.text('Eldrin'), findsOneWidget);
    expect(settings.settings.onboardingComplete, isTrue);
  });

  testWidgets('completed onboarding does not repeat for an empty Vault', (
    tester,
  ) async {
    final settings = InMemoryAppSettingsRepository(
      settings: const AppSettings(onboardingComplete: true),
    );

    await tester.pumpWidget(
      WhetstoneApp(
        settingsRepository: settings,
        repository: InMemoryCharacterSessionRepository(),
        definitionRepository: InMemoryCharacterDefinitionRepository(),
        contentPackRepository: InMemoryContentPackRepository(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Your characters, ready for play'), findsNothing);
    expect(find.text('Your Vault is empty'), findsOneWidget);
  });
}
