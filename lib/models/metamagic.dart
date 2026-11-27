import 'spell.dart';

enum Metamagic {
  careful('Careful Spell', 1),
  distant('Distant Spell', 1),
  empowered('Empowered Spell', 1),
  extended('Extended Spell', 1),
  heightened('Heightened Spell', 2),
  quickened('Quickened Spell', 2),
  seeking('Seeking Spell', 1),
  subtle('Subtle Spell', 1),
  transmuted('Transmuted Spell', 1),
  twinned('Twinned Spell', 1);

  const Metamagic(this.label, this.pointCost);
  final String label;
  final int pointCost;
  String get usageHint => switch (this) {
    quickened => 'Cast from spell details',
    subtle ||
    distant ||
    extended ||
    transmuted ||
    careful ||
    heightened ||
    twinned => 'Preview from spell details',
    empowered => 'Choose dice when rolling typed spell damage',
    seeking => 'Confirm a missed spell attack to reroll one d20',
  };

  static int capacity(int sorcererLevel) => switch (sorcererLevel) {
    >= 17 => 6,
    >= 10 => 4,
    >= 2 => 2,
    _ => 0,
  };
  static const transmutedTypes = [
    'Acid',
    'Cold',
    'Fire',
    'Lightning',
    'Poison',
    'Thunder',
  ];
  static String? transmutedType(String? value) => transmutedTypes
      .where((type) => type.toLowerCase() == value?.trim().toLowerCase())
      .firstOrNull;

  static String? distantRange(String? range) {
    if (range?.trim().toLowerCase() == 'touch') return '30 feet';
    final miles = RegExp(
      r'^(\d+)\s*(?:mile|miles|mi\.?)$',
      caseSensitive: false,
    ).firstMatch(range?.trim() ?? '');
    if (miles != null) {
      final count = int.tryParse(miles.group(1)!);
      return count != null && count > 0 ? '${count * 2} miles' : null;
    }
    final match = RegExp(
      r'^(\d+)\s*(?:feet|foot|ft\.?)$',
      caseSensitive: false,
    ).firstMatch(range?.trim() ?? '');
    final feet = int.tryParse(match?.group(1) ?? '');
    return feet != null && feet >= 5 ? '${feet * 2} feet' : null;
  }

  static String subtleComponents(Spell spell) {
    if (spell.components == null || spell.components!.trim().isEmpty) {
      return 'Verify Material requirements at the table; priced or consumed materials remain required.';
    }
    if (!spell.hasCostlyOrConsumedMaterial) return 'None';
    final match = RegExp(
      r'\bM\b',
      caseSensitive: false,
    ).firstMatch(spell.components!);
    return match == null
        ? 'Material requirements: ${spell.components}'
        : spell.components!.substring(match.start);
  }

  static int? durationTurns(String? duration) {
    final match = RegExp(
      r'^(?:concentration,\s*)?(?:up to\s*)?(\d+)\s*(minute|hour|day)s?$',
      caseSensitive: false,
    ).firstMatch(duration?.trim() ?? '');
    if (match == null) return null;
    final count = int.tryParse(match.group(1)!);
    if (count == null) return null;
    final turns =
        count *
        switch (match.group(2)!.toLowerCase()) {
          'minute' => 10,
          'hour' => 600,
          _ => 14400,
        };
    return turns >= 10 && turns <= 14400 ? turns : null;
  }

  static int? extendedTurns(String? duration) {
    final turns = durationTurns(duration);
    return turns == null ? null : (turns * 2).clamp(10, 14400);
  }

  // Verified 2024 definitions: base spell level and base target capacity.
  static const twinnedSpells = {
    'command': (1, 1),
    'fly': (3, 1),
    'charm monster': (4, 1),
    'charm person': (1, 1),
    'hold person': (2, 1),
    'hold monster': (5, 1),
    'invisibility': (2, 1),
    'bless': (1, 3),
  };

  static bool supportsTwinned(Spell spell) {
    final baseLevel = twinnedSpells[Spell.normalizedName(spell.name)]?.$1;
    return baseLevel == spell.level &&
        spell.damageFormula == null &&
        spell.rollModifier == null &&
        !spell.deriveAttackModifier;
  }

  static int? twinnedEffectiveLevel(Spell spell, int slotLevel) =>
      supportsTwinned(spell) && slotLevel >= spell.level && slotLevel < 9
      ? slotLevel + 1
      : null;

  static int? twinnedTargetCount(Spell spell, int slotLevel) {
    final effective = twinnedEffectiveLevel(spell, slotLevel);
    if (effective == null) return null;
    return twinnedSpells[Spell.normalizedName(spell.name)]!.$2 +
        effective -
        spell.level;
  }

  static int? extendedSpellTurns(Spell spell, {int? slotLevel}) {
    final baseline = extendedTurns(spell.duration);
    if (baseline == null) return null;
    final level = slotLevel ?? spell.level;
    final name = Spell.normalizedName(spell.name);
    if (name == 'hex' || name == "hunter's mark") {
      if (level >= 5) return 14400;
      if (level >= 3) return 9600;
      if (name == 'hex' && level == 2) return 4800;
    }
    return baseline;
  }
}

class SpellSaveEffect {
  final Metamagic option;
  final List<String> targets;
  final String? heightenedTarget;
  const SpellSaveEffect(this.option, this.targets, {this.heightenedTarget});

  String get guidance {
    final baseline = option == Metamagic.careful
        ? 'Careful Spell: ${targets.join(', ')} automatically succeed on saves; take no damage when a successful save normally halves damage.'
        : 'Heightened Spell: ${targets.single} has Disadvantage on saves against this spell. Cancel Advantage normally; other targets are unaffected.';
    return option == Metamagic.careful && heightenedTarget != null
        ? '$baseline Heightened Spell: $heightenedTarget has Disadvantage on saves against this spell. Cancel Advantage normally; other targets are unaffected.'
        : baseline;
  }

  Map<String, Object> toJson() => {
    'option': option.name,
    'targets': targets,
    if (option == Metamagic.careful && heightenedTarget != null)
      'heightenedTarget': heightenedTarget!,
  };
  static SpellSaveEffect? fromJson(Object? value) {
    if (value is! Map) return null;
    final option = Metamagic.values
        .where((o) => o.name == value['option'])
        .firstOrNull;
    if (option != Metamagic.careful && option != Metamagic.heightened) {
      return null;
    }
    final raw = value['targets'];
    if (raw is! List) return null;
    final names = raw
        .whereType<String>()
        .map((n) => n.trim())
        .where((n) => n.isNotEmpty && n.length <= 80)
        .toSet()
        .toList();
    if (names.isEmpty ||
        names.length > (option == Metamagic.heightened ? 1 : 10)) {
      return null;
    }
    final extra = value['heightenedTarget'];
    final heightened =
        option == Metamagic.careful &&
            extra is String &&
            extra.trim().isNotEmpty &&
            extra.trim().length <= 80
        ? extra.trim()
        : null;
    return SpellSaveEffect(
      option!,
      List.unmodifiable(names),
      heightenedTarget: heightened,
    );
  }
}
