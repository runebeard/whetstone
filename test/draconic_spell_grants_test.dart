import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/class_spells.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'support/sequence_dice_roller.dart';

Future<void> tap(WidgetTester tester, Finder finder) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Character draconic(int level) => seedCharacters.first.copyWith(
  characterClass: 'Sorcerer',
  level: level,
  subclasses: {'Sorcerer': 'Draconic Sorcery'},
  spells: [],
  resources: fullCasterSlots(level),
  abilityScores: {
    ...seedCharacters.first.abilityScores,
    Ability.charisma: 16,
    Ability.constitution: 14,
  },
);

void main() {
  test(
    'Draconic class levels grant exactly four/six/eight/ten always-prepared spells',
    () {
      for (final (level, count) in [
        (2, 0),
        (3, 4),
        (5, 6),
        (7, 8),
        (9, 10),
        (20, 10),
      ]) {
        final character = withDraconicSpellGrants(draconic(level));
        expect(character.spells.length, count);
        expect(
          character.spells.every(
            (s) =>
                s.prepared &&
                s.isDraconicGrant &&
                s.castingAbility == Ability.charisma,
          ),
          isTrue,
        );
        expect(
          withDraconicSpells(
            Character.fromJson(character.toJson()),
          ).map((s) => s.id).toSet().length,
          count,
        );
        expect(
          character
              .copyWith(innateSorceryActive: true)
              .spells
              .every(
                character
                    .copyWith(innateSorceryActive: true)
                    .benefitsFromInnateSorcery,
              ),
          isTrue,
        );
      }
      expect(
        withDraconicSpells(
          draconic(9).copyWith(additionalClassLevels: {'Wizard': 7}),
        ),
        isEmpty,
      );
      expect(
        withDraconicSpells(
          draconic(9).copyWith(subclasses: {'Sorcerer': 'Other'}),
        ),
        isEmpty,
      );
      final spells = withDraconicSpells(draconic(9));
      expect(
        spells.singleWhere((s) => s.name == 'Legend Lore').components,
        contains('250 GP'),
      );
      for (final name in ['Chromatic Orb', 'Legend Lore', 'Summon Dragon']) {
        expect(
          spells.singleWhere((s) => s.name == name).hasCostlyOrConsumedMaterial,
          isTrue,
        );
      }
    },
  );
  test(
    'Preserve authored spells, distinguish Wizard copies and remove only ineligible grants',
    () {
      const custom = Spell(
        id: 'custom-command',
        name: 'Command',
        level: 1,
        prepared: false,
        summary: 'Authored command.',
        castingAbility: Ability.charisma,
        range: '77 feet',
      );
      const wizard = Spell(
        id: 'wizard-fly',
        name: 'Fly',
        level: 3,
        prepared: false,
        summary: 'Wizard-owned.',
        castingAbility: Ability.intelligence,
      );
      final character = withDraconicSpellGrants(
        draconic(9).copyWith(spells: [custom, wizard]),
      );
      expect(character.spells.where((s) => s.name == 'Command').length, 1);
      expect(
        character.spells.singleWhere((s) => s.id == custom.id).range,
        '77 feet',
      );
      expect(
        character.spells.singleWhere((s) => s.id == custom.id).prepared,
        isTrue,
      );
      expect(character.spells.where((s) => s.name == 'Fly').length, 2);
      expect(
        character.spells.singleWhere((s) => s.id == wizard.id).prepared,
        isFalse,
      );
      expect(character.isAlwaysPreparedSpell(wizard), isFalse);
      final fly = character.spells.singleWhere(
        (s) => s.name == 'Fly' && s.isDraconicGrant,
      );
      final lost = withDraconicSpellGrants(
        character.copyWith(
          subclasses: {},
          initiallyPinnedActionKeys: {fly.actionKey, 'weapon:keep'},
        ),
      );
      expect(lost.spells.map((s) => s.id).toSet(), {custom.id, wizard.id});
      expect(lost.initiallyPinnedActionKeys, {'weapon:keep'});
    },
  );
  test(
    'Draconic and Circle grants coexist with their own casting abilities',
    () {
      final character = draconic(10).copyWith(
        additionalClassLevels: {'Druid': 5},
        subclasses: {
          'Sorcerer': 'Draconic Sorcery',
          'Druid': 'Circle of the Land',
        },
      );
      final spells = withClassSpells(character, DruidLand.polar);
      expect(spells.where((s) => s.isDraconicGrant).length, 6);
      expect(spells.where((s) => s.isCircleGrant).length, 4);
      expect(
        spells
            .where((s) => s.isCircleGrant)
            .every((s) => s.castingAbility == Ability.wisdom),
        isTrue,
      );
    },
  );
  testWidgets(
    'Grants repair preparation, stay protected, cast Fly and survive reload',
    (tester) async {
      var character = withDraconicSpellGrants(draconic(9));
      character = character.copyWith(
        spells: [
          for (final spell in character.spells) spell.withPrepared(false),
        ],
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          character,
        ).copyWith(currentHp: 22),
        inventory: [],
        archivedInventory: [],
      );
      var generation = 0;
      Widget app() => MaterialApp(
        home: CharacterOverview(
          key: ValueKey(generation),
          character: character,
          initialSession: session,
          onCharacterChanged: (value) => character = value,
          onSessionChanged: (value) => session = value,
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(character.spells.length, 10);
      expect(character.spells.every((s) => s.prepared), isTrue);
      await tap(tester, find.text('Spellbook'));
      expect(find.text('Always Prepared'), findsOneWidget);
      await tester.ensureVisible(find.text('Fly'));
      await tester.longPress(find.text('Fly'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Spell'), findsNothing);
      expect(find.text('Remove Spell'), findsNothing);
      expect(find.text('Unmark as Sorcerer Spell'), findsNothing);
      await tap(tester, find.text('Pin to Combat'));
      final fly = character.spells.singleWhere((s) => s.name == 'Fly');
      expect(session.characterState.pinnedActionKeys, contains(fly.actionKey));
      await tap(tester, find.text('Fly'));
      await tap(tester, find.text('Cast'));
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(session.characterState.concentrationSpellId, isNull);
      await tap(tester, find.text('Fly'));
      await tap(tester, find.text('Cast'));
      await tap(tester, find.text('Level 3 · 3 remaining'));
      expect(session.characterState.concentrationSpellId, fly.id);
      expect(session.characterState.concentrationTurnsRemaining, 100);
      expect(session.characterState.resourceValues[spellSlotId(3)], 2);
      expect(session.characterState.currentHp, 22);
      character = Character.fromJson(character.toJson());
      session = CharacterSession.fromJson(session.toJson());
      generation++;
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      expect(character.spells.length, 10);
      expect(session.characterState.concentrationTurnsRemaining, 100);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Granted Orb attack uses Charisma and Innate Advantage without a second slot cost',
    (tester) async {
      var character = withDraconicSpellGrants(
        draconic(3).copyWith(proficiencyBonus: 2),
      );
      final orb = character.spells.singleWhere(
        (s) => s.name == 'Chromatic Orb',
      );
      character = character.copyWith(
        initiallyPinnedActionKeys: {orb.actionKey},
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(character).copyWith(
          activeConditions: {innateSorceryCondition},
          conditionTurns: {innateSorceryCondition: 10},
        ),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      final dice = SequenceDiceRoller([2, 17]);
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (value) => session = value,
            diceRoller: dice,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(
        tester,
        find.byKey(ValueKey('attack-attacks-${orb.actionKey}')),
      );
      await tap(tester, find.text('Level 1 · 4 remaining'));
      expect(session.timeline.first.title, 'Chromatic Orb Attack: 22');
      expect(session.timeline.first.detail, contains('Advantage: 2, 17'));
      expect(session.characterState.resourceValues[spellSlotId(1)], 3);
      expect(session.usedCombatActions, {CombatActionCost.action});
      expect(dice.index, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Advancement acquires grants once and preserves live HP and spent slots',
    (tester) async {
      var character = draconic(2).copyWith(subclasses: {});
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
            onCharacterChanged: (value) => character = value,
            onSessionChanged: (value) => session = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.text('Profile'));
      await tap(tester, find.text('Advance Character'));
      await tester.enterText(
        find.byKey(const ValueKey('advancement-level')),
        '3',
      );
      await tester.pumpAndSettle();
      await tap(
        tester,
        find.byKey(const ValueKey('advancement-subclass-sorcerer')),
      );
      await tap(tester, find.text('Draconic Sorcery').last);
      await tap(tester, find.text('Apply level-up HP and proficiency'));
      await tap(tester, find.byKey(const ValueKey('save-advancement')));
      expect(character.spells.where((s) => s.isDraconicGrant).length, 4);
      expect(session.characterState.currentHp, 22);
      expect(session.characterState.maxHp, 51);
      expect(session.characterState.resourceValues[spellSlotId(1)], 2);
      await tap(tester, find.text('Advance Character'));
      await tap(tester, find.byKey(const ValueKey('save-advancement')));
      expect(character.spells.where((s) => s.isDraconicGrant).length, 4);
      expect(session.characterState.maxHp, 51);
      expect(tester.takeException(), isNull);
    },
  );
  for (final (name, level, slot, remaining, turns, bonus) in [
    ("Dragon's Breath", 3, 2, 2, 10, true),
    ('Fear', 5, 3, 2, 10, false),
  ]) {
    testWidgets(
      'Granted $name casts with correct action, slot and concentration',
      (tester) async {
        var character = withDraconicSpellGrants(
          draconic(level).copyWith(proficiencyBonus: 3),
        );
        final spell = character.spells.singleWhere((s) => s.name == name);
        character = character.copyWith(
          initiallyPinnedActionKeys: {spell.actionKey},
        );
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(character).copyWith(
            activeConditions: {innateSorceryCondition},
            conditionTurns: {innateSorceryCondition: 10},
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
              onCharacterChanged: (_) {},
              onSessionChanged: (value) => session = value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tap(tester, find.text(name).first);
        await tap(tester, find.text('Cast').last);
        await tap(tester, find.text('Level $slot · $remaining remaining'));
        if (name == 'Fear') {
          expect(
            find.textContaining('DC 15 Wisdom saving throw'),
            findsOneWidget,
          );
          await tap(tester, find.text('Failed save'));
        } else {
          expect(find.textContaining('target save'), findsNothing);
        }
        expect(session.usedCombatActions, {
          bonus ? CombatActionCost.bonusAction : CombatActionCost.action,
        });
        expect(session.characterState.concentrationSpellId, spell.id);
        expect(session.characterState.concentrationTurnsRemaining, turns);
        expect(
          session.characterState.resourceValues[spellSlotId(slot)],
          remaining - 1,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Ten-minute grant does not spend a combat action or slot', (
    tester,
  ) async {
    var character = withDraconicSpellGrants(draconic(9));
    final spell = character.spells.singleWhere((s) => s.name == 'Legend Lore');
    character = character.copyWith(
      initiallyPinnedActionKeys: {spell.actionKey},
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(character),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: character,
          initialSession: session,
          onCharacterChanged: (_) {},
          onSessionChanged: (value) => session = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, find.text('Legend Lore').first);
    await tap(tester, find.text('Cast').last);
    expect(
      find.text('Complete this 10-minute casting outside combat.'),
      findsOneWidget,
    );
    expect(session.usedCombatActions, isEmpty);
    expect(session.characterState.resourceValues[spellSlotId(5)] ?? 1, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'Level loss removes only class grants and clears their concentration and pins',
    (tester) async {
      var character = withDraconicSpellGrants(draconic(5));
      final fly = character.spells.singleWhere((s) => s.name == 'Fly');
      character = character.copyWith(
        level: 4,
        initiallyPinnedActionKeys: {fly.actionKey},
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(character).copyWith(
          concentrationSpellId: fly.id,
          concentrationTurnsRemaining: 100,
          pinnedActionKeys: {fly.actionKey},
        ),
        inventory: [],
        archivedInventory: [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: character,
            initialSession: session,
            onCharacterChanged: (value) => character = value,
            onSessionChanged: (value) => session = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(character.spells.length, 4);
      expect(session.characterState.concentrationSpellId, isNull);
      expect(
        session.characterState.pinnedActionKeys,
        isNot(contains(fly.actionKey)),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
