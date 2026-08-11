import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/inventory_item.dart';
import 'package:whetstone/models/journal_entry.dart';
import 'package:whetstone/persistence/portable_character_document.dart';

void main() {
  final character = Character(
    id: 'portable-hero',
    name: 'Aria',
    characterClass: 'Bard',
    level: 4,
    currentHp: 24,
    maxHp: 31,
    armourClass: 14,
    initiativeModifier: 2,
    status: 'Exploring',
    journalEntries: [
      JournalEntry(
        id: 'silver-song',
        title: 'Recover the Silver Song',
        notes: 'The final verse is hidden beneath the theatre.',
      ),
    ],
  );
  const session = CharacterSession(
    characterState: CharacterState(
      currentHp: 19,
      maxHp: 31,
      temporaryHp: 3,
      armourClass: 14,
      initiativeModifier: 2,
      deathSaveSuccesses: 0,
      deathSaveFailures: 0,
      activeConditions: {'Invisible'},
      pinnedActionKeys: {},
      resourceValues: {},
    ),
    inventory: [
      InventoryItem(
        name: 'Silver Flute',
        quantity: 1,
        weightPerItem: 1,
        category: ItemCategory.equipment,
      ),
    ],
    archivedInventory: [],
    isInCombat: true,
  );

  test('portable package round-trips definition and live state', () {
    final encoded = PortableCharacterDocument(
      character: character,
      session: session,
    ).encode(pretty: true);

    final restored = PortableCharacterDocument.decode(encoded);

    expect(restored.character.name, 'Aria');
    expect(
      restored.character.journalEntries.single.title,
      'Recover the Silver Song',
    );
    expect(restored.session.characterState.currentHp, 19);
    expect(restored.session.characterState.temporaryHp, 3);
    expect(restored.session.characterState.activeConditions, {'Invisible'});
    expect(restored.session.inventory.single.name, 'Silver Flute');
    expect(restored.session.isInCombat, isTrue);
  });

  test('rejects packages with the wrong format or future version', () {
    expect(
      () => PortableCharacterDocument.fromJson({
        'format': 'some-other-app',
        'schemaVersion': 1,
      }),
      throwsFormatException,
    );
    expect(
      () => PortableCharacterDocument.fromJson({
        'format': PortableCharacterDocument.format,
        'schemaVersion': 999,
      }),
      throwsA(isA<UnsupportedPortableCharacterVersion>()),
    );
  });

  test('rejects impossible live character state', () {
    final json = PortableCharacterDocument(
      character: character,
      session: session,
    ).toJson();
    final sessionJson = json['session'] as Map<String, Object>;
    final stateJson = sessionJson['characterState'] as Map<String, Object>;
    stateJson['currentHp'] = 99;

    expect(
      () => PortableCharacterDocument.fromJson(json),
      throwsFormatException,
    );
  });
}
