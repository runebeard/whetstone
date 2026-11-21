import 'dart:math';

enum D20Mode {
  normal('Normal'),
  advantage('Advantage'),
  disadvantage('Disadvantage');

  const D20Mode(this.label);
  final String label;

  D20Mode withAdvantage() =>
      this == D20Mode.disadvantage ? D20Mode.normal : D20Mode.advantage;

  int select(int first, int? second) => switch (this) {
    D20Mode.normal => first,
    D20Mode.advantage => max(first, second!),
    D20Mode.disadvantage => min(first, second!),
  };
}

class CheckRoll {
  final String label;
  final int naturalRoll;
  final int modifier;
  final int? minimumRoll;

  const CheckRoll({
    required this.label,
    required this.naturalRoll,
    required this.modifier,
    this.minimumRoll,
  });

  int get effectiveRoll =>
      minimumRoll == null ? naturalRoll : max(naturalRoll, minimumRoll!);
  int get total => effectiveRoll + modifier;
  bool get isNaturalOne => naturalRoll == 1;
  bool get isNaturalTwenty => naturalRoll == 20;

  String get displayModifier => modifier >= 0 ? '+$modifier' : '$modifier';
}

abstract class DiceRoller {
  const DiceRoller();

  int rollDie(int sides);

  int rollD20() => rollDie(20);
}

class RandomDiceRoller extends DiceRoller {
  final Random _random;

  RandomDiceRoller([Random? random]) : _random = random ?? Random();

  @override
  int rollDie(int sides) => _random.nextInt(sides) + 1;
}

class DiceExpression {
  final int diceCount;
  final int dieSides;
  final int modifier;

  const DiceExpression({
    required this.diceCount,
    required this.dieSides,
    this.modifier = 0,
  });

  static DiceExpression? tryParse(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll('−', '-')
        .replaceAll(' ', '');
    final match = RegExp(r'^(\d+)d(\d+)([+-]\d+)?$').firstMatch(normalized);
    if (match == null) return null;
    final diceCount = int.parse(match.group(1)!);
    final dieSides = int.parse(match.group(2)!);
    final modifier = int.tryParse(match.group(3) ?? '') ?? 0;
    if (diceCount < 1 || diceCount > 20 || dieSides < 2 || dieSides > 100) {
      return null;
    }
    return DiceExpression(
      diceCount: diceCount,
      dieSides: dieSides,
      modifier: modifier,
    );
  }

  String get notation {
    if (modifier == 0) return '${diceCount}d$dieSides';
    final sign = modifier > 0 ? '+' : '−';
    return '${diceCount}d$dieSides $sign ${modifier.abs()}';
  }

  DiceExpression withModifierBonus(int bonus) => DiceExpression(
    diceCount: diceCount,
    dieSides: dieSides,
    modifier: modifier + bonus,
  );

  DiceExpression withCriticalHitDice() => DiceExpression(
    diceCount: diceCount * 2,
    dieSides: dieSides,
    modifier: modifier,
  );

  DamageRoll roll(String label, DiceRoller diceRoller) {
    return DamageRoll(
      label: label,
      expression: this,
      dice: [
        for (var index = 0; index < diceCount; index++)
          diceRoller.rollDie(dieSides),
      ],
    );
  }
}

class DamageRoll {
  final String label;
  final DiceExpression expression;
  final List<int> dice;

  const DamageRoll({
    required this.label,
    required this.expression,
    required this.dice,
  });

  int get diceTotal => dice.fold(0, (total, value) => total + value);
  int get total => diceTotal + expression.modifier;
}
