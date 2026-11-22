import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/rest.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/screens/character_overview.dart';

void main() {
  const before = Spell(
    id: 'old',
    name: 'Old Spell',
    level: 1,
    prepared: true,
    summary: 'Vivid description',
    concentration: true,
    repeatableEffect: true,
    ritual: true,
    castingAbility: Ability.intelligence,
    deriveAttackModifier: true,
    additionalDicePerSlotLevel: 2,
    addCastingModifierToDamage: true,
    savingThrowAbility: Ability.dexterity,
    halfDamageOnSave: true,
    castingTime: 'Action',
    range: '60 ft',
    duration: '1 minute',
    components: 'V, S',
    rollModifier: 7,
    damageFormula: '2d6 + 4',
    damageType: 'fire',
  );
  test('Preparation copy preserves every spell field', () {
    final wizard = seedCharacters.first.copyWith(spells: [before]);
    final original = wizard.toJson();
    final copied = wizard
        .copyWith(spells: [before.withPrepared(false)])
        .toJson();
    final expected = (original['spells'] as List).single as Map;
    expected['prepared'] = false;
    expect((copied['spells'] as List).single, expected);
  });
  test(
    'Completed Short Rest grants one saved swap at Wizard five; Long Rest clears it',
    () {
      for (final level in [4, 5]) {
        final wizard = seedCharacters.first.copyWith(level: level);
        final state = CharacterState.fromCharacter(wizard);
        final short = RestPlan.forCharacter(
          character: wizard,
          currentState: state,
          type: RestType.shortRest,
        ).updatedState;
        expect(short.memorizeSpellAvailable, level == 5);
        expect(
          CharacterState.fromJson(short.toJson()).memorizeSpellAvailable,
          level == 5,
        );
        expect(
          RestPlan.forCharacter(
            character: wizard,
            currentState: short,
            type: RestType.longRest,
          ).updatedState.memorizeSpellAvailable,
          isFalse,
        );
      }
    },
  );
  testWidgets(
    'Memorize Spell swaps once atomically and preserves live casting state',
    (tester) async {
      var wizard = seedCharacters.first.copyWith(
        level: 5,
        spells: [
          before,
          const Spell(
            id: 'new',
            name: 'New Spell',
            level: 2,
            prepared: false,
            summary: 'New',
            castingAbility: Ability.intelligence,
          ),
          const Spell(
            id: 'cantrip',
            name: 'Cantrip',
            level: 0,
            prepared: true,
            summary: 'Cantrip',
          ),
          const Spell(
            id: 'foreign',
            name: 'Other Class',
            level: 1,
            prepared: false,
            summary: 'Other',
            castingAbility: Ability.wisdom,
          ),
          const Spell(
            id: 'whetstone:circle-spell:test',
            name: 'Circle Grant',
            level: 1,
            prepared: true,
            summary: 'Grant',
          ),
        ],
      );
      var session = CharacterSession(
        characterState: CharacterState.fromCharacter(wizard).copyWith(
          currentHp: 23,
          memorizeSpellAvailable: true,
          resourceValues: {'arcane_recovery': 0, 'level_1_slots': 1},
          concentrationSpellId: 'old',
          concentrationTurnsRemaining: 6,
          spellSummons: {'old': 'Companion'},
          pinnedActionKeys: {'spell:old'},
        ),
        inventory: [],
        archivedInventory: [],
      );
      Widget app() => MaterialApp(
        home: CharacterOverview(
          key: ValueKey(session.characterState.memorizeSpellAvailable),
          character: wizard,
          initialSession: session,
          onCharacterChanged: (v) => wizard = v,
          onSessionChanged: (v) => session = v,
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final button = find.text('Memorize Spell · After Short Rest');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Cantrip · Level 0'), findsNothing);
      expect(find.text('Circle Grant · Level 1'), findsNothing);
      await tester.tap(find.text('Old Spell · Level 1'));
      await tester.pumpAndSettle();
      expect(find.text('Other Class · Level 1'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(session.characterState.memorizeSpellAvailable, isTrue);
      expect(wizard.spells.first.prepared, isTrue);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Old Spell · Level 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Spell · Level 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(session.characterState.memorizeSpellAvailable, isTrue);
      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Old Spell · Level 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New Spell · Level 2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm eligible Wizard spell swap'));
      await tester.pumpAndSettle();
      expect(wizard.spells.first.prepared, isFalse);
      expect(wizard.spells[1].prepared, isTrue);
      expect(session.characterState.memorizeSpellAvailable, isFalse);
      expect(session.characterState.currentHp, 23);
      expect(session.characterState.concentrationSpellId, 'old');
      expect(session.characterState.concentrationTurnsRemaining, 6);
      expect(session.characterState.spellSummons, {'old': 'Companion'});
      expect(session.characterState.resourceValues['level_1_slots'], 1);
      expect(session.characterState.pinnedActionKeys, contains('spell:old'));
      wizard = Character.fromJson(wizard.toJson());
      session = CharacterSession.fromJson(session.toJson());
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final restored = find.text('Memorize Spell · After Short Rest');
      await tester.ensureVisible(restored);
      await tester.tap(restored);
      await tester.pumpAndSettle();
      expect(
        find.text('Memorize Spell · Replace prepared spell'),
        findsNothing,
      );
      expect(session.usedCombatActions, isEmpty);
    },
  );
}
