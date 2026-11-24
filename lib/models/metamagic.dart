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
    subtle || distant || extended => 'Preview from spell details',
    empowered => 'Choose dice when rolling typed spell damage',
    _ => 'Resolve this option at the table',
  };

  static int capacity(int sorcererLevel) => switch (sorcererLevel) {
    >= 17 => 6,
    >= 10 => 4,
    >= 2 => 2,
    _ => 0,
  };

  static String? distantRange(String? range) {
    if (range?.trim().toLowerCase() == 'touch') return '30 feet';
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

  static int? extendedTurns(String? duration) {
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
    return turns >= 10 && turns <= 14400 ? (turns * 2).clamp(10, 14400) : null;
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
