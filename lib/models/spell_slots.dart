import 'character_resource.dart';

const _fullCasterSlots = [
  [2],
  [3],
  [4, 2],
  [4, 3],
  [4, 3, 2],
  [4, 3, 3],
  [4, 3, 3, 1],
  [4, 3, 3, 2],
  [4, 3, 3, 3, 1],
  [4, 3, 3, 3, 2],
  [4, 3, 3, 3, 2, 1],
  [4, 3, 3, 3, 2, 1],
  [4, 3, 3, 3, 2, 1, 1],
  [4, 3, 3, 3, 2, 1, 1],
  [4, 3, 3, 3, 2, 1, 1, 1],
  [4, 3, 3, 3, 2, 1, 1, 1],
  [4, 3, 3, 3, 2, 1, 1, 1, 1],
  [4, 3, 3, 3, 3, 1, 1, 1, 1],
  [4, 3, 3, 3, 3, 2, 1, 1, 1],
  [4, 3, 3, 3, 3, 2, 2, 1, 1],
];

String spellSlotId(int level) => 'whetstone:spell-slot:$level';
String pactSlotId(int level) => 'whetstone:pact-slot:$level';

const wildResurgenceSlot = CharacterResource(
  id: 'whetstone:spell-slot:wild-resurgence',
  name: 'Wild Resurgence slot',
  maximum: 1,
  initialValue: 0,
  rechargePeriod: RechargePeriod.manual,
);

final natureMagicianSlots = [
  for (final level in [2, 4, 6, 8])
    CharacterResource(
      id: 'whetstone:spell-slot:nature-magician:$level',
      name: 'Nature Magician',
      maximum: 1,
      initialValue: 0,
      rechargePeriod: RechargePeriod.manual,
    ),
];

int? spellSlotLevel(CharacterResource resource) {
  if (resource.id == wildResurgenceSlot.id) return 1;
  for (final (index, slot) in natureMagicianSlots.indexed) {
    if (resource.id == slot.id) return 2 * (index + 1);
  }
  for (var level = 1; level <= 9; level++) {
    if (resource.id == spellSlotId(level) || resource.id == pactSlotId(level)) {
      return level;
    }
  }
  return null;
}

List<CharacterResource> fullCasterSlots(int casterLevel) {
  if (casterLevel < 1 || casterLevel > _fullCasterSlots.length) return [];
  return [
    for (final (index, count) in _fullCasterSlots[casterLevel - 1].indexed)
      CharacterResource(
        id: spellSlotId(index + 1),
        name: 'Level ${index + 1} Spell Slots',
        maximum: count,
        initialValue: count,
        rechargePeriod: RechargePeriod.longRest,
      ),
  ];
}

List<CharacterResource> spellSlotsForClass(String className, int level) {
  if (level < 1 || level > 20) return [];
  return switch (className.trim().toLowerCase()) {
    'bard' ||
    'cleric' ||
    'druid' ||
    'sorcerer' ||
    'wizard' => fullCasterSlots(level),
    'paladin' || 'ranger' => fullCasterSlots((level + 1) ~/ 2),
    'warlock' => [_pactMagicSlot(level)],
    _ => [],
  };
}

List<CharacterResource> spellSlotsForClassLevels(
  String primary,
  int totalLevel,
  Map<String, int> additional,
) {
  if (additional.isEmpty) return spellSlotsForClass(primary, totalLevel);
  final primaryLevel =
      totalLevel - additional.values.fold<int>(0, (sum, level) => sum + level);
  if (primaryLevel < 1 || totalLevel > 20) return [];
  var casterLevel = 0;
  var warlockLevel = 0;
  for (final entry in {primary: primaryLevel, ...additional}.entries) {
    switch (entry.key.trim().toLowerCase()) {
      case 'bard' || 'cleric' || 'druid' || 'sorcerer' || 'wizard':
        casterLevel += entry.value;
      case 'paladin' || 'ranger':
        casterLevel += (entry.value + 1) ~/ 2;
      case 'warlock':
        warlockLevel = entry.value;
    }
  }
  return [
    ...fullCasterSlots(casterLevel),
    if (warlockLevel > 0) _pactMagicSlot(warlockLevel, distinct: true),
  ];
}

int remainingSpellSlots(
  CharacterResource next,
  Iterable<CharacterResource> previousSlots,
  Map<String, int> remainingUses,
) {
  for (final previous in previousSlots) {
    if (spellSlotLevel(previous) == null ||
        previous.rechargePeriod != next.rechargePeriod) {
      continue;
    }
    final samePool =
        previous.id == next.id ||
        next.rechargePeriod == RechargePeriod.shortRest;
    if (!samePool) continue;
    final remaining = remainingUses[previous.id] ?? previous.initialValue;
    final spent = previous.maximum - remaining.clamp(0, previous.maximum);
    return (next.maximum - spent).clamp(0, next.maximum);
  }
  return next.initialValue;
}

CharacterResource _pactMagicSlot(int classLevel, {bool distinct = false}) {
  final slotLevel = ((classLevel + 1) ~/ 2).clamp(1, 5);
  final count = switch (classLevel) {
    1 => 1,
    >= 17 => 4,
    >= 11 => 3,
    _ => 2,
  };
  return CharacterResource(
    id: distinct ? pactSlotId(slotLevel) : spellSlotId(slotLevel),
    name: 'Level $slotLevel Pact Magic Slots',
    maximum: count,
    initialValue: count,
    rechargePeriod: RechargePeriod.shortRest,
  );
}
