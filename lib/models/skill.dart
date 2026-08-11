import 'ability.dart';

enum SkillProficiency { none, proficient, expertise }

class Skill {
  final String id;
  final String name;
  final Ability ability;

  const Skill({required this.id, required this.name, required this.ability});
}

class SkillCheck {
  final Skill skill;
  final int modifier;
  final SkillProficiency proficiency;

  const SkillCheck({
    required this.skill,
    required this.modifier,
    required this.proficiency,
  });
}

const standardSkills = [
  Skill(id: 'acrobatics', name: 'Acrobatics', ability: Ability.dexterity),
  Skill(
    id: 'animal_handling',
    name: 'Animal Handling',
    ability: Ability.wisdom,
  ),
  Skill(id: 'arcana', name: 'Arcana', ability: Ability.intelligence),
  Skill(id: 'athletics', name: 'Athletics', ability: Ability.strength),
  Skill(id: 'deception', name: 'Deception', ability: Ability.charisma),
  Skill(id: 'history', name: 'History', ability: Ability.intelligence),
  Skill(id: 'insight', name: 'Insight', ability: Ability.wisdom),
  Skill(id: 'intimidation', name: 'Intimidation', ability: Ability.charisma),
  Skill(
    id: 'investigation',
    name: 'Investigation',
    ability: Ability.intelligence,
  ),
  Skill(id: 'medicine', name: 'Medicine', ability: Ability.wisdom),
  Skill(id: 'nature', name: 'Nature', ability: Ability.intelligence),
  Skill(id: 'perception', name: 'Perception', ability: Ability.wisdom),
  Skill(id: 'performance', name: 'Performance', ability: Ability.charisma),
  Skill(id: 'persuasion', name: 'Persuasion', ability: Ability.charisma),
  Skill(id: 'religion', name: 'Religion', ability: Ability.intelligence),
  Skill(
    id: 'sleight_of_hand',
    name: 'Sleight of Hand',
    ability: Ability.dexterity,
  ),
  Skill(id: 'stealth', name: 'Stealth', ability: Ability.dexterity),
  Skill(id: 'survival', name: 'Survival', ability: Ability.wisdom),
];
