import 'package:whetstone/models/check_roll.dart';

class SequenceDiceRoller extends DiceRoller {
  final List<int> rolls;
  int index = 0;

  SequenceDiceRoller(this.rolls);

  @override
  int rollDie(int sides) => rolls[index++];
}
