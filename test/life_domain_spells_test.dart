import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/class_spells.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'cleric_channel_divinity_test.dart' as base;
import 'draconic_spell_grants_test.dart' as helpers;

Character life(int level) => base
    .cleric(level)
    .copyWith(
      subclasses: {'Cleric': 'Life Domain'},
      spells: [],
      resources: fullCasterSlots(level),
    );

void main() {
  test(
    'Life Domain grants four/six/eight/ten Wisdom spells once and always prepared',
    () {
      for (final (level, count) in [
        (2, 0),
        (3, 4),
        (5, 6),
        (7, 8),
        (9, 10),
        (20, 10),
      ]) {
        final character = withBuiltInSpellGrants(life(level));
        expect(character.spells, hasLength(count));
        expect(
          character.spells.every(
            (s) =>
                s.isLifeDomainGrant &&
                s.prepared &&
                s.castingAbility == Ability.wisdom &&
                character.isAlwaysPreparedSpell(s),
          ),
          isTrue,
        );
        final restored = withBuiltInSpellGrants(
          Character.fromJson(character.toJson()),
        );
        expect(
          restored.spells.map((s) => s.id).toSet(),
          character.spells.map((s) => s.id).toSet(),
        );
      }
    },
  );
  test(
    'Class levels and subclass gate Life spells and remove obsolete pins',
    () {
      var character = withBuiltInSpellGrants(life(9));
      character = character.copyWith(
        initiallyPinnedActionKeys: character.spells
            .map((s) => s.actionKey)
            .toSet(),
      );
      final changed = withBuiltInSpellGrants(
        character.copyWith(subclasses: {'Cleric': 'Other'}),
      );
      expect(changed.spells, isEmpty);
      expect(changed.initiallyPinnedActionKeys, isEmpty);
      expect(
        withBuiltInSpellGrants(
          life(20).copyWith(additionalClassLevels: {'Fighter': 18}),
        ).spells,
        isEmpty,
      );
    },
  );
  test(
    'Authored and Wizard versions survive as separate entries with their preparation',
    () {
      const wizard = Spell(
        id: 'wizard-bless',
        name: 'Bless',
        level: 1,
        prepared: false,
        castingAbility: Ability.intelligence,
        summary: 'Owned version',
      );
      final character = withBuiltInSpellGrants(
        life(3).copyWith(spells: [wizard]),
      );
      expect(character.spells, hasLength(5));
      expect(character.spells.first, same(wizard));
      expect(character.isAlwaysPreparedSpell(wizard), isFalse);
      expect(character.spells.where((s) => s.name == 'Bless'), hasLength(2));
    },
  );
  test(
    'Life, Draconic and Circle grants coexist with separate abilities and IDs',
    () {
      final character = life(13).copyWith(
        additionalClassLevels: {'Sorcerer': 5, 'Druid': 3},
        subclasses: {
          'Cleric': 'Life Domain',
          'Sorcerer': 'Draconic Sorcery',
          'Druid': 'Circle of the Land',
        },
      );
      final spells = withClassSpells(character, DruidLand.polar);
      expect(spells.where((s) => s.isLifeDomainGrant), hasLength(6));
      expect(spells.where((s) => s.isDraconicGrant), hasLength(6));
      expect(spells.where((s) => s.isCircleGrant), hasLength(3));
      expect(spells.map((s) => s.id).toSet(), hasLength(15));
      expect(
        spells
            .where((s) => s.isLifeDomainGrant)
            .every((s) => s.castingAbility == Ability.wisdom),
        isTrue,
      );
    },
  );

  test('Life metadata preserves costly components and Bonus Action spells', () {
    final spells = withBuiltInSpellGrants(life(9)).spells;
    for (final name in ['Bless', 'Revivify', 'Greater Restoration']) {
      expect(
        spells.singleWhere((s) => s.name == name).hasCostlyOrConsumedMaterial,
        isTrue,
      );
    }
    for (final name in ['Lesser Restoration', 'Mass Healing Word']) {
      expect(
        spells.singleWhere((s) => s.name == name).castingTime,
        'Bonus Action',
      );
    }
    expect(
      spells.singleWhere((s) => s.name == 'Aura of Life').duration,
      'Concentration, up to 10 minutes',
    );
    expect(spells.every((s) => s.damageFormula == null), isTrue);
  });

  for (final (name, level, available, turns, cost) in [
    ('Bless', 1, 4, 10, CombatActionCost.action),
    ('Aura of Life', 4, 3, 100, CombatActionCost.action),
    ('Lesser Restoration', 2, 3, null, CombatActionCost.bonusAction),
  ]) {
    testWidgets(
      'Life $name casts with correct slot/action/timer and survives reload',
      (tester) async {
        var character = withBuiltInSpellGrants(life(9));
        final spell = character.spells.singleWhere((s) => s.name == name);
        character = character.copyWith(
          initiallyPinnedActionKeys: {spell.actionKey},
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            character,
          ).copyWith(currentHp: 22),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        var generation = 0;
        Widget app() => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(generation),
            character: character,
            initialSession: session,
            onCharacterChanged: (v) => character = v,
            onSessionChanged: (v) => session = v,
          ),
        );
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        await helpers.tap(tester, find.text(name).first);
        await helpers.tap(tester, find.text('Cast').last);
        if (name == 'Lesser Restoration') {
          await helpers.tap(tester, find.text('Treat another creature'));
          await helpers.tap(tester, find.text('End Poisoned'));
        }
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(session.usedCombatActions, isEmpty);
        await helpers.tap(tester, find.text(name).first);
        await helpers.tap(tester, find.text('Cast').last);
        if (name == 'Lesser Restoration') {
          await helpers.tap(tester, find.text('Treat another creature'));
          await helpers.tap(tester, find.text('End Poisoned'));
        }
        await helpers.tap(
          tester,
          find.text('Level $level · $available remaining'),
        );
        expect(
          session.characterState.resourceValues[spellSlotId(level)],
          available - 1,
        );
        expect(session.usedCombatActions, {cost});
        expect(session.characterState.currentHp, 22);
        expect(session.characterState.concentrationTurnsRemaining, turns);
        if (turns != null) {
          expect(session.characterState.concentrationSpellId, spell.id);
        }
        character = Character.fromJson(character.toJson());
        session = CharacterSession.fromJson(session.toJson());
        generation++;
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(
          character.spells.where((s) => s.isLifeDomainGrant),
          hasLength(10),
        );
        expect(session.characterState.concentrationTurnsRemaining, turns);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Canonical Life preparation/metadata repair stays protected in Spellbook',
    (tester) async {
      var character = withBuiltInSpellGrants(life(9));
      character = Character.fromJson({
        ...character.toJson(),
        'spells': [
          for (final raw
              in (character.toJson()['spells'] as List)
                  .cast<Map<String, Object?>>())
            {
              ...raw,
              'prepared': false,
              'castingAbility': 'intelligence',
              'components': 'V',
            },
        ],
      });
      var session = CharacterSession.fromCharacter(character);
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            onCharacterChanged: (v) => character = v,
            onSessionChanged: (v) => session = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        character.spells.every(
          (s) => s.prepared && s.castingAbility == Ability.wisdom,
        ),
        isTrue,
      );
      expect(
        character.spells
            .singleWhere((s) => s.name == 'Bless')
            .hasCostlyOrConsumedMaterial,
        isTrue,
      );
      await helpers.tap(tester, find.text('Spellbook'));
      await tester.ensureVisible(find.text('Bless'));
      await tester.longPress(find.text('Bless'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Spell'), findsNothing);
      expect(find.text('Remove Spell'), findsNothing);
      expect(find.text('Unprepare'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Imported grant flags cannot turn Cure Wounds into a slot-free ritual',
    (tester) async {
      var character = withBuiltInSpellGrants(life(9));
      character = Character.fromJson({
        ...character.toJson(),
        'spells': [
          for (final raw
              in (character.toJson()['spells'] as List)
                  .cast<Map<String, Object?>>())
            {
              ...raw,
              'ritual': true,
              'repeatableEffect': true,
              'additionalDicePerSlotLevel': 7,
              'scaleCantripDamage': true,
              'addCastingModifierToDamage': true,
              'halfDamageOnSave': false,
            },
        ],
      });
      var session = CharacterSession.fromCharacter(character);
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            onCharacterChanged: (v) => character = v,
            onSessionChanged: (v) => session = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        character.spells.every(
          (s) =>
              !s.ritual &&
              !s.repeatableEffect &&
              !s.scaleCantripDamage &&
              s.additionalDicePerSlotLevel == 0 &&
              !s.addCastingModifierToDamage,
        ),
        isTrue,
      );
      await helpers.tap(tester, find.text('Spellbook'));
      await helpers.tap(tester, find.text('Cure Wounds'));
      expect(find.text('Cast as Ritual'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Losing Life Domain cleans live grant concentration/pins without refilling slots',
    (tester) async {
      var character = withBuiltInSpellGrants(life(9));
      final spell = character.spells.singleWhere(
        (s) => s.name == 'Aura of Life',
      );
      character = character.copyWith(
        subclasses: {'Cleric': 'Other'},
        initiallyPinnedActionKeys: {spell.actionKey},
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(character).copyWith(
          currentHp: 22,
          pinnedActionKeys: {spell.actionKey},
          concentrationSpellId: spell.id,
          concentrationSlotLevel: 4,
          concentrationTurnsRemaining: 100,
          resourceValues: {spellSlotId(4): 1},
        ),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            onCharacterChanged: (v) => character = v,
            onSessionChanged: (v) => session = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(character.spells, isEmpty);
      expect(session.characterState.concentrationSpellId, isNull);
      expect(
        session.characterState.pinnedActionKeys,
        isNot(contains(spell.actionKey)),
      );
      expect(session.characterState.resourceValues[spellSlotId(4)], 1);
      expect(session.characterState.currentHp, 22);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Life advancement acquires grants once without refilling spent slots',
    (tester) async {
      var character = life(2).copyWith(subclasses: {});
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          character,
        ).copyWith(currentHp: 22, resourceValues: {spellSlotId(1): 1}),
        inventory: [],
        archivedInventory: [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            onCharacterChanged: (v) => character = v,
            onSessionChanged: (v) => session = v,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text('Profile'));
      await helpers.tap(tester, find.text('Advance Character'));
      await tester.enterText(
        find.byKey(const ValueKey('advancement-level')),
        '3',
      );
      await tester.pumpAndSettle();
      await helpers.tap(
        tester,
        find.byKey(const ValueKey('advancement-subclass-cleric')),
      );
      await helpers.tap(tester, find.text('Life Domain').last);
      await helpers.tap(tester, find.byKey(const ValueKey('save-advancement')));
      expect(character.spells.where((s) => s.isLifeDomainGrant), hasLength(4));
      expect(session.characterState.currentHp, 22);
      expect(session.characterState.resourceValues[spellSlotId(1)], 2);
      await helpers.tap(tester, find.text('Advance Character'));
      await helpers.tap(tester, find.byKey(const ValueKey('save-advancement')));
      expect(character.spells.where((s) => s.isLifeDomainGrant), hasLength(4));
      expect(tester.takeException(), isNull);
    },
  );
}
