import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/circle_spells.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_resource.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/persistence/portable_character_document.dart';

import 'support/sequence_dice_roller.dart';

void main() {
  test('Beast Spells recognizes written costs and consumed components', () {
    bool restricted(String inputs) => Spell(
      id: 'test',
      name: 'Test Spell',
      level: 1,
      prepared: true,
      summary: 'Example',
      components: inputs,
    ).hasCostlyOrConsumedMaterial;
    expect(restricted('V, S, M (a gem worth 1,000 GP)'), isTrue);
    expect(restricted('M (a leaf, which the spell consumes)'), isTrue);
    expect(restricted('V, S, M (a locust)'), isFalse);
    expect(restricted('M (a leaf, which the spell does not consume)'), isFalse);
    expect(restricted('M (a leaf, not consumed)'), isFalse);
    expect(restricted("M (a leaf the spell doesn't consume)"), isFalse);
    expect(restricted('V, S'), isFalse);
  });

  test('ten leveled Circle spells carry their combat mechanics', () {
    final druid = Character(
      name: 'Druid',
      characterClass: 'Druid',
      level: 9,
      currentHp: 8,
      maxHp: 8,
      armourClass: 12,
      initiativeModifier: 0,
      status: 'Exploring',
      subclasses: const {'Druid': 'Circle of the Land'},
    );
    final spells = {
      for (final land in DruidLand.values)
        for (final spell in withCircleSpells(druid, land)) spell.name: spell,
    };
    for (final (name, damage) in [
      ('Burning Hands', '3d6'),
      ('Ray of Sickness', '2d8'),
      ('Fireball', '8d6'),
      ('Lightning Bolt', '8d6'),
      ('Blight', '8d8'),
      ('Cone of Cold', '8d8'),
      ('Insect Plague', '4d10'),
    ]) {
      expect(spells[name]!.damageFormula, damage);
      expect(spells[name]!.additionalDicePerSlotLevel, 1);
    }
    expect(spells['Insect Plague']!.repeatableEffect, isTrue);
    expect(spells['Ray of Sickness']!.deriveAttackModifier, isTrue);
    expect(spells['Cone of Cold']!.savingThrowAbility, Ability.constitution);
    expect(spells['Blur']!.duration, 'Concentration, up to 1 minute');
    expect(spells['Fog Cloud']!.range, '120 feet');
    expect(spells['Misty Step']!.castingTime, 'Bonus Action');
    for (final name in [
      'Hold Person',
      'Web',
      'Sleep',
      'Sleet Storm',
      'Ice Storm',
      'Stinking Cloud',
      'Polymorph',
      'Freedom of Movement',
      'Wall of Stone',
      'Tree Stride',
    ]) {
      final spell = spells[name]!;
      expect(spell.range, isNotNull, reason: name);
      expect(spell.duration, isNotNull, reason: name);
      expect(spell.summary, isNot(contains('untracked effects')), reason: name);
    }
    expect(spells['Hold Person']!.savingThrowAbility, Ability.wisdom);
    expect(spells['Web']!.savingThrowAbility, Ability.dexterity);
    expect(spells['Stinking Cloud']!.savingThrowAbility, Ability.constitution);
    expect(spells['Ice Storm']!.halfDamageOnSave, isTrue);
    expect(spells['Ice Storm']!.damageFormula, '2d10');
  });

  test(
    'Circle grants unlock by Druid level and keep owned prepared spells',
    () {
      const owned = Spell(
        id: 'owned-blur',
        name: 'Blur',
        level: 2,
        prepared: true,
        summary: 'Owned spell.',
      );
      final druid = Character(
        name: 'Druid',
        characterClass: 'Druid',
        level: 3,
        currentHp: 8,
        maxHp: 8,
        armourClass: 12,
        initiativeModifier: 0,
        status: 'Exploring',
        subclasses: const {'Druid': 'Circle of the Land'},
        spells: const [owned],
      );
      final first = withCircleSpells(druid, DruidLand.arid);
      expect(first.map((spell) => spell.name), [
        'Blur',
        'Burning Hands',
        'Fire Bolt',
      ]);
      expect(first.first, same(owned));
      final advanced = druid.copyWith(level: 9, spells: first);
      final grants = withCircleSpells(advanced, DruidLand.arid);
      expect(grants.length, 6);
      expect(grants.where((spell) => spell.isCircleGrant).length, 5);
      final restored = Character.fromJson(
        advanced.copyWith(spells: grants).toJson(),
      );
      expect(restored.spells.last.isCircleGrant, isTrue);
      expect(
        withCircleSpells(restored, DruidLand.polar).map((spell) => spell.name),
        [
          'Blur',
          'Fog Cloud',
          'Hold Person',
          'Ray of Frost',
          'Sleet Storm',
          'Ice Storm',
          'Cone of Cold',
        ],
      );
    },
  );

  test('Potent Spellcasting boosts only marked Druid cantrips', () {
    const spell = Spell(
      id: 'frost',
      name: 'Ray of Frost',
      level: 0,
      prepared: false,
      summary: 'Cold ray.',
      damageFormula: '1d8',
      range: '60 ft.',
    );
    final druid = Character(
      name: 'Druid',
      characterClass: 'Druid',
      level: 15,
      currentHp: 8,
      maxHp: 8,
      armourClass: 12,
      initiativeModifier: 0,
      status: 'Exploring',
      abilityScores: {Ability.wisdom: 16},
      elementalFury: ElementalFury.potentSpellcasting,
      druidCantripIds: {'frost'},
    );
    final saved = Character.fromJson(druid.toJson());
    expect(saved.damageFormulaFor(spell), '1d8 + 3');
    expect(saved.rangeForSpell(spell), '360 feet');
    expect(
      saved.damageFormulaFor(spell, applyPotentSpellcasting: false),
      '1d8',
    );
    expect(saved.copyWith(druidCantripIds: {}).rangeForSpell(spell), '60 ft.');
    expect(saved.copyWith(level: 14).rangeForSpell(spell), '60 ft.');
  });

  test('Primal Order Magician adds at least one to Arcana and Nature', () {
    final druid = Character(
      name: 'Druid',
      characterClass: 'Druid',
      level: 1,
      currentHp: 8,
      maxHp: 8,
      armourClass: 12,
      initiativeModifier: 0,
      status: 'Exploring',
      primalOrder: PrimalOrder.magician,
    );
    final restored = Character.fromJson(druid.toJson());
    final arcana = restored.skills.singleWhere((skill) => skill.id == 'arcana');
    final nature = restored.skills.singleWhere((skill) => skill.id == 'nature');
    expect(restored.primalOrder, PrimalOrder.magician);
    expect(restored.modifierFor(arcana), 1);
    expect(restored.modifierFor(nature), 1);
    expect(
      restored.copyWith(primalOrder: PrimalOrder.warden).modifierFor(arcana),
      0,
    );
  });

  test(
    'Wild Shape regains one use on a short rest and reverts on a long rest',
    () {
      final druid = Character(
        name: 'Druid',
        characterClass: 'Druid',
        level: 6,
        currentHp: 10,
        maxHp: 10,
        armourClass: 12,
        initiativeModifier: 0,
        status: 'Exploring',
        resources: BuiltInClass.druid.classResources(6, charismaModifier: 0),
      );
      final state = CharacterState.fromCharacter(druid).copyWith(
        wildShapeForm: 'Wolf',
        wildCompanion: 'Owl',
        resourceValues: {wildShapeResourceId: 0, wildResurgenceSlot.id: 1},
      );
      final short = RestPlan.forCharacter(
        type: RestType.shortRest,
        character: druid,
        currentState: state,
      ).updatedState;
      expect(short.resourceValues[wildShapeResourceId], 1);
      expect(short.wildShapeForm, 'Wolf');
      expect(short.resourceValues[wildResurgenceSlot.id], 1);
      final long = RestPlan.forCharacter(
        type: RestType.longRest,
        character: druid,
        currentState: short,
      ).updatedState;
      expect(long.resourceValues[wildShapeResourceId], 3);
      expect(long.wildShapeForm, isNull);
      expect(long.wildCompanion, isNull);
      expect(long.resourceValues.containsKey(wildResurgenceSlot.id), isFalse);
    },
  );

  test(
    'Action Surge has two uses at Fighter 17 and refills on a short rest',
    () {
      final fighter = Character(
        name: 'Fighter',
        characterClass: 'Fighter',
        level: 17,
        currentHp: 10,
        maxHp: 10,
        armourClass: 12,
        initiativeModifier: 0,
        status: 'Exploring',
        resources: BuiltInClass.fighter.classResources(17, charismaModifier: 0),
      );
      final spent = CharacterState.fromCharacter(
        fighter,
      ).copyWith(resourceValues: {actionSurgeResourceId: 0});
      final recovered = RestPlan.forCharacter(
        type: RestType.shortRest,
        character: fighter,
        currentState: spent,
      );
      expect(recovered.updatedState.resourceValues[actionSurgeResourceId], 2);
    },
  );

  test('built-in resource capacities and recovery follow class levels', () {
    CharacterResource resource(BuiltInClass type, int level, String id) => type
        .classResources(level, charismaModifier: 3)
        .singleWhere((resource) => resource.id == id);
    expect(resource(BuiltInClass.barbarian, 17, rageResourceId).maximum, 6);
    expect(resource(BuiltInClass.fighter, 4, secondWindResourceId).maximum, 3);
    expect(
      resource(BuiltInClass.paladin, 11, layOnHandsResourceId).maximum,
      55,
    );
    final bard = resource(BuiltInClass.bard, 5, bardicInspirationResourceId);
    expect(bard.maximum, 3);
    final cleric = resource(BuiltInClass.cleric, 18, clericChannelDivinityId);
    final paladin = resource(
      BuiltInClass.paladin,
      11,
      paladinChannelDivinityId,
    );
    expect(cleric.maximum, 4);
    expect(paladin.maximum, 3);
    final character = Character(
      name: 'Resource Tester',
      characterClass: 'Cleric',
      level: 18,
      currentHp: 10,
      maxHp: 10,
      armourClass: 12,
      initiativeModifier: 0,
      status: 'Exploring',
      resources: [bard, cleric, paladin],
    );
    final spent = CharacterState.fromCharacter(character).copyWith(
      resourceValues: {
        for (final resource in character.resources) resource.id: 0,
      },
    );
    final short = RestPlan.forCharacter(
      type: RestType.shortRest,
      character: character,
      currentState: spent,
    ).updatedState;
    expect(short.resourceValues, {
      bardicInspirationResourceId: 3,
      clericChannelDivinityId: 1,
      paladinChannelDivinityId: 1,
    });
  });

  test('multiclass slots combine casters and migrate spent Pact Magic', () {
    final previous = spellSlotsForClass('Warlock', 1);
    final slots = spellSlotsForClassLevels('Warlock', 4, {
      'Wizard': 1,
      'Paladin': 1,
      'Ranger': 1,
    });
    expect(
      {for (final slot in slots) slot.id: slot.maximum},
      {spellSlotId(1): 4, spellSlotId(2): 2, pactSlotId(1): 1},
    );
    final remaining = {
      for (final slot in slots)
        slot.id: remainingSpellSlots(slot, previous, {spellSlotId(1): 0}),
    };
    expect(remaining, {spellSlotId(1): 4, spellSlotId(2): 2, pactSlotId(1): 0});
    final caster = Character(
      name: 'Multiclass caster',
      characterClass: 'Warlock',
      level: 4,
      currentHp: 10,
      maxHp: 10,
      armourClass: 12,
      initiativeModifier: 0,
      status: 'Exploring',
      resources: slots,
    );
    final spent = CharacterState.fromCharacter(
      caster,
    ).copyWith(resourceValues: {...remaining, spellSlotId(1): 2});
    final short = RestPlan.forCharacter(
      type: RestType.shortRest,
      character: caster,
      currentState: spent,
    ).updatedState;
    expect(short.resourceValues[pactSlotId(1)], 1);
    expect(short.resourceValues[spellSlotId(1)], 2);
    final long = RestPlan.forCharacter(
      type: RestType.longRest,
      character: caster,
      currentState: short,
    ).updatedState;
    expect(long.resourceValues[spellSlotId(1)], 4);
  });

  test('mixed Hit Dice preserve legacy spending and recover by size', () {
    final fighter = Character(
      name: 'Multiclass',
      characterClass: 'Fighter',
      additionalClassLevels: const {'Wizard': 2},
      level: 4,
      currentHp: 4,
      maxHp: 20,
      armourClass: 12,
      initiativeModifier: 0,
      status: 'Exploring',
    );
    final character = Character.fromJson(fighter.toJson());
    final legacy = CharacterState.fromJson(
      CharacterState.fromCharacter(
        character,
      ).copyWith(hitDiceSpent: 1).toJson(),
    );
    expect(RestPlan.availableHitDiceBySize(character, legacy), {10: 1, 6: 2});
    final short =
        RestPlan.forCharacter(
          type: RestType.shortRest,
          character: character,
          currentState: legacy,
        ).spendHitDice(
          character: character,
          countsBySize: {10: 1, 6: 1},
          roller: SequenceDiceRoller([7, 4]),
        );
    final restored = PortableCharacterDocument.decode(
      PortableCharacterDocument(
        character: character,
        session: CharacterSession(
          characterState: short.updatedState,
          inventory: [],
          archivedInventory: [],
        ),
      ).encode(),
    );
    final saved = restored.session.characterState;
    expect(restored.character.additionalClassLevels, {'Wizard': 2});
    expect(saved.currentHp, 15);
    expect(saved.legacyHitDiceSpent, 0);
    expect(saved.hitDiceSpentBySize, {10: 2, 6: 1});
    expect(RestPlan.availableHitDiceBySize(character, saved), {10: 0, 6: 1});
    final long = RestPlan.forCharacter(
      type: RestType.longRest,
      character: character,
      currentState: saved,
    );
    expect(RestPlan.availableHitDiceBySize(character, long.updatedState), {
      10: 2,
      6: 2,
    });
  });

  test('Persistent Rage recovery resets only on a long rest', () {
    final barbarian = Character(
      name: 'Barbarian',
      characterClass: 'Barbarian',
      level: 15,
      currentHp: 10,
      maxHp: 10,
      armourClass: 12,
      initiativeModifier: 0,
      status: 'Exploring',
    );
    final spent = CharacterState.fromCharacter(
      barbarian,
    ).copyWith(persistentRageRecoveryUsed: true, relentlessRageAttempts: 2);
    CharacterState rest(RestType type) => RestPlan.forCharacter(
      type: type,
      character: barbarian,
      currentState: spent,
    ).updatedState;

    expect(rest(RestType.shortRest).persistentRageRecoveryUsed, isTrue);
    expect(rest(RestType.longRest).persistentRageRecoveryUsed, isFalse);
    expect(rest(RestType.shortRest).relentlessRageAttempts, 0);
    expect(rest(RestType.longRest).relentlessRageAttempts, 0);
  });

  final character = Character(
    name: 'Rest Tester',
    characterClass: 'Adventurer',
    level: 1,
    currentHp: 5,
    maxHp: 20,
    armourClass: 12,
    initiativeModifier: 0,
    status: 'Exploring',
    resources: const [
      CharacterResource(
        id: 'short',
        name: 'Short Resource',
        maximum: 2,
        initialValue: 2,
        rechargePeriod: RechargePeriod.shortRest,
      ),
      CharacterResource(
        id: 'long',
        name: 'Long Resource',
        maximum: 3,
        initialValue: 3,
        rechargePeriod: RechargePeriod.longRest,
      ),
      CharacterResource(
        id: 'manual',
        name: 'Manual Resource',
        maximum: 1,
        initialValue: 1,
        rechargePeriod: RechargePeriod.manual,
      ),
    ],
  );
  const state = CharacterState(
    currentHp: 5,
    maxHp: 20,
    temporaryHp: 3,
    armourClass: 12,
    initiativeModifier: 0,
    deathSaveSuccesses: 2,
    deathSaveFailures: 1,
    activeConditions: {'Poisoned'},
    pinnedActionKeys: {},
    resourceValues: {'short': 0, 'long': 1, 'manual': 0},
  );

  test(
    'slot progression preserves expenditure and applies the right rest rules',
    () {
      for (final name in ['Wizard', 'Paladin', 'Warlock']) {
        final before = spellSlotsForClass(name, 4);
        final after = spellSlotsForClass(name, 5);
        final oldPool = before.last;
        final spent = {oldPool.id: oldPool.maximum - 1};
        final nextPool = name == 'Warlock'
            ? after.single
            : after.singleWhere((resource) => resource.id == oldPool.id);
        final remaining = remainingSpellSlots(nextPool, before, spent);
        expect(remaining, nextPool.maximum - 1);
        final caster = character.copyWith(resources: [nextPool]);
        final saved = CharacterState.fromJson(
          state.copyWith(resourceValues: {nextPool.id: remaining}).toJson(),
        );
        for (final type in RestType.values) {
          final result = RestPlan.forCharacter(
            type: type,
            character: caster,
            currentState: saved,
          );
          expect(
            result.updatedState.resourceValues[nextPool.id],
            type == RestType.longRest || name == 'Warlock'
                ? nextPool.maximum
                : remaining,
          );
        }
      }
    },
  );

  test('hit dice heal, survive a save, and recover on a long rest', () {
    final short =
        RestPlan.forCharacter(
          type: RestType.shortRest,
          character: character,
          currentState: state,
        ).spendHitDice(
          character: character,
          count: 3,
          roller: SequenceDiceRoller([6]),
        );
    expect(short.updatedState.currentHp, 11);
    expect(short.updatedState.hitDiceSpent, 1);
    final restored = CharacterState.fromJson(short.updatedState.toJson());
    expect(RestPlan.availableHitDice(character, restored), 0);

    final long = RestPlan.forCharacter(
      type: RestType.longRest,
      character: character,
      currentState: restored,
    );
    expect(long.updatedState.hitDiceSpent, 0);
    expect(RestPlan.availableHitDice(character, long.updatedState), 1);
  });

  test(
    'starting Bard resources include slots and Charisma-based inspiration',
    () {
      final resources = BuiltInClass.bard.startingResources(
        charismaModifier: 3,
      );
      expect(resources.map((resource) => resource.maximum), [2, 3]);
      expect(resources.map((resource) => resource.initialValue), [2, 3]);
      expect(
        BuiltInClass.bard.startingResources(charismaModifier: -1).last.maximum,
        1,
      );
      final bard = character.copyWith(resources: resources);
      final plan = RestPlan.forCharacter(
        type: RestType.longRest,
        character: bard,
        currentState: state.copyWith(
          resourceValues: {for (final resource in resources) resource.id: 0},
        ),
      );
      expect(plan.updatedState.resourceValues.values, [2, 3]);
    },
  );

  test('Rage and Second Wind recover one use on a short rest', () {
    for (final builtIn in [BuiltInClass.barbarian, BuiltInClass.fighter]) {
      final resource = builtIn.startingResources(charismaModifier: 0).single;
      final adventurer = character.copyWith(resources: [resource]);
      final spent = state.copyWith(resourceValues: {resource.id: 0});
      final short = RestPlan.forCharacter(
        type: RestType.shortRest,
        character: adventurer,
        currentState: spent,
      );
      final long = RestPlan.forCharacter(
        type: RestType.longRest,
        character: adventurer,
        currentState: spent,
      );
      expect(short.updatedState.resourceValues[resource.id], 1);
      expect(long.updatedState.resourceValues[resource.id], 2);
    }
  });

  test('short rest only refills short-rest resources', () {
    final plan = RestPlan.forCharacter(
      type: RestType.shortRest,
      character: character,
      currentState: state,
    );

    expect(plan.updatedState.resourceValues, {
      'short': 2,
      'long': 1,
      'manual': 0,
    });
    expect(plan.updatedState.currentHp, 5);
    expect(plan.updatedState.temporaryHp, 3);
    expect(plan.updatedState.deathSaveSuccesses, 2);
    expect(plan.updatedState.activeConditions, {'Poisoned'});
    expect(plan.changes, ['Short Resource: 0 → 2']);
  });

  test('long rest restores health, saves, and eligible resources', () {
    final plan = RestPlan.forCharacter(
      type: RestType.longRest,
      character: character,
      currentState: state,
    );

    expect(plan.updatedState.resourceValues, {
      'short': 2,
      'long': 3,
      'manual': 0,
    });
    expect(plan.updatedState.currentHp, 20);
    expect(plan.updatedState.temporaryHp, 0);
    expect(plan.updatedState.deathSaveSuccesses, 0);
    expect(plan.updatedState.deathSaveFailures, 0);
    expect(plan.updatedState.activeConditions, {'Poisoned'});
    expect(plan.changes, contains('Death saves cleared'));
  });
}
