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
}
