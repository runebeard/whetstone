import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/spell.dart';
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
    combatRound: 3,
    combatInitiative: 16,
    usedCombatActions: {CombatActionCost.bonusAction},
  );

  test('upcast damage uses the selected slot and survives a save', () {
    const spell = Spell(
      id: 'burst',
      name: 'Burst',
      level: 2,
      prepared: true,
      summary: 'Example',
      damageFormula: '3d6 + 2',
      additionalDicePerSlotLevel: 2,
    );
    final restored = Character.fromJson(
      character.copyWith(spells: [spell]).toJson(),
    );
    final burst = restored.spells.single;
    expect(restored.damageFormulaFor(burst), '3d6 + 2');
    expect(restored.damageFormulaFor(burst, slotLevel: 1), '3d6 + 2');
    expect(restored.damageFormulaFor(burst, slotLevel: 4), '7d6 + 2');
  });

  test('an active spell retains its slot until concentration changes', () {
    final state = session.characterState.copyWith(
      concentrationSpellId: 'burst',
      concentrationSlotLevel: 4,
      concentrationTurnsRemaining: 2,
    );
    final restored = CharacterState.fromJson(state.toJson());
    expect(restored.concentrationSlotLevel, 4);
    expect(restored.concentrationTurnsRemaining, 2);
    final nextTurn = restored.advanceConcentrationTurn();
    expect(nextTurn.concentrationTurnsRemaining, 1);
    final expired = nextTurn.advanceConcentrationTurn();
    expect(expired.concentrationSpellId, isNull);
    expect(expired.concentrationSlotLevel, isNull);
    expect(expired.concentrationTurnsRemaining, isNull);
    expect(restored.copyWith(currentHp: 10).concentrationSlotLevel, 4);
    expect(
      restored.copyWith(concentrationSpellId: 'another').concentrationSlotLevel,
      isNull,
    );
    expect(
      restored.copyWith(clearConcentration: true).concentrationSlotLevel,
      isNull,
    );
  });

  test('opt-in cantrip damage scales after a save round-trip', () {
    const spell = Spell(
      id: 'spark',
      name: 'Spark',
      level: 0,
      prepared: false,
      summary: 'A spark',
      damageFormula: '1d8 + 2',
      scaleCantripDamage: true,
      castingAbility: Ability.wisdom,
      addCastingModifierToDamage: true,
    );
    final decoded = Character.fromJson(
      character.copyWith(spells: [spell]).toJson(),
    );
    final restored = decoded.spells.single;
    final empowered = decoded.copyWith(
      level: 5,
      abilityScores: {Ability.wisdom: 16},
    );
    expect(empowered.damageFormulaFor(restored), '2d8 + 5');
    for (final (level, dice) in [(1, 1), (5, 2), (11, 3), (17, 4)]) {
      expect(
        decoded.copyWith(level: level).damageFormulaFor(restored),
        '${dice}d8 + 2',
      );
    }
  });

  test('casting details round-trip and older spells retain defaults', () {
    const spell = Spell(
      id: 'ritual',
      name: 'Ritual',
      level: 1,
      prepared: true,
      summary: 'Example',
      ritual: true,
      castingAbility: Ability.wisdom,
      deriveAttackModifier: true,
      savingThrowAbility: Ability.dexterity,
      halfDamageOnSave: true,
      concentration: true,
      repeatableEffect: true,
      rollEffectOnCast: true,
      castingTime: '1 minute',
      range: 'Touch',
      duration: '10 minutes',
      components: 'V, S, M',
    );
    final data = character.copyWith(spells: [spell]).toJson();
    final decoded = Character.fromJson(data);
    final restored = decoded.spells.single;
    expect(restored.castingAbility, Ability.wisdom);
    expect(restored.savingThrowAbility, Ability.dexterity);
    expect(restored.halfDamageOnSave, isTrue);
    expect(decoded.spellSaveDc(restored), 10);
    expect(decoded.attackModifierFor(restored), 2);
    expect(
      decoded
          .copyWith(abilityScores: {Ability.wisdom: 16})
          .attackModifierFor(restored),
      5,
    );
    expect(
      decoded
          .copyWith(abilityScores: {Ability.wisdom: 16})
          .spellSaveDc(restored),
      13,
    );
    expect(restored.ritual, isTrue);
    expect(restored.concentration, isTrue);
    expect(restored.repeatableEffect, isTrue);
    expect(restored.rollEffectOnCast, isTrue);
    expect(restored.castingTime, '1 minute');
    expect(restored.range, 'Touch');
    expect(restored.duration, '10 minutes');
    expect(restored.components, 'V, S, M');

    final legacy = (data['spells'] as List).single as Map<String, Object?>;
    for (final key in [
      'ritual',
      'concentration',
      'castingTime',
      'range',
      'duration',
      'components',
    ]) {
      legacy.remove(key);
    }
    final older = Character.fromJson(data).spells.single;
    expect(older.ritual, isFalse);
    expect(older.castingTime, isNull);
  });

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
    expect(restored.session.combatRound, 3);
    expect(restored.session.combatInitiative, 16);
    expect(restored.session.usedCombatActions, {CombatActionCost.bonusAction});
  });

  test('preserves saved class rules through a character edit and export', () {
    const snapshot = {
      'example': ['opaque snapshot data'],
    };
    final imported = Character.fromJson({
      ...character.toJson(),
      'savedClassRules': snapshot,
    });
    final exported = PortableCharacterDocument(
      character: imported.copyWith(name: 'Edited'),
      session: session,
    ).encode();

    final restored = PortableCharacterDocument.decode(exported);
    expect(restored.character.name, 'Edited');
    expect(restored.character.savedClassRules, snapshot);
    expect(character.toJson(), isNot(contains('savedClassRules')));
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
