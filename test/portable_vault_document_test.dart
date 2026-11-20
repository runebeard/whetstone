import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/session_event.dart';
import 'package:whetstone/persistence/portable_vault_document.dart';

void main() {
  test('legacy vault entries retain live state and default new fields', () {
    final eldrin = seedCharacters.first;
    final base = CharacterSession.fromCharacter(eldrin);
    final definition = eldrin.toJson()..remove('savedClassRules');
    final state = base.characterState.toJson()
      ..['currentHp'] = 12
      ..['temporaryHp'] = 3
      ..['activeConditions'] = ['Poisoned'];
    final legacy = PortableVaultDocument.fromJson({
      'format': PortableVaultDocument.format,
      'schemaVersion': 1,
      'createdAt': '2026-08-12T09:00:00Z',
      'characters': {eldrin.id: definition},
      'sessions': {
        eldrin.id: {
          'characterState': state,
          'inventory': [for (final item in base.inventory) item.toJson()],
          'archivedInventory': [],
          'isInCombat': true,
        },
      },
    });
    final restored = PortableVaultDocument.decode(
      legacy.encode(),
    ).sessions[eldrin.id]!;
    expect(restored.characterState.currentHp, 12);
    expect(restored.characterState.temporaryHp, 3);
    expect(restored.characterState.activeConditions, {'Poisoned'});
    expect(restored.characterState.conditionTurns, isEmpty);
    expect(restored.characterState.hitDiceSpent, 0);
    expect(restored.characterState.concentrationTarget, isNull);
    expect(restored.combatRound, 1);
    expect(restored.usedCombatActions, isEmpty);
    expect(restored.readiedAction, isNull);
    expect(
      restored.inventory.map((item) => item.name),
      base.inventory.map((item) => item.name),
    );
  });

  test('vault package round-trips every character and live session', () {
    final eldrin = seedCharacters[0];
    final mara = seedCharacters[1];
    final eldrinBase = CharacterSession.fromCharacter(eldrin);
    final eldrinSession = CharacterSession(
      characterState: eldrinBase.characterState.copyWith(
        currentHp: eldrin.maxHp - 5,
        temporaryHp: 3,
        activeConditions: {'Blessed'},
      ),
      inventory: eldrinBase.inventory,
      archivedInventory: eldrinBase.archivedInventory,
      isInCombat: true,
      timeline: [
        SessionEvent(
          id: 'entered-combat',
          occurredAt: DateTime.utc(2026, 8, 11, 9, 30),
          type: SessionEventType.combat,
          title: 'Entered combat',
        ),
      ],
    );

    final encoded = PortableVaultDocument(
      createdAt: DateTime.utc(2026, 8, 11, 10),
      characters: {eldrin.id: eldrin, mara.id: mara},
      sessions: {
        eldrin.id: eldrinSession,
        mara.id: CharacterSession.fromCharacter(mara),
      },
    ).encode(pretty: true);

    final restored = PortableVaultDocument.decode(encoded);

    expect(restored.characters.keys, containsAll([eldrin.id, mara.id]));
    expect(
      restored.sessions[eldrin.id]!.characterState.currentHp,
      eldrin.maxHp - 5,
    );
    expect(restored.sessions[eldrin.id]!.characterState.temporaryHp, 3);
    expect(restored.sessions[eldrin.id]!.characterState.activeConditions, {
      'Blessed',
    });
    expect(restored.sessions[eldrin.id]!.isInCombat, isTrue);
    expect(
      restored.sessions[eldrin.id]!.timeline.single.title,
      'Entered combat',
    );
    expect(restored.createdAt, DateTime.utc(2026, 8, 11, 10));
  });

  test('rejects the wrong format and unsupported versions', () {
    expect(
      () => PortableVaultDocument.fromJson({
        'format': 'some-other-app',
        'schemaVersion': 1,
      }),
      throwsFormatException,
    );
    expect(
      () => PortableVaultDocument.fromJson({
        'format': PortableVaultDocument.format,
        'schemaVersion': 999,
      }),
      throwsA(isA<UnsupportedPortableVaultVersion>()),
    );
  });

  test('rejects backups without matching live sessions', () {
    final character = seedCharacters.first;

    expect(
      () => PortableVaultDocument.validate({character.id: character}, const {}),
      throwsFormatException,
    );
  });
}
