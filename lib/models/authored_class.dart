import 'ability.dart';
import 'character.dart';
import 'character_resource.dart';
import 'feature.dart';
import 'inventory_item.dart';
import 'skill.dart';
import 'weapon.dart';

class AuthoredClass {
  final Map<String, Object?> pack;
  final Map<String, Object?> rules;

  AuthoredClass(this.pack, this.rules);

  String get name => rules['name'] as String;
  int get hitDie => rules['hitDie'] as int;
  int get skillCount => rules['skillChoiceCount'] as int;
  List<String> get skills => (rules['skillOptions'] as List).cast<String>();
  Set<Ability> get saves => {
    for (final name in (rules['savingThrows'] as List).cast<String>())
      Ability.values.byName(name),
  };

  List<String> featureNamesAt(int level) =>
      _featureEntriesAt(level).map((entry) => entry['name'] as String).toList();

  List<Feature> grants(int level) =>
      _featureEntriesAt(level).map(_feature).toList();

  Iterable<Map<String, Object?>> _featureEntriesAt(int level) sync* {
    final byLevel = rules['featureIdsByLevel'] as Map<String, Object?>;
    final entries = (pack['features'] as List).cast<Map<String, Object?>>();
    for (final id in (byLevel['$level'] as List? ?? const [])) {
      yield entries.singleWhere((entry) => entry['id'] == id);
    }
  }

  Feature _feature(Map<String, Object?> entry) {
    if (entry['actionMenu'] != null) {
      throw const FormatException('This level requires action automation.');
    }
    return Feature(
      id: entry['id'] as String,
      name: entry['name'] as String,
      summary: entry['summary'] as String,
    );
  }

  Map<String, List<String>> get initialTraining {
    final entryRules = rules['entryRules'] as Map<String, Object?>;
    final training = entryRules['initialTraining'] as Map<String, Object?>?;
    return {
      'Weapon training': (training?['weapons'] as List? ?? const [])
          .cast<String>(),
      'Armour training': (training?['armour'] as List? ?? const [])
          .cast<String>(),
    };
  }

  List<Map<String, Object?>> get equipmentOptions {
    final entryRules = rules['entryRules'] as Map<String, Object?>;
    return (entryRules['equipmentOptions'] as List)
        .cast<Map<String, Object?>>();
  }

  List<InventoryItem> startingEquipment([String? optionId]) {
    final option = _equipmentOption(optionId);
    if (option == null) return [];
    final entries = (pack['items'] as List).cast<Map<String, Object?>>();
    final quantities = option['items'] as Map<String, Object?>;
    return [
      for (final quantity in quantities.entries)
        InventoryItem.fromJson({
          ...entries.singleWhere((entry) => entry['id'] == quantity.key),
          'category': 'equipment',
          'quantity': quantity.value,
        }),
      if ((option['gold'] as int? ?? 0) > 0)
        InventoryItem(
          name: 'Gold (gp)',
          quantity: option['gold'] as int,
          weightPerItem: 0,
          category: ItemCategory.general,
        ),
    ];
  }

  Map<String, Object?>? _equipmentOption(String? optionId) {
    final options = equipmentOptions;
    if (options.isEmpty) return null;
    return optionId == null
        ? options.single
        : options.singleWhere((option) => option['id'] == optionId);
  }

  List<Weapon> startingWeapons(
    String? optionId,
    Map<Ability, int> scores,
    int proficiencyBonus,
  ) {
    final option = _equipmentOption(optionId);
    if (option == null) return [];
    final items = (pack['items'] as List).cast<Map<String, Object?>>();
    final weapons = (pack['weapons'] as List).cast<Map<String, Object?>>();
    final quantities = option['items'] as Map<String, Object?>;
    final linkedIds = {
      for (final id in quantities.keys)
        items.singleWhere((item) => item['id'] == id)['linkedWeaponId'],
    }.whereType<String>();
    return [
      for (final id in linkedIds)
        _startingWeapon(
          weapons.singleWhere((weapon) => weapon['id'] == id),
          scores,
          proficiencyBonus,
        ),
    ];
  }

  List<Weapon> refreshStartingWeapons(
    Character previous,
    List<Weapon> weapons,
    Map<Ability, int> scores,
    int proficiencyBonus,
  ) {
    final original = <String, Weapon>{};
    final recalculated = <String, Weapon>{};
    for (final option in equipmentOptions) {
      final id = option['id'] as String;
      for (final weapon in startingWeapons(
        id,
        previous.abilityScores,
        previous.proficiencyBonus,
      )) {
        original[weapon.id] = weapon;
      }
      for (final weapon in startingWeapons(id, scores, proficiencyBonus)) {
        recalculated[weapon.id] = weapon;
      }
    }
    return [
      for (final weapon in weapons)
        if (_matchesStartingWeapon(weapon, original[weapon.id]))
          recalculated[weapon.id]!
        else
          weapon,
    ];
  }

  bool _matchesStartingWeapon(Weapon weapon, Weapon? original) =>
      original != null &&
      weapon.name == original.name &&
      weapon.attackModifier == original.attackModifier &&
      weapon.damage == original.damage &&
      weapon.damageFormula == original.damageFormula &&
      weapon.damageType == original.damageType &&
      weapon.range == original.range;

  Weapon _startingWeapon(
    Map<String, Object?> entry,
    Map<Ability, int> scores,
    int proficiencyBonus,
  ) {
    int modifier(Ability ability) =>
        (((scores[ability] ?? 10) - 10) / 2).floor();
    final abilityName = entry['attackAbility'] as String?;
    var attackAbility = abilityName == null
        ? 0
        : modifier(Ability.values.byName(abilityName));
    if (entry['finesse'] == true) {
      final strength = modifier(Ability.strength);
      final dexterity = modifier(Ability.dexterity);
      attackAbility = strength > dexterity ? strength : dexterity;
    }
    final category = entry['category'] as String? ?? '';
    final trained = initialTraining['Weapon training']!.any(
      (training) =>
          training == category ||
          (training == 'martial' && category.startsWith('martial')) ||
          (training == 'simple' && category.startsWith('simple')),
    );
    final equipmentBonus = entry['equipmentBonus'] as int? ?? 0;
    final damageBonus =
        equipmentBonus +
        (entry['addAbilityToDamage'] == true ? attackAbility : 0);
    final dice = (entry['damageDice'] ?? entry['damageFormula']) as String?;
    final formula = dice == null || damageBonus == 0
        ? dice
        : '$dice ${damageBonus < 0 ? '-' : '+'} ${damageBonus.abs()}';
    final damageType = entry['damageType'] as String?;
    return Weapon(
      id: entry['id'] as String,
      name: entry['name'] as String,
      attackModifier:
          (entry['attackModifier'] as int) +
          attackAbility +
          equipmentBonus +
          (trained && entry['addProficiencyBonus'] == true
              ? proficiencyBonus
              : 0),
      damage: formula == null
          ? entry['damage'] as String
          : [formula, ?damageType].join(' '),
      damageFormula: formula,
      damageType: damageType,
      range: entry['range'] as String?,
    );
  }

  List<CharacterResource> resourcesAt(int level) {
    final data = rules['resources'] as Map<String, Object?>;
    final grants = data['grantLevels'] as Map<String, Object?>;
    final scaling = (data['scaling'] as List).cast<Map<String, Object?>>();
    final entries = (pack['resources'] as List).cast<Map<String, Object?>>();
    return [
      for (final grant in grants.entries)
        if ((grant.value as int) <= level)
          _resource(
            entries.singleWhere((entry) => entry['id'] == grant.key),
            scaling,
            level,
          ),
    ];
  }

  CharacterResource _resource(
    Map<String, Object?> entry,
    List<Map<String, Object?>> scaling,
    int level,
  ) {
    final id = entry['id'] as String;
    var maximum = entry['maximum'] as int;
    final modifiers = scaling.where((rule) => rule['resourceId'] == id);
    if (modifiers.isNotEmpty) {
      final rule = modifiers.single;
      if (rule.keys.any(
        (key) => !const {'resourceId', 'baseByLevel', 'minimum'}.contains(key),
      )) {
        throw const FormatException('Unsupported class resource scaling.');
      }
      final thresholds = rule['baseByLevel'] as Map<String, Object?>;
      var appliedLevel = 0;
      for (final threshold in thresholds.entries) {
        final at = int.parse(threshold.key);
        if (at > appliedLevel && at <= level) {
          maximum = threshold.value as int;
          appliedLevel = at;
        }
      }
      final minimum = rule['minimum'] as int? ?? 1;
      if (maximum < minimum) maximum = minimum;
    }
    final initial = entry['initialValue'] as int;
    final base = entry['maximum'] as int;
    if (base < 1 || initial < 0 || initial > base || maximum < 1) {
      throw const FormatException('Invalid class resource values.');
    }
    return CharacterResource(
      id: id,
      name: entry['name'] as String,
      maximum: maximum,
      initialValue: (maximum - (base - initial)).clamp(0, maximum).toInt(),
      rechargePeriod: RechargePeriod.values.byName(
        entry['rechargePeriod'] as String,
      ),
    );
  }

  bool get supportsFirstLevels {
    try {
      if (rules['spellcasting'] != null ||
          (rules['choices'] as List).isNotEmpty ||
          (rules['subclassLevels'] as List).any(
            (level) => (level as int) <= 2,
          ) ||
          ![6, 8, 10, 12].contains(hitDie) ||
          skillCount < 0 ||
          skillCount > skills.toSet().length ||
          skills.any((id) => !standardSkills.any((skill) => skill.id == id))) {
        return false;
      }
      saves;
      for (final categories in initialTraining.values) {
        categories.toList();
      }
      grants(1);
      grants(2);
      resourcesAt(1);
      resourcesAt(2);
      final optionIds = <String>{};
      for (final option in equipmentOptions) {
        final id = option['id'] as String;
        if (id.trim().isEmpty ||
            !optionIds.add(id) ||
            (option['label'] as String).trim().isEmpty) {
          return false;
        }
        startingEquipment(id);
        startingWeapons(id, const {}, 2);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Map<String, Object?> get snapshot => {
    'recoveryClass': rules,
    'recoveryPack': pack,
  };

  static AuthoredClass? fromCharacter(Character character) {
    final snapshot = character.savedClassRules;
    if (snapshot is! Map<String, Object?>) return null;
    final rules = snapshot['recoveryClass'];
    final pack = snapshot['recoveryPack'];
    if (rules is! Map<String, Object?> || pack is! Map<String, Object?>) {
      return null;
    }
    final authored = AuthoredClass(pack, rules);
    return authored.supportsFirstLevels ? authored : null;
  }
}
