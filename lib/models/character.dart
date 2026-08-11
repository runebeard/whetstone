import 'ability.dart';
import 'character_action.dart';
import 'character_resource.dart';
import 'feature.dart';
import 'inventory_item.dart';
import 'journal_entry.dart';
import 'skill.dart';
import 'spell.dart';
import 'weapon.dart';

class Character {
  final String id;
  final String name;
  final String characterClass;
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

  int scoreFor(Ability ability) {
    return abilityScores[ability] ?? 10;
  }

  int abilityModifierFor(Ability ability) {
    return ((scoreFor(ability) - 10) / 2).floor();
  }

  SavingThrowCheck savingThrowFor(Ability ability) {
    final proficient = savingThrowProficiencies.contains(ability);
    return SavingThrowCheck(
      ability: ability,
      modifier:
          abilityModifierFor(ability) + (proficient ? proficiencyBonus : 0),
      proficient: proficient,
    );
  }

  int modifierFor(Skill skill) {
    final abilityModifier = abilityModifierFor(skill.ability);
    final proficiencyMultiplier = switch (proficiencyFor(skill)) {
      SkillProficiency.none => 0,
      SkillProficiency.proficient => 1,
      SkillProficiency.expertise => 2,
    };

    return abilityModifier + (proficiencyBonus * proficiencyMultiplier);
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
