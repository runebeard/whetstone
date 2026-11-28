import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/main.dart';
import 'package:whetstone/content/starter_content_pack.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/modes/combat_mode.dart';
import 'package:whetstone/modes/exploration_mode.dart';
import 'package:whetstone/modes/profile_mode.dart';
import 'package:whetstone/modes/spellbook_mode.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/inventory_item.dart';
import 'package:whetstone/models/journal_entry.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/models/weapon.dart';
import 'package:whetstone/persistence/character_session_repository.dart';
import 'package:whetstone/persistence/character_definition_repository.dart';
import 'package:whetstone/persistence/content_pack_repository.dart';
import 'package:whetstone/persistence/portable_character_document.dart';
import 'package:whetstone/widgets/character_card.dart';
import 'package:whetstone/widgets/inventory_item_card.dart';
import 'package:whetstone/widgets/skill_tile.dart';
import 'package:whetstone/widgets/weapon_editor_dialog.dart';

import 'support/sequence_dice_roller.dart';

class LegacyCharacterDefinitionRepository
    implements CharacterDefinitionRepository {
  CharacterDefinitionCatalog catalog;

  LegacyCharacterDefinitionRepository(this.catalog);

  @override
  Future<CharacterDefinitionCatalog> loadCatalog() async => catalog;

  @override
  Future<void> saveCatalog(CharacterDefinitionCatalog catalog) async {
    this.catalog = catalog;
  }
}

void main() {
  testWidgets(
    'Cleave rolls separate damage and preserves the original critical',
    (tester) async {
      final fighter = seedCharacters.first.copyWith(
        characterClass: 'Fighter',
        abilityScores: {
          ...seedCharacters.first.abilityScores,
          Ability.strength: 16,
        },
        weapons: const [
          Weapon(
            id: 'axe',
            name: 'Greataxe',
            attackModifier: 5,
            damage: '1d12 + 3',
            damageFormula: '1d12 + 3',
            damageType: 'slashing',
            usesStrength: true,
            mastery: WeaponMastery.cleave,
          ),
        ],
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(fighter),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: fighter,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
            diceRoller: SequenceDiceRoller([20, 10, 6, 2, 3, 10]),
          ),
        ),
      );
      final attack = find.byKey(const ValueKey('attack-attacks-weapon:axe'));
      await tester.ensureVisible(attack);
      await tester.tap(attack);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hit · Make Cleave Attack'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hit · Roll Cleave Damage'));
      await tester.pumpAndSettle();
      expect(session.timeline.first.title, 'Greataxe Cleave Damage: 6');
      expect(
        CharacterSession.fromJson(session.toJson()).cleaveUsedThisTurn,
        isTrue,
      );
      final damage = find.byKey(const ValueKey('damage-attacks-weapon:axe'));
      await tester.ensureVisible(damage);
      await tester.tap(damage);
      await tester.pumpAndSettle();
      expect(session.timeline.first.title, 'Greataxe Critical Damage: 8');
      await tester.ensureVisible(attack);
      await tester.tap(attack);
      await tester.pumpAndSettle();
      expect(find.text('Hit · Make Cleave Attack'), findsNothing);
      final next = find.text('Next Turn');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(session.cleaveUsedThisTurn, isFalse);
    },
  );

  testWidgets(
    'Nick rolls separate damage and preserves the original critical',
    (tester) async {
      final fighter = seedCharacters.first.copyWith(
        characterClass: 'Fighter',
        abilityScores: {
          ...seedCharacters.first.abilityScores,
          Ability.strength: 16,
        },
        weapons: const [
          Weapon(
            id: 'axe',
            name: 'Shortsword',
            attackModifier: 5,
            damage: '1d6 + 3',
            damageFormula: '1d6 + 3',
            damageType: 'slashing',
            usesStrength: true,
          ),
          Weapon(
            id: 'dagger',
            name: 'Dagger',
            attackModifier: 5,
            damage: '1d4 + 3',
            damageFormula: '1d4 + 3',
            damageType: 'piercing',
            usesStrength: true,
            mastery: WeaponMastery.nick,
          ),
        ],
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(fighter),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: fighter,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
            diceRoller: SequenceDiceRoller([20, 10, 4, 2, 3, 10]),
          ),
        ),
      );
      final attack = find.byKey(const ValueKey('attack-attacks-weapon:axe'));
      await tester.ensureVisible(attack);
      await tester.tap(attack);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nick · Dagger'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hit · Roll Nick Damage'));
      await tester.pumpAndSettle();
      expect(session.timeline.first.title, 'Dagger Nick Damage: 4');
      expect(session.usedCombatActions, {CombatActionCost.action});
      expect(
        CharacterSession.fromJson(session.toJson()).nickUsedThisTurn,
        isTrue,
      );
      final damage = find.byKey(const ValueKey('damage-attacks-weapon:axe'));
      await tester.ensureVisible(damage);
      await tester.tap(damage);
      await tester.pumpAndSettle();
      expect(session.timeline.first.title, 'Shortsword Critical Damage: 8');
      await tester.ensureVisible(attack);
      await tester.tap(attack);
      await tester.pumpAndSettle();
      expect(find.text('Nick · Dagger'), findsNothing);
      final next = find.text('Next Turn');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(session.nickUsedThisTurn, isFalse);
    },
  );

  testWidgets('Nick keeps negative modifiers and doubles only critical dice', (
    tester,
  ) async {
    final fighter = seedCharacters.first.copyWith(
      characterClass: 'Fighter',
      abilityScores: {
        ...seedCharacters.first.abilityScores,
        Ability.strength: 8,
      },
      weapons: const [
        Weapon(
          id: 'axe',
          name: 'Shortsword',
          attackModifier: 5,
          damage: '1d6 - 1',
          damageFormula: '1d6 - 1',
          damageType: 'slashing',
          usesStrength: true,
        ),
        Weapon(
          id: 'dagger',
          name: 'Dagger',
          attackModifier: 5,
          damage: '1d4 - 1',
          damageFormula: '1d4 - 1',
          damageType: 'piercing',
          usesStrength: true,
          mastery: WeaponMastery.nick,
        ),
      ],
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(fighter),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: fighter,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
          diceRoller: SequenceDiceRoller([20, 20, 4, 3, 2, 3, 10]),
        ),
      ),
    );
    final attack = find.byKey(const ValueKey('attack-attacks-weapon:axe'));
    await tester.ensureVisible(attack);
    await tester.tap(attack);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nick · Dagger'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hit · Roll Nick Damage'));
    await tester.pumpAndSettle();
    expect(session.timeline.first.title, 'Dagger Nick Damage: 6');
    expect(session.usedCombatActions, {CombatActionCost.action});
    expect(
      CharacterSession.fromJson(session.toJson()).nickUsedThisTurn,
      isTrue,
    );
    final damage = find.byKey(const ValueKey('damage-attacks-weapon:axe'));
    await tester.ensureVisible(damage);
    await tester.tap(damage);
    await tester.pumpAndSettle();
    expect(session.timeline.first.title, 'Shortsword Critical Damage: 4');
    await tester.ensureVisible(attack);
    await tester.tap(attack);
    await tester.pumpAndSettle();
    expect(find.text('Nick · Dagger'), findsNothing);
    final next = find.text('Next Turn');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(session.nickUsedThisTurn, isFalse);
  });

  testWidgets(
    'Nick cancellation preserves use and misses still allow the extra attack',
    (tester) async {
      final fighter = seedCharacters.first.copyWith(
        characterClass: 'Fighter',
        abilityScores: {
          ...seedCharacters.first.abilityScores,
          Ability.strength: 16,
        },
        weapons: const [
          Weapon(
            id: 'axe',
            name: 'Shortsword',
            attackModifier: 5,
            damage: '1d6 + 3',
            damageFormula: '1d6 + 3',
            damageType: 'slashing',
            usesStrength: true,
          ),
          Weapon(
            id: 'dagger',
            name: 'Dagger',
            attackModifier: 5,
            damage: '1d4 + 3',
            damageFormula: '1d4 + 3',
            damageType: 'piercing',
            usesStrength: true,
            mastery: WeaponMastery.nick,
          ),
        ],
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(fighter),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: fighter,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
            diceRoller: SequenceDiceRoller([1, 1, 1]),
          ),
        ),
      );
      final attack = find.byKey(const ValueKey('attack-attacks-weapon:axe'));
      await tester.ensureVisible(attack);
      await tester.tap(attack);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(session.nickUsedThisTurn, isFalse);
      await tester.ensureVisible(attack);
      await tester.tap(attack);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nick · Dagger'));
      await tester.pumpAndSettle();
      expect(session.nickUsedThisTurn, isTrue);
      expect(session.usedCombatActions, {CombatActionCost.action});
      expect(find.text('Hit · Roll Nick Damage'), findsNothing);
    },
  );

  testWidgets(
    'reopening incapacitated Druid clears form and concentration effects',
    (tester) async {
      final druid = seedCharacters.first.copyWith(
        characterClass: 'Druid',
        level: 14,
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(druid).copyWith(
          wildShapeForm: 'Wolf',
          wildShapeTurnsRemaining: 300,
          concentrationSpellId: 'legacy-concentration',
          spellSummons: {'legacy-concentration': 'Spirit'},
          activeConditions: {
            'Incapacitated',
            naturesSanctuaryCondition,
            dodgingCondition,
          },
          conditionTurns: {naturesSanctuaryCondition: 4, dodgingCondition: 1},
        ),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      final initial = CharacterSession.fromJson(session.toJson());
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: druid,
            initialSession: initial,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(session.characterState.wildShapeForm, isNull);
      expect(session.characterState.wildShapeTurnsRemaining, isNull);
      expect(session.characterState.concentrationSpellId, isNull);
      expect(session.characterState.spellSummons, isEmpty);
      expect(session.characterState.activeConditions, {'Incapacitated'});
      expect(session.characterState.conditionTurns, isEmpty);
    },
  );

  testWidgets(
    'scroll attack damage uses the scroll level without a second slot prompt',
    (tester) async {
      final caster = seedCharacters.first.copyWith(
        spells: const [
          Spell(
            id: 'ray',
            name: 'Test Ray',
            level: 1,
            prepared: true,
            summary: 'Attack ray.',
            rollModifier: 9,
            damageFormula: '2d8',
            additionalDicePerSlotLevel: 1,
          ),
        ],
        initiallyPinnedActionKeys: {'spell:ray'},
        resources: fullCasterSlots(3),
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(caster),
        inventory: const [
          InventoryItem(
            name: 'Spell Scroll: Test Ray',
            quantity: 1,
            weightPerItem: 0,
            category: ItemCategory.consumable,
          ),
        ],
        archivedInventory: [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: caster,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
            diceRoller: SequenceDiceRoller([10, 3, 4]),
          ),
        ),
      );
      await tester.tap(find.text('Spellbook'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Test Ray'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cast from Scroll'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cast from Scroll'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Combat'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.check));
      await tester.pumpAndSettle();
      final damage = find.byKey(const ValueKey('damage-attacks-spell:ray'));
      await tester.ensureVisible(damage);
      await tester.tap(damage);
      await tester.pumpAndSettle();
      expect(find.text('Test Ray slot level'), findsNothing);
      expect(session.timeline.first.title, 'Test Ray Damage: 7');
      expect(session.inventory.single.quantity, 0);
      expect(session.characterState.resourceValues[spellSlotId(1)], 4);
      expect(session.characterState.resourceValues[spellSlotId(2)], 2);
    },
  );

  testWidgets(
    'Acid Splash deals zero on a successful save and scales on failure',
    (tester) async {
      final druid = seedCharacters.first.copyWith(
        characterClass: 'Druid',
        level: 5,
        subclasses: const {'Druid': 'Circle of the Land'},
        initiallyPinnedActionKeys: const {
          'spell:whetstone:circle-spell:acid-splash',
        },
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          druid,
        ).copyWith(druidLand: DruidLand.tropical),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      final dice = SequenceDiceRoller([3, 4]);
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: druid,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
            diceRoller: dice,
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> cast(String outcome) async {
        final spell = find.text('Acid Splash');
        await tester.ensureVisible(spell);
        await tester.tap(spell);
        await tester.pumpAndSettle();
        expect(find.text('No damage on a successful save'), findsOneWidget);
        await tester.tap(find.text('Cast'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(outcome));
        await tester.pumpAndSettle();
      }

      await cast('Successful save');
      expect(session.timeline.first.title, 'Acid Splash Damage: 0');
      expect(session.usedCombatActions, {CombatActionCost.action});
      expect(dice.index, 0);
      final next = find.text('Next Turn');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      await cast('Failed save');
      expect(session.timeline.first.title, 'Acid Splash Damage: 7');
      expect(dice.index, 2);
    },
  );

  testWidgets(
    'readied Beast attack preserves Reaction when Pack Tactics is cancelled',
    (tester) async {
      final druid = seedCharacters.first.copyWith(
        characterClass: 'Druid',
        level: 3,
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          druid,
        ).copyWith(wildShapeForm: 'Wolf'),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
        readiedAction: 'Bite when the enemy approaches',
        readiedEffect: 'weapon:wild-shape-wolf',
        usedCombatActions: {CombatActionCost.action},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: druid,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
            diceRoller: SequenceDiceRoller([8, 17]),
          ),
        ),
      );
      final trigger = find.text('Trigger');
      await tester.ensureVisible(trigger);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(session.usedCombatActions, {CombatActionCost.action});
      expect(session.readiedAction, isNotNull);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(session.usedCombatActions, {
        CombatActionCost.action,
        CombatActionCost.reaction,
      });
      expect(session.readiedAction, isNull);
      expect(
        session.timeline.any((event) => event.title == 'Wolf Bite Attack: 21'),
        isTrue,
      );
    },
  );

  testWidgets(
    'Freedom of Movement self cast tracks duration and restraint escape',
    (tester) async {
      final druid = seedCharacters.first.copyWith(
        characterClass: 'Druid',
        level: 7,
        subclasses: const {'Druid': 'Circle of the Land'},
        resources: fullCasterSlots(7),
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(druid).copyWith(
          druidLand: DruidLand.temperate,
          activeConditions: {'Grappled'},
        ),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: druid,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final spell = find.text('Freedom of Movement');
      await tester.ensureVisible(spell);
      await tester.tap(spell);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cast'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yourself'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Level 4 · 1 remaining'));
      await tester.pumpAndSettle();
      expect(
        session.characterState.conditionTurns[freedomOfMovementCondition],
        600,
      );
      await tester.tap(find.byTooltip('Druid features'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Escape nonmagical restraints'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Escape Grappled'));
      await tester.pumpAndSettle();
      expect(
        session.characterState.activeConditions,
        isNot(contains('Grappled')),
      );
      expect(session.usedCombatActions, {CombatActionCost.action});
      expect(session.characterState.resourceValues[spellSlotId(4)], 0);
    },
  );

  testWidgets('flying form requires Druid eight and Cat keeps fixed damage', (
    tester,
  ) async {
    final druid = seedCharacters.first.copyWith(
      characterClass: 'Druid',
      level: 3,
      resources: BuiltInClass.druid.classResources(3, charismaModifier: 0),
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(druid),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: druid,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
          diceRoller: SequenceDiceRoller([20, 10]),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Wild Shape'));
    await tester.pumpAndSettle();
    expect(find.text('Eagle'), findsNothing);
    expect(find.text('Owl'), findsNothing);
    expect(find.text('Raven'), findsNothing);
    expect(find.text('Bat'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Eagle');
    await tester.ensureVisible(find.text('Use another known form'));
    await tester.tap(find.text('Use another known form'));
    await tester.pumpAndSettle();
    expect(session.characterState.wildShapeForm, isNull);
    expect(session.characterState.resourceValues[wildShapeResourceId], 2);
    await tester.tap(find.byTooltip('Wild Shape'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cat'));
    await tester.pumpAndSettle();
    final attack = find.byKey(
      const ValueKey('attack-attacks-weapon:wild-shape-cat'),
    );
    await tester.ensureVisible(attack);
    await tester.tap(attack);
    await tester.pumpAndSettle();
    final damage = find.byKey(
      const ValueKey('damage-attacks-weapon:wild-shape-cat'),
    );
    await tester.ensureVisible(damage);
    await tester.tap(damage);
    await tester.pumpAndSettle();
    expect(session.timeline.first.title, 'Cat Scratch Damage: 1');
    final dexteritySave = find.byTooltip('Dexterity saving throw');
    await tester.ensureVisible(dexteritySave);
    await tester.tap(dexteritySave);
    await tester.pumpAndSettle();
    expect(session.timeline.first.title, 'Dexterity Save: 14');
  });

  for (final (name, attackName, senses, level) in [
    ('Crab', 'Crab Claw', 'Blindsight 30 feet', 3),
    ('Lizard', 'Lizard Bite', 'Darkvision 30 feet', 3),
    ('Bat', 'Bat Bite', 'Blindsight 60 feet', 8),
  ]) {
    testWidgets('$name form survives reload and keeps fixed critical damage', (
      tester,
    ) async {
      final druid = seedCharacters.first.copyWith(
        characterClass: 'Druid',
        level: level,
        resources: BuiltInClass.druid.classResources(
          level,
          charismaModifier: 0,
        ),
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(druid),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      Widget app() => MaterialApp(
        home: CharacterOverview(
          character: druid,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
          diceRoller: SequenceDiceRoller([20]),
        ),
      );
      await tester.pumpWidget(app());
      await tester.tap(find.byTooltip('Wild Shape'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(name));
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      expect(session.characterState.wildShapeForm, name);
      session = CharacterSession.fromJson(session.toJson());
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final id = 'wild-shape-${name.toLowerCase()}';
      final attack = find.byKey(ValueKey('attack-attacks-weapon:$id'));
      await tester.ensureVisible(attack);
      await tester.tap(attack);
      await tester.pumpAndSettle();
      final damage = find.byKey(ValueKey('damage-attacks-weapon:$id'));
      await tester.ensureVisible(damage);
      await tester.tap(damage);
      await tester.pumpAndSettle();
      expect(session.timeline.first.title, '$attackName Damage: 1');
      expect(session.usedCombatActions, contains(CombatActionCost.action));
      await tester.tap(find.byTooltip('Druid features'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View Wild Shape form'));
      await tester.pumpAndSettle();
      expect(find.textContaining(senses), findsOneWidget);
    });
  }

  testWidgets('elapsed Wild Shape time reverts a saved form', (tester) async {
    final druid = seedCharacters.first.copyWith(
      characterClass: 'Druid',
      level: 3,
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(
        druid,
      ).copyWith(wildShapeForm: 'Wolf', wildShapeTurnsRemaining: 600),
      inventory: [],
      archivedInventory: [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: druid,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
        ),
      ),
    );
    Future<void> elapse(int minutes) async {
      await tester.tap(find.byTooltip('Druid features'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Advance Wild Shape time'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '$minutes');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    await elapse(15);
    expect(session.characterState.wildShapeTurnsRemaining, 450);
    expect(session.characterState.wildShapeForm, 'Wolf');
    await elapse(45);
    expect(session.characterState.wildShapeForm, isNull);
    expect(session.characterState.armourClass, druid.armourClass);
    expect(session.timeline.first.title, 'Wild Shape expired');
  });

  testWidgets(
    'Circle control casting logs the target save and keeps its slot spent',
    (tester) async {
      final druid = seedCharacters.first.copyWith(
        characterClass: 'Druid',
        level: 3,
        subclasses: const {'Druid': 'Circle of the Land'},
        resources: fullCasterSlots(3),
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          druid,
        ).copyWith(druidLand: DruidLand.polar),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: druid,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final hold = find.text('Hold Person');
      await tester.ensureVisible(hold);
      await tester.tap(hold);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cast'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Level 2 · 2 remaining'));
      await tester.pumpAndSettle();
      expect(find.textContaining('DC 12 Wisdom saving throw'), findsOneWidget);
      await tester.tap(find.text('Failed save'));
      await tester.pumpAndSettle();
      expect(session.timeline.first.title, 'Hold Person target save');
      expect(session.timeline.first.detail, contains('Failed save'));
      expect(session.characterState.resourceValues[spellSlotId(2)], 1);
      expect(session.usedCombatActions, {CombatActionCost.action});
      expect(session.characterState.concentrationTurnsRemaining, 10);
      await tester.tap(find.byTooltip('Concentration: Hold Person'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resolve Target Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Successful save'));
      await tester.pumpAndSettle();
      expect(session.timeline.first.detail, contains('Successful save'));
      expect(session.characterState.resourceValues[spellSlotId(2)], 1);
    },
  );

  testWidgets('Ice Storm rolls both damage types and halves each on a save', (
    tester,
  ) async {
    final druid = seedCharacters.first.copyWith(
      characterClass: 'Druid',
      level: 7,
      subclasses: const {'Druid': 'Circle of the Land'},
      resources: fullCasterSlots(7),
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(
        druid,
      ).copyWith(druidLand: DruidLand.polar),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: druid,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
          diceRoller: SequenceDiceRoller([3, 4, 1, 2, 3, 3]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final spell = find.text('Ice Storm');
    await tester.ensureVisible(spell);
    await tester.tap(spell);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cast'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Level 4 · 1 remaining'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Successful save'));
    await tester.pumpAndSettle();
    expect(session.timeline.first.title, 'Ice Storm Damage: 7');
    expect(session.timeline.first.detail, contains('3 bludgeoning + 4 cold'));
    expect(session.characterState.resourceValues[spellSlotId(4)], 0);
  });

  testWidgets(
    'Spider damage separates types and Wild Shape expires on its final turn',
    (tester) async {
      final druid = seedCharacters.first.copyWith(
        characterClass: 'Druid',
        level: 3,
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          druid,
        ).copyWith(wildShapeForm: 'Spider', wildShapeTurnsRemaining: 1),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: druid,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
            diceRoller: SequenceDiceRoller([20, 3, 2]),
          ),
        ),
      );
      final attack = find.byKey(
        const ValueKey('attack-attacks-weapon:wild-shape-spider'),
      );
      await tester.ensureVisible(attack);
      await tester.tap(attack);
      await tester.pumpAndSettle();
      final damage = find.byKey(
        const ValueKey('damage-attacks-weapon:wild-shape-spider'),
      );
      await tester.ensureVisible(damage);
      await tester.tap(damage);
      await tester.pumpAndSettle();
      expect(session.timeline.first.detail, contains('1 piercing + 5 poison'));
      expect(
        CharacterSession.fromJson(
          session.toJson(),
        ).characterState.wildShapeTurnsRemaining,
        1,
      );
      final next = find.text('Next Turn');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(session.characterState.wildShapeForm, isNull);
      expect(session.characterState.wildShapeTurnsRemaining, isNull);
    },
  );

  testWidgets('Wild Shape replaces weapon controls with the Beast attack', (
    tester,
  ) async {
    final druid = seedCharacters.first.copyWith(
      characterClass: 'Druid',
      level: 3,
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(
        druid,
      ).copyWith(wildShapeForm: 'Wolf'),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: druid,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
          diceRoller: SequenceDiceRoller([12, 4, 10]),
        ),
      ),
    );
    expect(find.text('Quarterstaff'), findsNothing);
    final attack = find.byKey(
      const ValueKey('attack-attacks-weapon:wild-shape-wolf'),
    );
    await tester.ensureVisible(attack);
    await tester.tap(attack);
    await tester.pumpAndSettle();
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(
      session.timeline.any((event) => event.title == 'Wolf Bite Attack: 16'),
      isTrue,
    );
    final damage = find.byKey(
      const ValueKey('damage-attacks-weapon:wild-shape-wolf'),
    );
    await tester.ensureVisible(damage);
    await tester.tap(damage);
    await tester.pumpAndSettle();
    expect(session.timeline.first.title, 'Wolf Bite Damage: 6');
    expect(session.usedCombatActions, {CombatActionCost.action});
    await tester.ensureVisible(attack);
    await tester.tap(attack);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('No Attack action attacks remaining'),
      findsOneWidget,
    );
    expect(find.text('Pack Tactics'), findsNothing);
    expect(druid.weapons.first.name, 'Quarterstaff');
    await tester.tap(find.text('End Combat'));
    await tester.pumpAndSettle();
    final perception = find.widgetWithText(SkillTile, 'Perception');
    await tester.ensureVisible(perception);
    await tester.tap(perception);
    await tester.pumpAndSettle();
    expect(session.timeline.first.title, 'Perception: 15');
  });

  testWidgets('granted Fireball upcasts and applies half damage after a save', (
    tester,
  ) async {
    final druid = seedCharacters.first.copyWith(
      characterClass: 'Druid',
      level: 7,
      subclasses: const {'Druid': 'Circle of the Land'},
      resources: fullCasterSlots(7),
      spells: const [
        Spell(
          id: 'whetstone:circle-spell:fireball',
          name: 'Fireball',
          level: 3,
          prepared: true,
          summary: 'Older grant.',
        ),
      ],
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(
        druid,
      ).copyWith(druidLand: DruidLand.arid),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: druid,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
          diceRoller: SequenceDiceRoller(List.filled(9, 2)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final spell = find.text('Fireball');
    await tester.ensureVisible(spell);
    await tester.tap(spell);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cast'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Level 4 · 1 remaining'));
    await tester.pumpAndSettle();
    expect(find.textContaining('DC 12 Dexterity save'), findsOneWidget);
    await tester.tap(find.text('Successful save'));
    await tester.pumpAndSettle();
    expect(session.characterState.resourceValues[spellSlotId(4)], 0);
    expect(session.usedCombatActions, {CombatActionCost.action});
    expect(session.timeline.first.title, 'Fireball Damage: 9');
  });

  testWidgets('improved Primal Strike rolls extra damage once per turn', (
    tester,
  ) async {
    final druid = seedCharacters.first.copyWith(
      characterClass: 'Druid',
      level: 15,
      elementalFury: ElementalFury.primalStrike,
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(druid),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: druid,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
          diceRoller: SequenceDiceRoller([3, 5]),
        ),
      ),
    );
    final menu = find.byTooltip('Druid features');
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Primal Strike'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thunder'));
    await tester.pumpAndSettle();
    expect(session.timeline.first.title, 'Primal Strike: 8');
    expect(
      CharacterSession.fromJson(session.toJson()).primalStrikeUsedThisTurn,
      isTrue,
    );
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(PopupMenuItem<String>, 'Primal Strike'),
      findsNothing,
    );
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    final next = find.text('Next Turn');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(session.primalStrikeUsedThisTurn, isFalse);
  });

  testWidgets('Nature Magician creates a separate slot once per long rest', (
    tester,
  ) async {
    final druid = seedCharacters.first.copyWith(
      characterClass: 'Druid',
      level: 20,
      spells: const [
        Spell(
          id: 'ward',
          name: 'Druid Ward',
          level: 1,
          prepared: true,
          castingTime: 'Action',
          summary: 'A ward.',
        ),
      ],
      resources: BuiltInClass.druid.classResources(20, charismaModifier: 0),
    );
    var session = CharacterSession.fromCharacter(druid);
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: druid,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.byTooltip('Druid features'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nature Magician'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spend 2 · Create level 4 slot'));
    await tester.pumpAndSettle();
    expect(session.characterState.resourceValues[wildShapeResourceId], 2);
    expect(session.characterState.resourceValues[natureMagicianSlots[1].id], 1);
    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Druid Ward'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cast'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Level 4 Nature Magician · 1 remaining'));
    await tester.pumpAndSettle();
    expect(session.characterState.resourceValues[natureMagicianSlots[1].id], 0);
    await tester.tap(find.byTooltip('Druid features'));
    await tester.pumpAndSettle();
    expect(find.text('Nature Magician'), findsNothing);
  });

  testWidgets(
    'Circle terrain grants resistance and shapes Nature’s Sanctuary',
    (tester) async {
      final druid = seedCharacters.first.copyWith(
        characterClass: 'Druid',
        level: 14,
        subclasses: const {'Druid': 'Circle of the Land'},
        resources: BuiltInClass.druid.classResources(14, charismaModifier: 0),
        spells: const [
          Spell(
            id: 'blur-test',
            name: 'Blur',
            level: 2,
            prepared: true,
            summary: 'Illusion.',
          ),
          Spell(
            id: 'burning-hands-test',
            name: 'Burning Hands',
            level: 1,
            prepared: true,
            summary: 'Fire.',
          ),
        ],
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(druid),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: druid,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
          ),
        ),
      );
      Future<void> choose(String action) async {
        await tester.tap(find.byTooltip('Druid features'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(action));
        await tester.pumpAndSettle();
      }

      await choose('Choose terrain');
      await tester.tap(find.text('Arid'));
      await tester.pumpAndSettle();
      expect(
        CharacterSession.fromJson(session.toJson()).characterState.druidLand,
        DruidLand.arid,
      );
      await tester.tap(find.text('❤️ HP'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '9');
      await tester.tap(find.byType(DropdownButton<IncomingDamageType>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fire').last);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Damage').hitTestable().last);
      await tester.pumpAndSettle();
      expect(session.characterState.currentHp, 30);
      await choose('Nature’s Sanctuary');
      await tester.tap(find.text('Create Sanctuary'));
      await tester.pumpAndSettle();
      expect(
        session.characterState.conditionTurns[naturesSanctuaryCondition],
        10,
      );
      expect(session.usedCombatActions, {CombatActionCost.action});
      expect(session.timeline.first.detail, contains('Fire resistance'));
      expect(session.characterState.resourceValues[wildShapeResourceId], 2);
      await choose('Move Nature’s Sanctuary');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(session.usedCombatActions, {CombatActionCost.action});
      await choose('Move Nature’s Sanctuary');
      await tester.tap(find.text('Move Sanctuary'));
      await tester.pumpAndSettle();
      expect(session.usedCombatActions, {
        CombatActionCost.action,
        CombatActionCost.bonusAction,
      });
      expect(
        session.characterState.conditionTurns[naturesSanctuaryCondition],
        10,
      );
      expect(session.characterState.resourceValues[wildShapeResourceId], 2);
      expect(session.timeline.first.title, 'Nature’s Sanctuary moved');
      await tester.tap(find.text('End Combat'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spellbook'));
      await tester.pumpAndSettle();
      expect(find.text('Arid Circle Spells'), findsOneWidget);
      expect(find.text('Fire Bolt'), findsOneWidget);
      expect(find.text('Fireball'), findsOneWidget);
      final blur = find.text('Blur');
      await tester.ensureVisible(blur);
      await tester.longPress(blur);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use Free Cast'));
      await tester.pumpAndSettle();
      expect(session.characterState.naturalRecoveryCastUsed, isTrue);
      final burningHands = find.text('Burning Hands');
      await tester.ensureVisible(burningHands);
      await tester.longPress(burningHands);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<ListTile>(find.widgetWithText(ListTile, 'Use Free Cast'))
            .onTap,
        isNull,
      );
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Explore'));
      await tester.pumpAndSettle();
      final longRest = find.text('Long Rest');
      await tester.ensureVisible(longRest);
      await tester.tap(longRest);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take Long Rest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Polar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spellbook'));
      await tester.pumpAndSettle();
      expect(find.text('Polar Circle Spells'), findsOneWidget);
      expect(find.text('Fire Bolt'), findsNothing);
      expect(find.text('Ray of Frost'), findsOneWidget);
      expect(find.text('Blur'), findsOneWidget);
    },
  );

  testWidgets(
    'Natural Recovery restores up to three slot levels at Druid six',
    (tester) async {
      final druid = seedCharacters.first.copyWith(
        characterClass: 'Druid',
        level: 6,
        subclasses: const {'Druid': 'Circle of the Land'},
        resources: fullCasterSlots(6),
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(druid).copyWith(
          currentHp: druid.maxHp,
          resourceValues: {
            spellSlotId(1): 2,
            spellSlotId(2): 2,
            spellSlotId(3): 1,
          },
        ),
        inventory: [],
        archivedInventory: [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: druid,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
          ),
        ),
      );
      final rest = find.text('Short Rest');
      await tester.ensureVisible(rest);
      await tester.tap(rest);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take Short Rest'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recover a level 2 slot'));
      await tester.pumpAndSettle();
      expect(find.text('Recover a level 3 slot'), findsNothing);
      await tester.tap(find.text('Recover a level 1 slot'));
      await tester.pumpAndSettle();
      expect(session.characterState.resourceValues[spellSlotId(1)], 3);
      expect(session.characterState.resourceValues[spellSlotId(2)], 3);
      expect(session.characterState.resourceValues[spellSlotId(3)], 1);
      expect(
        CharacterSession.fromJson(
          session.toJson(),
        ).characterState.naturalRecoveryUsed,
        isTrue,
      );
    },
  );

  testWidgets('Druid features track a familiar and resolve Land’s Aid', (
    tester,
  ) async {
    final druid = seedCharacters.first.copyWith(
      characterClass: 'Druid',
      level: 10,
      subclasses: const {'Druid': 'Circle of the Land'},
      resources: BuiltInClass.druid.classResources(10, charismaModifier: 0),
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(
        druid,
      ).copyWith(activeConditions: {'Poisoned'}),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: druid,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
          diceRoller: SequenceDiceRoller([2, 3, 4, 1, 1, 1]),
        ),
      ),
    );
    Future<void> choose(String name) async {
      await tester.tap(find.byTooltip('Druid features'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }

    await choose('Wild Companion');
    expect(
      session.characterState.activeConditions,
      isNot(contains('Poisoned')),
    );
    await tester.enterText(find.byType(TextField), 'Owl');
    await tester.tap(find.text('Spend Wild Shape'));
    await tester.pumpAndSettle();
    expect(
      CharacterSession.fromJson(session.toJson()).characterState.wildCompanion,
      'Owl',
    );
    expect(session.usedCombatActions, {CombatActionCost.action});
    expect(session.characterState.resourceValues[wildShapeResourceId], 2);
    final next = find.text('Next Turn');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    await choose('Land’s Aid');
    await tester.tap(find.text('Heal yourself'));
    await tester.pumpAndSettle();
    expect(session.characterState.currentHp, 37);
    expect(session.characterState.resourceValues[wildShapeResourceId], 1);
    expect(
      session.timeline.first.detail,
      contains('9 Necrotic damage (4 on success)'),
    );
    await choose('Dismiss Owl');
    expect(session.characterState.wildCompanion, isNull);
  });

  testWidgets(
    'Wild Resurgence exchanges a slot and a use with distinct limits',
    (tester) async {
      final druid = seedCharacters.first.copyWith(
        characterClass: 'Druid',
        level: 5,
        spells: const [
          Spell(
            id: 'test-ward',
            name: 'Druid Ward',
            level: 1,
            prepared: true,
            castingTime: 'Action',
            summary: 'A ward.',
          ),
        ],
        resources: [
          ...fullCasterSlots(5),
          ...BuiltInClass.druid.classResources(5, charismaModifier: 0),
        ],
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          druid,
        ).copyWith(resourceValues: {wildShapeResourceId: 0}),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: druid,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
          ),
        ),
      );
      Future<void> openPool(int uses) async {
        final pool = find.byKey(
          ValueKey('resource-$wildShapeResourceId-$uses'),
        );
        await tester.ensureVisible(pool);
        await tester.longPress(pool);
        await tester.pumpAndSettle();
      }

      await openPool(0);
      await tester.tap(find.text('Spend a Slot to Restore One'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Level 1 · 4 remaining'));
      await tester.pumpAndSettle();
      expect(session.characterState.resourceValues[spellSlotId(1)], 3);
      expect(
        CharacterSession.fromJson(session.toJson()).wildResurgenceUsedThisTurn,
        isTrue,
      );
      await openPool(1);
      await tester.tap(find.text('Spend a Use to Create a Level 1 Slot'));
      await tester.pumpAndSettle();
      expect(session.characterState.resourceValues[wildResurgenceSlot.id], 1);
      await openPool(0);
      expect(find.text('Spend a Slot to Restore One'), findsNothing);
      expect(find.text('Spend a Use to Create a Level 1 Slot'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      final spell = find.text('Druid Ward');
      await tester.ensureVisible(spell);
      await tester.tap(spell);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cast'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Level 1 Wild Resurgence · 1 remaining'));
      await tester.pumpAndSettle();
      expect(session.characterState.resourceValues[wildResurgenceSlot.id], 0);
      expect(session.characterState.resourceValues[spellSlotId(1)], 3);
    },
  );

  testWidgets('Wild Shape spends one use and tracks a form until reversion', (
    tester,
  ) async {
    final druid = seedCharacters.first.copyWith(
      characterClass: 'Druid',
      level: 20,
      resources: BuiltInClass.druid.classResources(20, charismaModifier: 0),
      spells: const [
        Spell(
          id: 'costly-test',
          name: 'Costly Ward',
          level: 1,
          prepared: true,
          castingTime: 'Action',
          components: 'V, S, M (a gem worth 10 gp)',
          summary: 'A ward.',
        ),
      ],
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(
        druid,
      ).copyWith(resourceValues: {wildShapeResourceId: 0}),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: druid,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
          diceRoller: SequenceDiceRoller([12]),
        ),
      ),
    );
    await tester.tap(find.text('⚡ Init'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record Initiative'));
    await tester.pumpAndSettle();
    expect(session.characterState.resourceValues[wildShapeResourceId], 1);
    final shape = find.byTooltip('Wild Shape');
    await tester.tap(shape);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Wolf'));
    await tester.tap(find.text('Wolf'));
    await tester.pumpAndSettle();
    expect(session.characterState.temporaryHp, 20);
    expect(session.characterState.resourceValues[wildShapeResourceId], 0);
    expect(session.usedCombatActions, {CombatActionCost.bonusAction});
    expect(find.text('12'), findsWidgets);
    await tester.tap(find.byTooltip('Druid features'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View Wild Shape form'));
    await tester.pumpAndSettle();
    expect(find.textContaining('STR 14 · DEX 15 · CON 12'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    final costly = find.text('Costly Ward');
    await tester.ensureVisible(costly);
    await tester.tap(costly);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cast'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('cannot use costly or consumed'),
      findsOneWidget,
    );
    expect(session.usedCombatActions, {CombatActionCost.bonusAction});
    expect(
      CharacterSession.fromJson(session.toJson()).characterState.wildShapeForm,
      'Wolf',
    );
    final revert = find.byTooltip('Wild Shape: Wolf · Revert');
    await tester.tap(revert);
    await tester.pumpAndSettle();
    expect(session.characterState.wildShapeForm, 'Wolf');
    final next = find.text('Next Turn');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    await tester.tap(revert);
    await tester.pumpAndSettle();
    expect(session.characterState.wildShapeForm, isNull);
    expect(session.characterState.armourClass, druid.armourClass);
    expect(session.characterState.resourceValues[wildShapeResourceId], 0);
    expect(session.usedCombatActions, {CombatActionCost.bonusAction});
  });

  testWidgets('Champion Survivor restores HP on a death save and next turn', (
    tester,
  ) async {
    final champion = seedCharacters.first.copyWith(
      characterClass: 'Fighter',
      level: 18,
      subclasses: {'Fighter': 'Champion'},
      currentHp: 0,
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(champion),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: champion,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
          diceRoller: SequenceDiceRoller([2, 18]),
        ),
      ),
    );
    final save = find.byKey(const ValueKey('roll-death-save'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Natural 18 · Recovered 1 HP'), findsOneWidget);
    expect(find.textContaining('Advantage: 2, 18'), findsOneWidget);
    expect(session.characterState.currentHp, 1);
    final next = find.text('Next Turn');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(session.characterState.currentHp, 8);
    expect(
      session.timeline.any((event) => event.title == 'Heroic Rally'),
      isTrue,
    );
  });

  testWidgets('Champion weapon criticals and initiative use subclass rules', (
    tester,
  ) async {
    final champion = seedCharacters.first.copyWith(
      characterClass: 'Fighter',
      level: 3,
      subclasses: const {'Fighter': 'Champion'},
    );
    final character = Character.fromJson(champion.toJson());
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(character),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    final dice = SequenceDiceRoller([4, 15, 19, 3, 4]);
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: character,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
          diceRoller: dice,
        ),
      ),
    );
    await tester.tap(find.text('⚡ Init'));
    await tester.pumpAndSettle();
    expect(find.text('Rolled 4 and 15'), findsOneWidget);
    await tester.tap(find.text('Record Initiative'));
    await tester.pumpAndSettle();
    final attack = find.byKey(
      const ValueKey('attack-attacks-weapon:quarterstaff'),
    );
    await tester.ensureVisible(attack);
    await tester.tap(attack);
    await tester.pumpAndSettle();
    expect(find.text('Critical hit · Natural 19'), findsOneWidget);
    expect(session.timeline.first.title, 'Remarkable Athlete');
    final damage = find.byKey(
      const ValueKey('damage-attacks-weapon:quarterstaff'),
    );
    await tester.ensureVisible(damage);
    await tester.tap(damage);
    await tester.pumpAndSettle();
    expect(find.text('Quarterstaff Critical Damage'), findsOneWidget);
    expect(dice.index, 5);
    expect(character.copyWith(level: 15).weaponCriticalThreshold, 18);
  });

  testWidgets('Tactical Mind spends Second Wind only if the bonus succeeds', (
    tester,
  ) async {
    final fighter = seedCharacters.first.copyWith(
      characterClass: 'Fighter',
      level: 2,
      resources: BuiltInClass.fighter.classResources(2, charismaModifier: 0),
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(fighter),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: fighter,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
          diceRoller: SequenceDiceRoller([5, 3, 5, 9]),
        ),
      ),
    );
    Future<void> attempt() async {
      final menu = find.text('Use an Action');
      await tester.ensureVisible(menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hide'));
      await tester.pumpAndSettle();
      final pool = find.byKey(
        const ValueKey('resource-$secondWindResourceId-2'),
      );
      await tester.ensureVisible(pool);
      await tester.longPress(pool);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tactical Mind'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '15');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    await attempt();
    expect(session.characterState.resourceValues[secondWindResourceId], 2);
    final next = find.text('Next Turn');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    await attempt();
    expect(session.characterState.resourceValues[secondWindResourceId], 1);
    expect(session.usedCombatActions, {CombatActionCost.action});
  });

  testWidgets('Action Surge grants one separate action per turn', (
    tester,
  ) async {
    final fighter = seedCharacters.first.copyWith(
      characterClass: 'Fighter',
      level: 17,
      resources: BuiltInClass.fighter.classResources(17, charismaModifier: 0),
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(fighter),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: fighter,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
        ),
      ),
    );
    final action = find.widgetWithText(FilterChip, 'Action');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    Future<void> useSurge(int uses) async {
      final surge = find.byKey(
        ValueKey('resource-$actionSurgeResourceId-$uses'),
      );
      await tester.ensureVisible(surge);
      await tester.tap(surge);
      await tester.pumpAndSettle();
    }

    await useSurge(2);
    final restored = CharacterSession.fromJson(session.toJson());
    expect(restored.actionSurge, ActionSurgeState.available);
    expect(restored.characterState.resourceValues[actionSurgeResourceId], 1);
    final menu = find.text('Use an Action');
    await tester.ensureVisible(menu);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dash'));
    await tester.pumpAndSettle();
    expect(session.actionSurge, ActionSurgeState.spent);
    expect(session.usedCombatActions, {CombatActionCost.action});
    await useSurge(1);
    expect(session.characterState.resourceValues[actionSurgeResourceId], 1);
    final next = find.text('Next Turn');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(session.actionSurge, isNull);
    await useSurge(1);
    expect(session.actionSurge, ActionSurgeState.available);
    expect(session.characterState.resourceValues[actionSurgeResourceId], 0);
  });

  testWidgets(
    'Indomitable rerolls a failed save with the Fighter level bonus',
    (tester) async {
      final fighter = seedCharacters.first.copyWith(
        characterClass: 'Fighter',
        level: 9,
        resources: BuiltInClass.fighter.classResources(9, charismaModifier: 0),
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(fighter),
        inventory: [],
        archivedInventory: [],
        isInCombat: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: fighter,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
            diceRoller: SequenceDiceRoller([2, 3, 12]),
          ),
        ),
      );
      final save = find.byTooltip('Dexterity saving throw');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep Result'));
      await tester.pumpAndSettle();
      expect(session.characterState.resourceValues[indomitableResourceId], 1);
      await tester.tap(save);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reroll Failed Save'));
      await tester.pumpAndSettle();
      expect(session.characterState.resourceValues[indomitableResourceId], 0);
      expect(session.timeline.first.title, 'Dexterity Save · Indomitable: 23');
    },
  );

  testWidgets('Lay on Hands heals and removes Poisoned with separate spends', (
    tester,
  ) async {
    final paladin = seedCharacters.first.copyWith(
      characterClass: 'Paladin',
      level: 2,
      resources: BuiltInClass.paladin.classResources(2, charismaModifier: 2),
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(
        paladin,
      ).copyWith(activeConditions: {'Poisoned'}),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: paladin,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
        ),
      ),
    );
    Future<void> openPool(int remaining) async {
      final pool = find.byKey(
        ValueKey('resource-$layOnHandsResourceId-$remaining'),
      );
      await tester.ensureVisible(pool);
      await tester.tap(pool);
      await tester.pumpAndSettle();
    }

    await openPool(10);
    await tester.tap(find.text('Heal yourself'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '4');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(session.characterState.currentHp, 38);
    expect(session.characterState.resourceValues[layOnHandsResourceId], 6);
    expect(session.usedCombatActions, contains(CombatActionCost.bonusAction));
    await openPool(6);
    expect(find.text('Heal yourself'), findsNothing);
    final next = find.text('Next Turn');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    await openPool(6);
    await tester.tap(find.text('Remove your Poisoned condition (5 points)'));
    await tester.pumpAndSettle();
    expect(
      session.characterState.activeConditions,
      isNot(contains('Poisoned')),
    );
    expect(session.characterState.resourceValues[layOnHandsResourceId], 1);
  });

  testWidgets('Bard recovers Inspiration with a slot and on initiative', (
    tester,
  ) async {
    final bard = seedCharacters.first.copyWith(
      characterClass: 'Bard',
      level: 18,
      resources: [
        ...fullCasterSlots(1),
        ...BuiltInClass.bard.classResources(18, charismaModifier: 3),
      ],
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(bard).copyWith(
        resourceValues: {bardicInspirationResourceId: 0, spellSlotId(1): 2},
      ),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: bard,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
          diceRoller: SequenceDiceRoller([13]),
        ),
      ),
    );
    final pool = find.byKey(
      const ValueKey('resource-$bardicInspirationResourceId-0'),
    );
    await tester.ensureVisible(pool);
    await tester.longPress(pool);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spend a Slot to Restore One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Level 1 · 2 remaining'));
    await tester.pumpAndSettle();
    expect(
      session.characterState.resourceValues[bardicInspirationResourceId],
      1,
    );
    expect(session.characterState.resourceValues[spellSlotId(1)], 1);
    expect(session.usedCombatActions, isEmpty);
    final initiative = find.text('⚡ Init');
    await tester.ensureVisible(initiative);
    await tester.tap(initiative);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record Initiative'));
    await tester.pumpAndSettle();
    expect(
      session.characterState.resourceValues[bardicInspirationResourceId],
      2,
    );
  });

  testWidgets(
    'Fighter advancement increases Second Wind and preserves spent uses',
    (tester) async {
      final fighter = seedCharacters.first.copyWith(
        characterClass: 'Fighter',
        level: 3,
        proficiencyBonus: 2,
        abilityScores: {
          ...seedCharacters.first.abilityScores,
          Ability.constitution: 15,
          Ability.dexterity: 15,
          Ability.strength: 19,
        },
        resources: BuiltInClass.fighter.startingResources(charismaModifier: 0),
      );
      Character? updated;
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(
          fighter,
        ).copyWith(resourceValues: {secondWindResourceId: 1}),
        inventory: [],
        archivedInventory: [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: fighter,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (value) => updated = value,
          ),
        ),
      );
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('advance-character')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('advancement-level')),
        '5',
      );
      final defaults = find.text('Apply level-up HP and proficiency');
      await tester.ensureVisible(defaults);
      await tester.tap(defaults);
      await tester.pumpAndSettle();
      final improvement = find.text('Choose Ability Score Improvement');
      await tester.ensureVisible(improvement);
      await tester.tap(improvement);
      await tester.pumpAndSettle();
      final abilityPicker = find.byType(DropdownButtonFormField<Ability>);
      for (final picker in [abilityPicker.first, abilityPicker.last]) {
        await tester.tap(picker);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Strength (19)').last);
        await tester.pumpAndSettle();
      }
      expect(find.text('An ability score cannot exceed 20.'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Apply Ability Increase'),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(abilityPicker.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Constitution (15)').last);
      await tester.pumpAndSettle();
      await tester.tap(abilityPicker.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dexterity (15)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply Ability Increase'));
      await tester.pumpAndSettle();
      final subclass = find.byKey(
        const ValueKey('advancement-subclass-fighter'),
      );
      await tester.ensureVisible(subclass);
      await tester.tap(subclass);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Champion').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-advancement')));
      await tester.pumpAndSettle();
      expect(
        updated!.resources
            .singleWhere((resource) => resource.id == secondWindResourceId)
            .maximum,
        3,
      );
      expect(session.characterState.resourceValues[secondWindResourceId], 2);
      expect(updated!.proficiencyBonus, 3);
      expect(updated!.subclasses, {'Fighter': 'Champion'});
      expect(updated!.scoreFor(Ability.constitution), 16);
      expect(updated!.scoreFor(Ability.dexterity), 16);
      expect(session.characterState.initiativeModifier, 3);
      expect(session.characterState.maxHp, 63);
      expect(session.characterState.currentHp, 34);
    },
  );

  testWidgets(
    'spell scroll attempts consume inventory but leave slots intact',
    (tester) async {
      final caster = seedCharacters.first.copyWith(
        resources: fullCasterSlots(1),
        spells: const [
          Spell(
            id: 'scroll-spell',
            name: 'Test Ward',
            level: 1,
            prepared: false,
            concentration: true,
            castingAbility: Ability.intelligence,
            rollModifier: 10,
            summary: 'A ward.',
            castingTime: 'Action',
          ),
          Spell(
            id: 'scroll-wave',
            name: 'Test Wave',
            level: 3,
            prepared: false,
            summary: 'A wave.',
            rollEffectOnCast: true,
            damageFormula: '1d6',
            savingThrowAbility: Ability.dexterity,
            halfDamageOnSave: true,
          ),
        ],
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(caster),
        inventory: const [
          InventoryItem(
            name: 'Spell Scroll: Test Ward',
            quantity: 2,
            weightPerItem: 0,
            category: ItemCategory.consumable,
          ),
          InventoryItem(
            name: 'Spell Scroll (Level 1)',
            quantity: 1,
            weightPerItem: 0,
            category: ItemCategory.consumable,
          ),
          InventoryItem(
            name: 'Spell Scroll: Test Wave',
            quantity: 1,
            weightPerItem: 0,
            category: ItemCategory.consumable,
          ),
        ],
        archivedInventory: [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: caster,
            initialSession: session,
            onSessionChanged: (value) => session = value,
            onCharacterChanged: (_) {},
            diceRoller: SequenceDiceRoller([10, 10, 4]),
          ),
        ),
      );
      await tester.tap(find.text('Spellbook'));
      await tester.pumpAndSettle();
      Future<void> openScroll([
        String? stack,
        String spell = 'Test Ward',
      ]) async {
        final ward = find.text(spell);
        await tester.ensureVisible(ward);
        await tester.longPress(ward);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cast from Scroll'));
        await tester.pumpAndSettle();
        if (find.text('Choose a Spell Scroll').evaluate().isNotEmpty) {
          await tester.tap(find.text(stack ?? 'Spell Scroll: Test Ward'));
          await tester.pumpAndSettle();
        }
      }

      await openScroll();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(session.inventory.first.quantity, 2);
      await openScroll();
      await tester.tap(find.text('Failed check'));
      await tester.pumpAndSettle();
      expect(session.inventory.first.quantity, 1);
      expect(session.characterState.concentrationSpellId, isNull);
      await openScroll('Spell Scroll (Level 1)');
      await tester.tap(find.text('Roll Ability Check'));
      await tester.pumpAndSettle();
      expect(session.inventory.first.quantity, 1);
      expect(session.inventory[1].quantity, 0);
      expect(session.characterState.concentrationSpellId, 'scroll-spell');
      expect(session.characterState.resourceValues[spellSlotId(1)], 2);
      expect(session.timeline.first.title, 'Test Ward Attack: 15');
      expect(
        session.timeline.any(
          (event) => event.title == 'Test Ward Scroll Check: 14',
        ),
        isTrue,
      );
      await openScroll(null, 'Test Wave');
      await tester.tap(find.text('Cast from Scroll'));
      await tester.pumpAndSettle();
      expect(find.textContaining('DC 15 Dexterity save'), findsOneWidget);
      await tester.tap(find.text('Successful save'));
      await tester.pumpAndSettle();
      expect(session.inventory.last.quantity, 0);
      expect(session.timeline.first.title, 'Test Wave Damage: 2');
    },
  );

  testWidgets('spell summons can be dismissed and end with concentration', (
    tester,
  ) async {
    final caster = seedCharacters.first.copyWith(
      spells: const [
        Spell(
          id: 'summon-beast',
          name: 'Summon Beast',
          level: 2,
          prepared: true,
          concentration: true,
          summary: 'Summon a bestial spirit.',
        ),
      ],
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(
        caster,
      ).copyWith(concentrationSpellId: 'summon-beast'),
      inventory: [],
      archivedInventory: [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: caster,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
        ),
      ),
    );
    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();

    Future<void> track() async {
      await tester.longPress(find.text('Summon Beast'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Track Summon'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Bestial Spirit');
      await tester.tap(find.text('Track'));
      await tester.pumpAndSettle();
    }

    await track();
    expect(find.text('Active Summons'), findsOneWidget);
    expect(
      CharacterSession.fromJson(session.toJson()).characterState.spellSummons,
      {'summon-beast': 'Bestial Spirit'},
    );
    await tester.tap(find.text('Bestial Spirit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dismiss Summon'));
    await tester.pumpAndSettle();
    expect(session.characterState.spellSummons, isEmpty);
    await track();
    await tester.tap(find.text('Bestial Spirit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End Concentration'));
    await tester.pumpAndSettle();
    expect(find.text('Active Summons'), findsNothing);
    expect(session.characterState.spellSummons, isEmpty);
  });

  testWidgets('universal actions roll checks and spend one Action', (
    tester,
  ) async {
    final character = seedCharacters.first;
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(character),
      inventory: const [
        InventoryItem(
          name: 'Rope',
          quantity: 1,
          weightPerItem: 5,
          category: ItemCategory.equipment,
        ),
      ],
      archivedInventory: [],
      isInCombat: true,
    );
    final dice = SequenceDiceRoller([14, 11, 10, 12, 3, 17]);
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: character,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
          diceRoller: dice,
        ),
      ),
    );

    Future<void> choose(String name) async {
      final menu = find.text('Use an Action');
      await tester.ensureVisible(menu);
      await tester.tap(menu);
      await tester.pumpAndSettle();
      final action = find.text(name);
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
    }

    Future<void> nextTurn() async {
      final next = find.text('Next Turn');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
    }

    await choose('Hide');
    expect(session.timeline.first.title, 'Hide · Stealth: 16');
    expect(session.usedCombatActions, {CombatActionCost.action});
    await nextTurn();
    await choose('Search');
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(session.usedCombatActions, isEmpty);
    expect(dice.index, 1);
    await choose('Search');
    await tester.tap(find.text('Perception'));
    await tester.pumpAndSettle();
    expect(session.timeline.first.title, 'Search · Perception: 15');
    expect(session.usedCombatActions, {CombatActionCost.action});
    await nextTurn();
    await choose('Study');
    await tester.tap(find.text('Arcana'));
    await tester.pumpAndSettle();
    expect(session.timeline.first.title, 'Study · Arcana: 17');
    expect(session.usedCombatActions, {CombatActionCost.action});
    await nextTurn();
    await choose('Influence');
    await tester.tap(find.text('Persuasion'));
    await tester.pumpAndSettle();
    expect(session.timeline.first.title, 'Influence · Persuasion: 12');
    await nextTurn();
    await choose('Utilize');
    await tester.tap(find.text('Rope'));
    await tester.pumpAndSettle();
    expect(session.timeline.first.detail, 'Rope');
    expect(session.inventory.single.quantity, 1);
    await nextTurn();
    await choose('Dodge');
    expect(session.characterState.activeConditions, contains(dodgingCondition));
    final dexteritySave = find.byTooltip('Dexterity saving throw');
    await tester.ensureVisible(dexteritySave);
    await tester.tap(dexteritySave);
    await tester.pumpAndSettle();
    expect(find.textContaining('Advantage: 3, 17'), findsOneWidget);
    await nextTurn();
    expect(
      session.characterState.activeConditions,
      isNot(contains(dodgingCondition)),
    );
    await choose('Dash');
    expect(session.characterState.conditionTurns[dashingCondition], 1);
    expect(session.timeline.first.detail, contains('current Speed'));
    await nextTurn();
    expect(
      session.characterState.activeConditions,
      isNot(contains(dashingCondition)),
    );
    await choose('Disengage');
    final reloaded = CharacterSession.fromJson(session.toJson());
    expect(reloaded.characterState.conditionTurns[disengagingCondition], 1);
    await nextTurn();
    expect(
      session.characterState.activeConditions,
      isNot(contains(disengagingCondition)),
    );
    await choose('Help');
    await tester.tap(find.text('Distract an enemy'));
    await tester.pumpAndSettle();
    expect(session.timeline.first.title, 'Help used');
    expect(session.timeline.first.detail, contains('Advantage'));
    expect(session.usedCombatActions, {CombatActionCost.action});
  });

  testWidgets('short rest spends the selected die size', (tester) async {
    final fighter = seedCharacters.first.copyWith(
      characterClass: 'Fighter',
      level: 4,
    );
    var session = CharacterSession.fromCharacter(fighter);
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: fighter,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
          diceRoller: SequenceDiceRoller([3]),
        ),
      ),
    );
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('advance-character')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Additional class levels'));
    await tester.pumpAndSettle();
    final cleric = find.byKey(const ValueKey('advancement-class-cleric'));
    await tester.ensureVisible(cleric);
    await tester.enterText(cleric, '1');
    await tester.tap(find.byKey(const ValueKey('save-advancement')));
    await tester.pumpAndSettle();
    expect(
      find.text('Multiclassing requires Wisdom 13 for Cleric.'),
      findsOneWidget,
    );
    await tester.enterText(cleric, '0');
    final wizard = find.byKey(const ValueKey('advancement-class-wizard'));
    await tester.ensureVisible(wizard);
    await tester.enterText(wizard, '2');
    await tester.tap(find.byKey(const ValueKey('save-advancement')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    final rest = find.text('Short Rest');
    await tester.ensureVisible(rest);
    await tester.tap(rest);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('short-rest-hit-dice-10')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('short-rest-hit-dice-6')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Short Rest'));
    await tester.pumpAndSettle();
    expect(session.characterState.hitDiceSpentBySize, {6: 1});
    expect(session.characterState.currentHp, 39);
    expect(session.characterState.resourceValues[spellSlotId(1)], 3);
  });

  testWidgets('Barbarian rolls initiative and Dexterity saves with advantage', (
    tester,
  ) async {
    final barbarian = seedCharacters.first.copyWith(
      characterClass: 'Barbarian',
      level: 7,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: barbarian,
          initialSession: CharacterSession.fromCharacter(barbarian),
          onSessionChanged: (_) {},
          onCharacterChanged: (_) {},
          diceRoller: SequenceDiceRoller([4, 15, 3, 17]),
        ),
      ),
    );
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    await tester.tap(find.text('⚡ Init'));
    await tester.pumpAndSettle();
    expect(find.text('Rolled 4 and 15'), findsOneWidget);
    expect(
      tester
          .widget<Text>(find.byKey(const ValueKey('initiative-die-result')))
          .data,
      '15',
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    final dexteritySave = find.byTooltip('Dexterity saving throw');
    await tester.ensureVisible(dexteritySave);
    await tester.tap(dexteritySave);
    await tester.pumpAndSettle();
    expect(find.textContaining('Advantage: 3, 17'), findsOneWidget);
  });

  testWidgets('Topple records failed, successful and deferred target saves', (
    tester,
  ) async {
    final fighter = seedCharacters.first.copyWith(
      characterClass: 'Fighter',
      level: 11,
      abilityScores: {
        ...seedCharacters.first.abilityScores,
        Ability.strength: 16,
      },
      weapons: const [
        Weapon(
          id: 'staff',
          name: 'Quarterstaff',
          attackModifier: 5,
          damage: '1d6 + 3',
          damageFormula: '1d6 + 3',
          damageType: 'bludgeoning',
          usesStrength: true,
          mastery: WeaponMastery.topple,
        ),
      ],
    );
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(fighter),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: fighter,
          initialSession: session,
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
          diceRoller: SequenceDiceRoller([10, 10, 10]),
        ),
      ),
    );
    final attack = find.byKey(const ValueKey('attack-attacks-weapon:staff'));
    for (final outcome in [
      'Save failed · Prone',
      'Save succeeded',
      'Resolve later',
    ]) {
      await tester.ensureVisible(attack);
      await tester.tap(attack);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hit and force save'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Constitution save.'), findsOneWidget);
      await tester.tap(find.text(outcome));
      await tester.pumpAndSettle();
      expect(
        session.timeline.first.title,
        outcome == 'Resolve later'
            ? 'Quarterstaff · Topple'
            : outcome == 'Save succeeded'
            ? 'Quarterstaff · Topple successful save'
            : 'Quarterstaff · Topple failed save',
      );
    }
    expect(
      session.timeline
          .where((event) => event.title == 'Quarterstaff · Topple failed save')
          .length,
      1,
    );
    expect(session.characterState.activeConditions, isNot(contains('Prone')));
  });

  testWidgets('Graze records ability damage only on a confirmed miss', (
    tester,
  ) async {
    final fighter = seedCharacters.first.copyWith(
      characterClass: 'Fighter',
      abilityScores: {
        ...seedCharacters.first.abilityScores,
        Ability.strength: 16,
      },
      weapons: const [
        Weapon(
          id: 'greatsword',
          name: 'Greatsword',
          attackModifier: 5,
          damage: '2d6',
          damageType: 'slashing',
          mastery: WeaponMastery.graze,
          usesStrength: true,
        ),
      ],
    );
    CharacterSession? session;
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: fighter,
          initialSession: CharacterSession.fromCharacter(fighter),
          onSessionChanged: (value) => session = value,
          onCharacterChanged: (_) {},
          diceRoller: SequenceDiceRoller([20, 4]),
        ),
      ),
    );
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    final attack = find.byKey(
      const ValueKey('attack-attacks-weapon:greatsword'),
    );
    await tester.ensureVisible(attack);
    await tester.tap(attack);
    await tester.pumpAndSettle();
    expect(find.text('Attack missed'), findsNothing);
    await tester.tap(attack);
    await tester.pumpAndSettle();
    expect(find.textContaining('3 slashing damage'), findsOneWidget);
    await tester.tap(find.text('Attack missed'));
    await tester.pumpAndSettle();
    expect(session!.timeline.first.title, 'Greatsword Graze Damage: 3');
  });

  testWidgets('long rest can replace one eligible weapon mastery', (
    tester,
  ) async {
    final fighter = seedCharacters.first.copyWith(
      characterClass: 'Fighter',
      weapons: const [
        Weapon(
          id: 'dagger',
          name: 'Dagger',
          attackModifier: 2,
          damage: '1d4',
          mastery: WeaponMastery.nick,
        ),
        Weapon(id: 'spear', name: 'Spear', attackModifier: 2, damage: '1d6'),
      ],
    );
    Character? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: fighter,
          initialSession: CharacterSession.fromCharacter(fighter),
          onSessionChanged: (_) {},
          onCharacterChanged: (value) => saved = value,
        ),
      ),
    );
    final rest = find.text('Long Rest');
    await tester.ensureVisible(rest);
    await tester.tap(rest);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Long Rest'));
    await tester.pumpAndSettle();
    final dialog = find.byType(SimpleDialog);
    await tester.tap(
      find.descendant(of: dialog, matching: find.text('Dagger')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: dialog, matching: find.text('Spear')));
    await tester.pumpAndSettle();
    expect(saved!.weapons.first.mastery, isNull);
    expect(saved!.weapons.last.mastery, WeaponMastery.sap);
    expect(BuiltInClass.rogue.allowsMastery('Rapier'), isTrue);
    expect(BuiltInClass.rogue.allowsMastery('Greatsword'), isFalse);
  });

  testWidgets('weapon editor offers mastery for eligible classes', (
    tester,
  ) async {
    const weapon = Weapon(
      id: 'spear',
      name: 'Spear',
      attackModifier: 2,
      damage: '1d6',
      damageFormula: '1d6',
    );
    Weapon? saved;
    Future<void> open(BuiltInClass builtIn) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                saved = await showDialog<Weapon>(
                  context: context,
                  builder: (context) => WeaponEditorDialog(
                    weapon: weapon,
                    canSelectMastery: builtIn.hasWeaponMastery,
                  ),
                );
              },
              child: const Text('Edit test weapon'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Edit test weapon'));
      await tester.pumpAndSettle();
    }

    final picker = find.byType(DropdownButtonFormField<WeaponMastery>);
    await open(BuiltInClass.wizard);
    expect(picker, findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await open(BuiltInClass.fighter);
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sap').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-weapon')));
    await tester.pumpAndSettle();
    expect(saved?.mastery, WeaponMastery.sap);
  });

  testWidgets(
    'tracked casting spends one slot and action only after confirmation',
    (tester) async {
      final caster = seedCharacters.first.copyWith(
        resources: spellSlotsForClassLevels('Wizard', 6, {'Warlock': 3}),
        spells: const [
          Spell(
            id: 'burst',
            name: 'Test Burst',
            level: 1,
            prepared: true,
            summary: 'Test',
            castingTime: 'Action',
            rollEffectOnCast: true,
            damageFormula: '1d6',
            additionalDicePerSlotLevel: 1,
          ),
        ],
      );
      final initial = CharacterSession.fromCharacter(caster);
      var latest = CharacterSession(
        characterState: initial.characterState,
        inventory: initial.inventory,
        archivedInventory: [],
        isInCombat: true,
      );
      final dice = SequenceDiceRoller([4, 5, 4, 5]);
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: caster,
            initialSession: latest,
            onSessionChanged: (session) => latest = session,
            onCharacterChanged: (_) {},
            diceRoller: dice,
          ),
        ),
      );
      Future<void> selectCast() async {
        final card = find.text('Test Burst');
        await tester.ensureVisible(card);
        await tester.tap(card);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cast'));
        await tester.pumpAndSettle();
      }

      await selectCast();
      expect(find.text('Level 2 · 2 remaining'), findsOneWidget);
      expect(find.text('Level 2 Pact Magic · 2 remaining'), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(latest.usedCombatActions, isEmpty);
      expect(latest.characterState.resourceValues[spellSlotId(2)], 2);
      expect(dice.index, 0);

      await selectCast();
      await tester.tap(find.text('Level 2 · 2 remaining'));
      await tester.pumpAndSettle();
      expect(latest.usedCombatActions, {CombatActionCost.action});
      expect(latest.characterState.resourceValues[spellSlotId(2)], 1);
      expect(dice.index, 2);
      final restored = CharacterSession.fromJson(latest.toJson());
      expect(restored.characterState.resourceValues[spellSlotId(2)], 1);

      await selectCast();
      expect(find.text('Action already used this turn.'), findsOneWidget);
      expect(latest.characterState.resourceValues[spellSlotId(2)], 1);
      final next = find.text('Next Turn');
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
      expect(latest.usedCombatActions, isEmpty);
      expect(latest.characterState.resourceValues[spellSlotId(2)], 1);
      await selectCast();
      await tester.tap(find.text('Level 2 Pact Magic · 2 remaining'));
      await tester.pumpAndSettle();
      expect(latest.characterState.resourceValues[pactSlotId(2)], 1);
      expect(latest.characterState.resourceValues[spellSlotId(2)], 1);
      await tester.tap(find.text('End Combat'));
      await tester.pumpAndSettle();
      expect(latest.isInCombat, isFalse);
      expect(latest.usedCombatActions, isEmpty);
    },
  );

  testWidgets('two-handed weapon critical doubles the selected dice', (
    tester,
  ) async {
    final fighter = seedCharacters.first.copyWith(
      weapons: const [
        Weapon(
          id: 'spear',
          name: 'Spear',
          attackModifier: 3,
          damage: '1d6 + 2',
          damageFormula: '1d6 + 2',
          versatileDamageFormula: '1d8 + 2',
        ),
      ],
    );
    final initial = CharacterSession.fromCharacter(fighter);
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: fighter,
          initialSession: CharacterSession(
            characterState: initial.characterState,
            inventory: initial.inventory,
            archivedInventory: [],
            isInCombat: true,
          ),
          onSessionChanged: (_) {},
          onCharacterChanged: (_) {},
          diceRoller: SequenceDiceRoller([20, 7, 8]),
        ),
      ),
    );
    final attack = find.byKey(const ValueKey('attack-attacks-weapon:spear'));
    await tester.ensureVisible(attack);
    await tester.tap(attack);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('damage-attacks-weapon:spear')));
    await tester.pumpAndSettle();
    expect(find.text('One-handed · 1d6 + 2'), findsOneWidget);
    await tester.tap(find.text('Two-handed · 1d8 + 2'));
    await tester.pumpAndSettle();
    expect(find.text('Spear Critical Damage'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '17',
    );
  });

  testWidgets('ammunition follows the inventory across attacks and reloads', (
    tester,
  ) async {
    final archer = seedCharacters.first.copyWith(
      characterClass: 'Fighter',
      weapons: const [
        Weapon(
          id: 'bow',
          name: 'Bow',
          attackModifier: 3,
          damage: '1d6',
          damageFormula: '1d6',
          ammunitionName: 'Arrows',
        ),
      ],
      initialInventory: const [
        InventoryItem(
          name: 'Arrows',
          quantity: 1,
          weightPerItem: 0,
          category: ItemCategory.consumable,
        ),
      ],
    );
    final initial = CharacterSession.fromCharacter(archer);
    var latest = CharacterSession(
      characterState: initial.characterState,
      inventory: initial.inventory,
      archivedInventory: [],
      isInCombat: true,
    );
    final dice = SequenceDiceRoller([10, 12]);
    Future<void> open(int instance) async {
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            key: ValueKey(instance),
            character: archer,
            initialSession: latest,
            onSessionChanged: (session) => latest = session,
            onCharacterChanged: (_) {},
            diceRoller: dice,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    final attack = find.byKey(const ValueKey('attack-attacks-weapon:bow'));
    Future<void> shoot() async {
      await tester.ensureVisible(attack);
      await tester.tap(attack);
      await tester.pumpAndSettle();
    }

    await open(1);
    expect(find.text('Arrows: 1'), findsOneWidget);
    await shoot();
    expect(latest.inventory.single.quantity, 0);
    expect(find.text('Arrows: 0'), findsOneWidget);

    latest = CharacterSession.fromJson(latest.toJson());
    await open(2);
    await shoot();
    expect(dice.index, 1);
    expect(find.text('No Arrows remaining.'), findsOneWidget);

    await open(3);
    latest = CharacterSession(
      characterState: latest.characterState,
      inventory: [latest.inventory.single.copyWith(quantity: 1)],
      archivedInventory: [],
      isInCombat: true,
    );
    await open(4);
    await shoot();
    expect(dice.index, 2);
    expect(latest.inventory.single.quantity, 0);
  });

  testWidgets('ability generation applies array, point buy and rolled scores', (
    tester,
  ) async {
    await tester.pumpWidget(WhetstoneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Create Character'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('character-class')),
      'Fighter',
    );
    await tester.tap(find.byKey(const ValueKey('creator-continue-0')));
    await tester.pumpAndSettle();

    List<int> scores() => [
      for (final id in [
        'strength',
        'dexterity',
        'constitution',
        'intelligence',
        'wisdom',
        'charisma',
      ])
        int.parse(
          tester
              .widget<TextFormField>(find.byKey(ValueKey('ability-$id')))
              .controller!
              .text,
        ),
    ];
    await tester.ensureVisible(find.text('Use Standard Array'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use Standard Array'));
    await tester.pumpAndSettle();
    expect(scores(), [15, 14, 13, 12, 10, 8]);
    await tester.ensureVisible(find.byTooltip('Swap Strength score'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Swap Strength score'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dexterity (14)'));
    await tester.pumpAndSettle();
    expect(scores(), [14, 15, 13, 12, 10, 8]);

    await tester.ensureVisible(find.text('Point Buy'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Point Buy'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.byTooltip('Raise Strength'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Point Buy · 18 points left'), findsOneWidget);
    expect(
      tester
          .widgetList<IconButton>(find.byType(IconButton))
          .singleWhere((button) => button.tooltip == 'Raise Strength')
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Apply Scores'));
    await tester.pumpAndSettle();
    expect(scores(), [15, 8, 8, 8, 8, 8]);

    await tester.ensureVisible(find.text('Roll Ability Scores'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Roll Ability Scores'));
    await tester.pumpAndSettle();
    expect(scores(), everyElement(inInclusiveRange(3, 18)));
  });

  testWidgets(
    'concentration target transfer retains slot and duration after reload',
    (tester) async {
      final caster = seedCharacters.first.copyWith(
        spells: const [
          Spell(
            id: 'hex',
            name: 'Hex',
            level: 1,
            prepared: true,
            summary: 'A curse',
            concentration: true,
            damageFormula: '1d6',
            repeatableEffect: true,
          ),
        ],
      );
      final initial = CharacterSession.fromCharacter(caster);
      var latest = CharacterSession(
        characterState: initial.characterState.copyWith(
          concentrationSpellId: 'hex',
          concentrationSlotLevel: 2,
          concentrationTurnsRemaining: 3,
          concentrationTarget: 'First target',
        ),
        inventory: initial.inventory,
        archivedInventory: [],
        isInCombat: true,
      );
      Future<void> open(int instance) async {
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              key: ValueKey(instance),
              character: caster,
              initialSession: latest,
              onSessionChanged: (session) => latest = session,
              onCharacterChanged: (_) {},
              diceRoller: SequenceDiceRoller([4]),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await open(1);
      final indicator = find.byTooltip('Concentration: Hex');
      await tester.tap(indicator);
      await tester.pumpAndSettle();
      expect(find.textContaining('Target: First target'), findsOneWidget);
      await tester.tap(find.text('Move Target'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Second target');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      latest = CharacterSession.fromJson(latest.toJson());
      await open(2);
      await tester.tap(indicator);
      await tester.pumpAndSettle();
      expect(find.textContaining('Target: Second target'), findsOneWidget);
      expect(find.textContaining('Slot level 2'), findsOneWidget);
      expect(find.textContaining('Turns remaining: 3'), findsOneWidget);
      expect(find.text('Roll Repeat Effect'), findsOneWidget);
      expect(latest.usedCombatActions, contains(CombatActionCost.bonusAction));
      await tester.tap(find.text('Roll Repeat Effect'));
      await tester.pumpAndSettle();
      expect(find.text('Hex Repeat Effect'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('latest-roll-total')))
            .data,
        '4',
      );
      expect(latest.characterState.concentrationTarget, 'Second target');
    },
  );

  testWidgets(
    'Ready survives reload, spends a reaction and expires on next turn',
    (tester) async {
      final fighter = seedCharacters.first;
      final dice = SequenceDiceRoller([14]);
      final initial = CharacterSession.fromCharacter(fighter);
      var latest = CharacterSession(
        characterState: initial.characterState,
        inventory: initial.inventory,
        archivedInventory: [],
        isInCombat: true,
      );
      Future<void> open(int instance) async {
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              key: ValueKey(instance),
              character: fighter,
              initialSession: latest,
              onSessionChanged: (session) => latest = session,
              onCharacterChanged: (_) {},
              diceRoller: dice,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> ready([String? effect]) async {
        final action = find.text('Use an Action');
        await tester.ensureVisible(action);
        await tester.tap(action);
        await tester.pumpAndSettle();
        final ready = find.text('Ready');
        await tester.ensureVisible(ready);
        await tester.tap(ready);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField),
          'When the door opens, step back',
        );
        if (effect != null) {
          await tester.tap(find.byType(DropdownButtonFormField<String>));
          await tester.pumpAndSettle();
          await tester.tap(find.text(effect).last);
          await tester.pumpAndSettle();
        }
        await tester.tap(ready);
        await tester.pumpAndSettle();
      }

      Future<void> nextTurn() async {
        final next = find.text('Next Turn');
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
      }

      await open(1);
      await ready('Attack with Quarterstaff');
      expect(latest.usedCombatActions, {CombatActionCost.action});
      latest = CharacterSession.fromJson(latest.toJson());
      expect(latest.readiedEffect, 'weapon:quarterstaff');
      await open(2);
      final trigger = find.text('Trigger');
      await tester.ensureVisible(trigger);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(latest.readiedAction, isNull);
      expect(latest.readiedEffect, isNull);
      expect(latest.timeline.first.title, startsWith('Quarterstaff Attack:'));
      expect(dice.index, 1);
      expect(latest.usedCombatActions, contains(CombatActionCost.reaction));
      await nextTurn();
      await ready('Move up to your Speed');
      await tester.ensureVisible(trigger);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(latest.timeline.first.detail, contains('Move up to your Speed'));
      await nextTurn();
      await ready();
      expect(latest.readiedAction, isNotNull);
      await nextTurn();
      expect(latest.readiedAction, isNull);
      expect(latest.usedCombatActions, isEmpty);
    },
  );

  testWidgets('opens a character from the vault in exploration mode', (
    tester,
  ) async {
    await tester.pumpWidget(const WhetstoneApp());
    await tester.pumpAndSettle();

    expect(find.text('Whetstone α'), findsOneWidget);
    expect(find.text('Eldrin'), findsOneWidget);

    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    expect(find.text('Level 6 Wizard'), findsOneWidget);
    expect(find.text('Combat'), findsOneWidget);
    expect(find.text('Spellbook'), findsOneWidget);
    expect(find.byType(ExplorationModeView), findsOneWidget);

    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();

    expect(find.byType(SpellbookModeView), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileModeView), findsOneWidget);
    expect(find.text('Features & Traits'), findsOneWidget);
    expect(find.text('No features or actions added yet'), findsOneWidget);
    expect(find.text('Features & Traits').hitTestable(), findsOneWidget);
    expect(find.text('Ability Scores'), findsOneWidget);
    expect(find.text('18'), findsOneWidget);
    expect(find.text('+4'), findsOneWidget);

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();

    expect(find.byType(ExplorationModeView), findsOneWidget);
  });

  testWidgets(
    'imports, exports, duplicates, and persists portable characters',
    (tester) async {
      final sessionRepository = InMemoryCharacterSessionRepository();
      final definitionRepository = InMemoryCharacterDefinitionRepository();
      final character = Character(
        id: 'portable-aria',
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
            notes: 'Search beneath the theatre.',
          ),
        ],
      );
      const session = CharacterSession(
        characterState: CharacterState(
          currentHp: 19,
          maxHp: 31,
          temporaryHp: 2,
          armourClass: 14,
          initiativeModifier: 2,
          deathSaveSuccesses: 0,
          deathSaveFailures: 0,
          activeConditions: {},
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
        isInCombat: false,
      );
      final package = PortableCharacterDocument(
        character: character,
        session: session,
      ).encode();

      Future<void> importPackage() async {
        await tester.tap(find.byKey(const ValueKey('transfer-characters')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('transfer-import-character')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('import-package-text')),
          package,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('review-character-package')),
        );
        await tester.tap(
          find.byKey(const ValueKey('review-character-package')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('import-preview-name')),
          findsOneWidget,
        );
        expect(find.text('19 / 31'), findsOneWidget);
        expect(find.text('1 entries'), findsNWidgets(2));
        await tester.tap(
          find.byKey(const ValueKey('confirm-character-import')),
        );
        await tester.pumpAndSettle();
      }

      await tester.pumpWidget(
        WhetstoneApp(
          repository: sessionRepository,
          definitionRepository: definitionRepository,
        ),
      );
      await tester.pumpAndSettle();
      await importPackage();
      await tester.ensureVisible(find.text('Aria'));
      await tester.pumpAndSettle();
      expect(find.text('Aria'), findsOneWidget);
      expect(find.text('HP 19 / 31'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('transfer-characters')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('transfer-export-character')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('export-character-portable-aria')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('export-character-portable-aria')),
      );
      await tester.pumpAndSettle();
      final exported = tester
          .widget<SelectableText>(
            find.byKey(const ValueKey('export-package-text')),
          )
          .data!;
      final restored = PortableCharacterDocument.decode(exported);
      expect(
        restored.character.journalEntries.single.title,
        'Recover the Silver Song',
      );
      expect(restored.session.inventory.single.name, 'Silver Flute');
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      await importPackage();
      await tester.scrollUntilVisible(find.text('Aria Copy'), 250);
      await tester.pumpAndSettle();
      expect(find.text('Aria Copy'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        WhetstoneApp(
          repository: sessionRepository,
          definitionRepository: definitionRepository,
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Aria Copy'), 250);
      await tester.pumpAndSettle();
      expect(find.text('Aria'), findsOneWidget);
      expect(find.text('Aria Copy'), findsOneWidget);
    },
  );

  testWidgets('rejects invalid character packages before import', (
    tester,
  ) async {
    await tester.pumpWidget(const WhetstoneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('transfer-characters')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('transfer-import-character')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('import-package-text')),
      '{"not":"a character"}',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('review-character-package')),
    );
    await tester.tap(find.byKey(const ValueKey('review-character-package')));
    await tester.pumpAndSettle();

    expect(
      find.text('This is not a valid Whetstone character package.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('confirm-character-import')),
      findsNothing,
    );
  });

  testWidgets('manages a persistent quest journal from Explore', (
    tester,
  ) async {
    final definitionRepository = InMemoryCharacterDefinitionRepository();
    await tester.pumpWidget(
      WhetstoneApp(definitionRepository: definitionRepository),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    final addQuest = find.byKey(const ValueKey('add-journal-entry'));
    await tester.ensureVisible(addQuest);
    await tester.pumpAndSettle();
    expect(find.text('No active quests'), findsOneWidget);

    await tester.tap(addQuest);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('journal-title')),
      'Find the Moon Key',
    );
    await tester.enterText(
      find.byKey(const ValueKey('journal-notes')),
      'Ask the ferryman about the ruined observatory.',
    );
    await tester.tap(find.byKey(const ValueKey('save-journal-entry')));
    await tester.pumpAndSettle();

    expect(find.text('Active Quests'), findsOneWidget);
    await tester.tap(find.text('Find the Moon Key'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Ask the ferryman about the ruined observatory.'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Find the Moon Key'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as Complete'));
    await tester.pumpAndSettle();
    expect(find.text('No active quests'), findsOneWidget);
    expect(find.text('Completed (1)'), findsOneWidget);

    await tester.tap(find.text('Completed (1)'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Find the Moon Key'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as Active'));
    await tester.pumpAndSettle();
    expect(find.text('Active Quests'), findsOneWidget);

    await tester.longPress(find.text('Find the Moon Key'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Quest'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('journal-title')),
      'Recover the Moon Key',
    );
    await tester.tap(find.byKey(const ValueKey('save-journal-entry')));
    await tester.pumpAndSettle();
    expect(find.text('Recover the Moon Key'), findsOneWidget);

    await tester.tap(addQuest);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('journal-title')),
      'Mistaken Quest',
    );
    await tester.tap(find.byKey(const ValueKey('save-journal-entry')));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Mistaken Quest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove Quest'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm-remove-journal-entry')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mistaken Quest'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      WhetstoneApp(definitionRepository: definitionRepository),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('add-journal-entry')));
    await tester.pumpAndSettle();
    expect(find.text('Recover the Moon Key'), findsOneWidget);
    expect(find.text('Mistaken Quest'), findsNothing);
  });

  testWidgets('the next roll menu applies advantage once', (tester) async {
    await tester.pumpWidget(
      WhetstoneApp(diceRoller: SequenceDiceRoller([4, 17, 8])),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Next d20 roll: Normal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Advantage'));
    await tester.pumpAndSettle();

    final perception = find.widgetWithText(SkillTile, 'Perception');
    await tester.ensureVisible(perception);
    await tester.tap(perception);
    await tester.pumpAndSettle();
    expect(find.textContaining('Advantage: 4, 17'), findsOneWidget);
    expect(find.byTooltip('Next d20 roll: Normal'), findsOneWidget);

    await tester.tap(perception);
    await tester.pumpAndSettle();
    expect(find.textContaining('d20 8'), findsOneWidget);
  });

  testWidgets('rolls skills, saves, weapons, and configured spell attacks', (
    tester,
  ) async {
    final diceRoller = SequenceDiceRoller([20, 1, 12, 15, 10]);
    await tester.pumpWidget(WhetstoneApp(diceRoller: diceRoller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    final perception = find.widgetWithText(SkillTile, 'Perception');
    await tester.ensureVisible(perception);
    await tester.pumpAndSettle();
    await tester.tap(perception);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('latest-roll-notice')), findsOneWidget);
    expect(find.text('Natural 20'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '24',
    );

    await tester.tap(perception);
    await tester.pumpAndSettle();
    expect(find.text('Natural 1'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '5',
    );
    expect(find.byKey(const ValueKey('roll-notice-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('roll-notice-1')), findsOneWidget);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('roll-notice-1'))).dy,
      lessThan(
        tester.getTopLeft(find.byKey(const ValueKey('roll-notice-0'))).dy,
      ),
    );

    final combatButton = find.widgetWithText(FilledButton, 'Combat');
    await tester.ensureVisible(combatButton);
    await tester.pumpAndSettle();
    await tester.tap(combatButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Quarterstaff'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('attack-attacks-weapon:quarterstaff')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '14',
    );

    await tester.tap(
      find.byKey(const ValueKey('attack-attacks-spell:fire_bolt')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '22',
    );

    final intelligenceSave = find.byTooltip('Intelligence saving throw');
    await tester.ensureVisible(intelligenceSave);
    await tester.pumpAndSettle();
    await tester.tap(intelligenceSave);
    await tester.pumpAndSettle();
    expect(find.text('Intelligence Save'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '17',
    );

    await tester.tap(find.text('End Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mage Hand'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('30 ft spectral hand'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('roll notices fade away after five seconds', (tester) async {
    await tester.pumpWidget(WhetstoneApp(diceRoller: SequenceDiceRoller([12])));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    final perception = find.widgetWithText(SkillTile, 'Perception');
    await tester.ensureVisible(perception);
    await tester.tap(perception);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('latest-roll-notice')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 3600));
    expect(find.byKey(const ValueKey('latest-roll-notice')), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1100));
    expect(find.byKey(const ValueKey('latest-roll-notice')), findsNothing);
  });

  testWidgets('a natural 20 death save restores HP and explains the result', (
    tester,
  ) async {
    await tester.pumpWidget(WhetstoneApp(diceRoller: SequenceDiceRoller([20])));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    await tester.tap(find.text('❤️ HP'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '100');
    await tester.tap(find.textContaining('Damage'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('roll-death-save')));
    await tester.pumpAndSettle();
    expect(find.text('Natural 20 · Recovered 1 HP'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^1 / \d+$')), findsOneWidget);
    expect(find.byKey(const ValueKey('roll-death-save')), findsNothing);
  });

  testWidgets('a natural 20 doubles only the next matching damage roll', (
    tester,
  ) async {
    await tester.pumpWidget(
      WhetstoneApp(diceRoller: SequenceDiceRoller([20, 5, 7, 4, 6, 3])),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    final attack = find.byKey(
      const ValueKey('attack-attacks-weapon:quarterstaff'),
    );
    final damage = find.byKey(
      const ValueKey('damage-attacks-weapon:quarterstaff'),
    );
    await tester.ensureVisible(attack);
    await tester.tap(attack);
    await tester.pumpAndSettle();
    final otherDamage = find.byKey(
      const ValueKey('damage-attacks-spell:fire_bolt'),
    );
    await tester.ensureVisible(otherDamage);
    await tester.tap(otherDamage);
    await tester.pumpAndSettle();
    expect(find.text('Fire Bolt Damage'), findsOneWidget);

    await tester.ensureVisible(damage);
    await tester.tap(damage);
    await tester.pumpAndSettle();
    expect(find.text('Quarterstaff Critical Damage'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '9',
    );

    await tester.tap(damage);
    await tester.pumpAndSettle();
    expect(find.text('Quarterstaff Damage'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '2',
    );
  });

  testWidgets('rolls attacks and damage directly from combat cards', (
    tester,
  ) async {
    final diceRoller = SequenceDiceRoller([4, 6, 14, 7, 9, 3]);
    await tester.pumpWidget(WhetstoneApp(diceRoller: diceRoller));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    final quarterstaffDamage = find.byKey(
      const ValueKey('damage-attacks-weapon:quarterstaff'),
    );
    await tester.ensureVisible(quarterstaffDamage);
    await tester.pumpAndSettle();
    await tester.tap(quarterstaffDamage);
    await tester.pumpAndSettle();
    expect(find.text('Quarterstaff Damage'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '3',
    );
    expect(find.textContaining('bludgeoning damage'), findsOneWidget);

    await tester.tap(quarterstaffDamage);
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '5',
    );

    await tester.tap(
      find.byKey(const ValueKey('attack-attacks-weapon:quarterstaff')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '16',
    );
    expect(
      find.byKey(const ValueKey('roll-damage-after-attack')),
      findsNothing,
    );

    await tester.tap(
      find.byKey(const ValueKey('damage-attacks-spell:fire_bolt')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fire Bolt Damage'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '16',
    );

    expect(
      find.byKey(const ValueKey('attack-attacks-spell:magic_missile')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey('damage-attacks-spell:magic_missile')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Magic Missile Damage'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '4',
    );
    expect(find.textContaining('force per dart damage'), findsOneWidget);
  });

  testWidgets('upgrades Fire Bolt rolls for an existing saved Eldrin', (
    tester,
  ) async {
    final legacyEldrin = Character(
      id: 'eldrin',
      name: 'Eldrin',
      characterClass: 'Wizard',
      level: 6,
      currentHp: 34,
      maxHp: 42,
      armourClass: 15,
      initiativeModifier: 2,
      status: 'Exploring',
      spells: const [
        Spell(
          id: 'fire_bolt',
          name: 'Fire Bolt',
          level: 0,
          prepared: false,
          summary: '+7 to hit • 2d10 fire • 120 ft',
        ),
      ],
      initiallyPinnedActionKeys: const {'spell:fire_bolt'},
    );
    final definitionRepository = LegacyCharacterDefinitionRepository(
      CharacterDefinitionCatalog(
        characters: {'eldrin': legacyEldrin},
        schemaVersion: 1,
      ),
    );
    await tester.pumpWidget(
      WhetstoneApp(
        repository: InMemoryCharacterSessionRepository(),
        definitionRepository: definitionRepository,
        diceRoller: SequenceDiceRoller([10]),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      definitionRepository.catalog.schemaVersion,
      CharacterDefinitionCatalog.currentSchemaVersion,
    );
    expect(
      definitionRepository
          .catalog
          .characters['eldrin']!
          .spells
          .single
          .rollModifier,
      7,
    );
    expect(
      definitionRepository
          .catalog
          .characters['eldrin']!
          .spells
          .single
          .damageFormula,
      '2d10',
    );

    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('attack-attacks-spell:fire_bolt')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('attack-attacks-spell:fire_bolt')),
    );
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('latest-roll-total'))).data,
      '17',
    );
  });

  testWidgets('adds features and edits ability scores from Profile', (
    tester,
  ) async {
    final sessionRepository = InMemoryCharacterSessionRepository();
    final definitionRepository = InMemoryCharacterDefinitionRepository();

    Future<void> pumpApp() async {
      await tester.pumpWidget(
        WhetstoneApp(
          repository: sessionRepository,
          definitionRepository: definitionRepository,
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpApp();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-profile-feature')));
    await tester.pumpAndSettle();
    expect(find.text('Add Feature'), findsWidgets);
    await tester.enterText(
      find.byKey(const ValueKey('feature-name')),
      'Ritual Casting',
    );
    await tester.enterText(
      find.byKey(const ValueKey('feature-summary')),
      'Cast ritual spells without preparing them',
    );
    await tester.tap(find.byKey(const ValueKey('save-feature')));
    await tester.pumpAndSettle();
    expect(find.text('Ritual Casting'), findsOneWidget);

    await tester.longPress(find.text('Ritual Casting'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Feature'), findsOneWidget);
    expect(find.text('Pin to Combat'), findsOneWidget);
    expect(find.text('Remove Feature'), findsOneWidget);
    await tester.tap(find.text('Edit Feature'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('feature-name')),
      'Improved Ritual Casting',
    );
    await tester.tap(find.byKey(const ValueKey('save-feature')));
    await tester.pumpAndSettle();
    expect(find.text('Improved Ritual Casting'), findsOneWidget);

    await tester.longPress(find.text('Improved Ritual Casting'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin to Combat'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Improved Ritual Casting'));
    await tester.pumpAndSettle();
    expect(find.text('Unpin from Combat'), findsOneWidget);
    await tester.tap(find.text('Remove Feature'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Feature?'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('confirm-remove-profile-feature')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Improved Ritual Casting'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('add-profile-feature')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('feature-name')),
      'Ritual Casting',
    );
    await tester.enterText(
      find.byKey(const ValueKey('feature-summary')),
      'Cast ritual spells without preparing them',
    );
    await tester.tap(find.byKey(const ValueKey('save-feature')));
    await tester.pumpAndSettle();

    final strengthTile = find.byKey(const ValueKey('profile-ability-strength'));
    await tester.ensureVisible(strengthTile);
    await tester.pumpAndSettle();
    await tester.longPress(strengthTile);
    await tester.pumpAndSettle();
    expect(find.text('Edit Strength'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('profile-ability-score')),
      '10',
    );
    await tester.tap(find.byKey(const ValueKey('save-profile-ability')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: strengthTile, matching: find.text('10')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: strengthTile, matching: find.text('0')),
      findsOneWidget,
    );

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await pumpApp();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Ritual Casting'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('profile-ability-strength')),
        matching: find.text('10'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('advances a character from Profile while preserving live state', (
    tester,
  ) async {
    final sessionRepository = InMemoryCharacterSessionRepository();
    final definitionRepository = InMemoryCharacterDefinitionRepository();
    final contentPackRepository = InMemoryContentPackRepository();
    await contentPackRepository.savePacks({
      starterContentPack.id: starterContentPack,
    });

    Future<void> pumpApp() async {
      await tester.pumpWidget(
        WhetstoneApp(
          repository: sessionRepository,
          definitionRepository: definitionRepository,
          contentPackRepository: contentPackRepository,
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpApp();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('34 / 42'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.textContaining('Damage'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    final arcaneRecovery = find.text('Arcane Recovery');
    await tester.ensureVisible(arcaneRecovery);
    await tester.pumpAndSettle();
    await tester.longPress(arcaneRecovery);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spend One'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('advance-character')));
    await tester.pumpAndSettle();
    expect(find.text('Advance Character'), findsOneWidget);
    expect(find.text('Spells'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('advancement-level')),
      '7',
    );
    await tester.enterText(
      find.byKey(const ValueKey('advancement-proficiency')),
      '4',
    );
    await tester.enterText(
      find.byKey(const ValueKey('advancement-max-hp')),
      '50',
    );
    tester.testTextInput.hide();
    await tester.pumpAndSettle();

    final addSpell = find.byKey(const ValueKey('advancement-add-spell'));
    await tester.ensureVisible(addSpell);
    await tester.pumpAndSettle();
    await tester.tap(addSpell);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('spell-name')),
      'Chromatic Spark',
    );
    await tester.enterText(
      find.byKey(const ValueKey('spell-summary')),
      'Action • 60 ft • Elemental damage',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('spell-pinned')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('spell-pinned')));
    await tester.tap(find.byKey(const ValueKey('save-spell')));
    await tester.pumpAndSettle();
    expect(find.text('Chromatic Spark'), findsOneWidget);

    final addResource = find.byKey(const ValueKey('advancement-add-resource'));
    await tester.scrollUntilVisible(
      addResource,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(addResource);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('resource-name')),
      'Arcane Surge',
    );
    await tester.enterText(find.byKey(const ValueKey('resource-maximum')), '2');
    await tester.tap(find.byKey(const ValueKey('save-resource')));
    await tester.pumpAndSettle();
    expect(find.text('Arcane Surge'), findsOneWidget);

    final libraryFeature = find.byKey(
      const ValueKey('advancement-library-feature'),
    );
    await tester.scrollUntilVisible(
      libraryFeature,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(libraryFeature);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rally'));
    await tester.pumpAndSettle();
    expect(find.text('Rally'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('save-advancement')));
    await tester.pumpAndSettle();
    expect(find.text('Level 7 Wizard'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('advance-character')),
        matching: find.textContaining('Proficiency +4'),
      ),
      findsOneWidget,
    );
    expect(find.text('Rally'), findsOneWidget);

    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();
    expect(find.text('Chromatic Spark'), findsOneWidget);
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    expect(find.text('29 / 50'), findsOneWidget);
    final combatButton = find.widgetWithText(FilledButton, 'Combat');
    await tester.ensureVisible(combatButton);
    await tester.pumpAndSettle();
    await tester.tap(combatButton);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Arcane Recovery'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('resource-arcane_recovery-0')),
      findsOneWidget,
    );
    expect(find.text('Arcane Surge'), findsOneWidget);
    await tester.tap(find.text('End Combat'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    await pumpApp();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    expect(find.text('Level 7 Wizard'), findsOneWidget);
    expect(find.text('29 / 50'), findsOneWidget);
    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();
    expect(find.text('Chromatic Spark'), findsOneWidget);
  });

  testWidgets('keeps live character state when combat begins and ends', (
    tester,
  ) async {
    await tester.pumpWidget(const WhetstoneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('34 / 42'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.textContaining('Damage'));
    await tester.pumpAndSettle();

    expect(find.text('29 / 42'), findsOneWidget);

    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('29 / 42'), findsOneWidget);
    expect(find.byType(CombatModeView), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Saving Throws'), findsOneWidget);
    expect(find.text('+7'), findsOneWidget);

    await tester.tap(find.text('End Combat'));
    await tester.pumpAndSettle();

    expect(find.text('29 / 42'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('pinned Spellbook actions appear in Combat attacks', (
    tester,
  ) async {
    await tester.pumpWidget(const WhetstoneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Mage Hand'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pin to Combat'));
    await tester.pumpAndSettle();

    expect(find.text('Mage Hand pinned to Combat'), findsOneWidget);

    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(find.text('Attacks'), findsOneWidget);
    expect(find.text('Mage Hand'), findsOneWidget);
    expect(find.text('Prepared Spells'), findsOneWidget);
    expect(find.text('Magic Missile'), findsNWidgets(2));
  });

  testWidgets(
    'casting a damage-only spell rolls damage and tracks concentration',
    (tester) async {
      await tester.pumpWidget(
        WhetstoneApp(diceRoller: SequenceDiceRoller([3])),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eldrin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spellbook'));
      await tester.pumpAndSettle();

      final spell = find.text('Magic Missile');
      await tester.ensureVisible(spell);
      await tester.longPress(spell);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Spell'));
      await tester.pumpAndSettle();
      final concentration = find.byKey(const ValueKey('spell-concentration'));
      await tester.ensureVisible(concentration);
      await tester.tap(concentration);
      final details = find.text('Casting details');
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pumpAndSettle();
      final rollOnCast = find.byKey(
        const ValueKey('spell-roll-effect-on-cast'),
      );
      await tester.ensureVisible(rollOnCast);
      await tester.tap(rollOnCast);
      await tester.tap(find.byKey(const ValueKey('save-spell')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(spell);
      await tester.tap(spell);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cast'));
      await tester.pumpAndSettle();
      expect(find.text('Magic Missile Damage'), findsOneWidget);
      expect(find.byTooltip('Concentration: Magic Missile'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('latest-roll-total')))
            .data,
        '4',
      );
    },
  );

  testWidgets('free casting spends its own resource once', (tester) async {
    final repository = InMemoryCharacterSessionRepository();
    await tester.pumpWidget(WhetstoneApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();
    final spell = find.text('Magic Missile');
    await tester.ensureVisible(spell);
    await tester.longPress(spell);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Track One Free Cast per Long Rest'));
    await tester.pumpAndSettle();
    await tester.longPress(spell);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Use Free Cast'));
    await tester.pumpAndSettle();

    final session = (await repository.loadSessions())['eldrin']!;
    expect(
      session
          .characterState
          .resourceValues['whetstone:free-cast:magic_missile'],
      0,
    );
    await tester.longPress(spell);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'Use Free Cast'))
          .onTap,
      isNull,
    );
  });

  testWidgets('Detect Magic can be cast as a ritual from the spellbook', (
    tester,
  ) async {
    await tester.pumpWidget(WhetstoneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();
    final spell = find.text('Detect Magic');
    await tester.ensureVisible(spell);
    await tester.tap(spell);
    await tester.pumpAndSettle();
    expect(find.text('Cast'), findsNothing);
    await tester.tap(find.text('Cast as Ritual'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Concentration: Detect Magic'), findsOneWidget);
  });

  testWidgets('damage prompts a concentration save at the calculated DC', (
    tester,
  ) async {
    await tester.pumpWidget(WhetstoneApp(diceRoller: SequenceDiceRoller([1])));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Fire Bolt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Track Concentration'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('34 / 42'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '22');
    await tester.tap(find.textContaining('Damage'));
    await tester.pumpAndSettle();
    expect(find.text('Fire Bolt · DC 11 after 22 damage'), findsOneWidget);
    await tester.tap(find.text('Roll Save'));
    await tester.pumpAndSettle();
    expect(find.text('DC 11 · Concentration ended'), findsOneWidget);
  });

  testWidgets(
    'casting a marked spell starts concentration and a failed save ends it',
    (tester) async {
      final repository = InMemoryCharacterSessionRepository();
      await tester.pumpWidget(
        WhetstoneApp(
          repository: repository,
          diceRoller: SequenceDiceRoller([12, 1]),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Eldrin'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Spellbook'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Fire Bolt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit Spell'));
      await tester.pumpAndSettle();
      final concentration = find.byKey(const ValueKey('spell-concentration'));
      await tester.ensureVisible(concentration);
      await tester.tap(concentration);
      await tester.tap(find.byKey(const ValueKey('save-spell')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Fire Bolt'));
      await tester.pumpAndSettle();

      final sessions = await repository.loadSessions();
      expect(
        sessions.values.any(
          (session) =>
              session.characterState.concentrationSpellId == 'fire_bolt',
        ),
        isTrue,
      );
      final indicator = find.byTooltip('Concentration: Fire Bolt');
      await tester.tap(indicator);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Set Save DC'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('DC 10 · Concentration ended'), findsOneWidget);
      expect(indicator, findsNothing);
      final updated = await repository.loadSessions();
      final entries = updated.values.expand((session) => session.timeline);
      expect(
        entries.map((event) => event.title),
        containsAll(['Concentration started', 'Concentration ended']),
      );
    },
  );

  testWidgets('edits and safely removes spells from the Spellbook', (
    tester,
  ) async {
    final sessions = InMemoryCharacterSessionRepository();
    final definitions = InMemoryCharacterDefinitionRepository();

    Future<void> pumpApp() async {
      await tester.pumpWidget(
        WhetstoneApp(repository: sessions, definitionRepository: definitions),
      );
      await tester.pumpAndSettle();
    }

    await pumpApp();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Fire Bolt'));
    await tester.pumpAndSettle();
    expect(find.text('Edit Spell'), findsOneWidget);
    expect(find.text('Unpin from Combat'), findsOneWidget);
    expect(find.text('Remove Spell'), findsOneWidget);
    await tester.tap(find.text('Edit Spell'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('spell-name')),
      'Flame Lance',
    );
    await tester.tap(find.byKey(const ValueKey('save-spell')));
    await tester.pumpAndSettle();
    expect(find.text('Flame Lance'), findsOneWidget);
    expect(find.text('Fire Bolt'), findsNothing);

    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.text('Flame Lance'), findsOneWidget);
    await tester.tap(find.text('End Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Flame Lance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove Spell'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Spell?'), findsOneWidget);
    expect(
      find.text('Remove Flame Lance from this character?'),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('confirm-remove-spellbook-spell')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Flame Lance'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spellbook'));
    await tester.pumpAndSettle();
    expect(find.text('Flame Lance'), findsNothing);
    expect(find.text('Fire Bolt'), findsNothing);
  });

  testWidgets('requires confirmation before exiting a character', (
    tester,
  ) async {
    await tester.pumpWidget(const WhetstoneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    expect(find.byType(BackButton), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Exit Character?'), findsOneWidget);

    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();

    expect(find.text('Level 6 Wizard'), findsOneWidget);

    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Exit Character'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit Character'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();

    expect(find.text('Whetstone α'), findsOneWidget);
    expect(find.text('Eldrin'), findsOneWidget);
  });

  testWidgets('resource changes remain when combat is reopened', (
    tester,
  ) async {
    await tester.pumpWidget(const WhetstoneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('1st-Level Slots'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1st-Level Slots'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('resource-level_1_slots-3')),
      findsOneWidget,
    );

    await tester.longPress(find.text('1st-Level Slots'));
    await tester.pumpAndSettle();

    expect(find.text('3 / 4'), findsOneWidget);
    expect(find.text('Spend One'), findsOneWidget);
    expect(find.text('Restore One'), findsOneWidget);
    expect(find.text('Refill'), findsOneWidget);

    await tester.tap(find.text('Restore One'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('resource-level_1_slots-4')),
      findsOneWidget,
    );

    await tester.longPress(find.text('1st-Level Slots'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spend One'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('End Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('1st-Level Slots'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('resource-level_1_slots-3')),
      findsOneWidget,
    );

    for (var spend = 0; spend < 3; spend++) {
      await tester.tap(find.text('1st-Level Slots'));
      await tester.pumpAndSettle();
    }
    expect(
      find.byKey(const ValueKey('resource-level_1_slots-0')),
      findsOneWidget,
    );

    await tester.tap(find.text('1st-Level Slots'));
    await tester.pumpAndSettle();
    expect(find.text('No 1st-Level Slots remaining'), findsOneWidget);

    await tester.longPress(find.text('1st-Level Slots'));
    await tester.pumpAndSettle();
    expect(find.text('Spend One'), findsOneWidget);
    expect(find.text('Restore One'), findsOneWidget);
    expect(find.text('Refill'), findsOneWidget);

    await tester.tap(find.text('Spend One'));
    await tester.pump();
    expect(find.text('3 / 4'), findsNothing);
    expect(find.text('0 / 4'), findsOneWidget);
  });

  testWidgets('restores character changes after the app is rebuilt', (
    tester,
  ) async {
    final repository = InMemoryCharacterSessionRepository();

    await tester.pumpWidget(WhetstoneApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('34 / 42'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.textContaining('Damage'));
    await tester.pumpAndSettle();

    expect(find.text('29 / 42'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(WhetstoneApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    expect(find.text('29 / 42'), findsOneWidget);
  });

  testWidgets('short rest spends hit dice and persists the result', (
    tester,
  ) async {
    final repository = InMemoryCharacterSessionRepository();
    await tester.pumpWidget(
      WhetstoneApp(repository: repository, diceRoller: SequenceDiceRoller([4])),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    final shortRest = find.text('Short Rest');
    await tester.ensureVisible(shortRest);
    await tester.tap(shortRest);
    await tester.pumpAndSettle();
    final picker = find.byKey(const ValueKey('short-rest-hit-dice'));
    await tester.tap(picker);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Short Rest'));
    await tester.pumpAndSettle();

    final sessions = await repository.loadSessions();
    final recovered = sessions.values.singleWhere(
      (session) => session.characterState.hitDiceSpent == 1,
    );
    expect(recovered.characterState.currentHp, greaterThan(34));
    expect(recovered.characterState.currentHp, lessThanOrEqualTo(42));
  });

  testWidgets('long rest restores health and saves the recovery', (
    tester,
  ) async {
    final repository = InMemoryCharacterSessionRepository();

    await tester.pumpWidget(WhetstoneApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('34 / 42'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.textContaining('Damage'));
    await tester.pumpAndSettle();
    expect(find.text('29 / 42'), findsOneWidget);

    await tester.ensureVisible(find.text('Long Rest'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Long Rest'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Hit points: 29 → 42'), findsOneWidget);
    expect(find.text('Conditions will not be removed.'), findsOneWidget);

    await tester.tap(find.text('Take Long Rest'));
    await tester.pumpAndSettle();
    expect(find.text('42 / 42'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(WhetstoneApp(repository: repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    expect(find.text('42 / 42'), findsOneWidget);
  });

  testWidgets('vault reflects and resumes a character in combat', (
    tester,
  ) async {
    final repository = InMemoryCharacterSessionRepository();

    await tester.pumpWidget(
      WhetstoneApp(
        repository: repository,
        diceRoller: SequenceDiceRoller([12]),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    await tester.tap(find.text('⚡ Init'));
    await tester.pumpAndSettle();
    final total = tester
        .widget<Text>(find.byKey(const ValueKey('initiative-roll-total')))
        .data;
    await tester.tap(find.text('Record Initiative'));
    await tester.pumpAndSettle();
    expect(find.text('Initiative $total'), findsOneWidget);

    final bonusAction = find.widgetWithText(FilterChip, 'Bonus Action');
    await tester.ensureVisible(bonusAction);
    await tester.tap(bonusAction);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(bonusAction).selected, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();

    expect(find.text('In Combat'), findsOneWidget);
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();

    expect(find.byType(CombatModeView), findsOneWidget);
    expect(find.text('End Combat'), findsOneWidget);
    expect(find.text('Round 1'), findsOneWidget);
    expect(find.text('Initiative $total'), findsOneWidget);
    expect(tester.widget<FilterChip>(bonusAction).selected, isTrue);

    await tester.tap(find.text('Next Turn'));
    await tester.pumpAndSettle();
    expect(find.text('Round 2'), findsOneWidget);
    expect(tester.widget<FilterChip>(bonusAction).selected, isFalse);
  });

  testWidgets('Rage spends a bonus action and expires on the turn tracker', (
    tester,
  ) async {
    final barbarian = Character(
      name: 'Barbarian',
      characterClass: 'Barbarian',
      level: 6,
      subclasses: const {'Barbarian': 'Path of the Berserker'},
      currentHp: 10,
      maxHp: 14,
      armourClass: 12,
      initiativeModifier: 0,
      status: 'Exploring',
      resources: BuiltInClass.barbarian.startingResources(charismaModifier: 0),
    );
    var latest = CharacterSession(
      characterState: CharacterState.fromCharacter(barbarian).copyWith(
        concentrationSpellId: 'old',
        temporaryHp: 2,
        activeConditions: {'Charmed', 'Frightened'},
      ),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: barbarian,
          initialSession: latest,
          onSessionChanged: (session) => latest = session,
          onCharacterChanged: (_) {},
        ),
      ),
    );
    final resource = find.byKey(
      const ValueKey('resource-whetstone:class:rage-2'),
    );
    await tester.ensureVisible(resource);
    await tester.tap(resource);
    await tester.pumpAndSettle();
    expect(latest.characterState.isRaging, isTrue);
    expect(latest.characterState.activeConditions, {ragingCondition});
    expect(latest.characterState.concentrationSpellId, isNull);
    expect(latest.characterState.resourceValues[rageResourceId], 1);
    expect(latest.usedCombatActions, contains(CombatActionCost.bonusAction));
    final hp = find.text('❤️ HP');
    await tester.ensureVisible(hp);
    await tester.tap(hp);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '9');
    await tester.tap(find.byType(DropdownButton<IncomingDamageType>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Slashing').last);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Damage').hitTestable().last);
    await tester.pumpAndSettle();
    expect(latest.characterState.temporaryHp, 0);
    expect(latest.characterState.currentHp, 8);

    final next = find.text('Next Turn');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(latest.characterState.isRaging, isTrue);
    final extend = find.text('Extend Rage');
    await tester.ensureVisible(extend);
    await tester.tap(extend);
    await tester.pumpAndSettle();
    expect(latest.characterState.conditionTurns[ragingCondition], 2);
    expect(latest.usedCombatActions, contains(CombatActionCost.bonusAction));
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(latest.characterState.isRaging, isTrue);
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(latest.characterState.isRaging, isFalse);
  });

  testWidgets('Persistent Rage extends duration and recovers uses once', (
    tester,
  ) async {
    final barbarian = seedCharacters.first.copyWith(
      characterClass: 'Barbarian',
      level: 15,
      resources: BuiltInClass.barbarian.startingResources(charismaModifier: 0),
    );
    var latest = CharacterSession(
      characterState: CharacterState.fromCharacter(barbarian),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: barbarian,
          initialSession: latest,
          onSessionChanged: (value) => latest = value,
          onCharacterChanged: (_) {},
          diceRoller: SequenceDiceRoller([4, 15, 5, 16]),
        ),
      ),
    );
    final rage = find.byKey(const ValueKey('resource-whetstone:class:rage-2'));
    await tester.ensureVisible(rage);
    await tester.tap(rage);
    await tester.pumpAndSettle();
    expect(latest.characterState.conditionTurns[ragingCondition], 100);
    expect(find.text('Extend Rage'), findsNothing);

    final next = find.text('Next Turn');
    await tester.ensureVisible(next);
    await tester.tap(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
    expect(latest.characterState.conditionTurns[ragingCondition], 98);
    expect(latest.characterState.isRaging, isTrue);

    Future<void> recordInitiative() async {
      final initiative = find.text('⚡ Init');
      await tester.ensureVisible(initiative);
      await tester.tap(initiative);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record Initiative'));
      await tester.pumpAndSettle();
    }

    await recordInitiative();
    await tester.tap(find.text('Recover Rage'));
    await tester.pumpAndSettle();
    final restored = CharacterState.fromJson(latest.characterState.toJson());
    expect(restored.resourceValues[rageResourceId], 2);
    expect(restored.persistentRageRecoveryUsed, isTrue);
    await tester.ensureVisible(find.text('End Rage'));
    await tester.tap(find.text('End Rage'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(rage);
    await tester.tap(rage);
    await tester.pumpAndSettle();
    expect(latest.characterState.resourceValues[rageResourceId], 1);
    await recordInitiative();
    expect(find.text('Recover Rage'), findsNothing);
  });

  testWidgets('Relentless Rage raises the save DC after each roll', (
    tester,
  ) async {
    final barbarian = seedCharacters.first.copyWith(
      characterClass: 'Barbarian',
      level: 11,
    );
    var latest = CharacterSession(
      characterState: CharacterState.fromCharacter(barbarian).copyWith(
        activeConditions: {ragingCondition},
        conditionTurns: {ragingCondition: 2},
      ),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: barbarian,
          initialSession: latest,
          onSessionChanged: (value) => latest = value,
          onCharacterChanged: (_) {},
          diceRoller: SequenceDiceRoller([11, 11]),
        ),
      ),
    );

    Future<void> takeDamage(int amount) async {
      await tester.tap(find.text('❤️ HP'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '$amount');
      await tester.tap(find.textContaining('Damage').hitTestable().last);
      await tester.pumpAndSettle();
    }

    await takeDamage(34);
    expect(latest.characterState.currentHp, 22);
    expect(latest.characterState.isRaging, isTrue);
    expect(
      CharacterState.fromJson(
        latest.characterState.toJson(),
      ).relentlessRageAttempts,
      1,
    );
    await takeDamage(22);
    expect(latest.characterState.currentHp, 0);
    expect(latest.characterState.isRaging, isFalse);
    expect(latest.characterState.relentlessRageAttempts, 2);
  });

  testWidgets('Second Wind heals and spends one bonus action', (tester) async {
    final fighter = Character(
      name: 'Fighter',
      characterClass: 'Fighter',
      level: 5,
      currentHp: 4,
      maxHp: 20,
      armourClass: 10,
      initiativeModifier: 0,
      status: 'Exploring',
      resources: BuiltInClass.fighter.startingResources(charismaModifier: 0),
    );
    final startingSession = CharacterSession.fromCharacter(fighter);
    var latest = CharacterSession(
      characterState: startingSession.characterState,
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: fighter,
          initialSession: latest,
          onSessionChanged: (session) => latest = session,
          onCharacterChanged: (_) {},
          diceRoller: SequenceDiceRoller([5]),
        ),
      ),
    );
    final resource = find.byKey(
      const ValueKey('resource-whetstone:class:second-wind-2'),
    );
    await tester.ensureVisible(resource);
    await tester.tap(resource);
    await tester.pumpAndSettle();
    expect(latest.characterState.currentHp, 14);
    expect(find.textContaining('Tactical Shift lets you move'), findsOneWidget);
    expect(latest.characterState.resourceValues[secondWindResourceId], 1);
    expect(latest.usedCombatActions, contains(CombatActionCost.bonusAction));

    final spent = find.byKey(
      const ValueKey('resource-whetstone:class:second-wind-1'),
    );
    await tester.tap(spent);
    await tester.pumpAndSettle();
    expect(latest.characterState.currentHp, 14);
    expect(latest.characterState.resourceValues[secondWindResourceId], 1);
  });

  testWidgets('built-in Fighter applies level-one HP and saving throws', (
    tester,
  ) async {
    await tester.pumpWidget(WhetstoneApp());
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Create Character'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('built-in-class-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fighter').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('creator-continue-0')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('ability-constitution')),
      '16',
    );
    await tester.tap(find.byKey(const ValueKey('creator-continue-1')));
    await tester.pumpAndSettle();

    for (final name in ['STR', 'CON']) {
      final chip = tester.widget<FilterChip>(
        find.widgetWithText(FilterChip, name),
      );
      expect(chip.selected, isTrue);
      expect(chip.onSelected, isNull);
    }
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();
    final maxHp = tester.widget<TextFormField>(
      find.byKey(const ValueKey('maximum-hp'), skipOffstage: false),
    );
    expect(maxHp.controller!.text, '13');
    await tester.tap(find.byKey(const ValueKey('creator-continue-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-1')));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(CheckboxListTile, 'Arcana'), findsNothing);
    final athletics = find.widgetWithText(CheckboxListTile, 'Athletics');
    final history = find.widgetWithText(CheckboxListTile, 'History');
    await tester.ensureVisible(athletics);
    await tester.tap(athletics);
    await tester.pumpAndSettle();
    await tester.ensureVisible(history);
    await tester.tap(history);
    await tester.pumpAndSettle();
    expect(find.text('Choose 2 class skills (2 selected)'), findsOneWidget);
    final perception = find.widgetWithText(CheckboxListTile, 'Perception');
    expect(tester.widget<CheckboxListTile>(perception).onChanged, isNull);
  });

  testWidgets('creates, persists, and edits a character with naming last', (
    tester,
  ) async {
    final sessions = InMemoryCharacterSessionRepository();
    final definitions = InMemoryCharacterDefinitionRepository();

    await tester.pumpWidget(
      WhetstoneApp(repository: sessions, definitionRepository: definitions),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Create Character'));
    await tester.pumpAndSettle();

    expect(find.text('Class & Essentials'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('character-name')).hitTestable(),
      findsNothing,
    );
    await tester.enterText(
      find.byKey(const ValueKey('character-class')),
      'Paladin',
    );
    expect(find.byKey(const ValueKey('current-hp')), findsNothing);
    expect(find.byKey(const ValueKey('initiative-modifier')), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('maximum-hp')), '27');
    await tester.tap(find.byKey(const ValueKey('creator-continue-0')));
    await tester.pumpAndSettle();

    expect(find.text('Ability Scores'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('character-name')).hitTestable(),
      findsNothing,
    );
    await tester.enterText(
      find.byKey(const ValueKey('ability-dexterity')),
      '14',
    );
    await tester.tap(find.byKey(const ValueKey('creator-continue-1')));
    await tester.pumpAndSettle();

    expect(find.text('Proficiencies'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('character-name')).hitTestable(),
      findsNothing,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-2')));
    await tester.pumpAndSettle();

    expect(find.text('Weapons'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('character-name')).hitTestable(),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('add-weapon')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('weapon-name')),
      'Longsword',
    );
    await tester.enterText(
      find.byKey(const ValueKey('weapon-attack-modifier')),
      '4',
    );
    await tester.enterText(
      find.byKey(const ValueKey('weapon-damage')),
      '1d8 + 2',
    );
    await tester.enterText(
      find.byKey(const ValueKey('weapon-damage-type')),
      'slashing',
    );
    await tester.enterText(find.byKey(const ValueKey('weapon-range')), 'Melee');
    await tester.tap(find.byKey(const ValueKey('save-weapon')));
    await tester.pumpAndSettle();
    expect(find.text('Longsword'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-weapon')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('weapon-name')), 'Dagger');
    await tester.enterText(find.byKey(const ValueKey('weapon-damage')), '1d4');
    await tester.enterText(
      find.byKey(const ValueKey('weapon-damage-type')),
      'piercing',
    );
    await tester.tap(find.byKey(const ValueKey('save-weapon')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove Dagger'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Weapon?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Dagger'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-3')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-3')));
    await tester.pumpAndSettle();

    expect(find.text('Spells'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('character-name')).hitTestable(),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('add-spell')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('spell-name')),
      'Sacred Flame',
    );
    await tester.enterText(
      find.byKey(const ValueKey('spell-summary')),
      '60 ft • 1d8 radiant',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('spell-pinned')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('spell-pinned')));
    await tester.tap(find.byKey(const ValueKey('save-spell')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('add-spell')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('spell-name')), 'Shield');
    await tester.tap(find.byKey(const ValueKey('spell-level')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Level 1').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('spell-summary')),
      'Reaction • +5 AC',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('spell-prepared')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('spell-prepared')));
    await tester.tap(find.byKey(const ValueKey('save-spell')));
    await tester.pumpAndSettle();
    expect(find.text('Sacred Flame'), findsOneWidget);
    expect(find.text('Shield'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-spell')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('spell-name')),
      'Guidance',
    );
    await tester.enterText(
      find.byKey(const ValueKey('spell-summary')),
      'Touch • Add 1d4 to a check',
    );
    await tester.tap(find.byKey(const ValueKey('save-spell')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove Guidance'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Spell?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Guidance'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-4')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-4')));
    await tester.pumpAndSettle();

    expect(find.text('Resources'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('character-name')).hitTestable(),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('add-resource')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('resource-name')),
      'Channel Divinity',
    );
    await tester.enterText(find.byKey(const ValueKey('resource-maximum')), '2');
    await tester.tap(find.byKey(const ValueKey('resource-recharge')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Short rest').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-resource')));
    await tester.pumpAndSettle();
    expect(find.text('Channel Divinity'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-resource')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('resource-name')),
      'Temporary Resource',
    );
    await tester.tap(find.byKey(const ValueKey('save-resource')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove Temporary Resource'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Resource?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Temporary Resource'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-5')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-5')));
    await tester.pumpAndSettle();

    expect(find.text('Starting Inventory'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('character-name')).hitTestable(),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('add-inventory-item')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('inventory-name')),
      'Potion of Healing',
    );
    await tester.tap(find.byKey(const ValueKey('inventory-category')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Consumable').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('inventory-quantity')),
      '3',
    );
    await tester.enterText(
      find.byKey(const ValueKey('inventory-weight')),
      '0.5',
    );
    await tester.tap(find.byKey(const ValueKey('save-inventory-item')));
    await tester.pumpAndSettle();
    expect(find.text('Potion of Healing'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-inventory-item')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('inventory-name')),
      'Temporary Item',
    );
    await tester.tap(find.byKey(const ValueKey('save-inventory-item')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove Temporary Item'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Item?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Temporary Item'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-6')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-6')));
    await tester.pumpAndSettle();

    expect(find.text('Features & Actions'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('character-name')).hitTestable(),
      findsNothing,
    );
    await tester.tap(find.byKey(const ValueKey('add-feature')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('feature-name')),
      'Second Wind',
    );
    await tester.enterText(
      find.byKey(const ValueKey('feature-summary')),
      'Bonus action • Recover 1d10 + level HP',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('feature-pinned')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('feature-pinned')));
    await tester.tap(find.byKey(const ValueKey('save-feature')));
    await tester.pumpAndSettle();
    expect(find.text('Second Wind'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('add-feature')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('feature-name')),
      'Temporary Feature',
    );
    await tester.enterText(
      find.byKey(const ValueKey('feature-summary')),
      'Remove this before creation',
    );
    await tester.tap(find.byKey(const ValueKey('save-feature')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Remove Temporary Feature'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Feature?'), findsOneWidget);
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(find.text('Temporary Feature'), findsNothing);

    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-7')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-7')));
    await tester.pumpAndSettle();

    expect(find.text('Name & Review'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('character-name')).hitTestable(),
      findsOneWidget,
    );
    await tester.enterText(
      find.byKey(const ValueKey('character-name')),
      'Aurelia',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('creator-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-save')));
    await tester.pumpAndSettle();

    expect(find.text('Aurelia'), findsOneWidget);
    expect(find.text('Level 1 Paladin'), findsOneWidget);
    final aureliaCard = find.ancestor(
      of: find.text('Aurelia'),
      matching: find.byType(CharacterCard),
    );
    expect(
      find.descendant(of: aureliaCard, matching: find.text('HP 27 / 27')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: aureliaCard, matching: find.text('Init +2')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(
      WhetstoneApp(repository: sessions, definitionRepository: definitions),
    );
    await tester.pumpAndSettle();
    expect(find.text('Aurelia'), findsOneWidget);

    await tester.longPress(find.text('Aurelia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit Character'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('character-class')),
      'Champion',
    );
    await tester.tap(find.byKey(const ValueKey('creator-continue-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-2')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-2')));
    await tester.pumpAndSettle();
    expect(find.text('Longsword'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Edit Longsword'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit Longsword'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('weapon-name')),
      'Silvered Longsword',
    );
    await tester.tap(find.byKey(const ValueKey('save-weapon')));
    await tester.pumpAndSettle();
    expect(find.text('Silvered Longsword'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-3')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-3')));
    await tester.pumpAndSettle();
    expect(find.text('Sacred Flame'), findsOneWidget);
    expect(find.text('Shield'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Edit Sacred Flame'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit Sacred Flame'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('spell-name')),
      'Radiant Flame',
    );
    await tester.tap(find.byKey(const ValueKey('save-spell')));
    await tester.pumpAndSettle();
    expect(find.text('Radiant Flame'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-4')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-4')));
    await tester.pumpAndSettle();
    expect(find.text('Channel Divinity'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Edit Channel Divinity'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit Channel Divinity'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('resource-maximum')), '3');
    await tester.tap(find.byKey(const ValueKey('save-resource')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-5')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-5')));
    await tester.pumpAndSettle();
    expect(find.text('Potion of Healing'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Edit Potion of Healing'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit Potion of Healing'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('inventory-quantity')),
      '2',
    );
    await tester.tap(find.byKey(const ValueKey('save-inventory-item')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-6')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-6')));
    await tester.pumpAndSettle();
    expect(find.text('Second Wind'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Edit Second Wind'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Edit Second Wind'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('feature-name')),
      'Heroic Recovery',
    );
    await tester.tap(find.byKey(const ValueKey('save-feature')));
    await tester.pumpAndSettle();
    expect(find.text('Heroic Recovery'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const ValueKey('creator-continue-7')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-continue-7')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('character-name')),
      'Aurelia Brightshield',
    );
    await tester.ensureVisible(find.byKey(const ValueKey('creator-save')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('creator-save')));
    await tester.pumpAndSettle();

    expect(find.text('Aurelia Brightshield'), findsOneWidget);
    expect(find.text('Level 1 Champion'), findsOneWidget);

    await tester.tap(find.text('Aurelia Brightshield'));
    await tester.pumpAndSettle();
    final potionCard = tester.widget<InventoryItemCard>(
      find.widgetWithText(InventoryItemCard, 'Potion of Healing'),
    );
    expect(potionCard.item.quantity, 2);
    expect(potionCard.item.weightPerItem, 0.5);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Features & Traits'), findsOneWidget);
    expect(find.text('Heroic Recovery'), findsOneWidget);
    expect(find.text('Features & Traits').hitTestable(), findsOneWidget);
    expect(find.text('Heroic Recovery').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Explore'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    expect(find.text('Silvered Longsword'), findsOneWidget);
    expect(find.text('Radiant Flame'), findsOneWidget);
    expect(find.text('Prepared Spells'), findsOneWidget);
    expect(find.text('Shield'), findsOneWidget);
    expect(find.text('Actions'), findsOneWidget);
    expect(find.text('Heroic Recovery'), findsOneWidget);
    await tester.ensureVisible(find.text('Channel Divinity'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Channel Divinity'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Channel Divinity'));
    await tester.pumpAndSettle();
    await tester.longPress(find.text('Channel Divinity'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('duplicates fresh characters and permanently deletes safely', (
    tester,
  ) async {
    final sessionRepository = InMemoryCharacterSessionRepository();
    final definitionRepository = InMemoryCharacterDefinitionRepository();

    Future<void> pumpApp() async {
      await tester.pumpWidget(
        WhetstoneApp(
          repository: sessionRepository,
          definitionRepository: definitionRepository,
        ),
      );
      await tester.pumpAndSettle();
    }

    await pumpApp();
    await tester.tap(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('34 / 42'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '5');
    await tester.tap(find.textContaining('Damage'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Combat'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Exit'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Duplicate Character'));
    await tester.pumpAndSettle();

    expect(find.text('Eldrin Copy'), findsOneWidget);
    final copyCard = find.ancestor(
      of: find.text('Eldrin Copy'),
      matching: find.byType(CharacterCard),
    );
    expect(
      find.descendant(of: copyCard, matching: find.text('HP 42 / 42')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: copyCard, matching: find.text('Exploring')),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp();
    expect(find.text('Eldrin Copy'), findsOneWidget);

    await tester.longPress(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Character'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Eldrin?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Eldrin'), findsOneWidget);

    await tester.longPress(find.text('Eldrin'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Character'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Eldrin'), findsNothing);
    expect(find.text('Eldrin Copy'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp();
    expect(find.text('Eldrin'), findsNothing);
    expect(find.text('Eldrin Copy'), findsOneWidget);
  });
}
