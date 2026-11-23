import 'ability.dart';
import 'check_roll.dart';
import 'character_action.dart';
import 'character_resource.dart';
import 'feature.dart';
import 'inventory_item.dart';
import 'journal_entry.dart';
import 'skill.dart';
import 'spell.dart';
import 'weapon.dart';

enum PrimalOrder {
  magician('Magician'),
  warden('Warden');

  const PrimalOrder(this.label);
  final String label;
}

enum ElementalFury {
  potentSpellcasting('Potent Spellcasting'),
  primalStrike('Primal Strike');

  const ElementalFury(this.label);
  final String label;
}

class Character {
  final String id;
  final String name;
  final String characterClass;
  final Map<String, int> additionalClassLevels;
  final Map<String, String> subclasses;
  final PrimalOrder? primalOrder;
  final ElementalFury? elementalFury;
  final Set<String> druidCantripIds;
  final Set<String> sorcererSpellIds;
  final int? draconicHpBonus;
  // A live effect supplied by the session; never serialized in the definition.
  final bool innateSorceryActive;
  final Map<String, int> skillModifierMinimums;
  final Map<Ability, int> saveModifierMinimums;
  // Derived live bonuses are not part of the saved character definition.
  final int savingThrowBonus;
  // Keep recovered class rules intact until their format can be decoded.
  final Object? savedClassRules;
  final int level;
  final int currentHp;
  final int maxHp;
  final int armourClass;
  final int initiativeModifier;
  final String status;
  final Map<Ability, int> abilityScores;
  final int proficiencyBonus;
  final List<Skill> skills;
  final Map<String, SkillProficiency> skillProficiencies;
  final List<Weapon> weapons;
  final List<Spell> spells;
  final Set<String> initiallyPinnedActionKeys;
  final Set<Ability> savingThrowProficiencies;
  final List<CharacterResource> resources;
  final List<InventoryItem> initialInventory;
  final List<Feature> features;
  final List<JournalEntry> journalEntries;

  Character({
    this.id = 'test-character',
    required this.name,
    required this.characterClass,
    this.additionalClassLevels = const {},
    this.subclasses = const {},
    this.primalOrder,
    this.elementalFury,
    this.druidCantripIds = const {},
    this.sorcererSpellIds = const {},
    this.draconicHpBonus,
    this.innateSorceryActive = false,
    this.skillModifierMinimums = const {},
    this.saveModifierMinimums = const {},
    this.savingThrowBonus = 0,
    this.savedClassRules,
    required this.level,
    required this.currentHp,
    required this.maxHp,
    required this.armourClass,
    required this.initiativeModifier,
    required this.status,
    this.abilityScores = const {},
    this.proficiencyBonus = 2,
    this.skills = standardSkills,
    this.skillProficiencies = const {},
    this.weapons = const [],
    this.spells = const [],
    this.initiallyPinnedActionKeys = const {},
    this.savingThrowProficiencies = const {},
    this.resources = const [],
    this.initialInventory = const [],
    this.features = const [],
    this.journalEntries = const [],
  });

  Character copyWith({
    String? id,
    String? name,
    String? characterClass,
    Map<String, int>? additionalClassLevels,
    Map<String, String>? subclasses,
    PrimalOrder? primalOrder,
    bool clearPrimalOrder = false,
    ElementalFury? elementalFury,
    bool clearElementalFury = false,
    Set<String>? druidCantripIds,
    Set<String>? sorcererSpellIds,
    int? draconicHpBonus,
    bool? innateSorceryActive,
    Map<String, int>? skillModifierMinimums,
    Map<Ability, int>? saveModifierMinimums,
    int? savingThrowBonus,
    int? level,
    int? currentHp,
    int? maxHp,
    int? armourClass,
    int? initiativeModifier,
    String? status,
    Map<Ability, int>? abilityScores,
    int? proficiencyBonus,
    Map<String, SkillProficiency>? skillProficiencies,
    Set<Ability>? savingThrowProficiencies,
    Set<String>? initiallyPinnedActionKeys,
    List<InventoryItem>? initialInventory,
    List<Weapon>? weapons,
    List<Spell>? spells,
    List<CharacterResource>? resources,
    List<Feature>? features,
    List<JournalEntry>? journalEntries,
  }) {
    return Character(
      id: id ?? this.id,
      name: name ?? this.name,
      characterClass: characterClass ?? this.characterClass,
      additionalClassLevels:
          additionalClassLevels ?? this.additionalClassLevels,
      subclasses: subclasses ?? this.subclasses,
      primalOrder: clearPrimalOrder ? null : primalOrder ?? this.primalOrder,
      elementalFury: clearElementalFury
          ? null
          : elementalFury ?? this.elementalFury,
      druidCantripIds: druidCantripIds ?? this.druidCantripIds,
      sorcererSpellIds: sorcererSpellIds ?? this.sorcererSpellIds,
      draconicHpBonus: draconicHpBonus ?? this.draconicHpBonus,
      innateSorceryActive: innateSorceryActive ?? this.innateSorceryActive,
      skillModifierMinimums:
          skillModifierMinimums ?? this.skillModifierMinimums,
      saveModifierMinimums: saveModifierMinimums ?? this.saveModifierMinimums,
      savingThrowBonus: savingThrowBonus ?? this.savingThrowBonus,
      savedClassRules: savedClassRules,
      level: level ?? this.level,
      currentHp: currentHp ?? this.currentHp,
      maxHp: maxHp ?? this.maxHp,
      armourClass: armourClass ?? this.armourClass,
      initiativeModifier: initiativeModifier ?? this.initiativeModifier,
      status: status ?? this.status,
      abilityScores: abilityScores ?? this.abilityScores,
      proficiencyBonus: proficiencyBonus ?? this.proficiencyBonus,
      skills: skills,
      skillProficiencies: skillProficiencies ?? this.skillProficiencies,
      weapons: weapons ?? this.weapons,
      spells: spells ?? this.spells,
      initiallyPinnedActionKeys:
          initiallyPinnedActionKeys ?? this.initiallyPinnedActionKeys,
      savingThrowProficiencies:
          savingThrowProficiencies ?? this.savingThrowProficiencies,
      resources: resources ?? this.resources,
      initialInventory: initialInventory ?? this.initialInventory,
      features: features ?? this.features,
      journalEntries: journalEntries ?? this.journalEntries,
    );
  }

  Map<String, Object> toJson() {
    return {
      'id': id,
      'name': name,
      'characterClass': characterClass,
      if (additionalClassLevels.isNotEmpty)
        'additionalClassLevels': additionalClassLevels,
      if (subclasses.isNotEmpty) 'subclasses': subclasses,
      'primalOrder': ?primalOrder?.name,
      'elementalFury': ?elementalFury?.name,
      if (druidCantripIds.isNotEmpty)
        'druidCantripIds': druidCantripIds.toList(),
      if (sorcererSpellIds.isNotEmpty)
        'sorcererSpellIds': sorcererSpellIds.toList(),
      'draconicHpBonus': ?draconicHpBonus,
      'savedClassRules': ?savedClassRules,
      'level': level,
      'currentHp': currentHp,
      'maxHp': maxHp,
      'armourClass': armourClass,
      'initiativeModifier': initiativeModifier,
      'status': status,
      'abilityScores': abilityScores.map(
        (ability, score) => MapEntry(ability.name, score),
      ),
      'proficiencyBonus': proficiencyBonus,
      'skillProficiencies': skillProficiencies.map(
        (skill, proficiency) => MapEntry(skill, proficiency.name),
      ),
      'weapons': weapons
          .map(
            (weapon) => {
              'id': weapon.id,
              'name': weapon.name,
              'attackModifier': weapon.attackModifier,
              'damage': weapon.damage,
              'damageFormula': weapon.damageFormula,
              'versatileDamageFormula': ?weapon.versatileDamageFormula,
              if (weapon.usesStrength) 'usesStrength': true,
              'ammunitionName': ?weapon.ammunitionName,
              'category': ?weapon.category?.name,
              'mastery': ?weapon.mastery?.name,
              if (weapon.properties.isNotEmpty) 'properties': weapon.properties,
              'normalRange': ?weapon.normalRange,
              'longRange': ?weapon.longRange,
              'damageType': weapon.damageType,
              'range': weapon.range,
            },
          )
          .toList(),
      'spells': spells
          .map(
            (spell) => {
              'id': spell.id,
              'name': spell.name,
              'level': spell.level,
              'prepared': spell.prepared,
              if (spell.concentration) 'concentration': true,
              if (spell.repeatableEffect) 'repeatableEffect': true,
              if (spell.rollEffectOnCast) 'rollEffectOnCast': true,
              if (spell.ritual) 'ritual': true,
              'castingAbility': ?spell.castingAbility?.name,
              if (spell.deriveAttackModifier) 'deriveAttackModifier': true,
              'savingThrowAbility': ?spell.savingThrowAbility?.name,
              if (spell.halfDamageOnSave) 'halfDamageOnSave': true,
              if (spell.scaleCantripDamage) 'scaleCantripDamage': true,
              if (spell.additionalDicePerSlotLevel > 0)
                'additionalDicePerSlotLevel': spell.additionalDicePerSlotLevel,
              if (spell.addCastingModifierToDamage)
                'addCastingModifierToDamage': true,
              'castingTime': ?spell.castingTime,
              'range': ?spell.range,
              'duration': ?spell.duration,
              'components': ?spell.components,
              'summary': spell.summary,
              'rollModifier': spell.rollModifier,
              'damageFormula': spell.damageFormula,
              'damageType': spell.damageType,
            },
          )
          .toList(),
      'initiallyPinnedActionKeys': initiallyPinnedActionKeys.toList()..sort(),
      'savingThrowProficiencies':
          savingThrowProficiencies.map((ability) => ability.name).toList()
            ..sort(),
      'resources': resources
          .map(
            (resource) => {
              'id': resource.id,
              'name': resource.name,
              'maximum': resource.maximum,
              'initialValue': resource.initialValue,
              'rechargePeriod': resource.rechargePeriod.name,
            },
          )
          .toList(),
      'initialInventory': initialInventory
          .map((item) => item.toJson())
          .toList(),
      'features': features
          .map(
            (feature) => {
              'id': feature.id,
              'name': feature.name,
              'summary': feature.summary,
              'rollModifier': feature.rollModifier,
            },
          )
          .toList(),
      'journalEntries': journalEntries.map((entry) => entry.toJson()).toList(),
    };
  }

  factory Character.fromJson(Map<String, Object?> json) {
    final abilityScoresJson = json['abilityScores'] as Map<String, Object?>;
    final skillsJson = json['skillProficiencies'] as Map<String, Object?>;
    return Character(
      id: json['id'] as String,
      name: json['name'] as String,
      characterClass: json['characterClass'] as String,
      elementalFury: ElementalFury.values
          .where((choice) => choice.name == json['elementalFury'])
          .firstOrNull,
      druidCantripIds: (json['druidCantripIds'] as List<Object?>? ?? const [])
          .cast<String>()
          .toSet(),
      sorcererSpellIds: (json['sorcererSpellIds'] as List<Object?>? ?? const [])
          .cast<String>()
          .toSet(),
      draconicHpBonus: (json['draconicHpBonus'] as int?)?.clamp(0, 20),
      primalOrder: PrimalOrder.values
          .where((order) => order.name == json['primalOrder'])
          .firstOrNull,
      subclasses:
          (json['subclasses'] as Map<String, Object?>?)
              ?.cast<String, String>() ??
          const {},
      additionalClassLevels:
          (json['additionalClassLevels'] as Map<String, Object?>?)
              ?.cast<String, int>() ??
          const {},
      savedClassRules: json['savedClassRules'],
      level: json['level'] as int,
      currentHp: json['currentHp'] as int,
      maxHp: json['maxHp'] as int,
      armourClass: json['armourClass'] as int,
      initiativeModifier: json['initiativeModifier'] as int,
      status: json['status'] as String,
      abilityScores: abilityScoresJson.map(
        (ability, score) =>
            MapEntry(Ability.values.byName(ability), score as int),
      ),
      proficiencyBonus: json['proficiencyBonus'] as int,
      skillProficiencies: skillsJson.map(
        (skill, proficiency) => MapEntry(
          skill,
          SkillProficiency.values.byName(proficiency as String),
        ),
      ),
      weapons: (json['weapons'] as List<Object?>).map((value) {
        final weapon = value as Map<String, Object?>;
        return Weapon(
          id: weapon['id'] as String,
          name: weapon['name'] as String,
          attackModifier: weapon['attackModifier'] as int,
          damage: weapon['damage'] as String,
          damageFormula: weapon['damageFormula'] as String?,
          versatileDamageFormula: weapon['versatileDamageFormula'] as String?,
          usesStrength: weapon['usesStrength'] as bool? ?? false,
          ammunitionName: weapon['ammunitionName'] as String?,
          category: WeaponCategory.values.asNameMap()[weapon['category']],
          mastery: WeaponMastery.values.asNameMap()[weapon['mastery']],
          properties: (weapon['properties'] as List<Object?>? ?? const [])
              .whereType<String>()
              .toList(),
          normalRange: weapon['normalRange'] as int?,
          longRange: weapon['longRange'] as int?,
          damageType: weapon['damageType'] as String?,
          range: weapon['range'] as String?,
        );
      }).toList(),
      spells: (json['spells'] as List<Object?>).map((value) {
        final spell = value as Map<String, Object?>;
        return Spell(
          id: spell['id'] as String,
          name: spell['name'] as String,
          level: spell['level'] as int,
          prepared: spell['prepared'] as bool,
          concentration: spell['concentration'] as bool? ?? false,
          repeatableEffect: spell['repeatableEffect'] as bool? ?? false,
          rollEffectOnCast: spell['rollEffectOnCast'] as bool? ?? false,
          ritual: spell['ritual'] as bool? ?? false,
          castingAbility: _optionalAbility(spell['castingAbility']),
          deriveAttackModifier: spell['deriveAttackModifier'] as bool? ?? false,
          savingThrowAbility: _optionalAbility(spell['savingThrowAbility']),
          halfDamageOnSave: spell['halfDamageOnSave'] as bool? ?? false,
          scaleCantripDamage: spell['scaleCantripDamage'] as bool? ?? false,
          additionalDicePerSlotLevel:
              spell['additionalDicePerSlotLevel'] as int? ?? 0,
          addCastingModifierToDamage:
              spell['addCastingModifierToDamage'] as bool? ?? false,
          castingTime: spell['castingTime'] as String?,
          range: spell['range'] as String?,
          duration: spell['duration'] as String?,
          components: spell['components'] as String?,
          summary: spell['summary'] as String,
          rollModifier: spell['rollModifier'] as int?,
          damageFormula: spell['damageFormula'] as String?,
          damageType: spell['damageType'] as String?,
        );
      }).toList(),
      initiallyPinnedActionKeys:
          (json['initiallyPinnedActionKeys'] as List<Object?>)
              .cast<String>()
              .toSet(),
      savingThrowProficiencies:
          (json['savingThrowProficiencies'] as List<Object?>)
              .cast<String>()
              .map(Ability.values.byName)
              .toSet(),
      resources: (json['resources'] as List<Object?>).map((value) {
        final resource = value as Map<String, Object?>;
        return CharacterResource(
          id: resource['id'] as String,
          name: resource['name'] as String,
          maximum: resource['maximum'] as int,
          initialValue: resource['initialValue'] as int,
          rechargePeriod: RechargePeriod.values.byName(
            resource['rechargePeriod'] as String,
          ),
        );
      }).toList(),
      initialInventory: (json['initialInventory'] as List<Object?>)
          .map((value) => InventoryItem.fromJson(value as Map<String, Object?>))
          .toList(),
      features: (json['features'] as List<Object?>? ?? const []).map((value) {
        final feature = value as Map<String, Object?>;
        return Feature(
          id: feature['id'] as String,
          name: feature['name'] as String,
          summary: feature['summary'] as String,
          rollModifier: feature['rollModifier'] as int?,
        );
      }).toList(),
      journalEntries: (json['journalEntries'] as List<Object?>? ?? const [])
          .map((value) => JournalEntry.fromJson(value as Map<String, Object?>))
          .toList(),
    );
  }

  SkillProficiency proficiencyFor(Skill skill) {
    return skillProficiencies[skill.id] ?? SkillProficiency.none;
  }

  static Ability? _optionalAbility(Object? name) =>
      name == null ? null : Ability.values.byName(name as String);

  int? attackModifierFor(CharacterAction action) {
    if (action case Spell(
      deriveAttackModifier: true,
      castingAbility: final ability?,
    )) {
      return proficiencyBonus + abilityModifierFor(ability);
    }
    return action.rollModifier;
  }

  int get sneakAttackDice => (levelInClass('Rogue') + 1) ~/ 2;

  int get bardicInspirationDieSides => switch (levelInClass('Bard')) {
    >= 15 => 12,
    >= 10 => 10,
    >= 5 => 8,
    >= 1 => 6,
    _ => 0,
  };
  bool get hasFiendishResilience =>
      levelInClass('Warlock') >= 10 && subclasses['Warlock'] == 'Fiend Patron';
  bool get hasDragonWings =>
      levelInClass('Sorcerer') >= 14 &&
      subclasses['Sorcerer'] == 'Draconic Sorcery';
  bool get hasDraconicResilience =>
      levelInClass('Sorcerer') >= 3 &&
      subclasses['Sorcerer'] == 'Draconic Sorcery';

  int get martialArtsDieSides => switch (levelInClass('Monk')) {
    >= 17 => 12,
    >= 11 => 10,
    >= 5 => 8,
    >= 1 => 6,
    _ => 0,
  };

  int get attacksPerAction {
    final fighter = levelInClass('Fighter');
    if (fighter >= 20) return 4;
    if (fighter >= 11) return 3;
    if ([
      'Fighter',
      'Barbarian',
      'Monk',
      'Paladin',
      'Ranger',
    ].any((name) => levelInClass(name) >= 5)) {
      return 2;
    }
    return 1;
  }

  int get championLevel =>
      subclasses['Fighter'] == 'Champion' ? levelInClass('Fighter') : 0;

  int get weaponCriticalThreshold => switch (championLevel) {
    >= 15 => 18,
    >= 3 => 19,
    _ => 20,
  };

  int levelInClass(String name) {
    final target = name.trim().toLowerCase();
    if (characterClass.trim().toLowerCase() == target) {
      return level -
          additionalClassLevels.values.fold<int>(
            0,
            (sum, count) => sum + count,
          );
    }
    for (final entry in additionalClassLevels.entries) {
      if (entry.key.trim().toLowerCase() == target) return entry.value;
    }
    return 0;
  }

  int rageDamageBonusFor(CharacterAction action) {
    if (action is! Weapon || !action.usesStrength) return 0;
    return rageDamageBonus;
  }

  int get rageDamageBonus {
    final barbarianLevel = levelInClass('Barbarian');
    return switch (barbarianLevel == 0 ? level : barbarianLevel) {
      >= 16 => 4,
      >= 9 => 3,
      _ => 2,
    };
  }

  String? damageFormulaFor(
    CharacterAction action, {
    int? slotLevel,
    bool raging = false,
    bool twoHanded = false,
    bool applyPotentSpellcasting = true,
  }) {
    if (action is Weapon) {
      final formula = twoHanded
          ? action.versatileDamageFormula
          : action.damageFormula;
      final bonus = raging ? rageDamageBonusFor(action) : 0;
      if (bonus == 0 || formula == null) return formula;
      return DiceExpression.tryParse(
            formula,
          )?.withModifierBonus(bonus).notation ??
          formula;
    }
    final formula = action.damageFormula;
    if (action is! Spell || formula == null) return formula;

    final scales = action.isCantrip && action.scaleCantripDamage;
    final castingAbility = action.castingAbility;
    var bonus = action.addCastingModifierToDamage && castingAbility != null
        ? abilityModifierFor(castingAbility)
        : 0;
    if (applyPotentSpellcasting &&
        benefitsFromPotentSpellcasting(action) &&
        !(action.addCastingModifierToDamage &&
            castingAbility == Ability.wisdom)) {
      bonus += abilityModifierFor(Ability.wisdom);
    }
    final higherLevels = action.level <= 0 || action.level >= 9
        ? 0
        : ((slotLevel ?? action.level) - action.level).clamp(
            0,
            9 - action.level,
          );
    final slotDice =
        higherLevels * action.additionalDicePerSlotLevel.clamp(0, 9);
    if (!scales && bonus == 0 && slotDice == 0) return formula;
    final base = DiceExpression.tryParse(formula);
    if (base == null) return formula;
    final extra = scales
        ? switch (level) {
            >= 17 => 3,
            >= 11 => 2,
            >= 5 => 1,
            _ => 0,
          }
        : 0;
    return DiceExpression(
      diceCount: (base.diceCount + extra + slotDice).clamp(1, 20),
      dieSides: base.dieSides,
      modifier: base.modifier + bonus,
    ).notation;
  }

  bool benefitsFromPotentSpellcasting(Spell spell) =>
      elementalFury == ElementalFury.potentSpellcasting &&
      levelInClass('Druid') >= 7 &&
      spell.isCantrip &&
      (spell.isCircleGrant || druidCantripIds.contains(spell.id));

  String? rangeForSpell(Spell spell) {
    final range = spell.range;
    if (range == null ||
        levelInClass('Druid') < 15 ||
        !benefitsFromPotentSpellcasting(spell)) {
      return range;
    }
    final match = RegExp(
      r'^(\d+)\s*(?:feet|ft\.?)$',
      caseSensitive: false,
    ).firstMatch(range.trim());
    final distance = int.tryParse(match?.group(1) ?? '');
    return distance != null && distance >= 10
        ? '${distance + 300} feet'
        : range;
  }

  int? spellSaveDc(Spell spell) {
    final ability = spell.castingAbility;
    if (ability == null || spell.savingThrowAbility == null) return null;
    return 8 +
        proficiencyBonus +
        abilityModifierFor(ability) +
        (benefitsFromInnateSorcery(spell) ? 1 : 0);
  }

  bool benefitsFromInnateSorcery(Spell spell) =>
      innateSorceryActive &&
      levelInClass('Sorcerer') >= 1 &&
      sorcererSpellIds.contains(spell.id);

  int scoreFor(Ability ability) {
    return abilityScores[ability] ?? 10;
  }

  int abilityModifierFor(Ability ability) {
    return ((scoreFor(ability) - 10) / 2).floor();
  }

  SavingThrowCheck savingThrowFor(Ability ability) {
    final proficient =
        savingThrowProficiencies.contains(ability) ||
        levelInClass('Monk') >= 14 ||
        (levelInClass('Rogue') >= 15 &&
            const {Ability.wisdom, Ability.charisma}.contains(ability));
    final modifier =
        abilityModifierFor(ability) + (proficient ? proficiencyBonus : 0);
    final minimum = saveModifierMinimums[ability];
    return SavingThrowCheck(
      ability: ability,
      modifier:
          (minimum != null && minimum > modifier ? minimum : modifier) +
          savingThrowBonus,
      proficient: proficient || minimum != null,
    );
  }

  int jackOfAllTradesBonusFor(Skill skill) =>
      levelInClass('Bard') >= 2 &&
          proficiencyFor(skill) == SkillProficiency.none &&
          !skillModifierMinimums.containsKey(skill.id)
      ? proficiencyBonus ~/ 2
      : 0;

  int modifierFor(Skill skill) {
    final abilityModifier = abilityModifierFor(skill.ability);
    final proficiencyMultiplier = switch (proficiencyFor(skill)) {
      SkillProficiency.none => 0,
      SkillProficiency.proficient => 1,
      SkillProficiency.expertise => 2,
    };

    final wisdom = abilityModifierFor(Ability.wisdom);
    final primalBonus =
        primalOrder == PrimalOrder.magician &&
            levelInClass('Druid') > 0 &&
            (skill.id == 'arcana' || skill.id == 'nature')
        ? (wisdom < 1 ? 1 : wisdom)
        : 0;
    final modifier =
        abilityModifier +
        (proficiencyBonus * proficiencyMultiplier) +
        jackOfAllTradesBonusFor(skill) +
        primalBonus;
    final minimum = skillModifierMinimums[skill.id];
    return minimum != null && minimum > modifier ? minimum : modifier;
  }

  SkillCheck checkFor(Skill skill) {
    return SkillCheck(
      skill: skill,
      modifier: modifierFor(skill),
      proficiency: proficiencyFor(skill),
    );
  }

  List<CharacterAction> get availableCombatActions {
    return [
      ...weapons,
      ...spells.where((spell) => spell.isAvailableInCombat),
      ...features,
    ];
  }

  CharacterAction? actionForKey(String actionKey) {
    for (final action in [...weapons, ...spells, ...features]) {
      if (action.actionKey == actionKey) {
        return action;
      }
    }

    return null;
  }
}
