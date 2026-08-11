import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/inventory_item.dart';
import 'package:whetstone/models/session_event.dart';
import 'package:whetstone/persistence/character_save_document.dart';
import 'package:whetstone/persistence/character_session_repository.dart';

void main() {
  test('save document round-trips every mutable character field', () {
    const state = CharacterState(
      currentHp: 17,
      maxHp: 42,
      temporaryHp: 4,
      armourClass: 16,
      initiativeModifier: 3,
      deathSaveSuccesses: 2,
      deathSaveFailures: 1,
      activeConditions: {'Poisoned'},
      pinnedActionKeys: {'spell:shield'},
      resourceValues: {'level_1_slots': 2},
    );
    final session = CharacterSession(
      characterState: state,
      inventory: [
        InventoryItem(
          name: 'Potion',
          quantity: 2,
          weightPerItem: 0.5,
          category: ItemCategory.consumable,
        ),
      ],
      archivedInventory: [
        InventoryItem(
          name: 'Old Map',
          quantity: 1,
          weightPerItem: 0,
          category: ItemCategory.quest,
        ),
      ],
      isInCombat: true,
      timeline: [
        SessionEvent(
          id: 'event-1',
          occurredAt: DateTime.utc(2026, 8, 11, 19, 30),
          type: SessionEventType.roll,
          title: 'Perception: 18',
          detail: 'd20 14 + 4 = 18',
        ),
      ],
    );

    final json = CharacterSaveDocument(sessions: {'eldrin': session}).toJson();
    final restored = CharacterSaveDocument.fromJson(json).sessions['eldrin']!;

    expect(restored.characterState.currentHp, 17);
    expect(restored.characterState.temporaryHp, 4);
    expect(restored.characterState.activeConditions, {'Poisoned'});
    expect(restored.characterState.pinnedActionKeys, {'spell:shield'});
    expect(restored.characterState.resourceValues['level_1_slots'], 2);
    expect(restored.inventory.single.quantity, 2);
    expect(restored.archivedInventory.single.name, 'Old Map');
    expect(restored.isInCombat, isTrue);
    expect(restored.timeline.single.title, 'Perception: 18');
    expect(restored.timeline.single.type, SessionEventType.roll);
    expect(
      restored.timeline.single.occurredAt,
      DateTime.utc(2026, 8, 11, 19, 30),
    );
  });

  test('rejects save data from an unknown future schema', () {
    expect(
      () => CharacterSaveDocument.fromJson({
        'schemaVersion': 999,
        'characters': <String, Object?>{},
      }),
      throwsA(isA<UnsupportedSaveVersion>()),
    );
  });

  test('older version-one sessions default to exploration', () {
    final sessionJson =
        const CharacterSession(
            characterState: CharacterState(
              currentHp: 10,
              maxHp: 10,
              temporaryHp: 0,
              armourClass: 12,
              initiativeModifier: 0,
              deathSaveSuccesses: 0,
              deathSaveFailures: 0,
              activeConditions: {},
              pinnedActionKeys: {},
              resourceValues: {},
            ),
            inventory: [],
            archivedInventory: [],
          ).toJson()
          ..remove('isInCombat')
          ..remove('timeline');

    final restored = CharacterSaveDocument.fromJson({
      'schemaVersion': 1,
      'characters': {'eldrin': sessionJson},
    });

    expect(restored.sessions['eldrin']!.isInCombat, isFalse);
    expect(restored.sessions['eldrin']!.timeline, isEmpty);
  });

  test('file repository restores a session through a new instance', () async {
    final directory = await Directory.systemTemp.createTemp(
      'whetstone-save-test-',
    );
    addTearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });
    Future<Directory> testDirectory() async => directory;
    final repository = FileCharacterSessionRepository(directory: testDirectory);
    const session = CharacterSession(
      characterState: CharacterState(
        currentHp: 9,
        maxHp: 20,
        temporaryHp: 0,
        armourClass: 14,
        initiativeModifier: 2,
        deathSaveSuccesses: 0,
        deathSaveFailures: 0,
        activeConditions: {},
        pinnedActionKeys: {'weapon:dagger'},
        resourceValues: {},
      ),
      inventory: [],
      archivedInventory: [],
    );

    await repository.saveSessions({'eldrin': session});
    final reopenedRepository = FileCharacterSessionRepository(
      directory: testDirectory,
    );
    final restored = await reopenedRepository.loadSessions();

    expect(restored['eldrin']!.characterState.currentHp, 9);
    expect(restored['eldrin']!.characterState.pinnedActionKeys, {
      'weapon:dagger',
    });
  });
}
