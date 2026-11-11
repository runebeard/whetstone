import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/check_roll.dart';

class SequenceRoller extends DiceRoller {
  final List<int> results;
  int index = 0;

  SequenceRoller(this.results);

  @override
  int rollDie(int sides) => results[index++];
}

void main() {
  test('critical damage doubles dice and applies the modifier once', () {
    final critical = DiceExpression.tryParse('2d6 + 3')!.withCriticalHitDice();
    expect(critical.diceCount, 4);
    expect(critical.dieSides, 6);
    expect(critical.modifier, 3);
  });

  test('parses and normalizes standard damage notation', () {
    expect(DiceExpression.tryParse('2d6 + 4')?.notation, '2d6 + 4');
    expect(DiceExpression.tryParse('1d6 − 1')?.notation, '1d6 − 1');
    expect(DiceExpression.tryParse('not dice'), isNull);
    expect(DiceExpression.tryParse('0d6'), isNull);
  });

  test('rolls every die and applies the modifier', () {
    final expression = DiceExpression.tryParse('2d6 + 4')!;
    final roll = expression.roll('Greatsword', SequenceRoller([3, 5]));

    expect(roll.dice, [3, 5]);
    expect(roll.diceTotal, 8);
    expect(roll.total, 12);
  });
}
