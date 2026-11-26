import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/class_spells.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/character_resource.dart';
import 'package:whetstone/models/metamagic.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'draconic_spell_grants_test.dart' as helpers;
import 'metamagic_test.dart' as base;
import 'support/sequence_dice_roller.dart';

const burst = Spell(
  id: 'save-burst',
  name: 'Save Burst',
  level: 1,
  prepared: true,
  castingTime: 'Action',
  savingThrowAbility: Ability.dexterity,
  halfDamageOnSave: true,
  rollEffectOnCast: true,
  damageFormula: '2d6',
  damageType: 'Fire',
  summary: 'A burst.',
);

Future<void> targets(WidgetTester tester, String names) async {
  await tester.enterText(
    find.byKey(const ValueKey('metamagic-save-targets')),
    names,
  );
  FocusManager.instance.primaryFocus?.unfocus();
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  await helpers.tap(tester, find.text('Confirm Targets'));
}

void main() {
  for (final option in [Metamagic.careful, Metamagic.heightened]) {
    testWidgets(
      '${option.label} free control cast keeps slot and original DC',
      (tester) async {
        var character = withDraconicSpellGrants(
          helpers.draconic(5).copyWith(metamagicOptions: {option}),
        );
        final spell = character.spells.singleWhere((s) => s.name == 'Fear');
        character = character.copyWith(
          initiallyPinnedActionKeys: {spell.actionKey},
          resources: [
            ...character.resources,
            CharacterResource(
              id: 'whetstone:free-cast:${spell.id}',
              name: 'Free Fear',
              maximum: 1,
              initialValue: 1,
              rechargePeriod: RechargePeriod.longRest,
            ),
          ],
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
        await helpers.tap(tester, find.text('Fear').first);
        await helpers.tap(tester, find.text(option.label));
        await targets(tester, 'Target');
        await helpers.tap(tester, find.text('Use Free Cast'));
        expect(
          find.textContaining(
            'DC ${character.spellSaveDc(spell)} Wisdom saving throw',
          ),
          findsOneWidget,
        );
        expect(
          find.textContaining(
            option == Metamagic.careful
                ? 'Target automatically succeed'
                : 'Target has Disadvantage',
          ),
          findsOneWidget,
        );
        await helpers.tap(
          tester,
          find.text(
            option == Metamagic.careful
                ? 'Protected target · Automatic save'
                : 'Failed save',
          ),
        );
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId],
          5 - option.pointCost,
        );
        expect(session.characterState.resourceValues[spellSlotId(3)], 2);
        expect(
          session
              .characterState
              .resourceValues['whetstone:free-cast:${spell.id}'],
          0,
        );
        expect(session.characterState.concentrationSpellId, spell.id);
        expect(session.characterState.spellSaveEffects[spell.id]!.targets, [
          'Target',
        ]);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Careful permits one protected creature with negative Charisma', (
    tester,
  ) async {
    final character = base.sorcerer().copyWith(
      spells: [burst],
      metamagicOptions: {Metamagic.careful},
      abilityScores: {Ability.charisma: 8},
      initiallyPinnedActionKeys: {burst.actionKey},
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: character,
          initialSession: CharacterSession.fromCharacter(character),
          onCharacterChanged: (_) {},
          onSessionChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await helpers.tap(tester, find.text('Spellbook'));
    await helpers.tap(tester, find.text(burst.name));
    await helpers.tap(tester, find.text('Careful Spell'));
    await tester.enterText(find.byType(TextField), 'One, Two');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirm Targets'),
          )
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'One');
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Confirm Targets'),
          )
          .onPressed,
      isNotNull,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('Heightened requires two points before target selection', (
    tester,
  ) async {
    final character = base.sorcerer().copyWith(
      spells: [burst],
      metamagicOptions: {Metamagic.heightened},
      initiallyPinnedActionKeys: {burst.actionKey},
    );
    final session = CharacterSession(
      characterState: CharacterSession.fromCharacter(
        character,
      ).characterState.copyWith(resourceValues: {sorceryPointsResourceId: 1}),
      inventory: [],
      archivedInventory: [],
      isInCombat: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: CharacterOverview(
          character: character,
          initialSession: session,
          onCharacterChanged: (_) {},
          onSessionChanged: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await helpers.tap(tester, find.text(burst.name).first);
    expect(find.text('Heightened Spell'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  test(
    'Saved save effects validate options and targets, roundtrip and remove orphaned links',
    () {
      final character = base.sorcerer().copyWith(spells: [burst]);
      final json = CharacterState.fromCharacter(character).toJson();
      json['spellSaveEffects'] = {
        burst.id: {
          'option': 'careful',
          'targets': [' Ally ', 'Ally', 'Friend'],
        },
        'invalid': {
          'option': 'quickened',
          'targets': ['Enemy'],
        },
        'too-many': {
          'option': 'heightened',
          'targets': ['A', 'B'],
        },
        'orphan': {
          'option': 'heightened',
          'targets': ['Enemy'],
        },
      };
      final state = CharacterState.fromJson(json);
      expect(state.spellSaveEffects.keys.toSet(), {burst.id, 'orphan'});
      expect(state.spellSaveEffects[burst.id]!.targets, ['Ally', 'Friend']);
      final normalized = state.normalizeSpellDamageTypes(character);
      expect(normalized.spellSaveEffects.keys, [burst.id]);
      expect(
        CharacterState.fromJson(
          normalized.toJson(),
        ).spellSaveEffects[burst.id]!.option,
        Metamagic.careful,
      );
      expect(
        normalized
            .normalizeSpellDamageTypes(character.copyWith(spells: []))
            .spellSaveEffects,
        isEmpty,
      );
    },
  );
  for (final option in [Metamagic.careful, Metamagic.heightened]) {
    testWidgets(
      '${option.label} validates targets, cancels safely, persists and clears on ordinary cast',
      (tester) async {
        var character = base.sorcerer().copyWith(
          spells: [burst],
          metamagicOptions: {option},
          abilityScores: {Ability.charisma: 14},
          initiallyPinnedActionKeys: {burst.actionKey},
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
            diceRoller: SequenceDiceRoller([4, 6, 3, 5, 4, 4]),
            onCharacterChanged: (value) => character = value,
            onSessionChanged: (value) => session = value,
          ),
        );
        await tester.pumpWidget(app(0));
        await tester.pumpAndSettle();
        Future<void> begin() async {
          await helpers.tap(tester, find.text(burst.name).first);
          await helpers.tap(tester, find.text(option.label));
        }

        await begin();
        await tester.enterText(
          find.byType(TextField),
          option == Metamagic.careful ? 'A, B, C' : 'A, B',
        );
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Confirm Targets'),
              )
              .onPressed,
          isNull,
        );
        FocusManager.instance.primaryFocus?.unfocus();
        tester.testTextInput.hide();
        await helpers.tap(tester, find.text('Cancel'));
        expect(session.characterState.spellSaveEffects, isEmpty);
        final names = option == Metamagic.careful ? 'Ally, Friend' : 'Enemy';
        await begin();
        await targets(tester, names);
        await helpers.tap(tester, find.text('Cancel'));
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId] ?? 7,
          7,
        );
        await begin();
        await targets(tester, names);
        await helpers.tap(tester, find.text('Cast with Metamagic'));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(session.characterState.spellSaveEffects, isEmpty);
        await begin();
        await targets(tester, names);
        await helpers.tap(tester, find.text('Cast with Metamagic'));
        await helpers.tap(tester, find.text('Level 1 · 4 remaining'));
        expect(
          find.textContaining(
            option == Metamagic.careful
                ? 'Ally, Friend automatically succeed'
                : 'Enemy has Disadvantage',
          ),
          findsOneWidget,
        );
        await helpers.tap(
          tester,
          find.text(
            option == Metamagic.careful
                ? 'Protected target · Automatic save'
                : 'Failed save',
          ),
        );
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId],
          7 - option.pointCost,
        );
        expect(session.characterState.resourceValues[spellSlotId(1)], 3);
        expect(session.usedCombatActions, {CombatActionCost.action});
        expect(
          session.characterState.spellSaveEffects[burst.id]!.targets,
          names.split(', '),
        );
        if (option == Metamagic.careful) {
          expect(session.timeline.first.title, 'Save Burst Damage: 0');
        }
        session = CharacterSession.fromJson(session.toJson());
        await tester.pumpWidget(app(1));
        await tester.pumpAndSettle();
        await helpers.tap(tester, find.text(burst.name).first);
        await helpers.tap(tester, find.text('Roll Damage'));
        expect(
          find.textContaining(
            option == Metamagic.careful
                ? 'Ally, Friend automatically succeed'
                : 'Enemy has Disadvantage',
          ),
          findsOneWidget,
        );
        await helpers.tap(tester, find.text('Successful save'));
        expect(session.timeline.first.title, 'Save Burst Damage: 5');
        await helpers.tap(tester, find.text('Next Turn'));
        await helpers.tap(tester, find.text(burst.name).first);
        await helpers.tap(tester, find.text('Cast').last);
        await helpers.tap(tester, find.text('Level 1 · 3 remaining'));
        expect(find.textContaining('Enemy has Disadvantage'), findsNothing);
        expect(find.text('Protected target · Automatic save'), findsNothing);
        await helpers.tap(tester, find.text('Failed save'));
        expect(session.characterState.spellSaveEffects, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
