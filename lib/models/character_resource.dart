enum RechargePeriod {
  shortRest('Short rest'),
  longRest('Long rest'),
  manual('Manual');

  final String label;

  const RechargePeriod(this.label);
}

class CharacterResource {
  final String id;
  final String name;
  final int maximum;
  final int initialValue;
  final RechargePeriod rechargePeriod;

  const CharacterResource({
    required this.id,
    required this.name,
    required this.maximum,
    required this.initialValue,
    required this.rechargePeriod,
  }) : assert(maximum > 0),
       assert(initialValue >= 0 && initialValue <= maximum);
}
