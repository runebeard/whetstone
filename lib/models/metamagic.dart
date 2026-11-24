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
}
