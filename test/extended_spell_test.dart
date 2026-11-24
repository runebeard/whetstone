import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/class_spells.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/metamagic.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'draconic_spell_grants_test.dart' as helpers;
import 'metamagic_test.dart' as base;
import 'support/sequence_dice_roller.dart';

const ward = Spell(
  id: 'extended-ward',
  name: 'Extended Ward',
  level: 1,
  prepared: true,
  concentration: true,
  castingTime: 'Action',
  duration: 'Concentration, up to 1 minute',
  summary: 'A protective spell.',
);

void main() {
  test('Extended duration requires at least one minute and caps at a day', () {
    for (final (duration, turns) in [
      ('1 minute', 20),
      ('Concentration, up to 1 hour', 1200),
      ('8 hours', 9600),
      ('20 hours', 14400),
      ('24 hours', 14400),
      ('1 day', 14400),
      ('2 days', null),
      ('Instantaneous', null),
      ('1 round', null),
      ('Until dispelled', null),
      (null, null),
    ]) {
      expect(Metamagic.extendedTurns(duration), turns);
    }
    for (final name in ['Hex', "Hunter's Mark"]) {
      final spell = Spell(
        id: name,
        name: name,
        level: 1,
        prepared: true,
        concentration: true,
        duration: '1 hour',
        summary: 'A mark.',
      );
      expect(Metamagic.extendedSpellTurns(spell, slotLevel: 1), 1200);
      expect(
        Metamagic.extendedSpellTurns(spell, slotLevel: 2),
        name == 'Hex' ? 4800 : 1200,
      );
      expect(Metamagic.extendedSpellTurns(spell, slotLevel: 3), 9600);
      expect(Metamagic.extendedSpellTurns(spell, slotLevel: 5), 14400);
    }
  });
  test('Extended concentration persists only with its current spell', () {
    final state = CharacterState.fromCharacter(base.sorcerer()).copyWith(
      concentrationSpellId: ward.id,
      extendedConcentration: true,
      concentrationTurnsRemaining: 2,
    );
    final saved = CharacterState.fromJson(state.toJson());
    expect(saved.extendedConcentration, isTrue);
    expect(saved.copyWith(currentHp: 10).extendedConcentration, isTrue);
    expect(
      saved.copyWith(concentrationTarget: 'New target').extendedConcentration,
      isTrue,
    );
    expect(
      saved.copyWith(concentrationSpellId: 'different').extendedConcentration,
      isFalse,
    );
    expect(
      saved.copyWith(clearConcentration: true).extendedConcentration,
      isFalse,
    );
    expect(
      saved
          .advanceConcentrationTurn()
          .advanceConcentrationTurn()
          .extendedConcentration,
      isFalse,
    );
    final json = saved.toJson()..remove('extendedConcentration');
    expect(CharacterState.fromJson(json).extendedConcentration, isFalse);
  });
  for (final disadvantage in [false, true]) {
    testWidgets(
      'Extended concentration reload applies Advantage, selected Disadvantage=$disadvantage',
      (tester) async {
        var character = base.sorcerer().copyWith(
          spells: [ward],
          metamagicOptions: {Metamagic.extended},
          initiallyPinnedActionKeys: {ward.actionKey},
        );
        var session = CharacterSession(
          characterState: CharacterSession.fromCharacter(
            character,
          ).characterState,
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        Widget app(int generation) => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(generation),
            character: character,
            initialSession: session,
            diceRoller: SequenceDiceRoller([2, 18]),
            onCharacterChanged: (value) => character = value,
            onSessionChanged: (value) => session = value,
          ),
        );
        await tester.pumpWidget(app(0));
        await tester.pumpAndSettle();
        await helpers.tap(tester, find.text(ward.name).first);
        await helpers.tap(tester, find.text('Extended Spell'));
        expect(
          find.textContaining('Duration for this casting: 2 minutes'),
          findsOneWidget,
        );
        await helpers.tap(tester, find.text('Cast with Metamagic'));
        await helpers.tap(tester, find.text('Level 1 · 4 remaining'));
        expect(session.characterState.extendedConcentration, isTrue);
        expect(session.characterState.concentrationTurnsRemaining, 20);
        session = CharacterSession.fromJson(session.toJson());
        await tester.pumpWidget(app(1));
        await tester.pumpAndSettle();
        if (disadvantage) {
          await helpers.tap(tester, find.byTooltip('Next d20 roll: Normal'));
          await helpers.tap(tester, find.text('Disadvantage'));
        }
        await helpers.tap(tester, find.text('34 / 42'));
        await tester.enterText(find.byType(TextField), '2');
        await helpers.tap(tester, find.textContaining('Damage'));
        await helpers.tap(tester, find.text('Roll Save'));
        expect(
          find.textContaining(disadvantage ? 'd20 2' : 'Advantage: 2, 18'),
          findsOneWidget,
        );
        expect(
          session.characterState.concentrationSpellId,
          disadvantage ? null : ward.id,
        );
        expect(session.characterState.extendedConcentration, !disadvantage);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final withoutConcentration in [true, false]) {
    testWidgets(
      'Extended Dragon Companion no concentration=$withoutConcentration preserves correct duration',
      (tester) async {
        var character = withDraconicSpellGrants(
          helpers.draconic(18).copyWith(metamagicOptions: {Metamagic.extended}),
        );
        final spell = character.spells.singleWhere(
          (s) => s.name == 'Summon Dragon',
        );
        character = character.copyWith(
          initiallyPinnedActionKeys: {spell.actionKey},
        );
        var session = CharacterSession(
          characterState: CharacterSession.fromCharacter(
            character,
          ).characterState,
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: character,
              initialSession: session,
              onCharacterChanged: (value) => character = value,
              onSessionChanged: (value) => session = value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await helpers.tap(tester, find.text('Summon Dragon').first);
        await helpers.tap(tester, find.text('Extended Spell'));
        await helpers.tap(tester, find.text('Use Free Cast'));
        await helpers.tap(
          tester,
          find.text(
            withoutConcentration
                ? 'Dragon Companion · No concentration · 2 minutes'
                : 'Concentrate · 2 hours',
          ),
        );
        expect(
          session.characterState.extendedConcentration,
          !withoutConcentration,
        );
        expect(
          session.characterState.concentrationTurnsRemaining,
          withoutConcentration ? null : 1200,
        );
        expect(
          session.characterState.conditionTurns[dragonCompanionCondition],
          withoutConcentration ? 20 : null,
        );
        expect(session.characterState.resourceValues[spellSlotId(5)], 3);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
