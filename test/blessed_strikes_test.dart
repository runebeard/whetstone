import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/check_roll.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/screens/character_advancement.dart';
import 'package:whetstone/screens/character_editor.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'life_domain_spells_test.dart' as fixtures;
import 'draconic_spell_grants_test.dart' as helpers;
import 'support/sequence_dice_roller.dart';

const flame = Spell(
  id: 'cleric-flame',
  name: 'Sacred Flame',
  level: 0,
  prepared: true,
  castingAbility: Ability.wisdom,
  castingTime: 'Action',
  damageFormula: '1d8',
  damageType: 'Radiant',
  scaleCantripDamage: true,
  range: '60 feet',
  summary: 'Test cantrip',
);

Character cleric(int level, BlessedStrikes choice) => fixtures
    .life(level)
    .copyWith(
      blessedStrikes: choice,
      divineOrder: DivineOrder.protector,
      abilityScores: {Ability.wisdom: 16, Ability.constitution: 14},
      clericCantripIds: {flame.id},
      spells: [flame],
    );

void main() {
  testWidgets('Cleric cantrip marking survives reload and can be removed', (
    tester,
  ) async {
    var hero = cleric(
      7,
      BlessedStrikes.potentSpellcasting,
    ).copyWith(clericCantripIds: {});
    var session = CharacterSession(
      characterState: CharacterState.fromCharacter(hero),
      inventory: [],
      archivedInventory: [],
    );
    Widget app(int generation) => MaterialApp(
      home: CharacterOverview(
        key: ValueKey(generation),
        character: hero,
        initialSession: session,
        onCharacterChanged: (v) => hero = v,
        onSessionChanged: (v) => session = v,
      ),
    );
    await tester.pumpWidget(app(0));
    await tester.pumpAndSettle();
    await helpers.tap(tester, find.text('Spellbook'));
    await tester.longPress(find.text(flame.name));
    await tester.pumpAndSettle();
    await helpers.tap(tester, find.text('Mark as Cleric Cantrip'));
    expect(hero.clericCantripIds, {flame.id});
    expect(DiceExpression.tryParse(hero.damageFormulaFor(flame)!)!.modifier, 3);
    hero = Character.fromJson(hero.toJson());
    session = CharacterSession.fromJson(session.toJson());
    await tester.pumpWidget(app(1));
    await tester.pumpAndSettle();
    await helpers.tap(tester, find.text('Spellbook'));
    await tester.longPress(find.text(flame.name));
    await tester.pumpAndSettle();
    await helpers.tap(tester, find.text('Unmark as Cleric Cantrip'));
    expect(hero.clericCantripIds, isEmpty);
    expect(DiceExpression.tryParse(hero.damageFormulaFor(flame)!)!.modifier, 0);
    await helpers.tap(tester, find.text('Profile'));
    expect(find.text('Blessed Strikes · Potent Spellcasting'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final choice in BlessedStrikes.values) {
    test('Blessed Strikes $choice and Cleric ownership round-trip', () {
      final original = cleric(7, choice);
      final restored = Character.fromJson(original.toJson());
      expect(restored.blessedStrikes, choice);
      expect(restored.clericCantripIds, {flame.id});
      expect(restored.copyWith(name: 'Changed').blessedStrikes, choice);
      expect(
        restored.copyWith(clearBlessedStrikes: true).blessedStrikes,
        isNull,
      );
      final legacy = {...original.toJson()}
        ..remove('blessedStrikes')
        ..remove('clericCantripIds');
      expect(Character.fromJson(legacy).blessedStrikes, isNull);
      expect(Character.fromJson(legacy).clericCantripIds, isEmpty);
    });
  }
  for (final level in [6, 7, 14]) {
    test('Cleric Potent Spellcasting eligibility at level $level', () {
      final hero = cleric(level, BlessedStrikes.potentSpellcasting);
      final dice = DiceExpression.tryParse(hero.damageFormulaFor(flame)!)!;
      expect(dice.modifier, level < 7 ? 0 : 3);
      expect(dice.diceCount, level >= 11 ? 3 : 2);
      expect(
        hero
            .copyWith(clericCantripIds: {})
            .benefitsFromClericPotentSpellcasting(flame),
        isFalse,
      );
      expect(
        hero
            .copyWith(blessedStrikes: BlessedStrikes.divineStrike)
            .damageFormulaFor(flame),
        '${dice.diceCount}d8',
      );
      expect(hero.rangeForSpell(flame), '60 feet');
    });
  }
  test(
    'Multiclass Potent Spellcasting uses Cleric levels and avoids duplicate Wisdom',
    () {
      final hero = cleric(20, BlessedStrikes.potentSpellcasting).copyWith(
        additionalClassLevels: {'Druid': 14},
        elementalFury: ElementalFury.potentSpellcasting,
      );
      expect(hero.benefitsFromClericPotentSpellcasting(flame), isFalse);
      final both = hero.copyWith(
        additionalClassLevels: {'Druid': 7},
        druidCantripIds: {flame.id},
      );
      expect(
        DiceExpression.tryParse(both.damageFormulaFor(flame)!)!.modifier,
        3,
      );
      expect(both.rangeForSpell(flame), '60 feet');
      final negative = both.copyWith(abilityScores: {Ability.wisdom: 8});
      expect(
        DiceExpression.tryParse(negative.damageFormulaFor(flame)!)!.modifier,
        -1,
      );
    },
  );

  for (final (level, critical, type, count) in [
    (7, false, 'Radiant', 1),
    (14, false, 'Necrotic', 2),
    (14, true, 'Radiant', 4),
  ]) {
    testWidgets(
      'Divine Strike level $level critical=$critical spends one turn use',
      (tester) async {
        final hero = cleric(level, BlessedStrikes.divineStrike);
        var session = CharacterSession(
          characterState: CharacterState.fromCharacter(
            hero,
          ).copyWith(currentHp: 13),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
          usedCombatActions: CombatActionCost.values.toSet(),
        );
        final dice = SequenceDiceRoller(List.filled(count * 2, 3));
        Widget app(int generation) => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(generation),
            character: hero,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (v) => session = v,
            diceRoller: dice,
          ),
        );
        await tester.pumpWidget(app(0));
        await tester.pumpAndSettle();
        await helpers.tap(tester, find.byTooltip('Divine Strike'));
        await helpers.tap(tester, find.text('Cancel'));
        expect(session.divineStrikeUsedThisTurn, isFalse);
        await helpers.tap(tester, find.byTooltip('Divine Strike'));
        if (critical) await helpers.tap(tester, find.text('Critical hit'));
        await helpers.tap(tester, find.text(type));
        expect(session.divineStrikeUsedThisTurn, isTrue);
        expect(session.primalStrikeUsedThisTurn, isFalse);
        expect(session.usedCombatActions, CombatActionCost.values.toSet());
        expect(session.characterState.currentHp, 13);
        expect(session.timeline.first.title, 'Divine Strike: ${3 * count}');
        expect(session.timeline.first.detail, contains('$type damage'));
        expect(dice.index, count);
        session = CharacterSession.fromJson(session.toJson());
        await tester.pumpWidget(app(1));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == 'Divine Strike',
                ),
              )
              .onPressed,
          isNull,
        );
        await helpers.tap(tester, find.text('Next Turn'));
        expect(session.divineStrikeUsedThisTurn, isFalse);
        await helpers.tap(tester, find.byTooltip('Divine Strike'));
        await helpers.tap(tester, find.text(type));
        expect(dice.index, 2 * count - (critical ? count ~/ 2 : 0));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final gate in ['low', 'potent', 'incapacitated', 'outside']) {
    testWidgets('Divine Strike cannot bypass $gate gate', (tester) async {
      final hero = cleric(
        gate == 'low' ? 6 : 7,
        gate == 'potent'
            ? BlessedStrikes.potentSpellcasting
            : BlessedStrikes.divineStrike,
      );
      final session = CharacterSession(
        characterState: CharacterState.fromCharacter(hero).copyWith(
          activeConditions: gate == 'incapacitated' ? {'Incapacitated'} : {},
        ),
        inventory: [],
        archivedInventory: [],
        isInCombat: gate != 'outside',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: CharacterOverview(
            character: hero,
            initialSession: session,
            onCharacterChanged: (_) {},
            onSessionChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Divine Strike',
      );
      if (gate == 'low' || gate == 'potent') {
        expect(button, findsNothing);
      } else {
        expect(tester.widget<IconButton>(button).onPressed, isNull);
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final choice in BlessedStrikes.values) {
    testWidgets(
      'Advancement and detailed edits retain $choice and marked cantrips',
      (tester) async {
        var hero = cleric(6, choice).copyWith(
          clearBlessedStrikes: true,
          currentHp: 13,
          features: [],
          initialInventory: [],
        );
        Future<void> open(Widget screen, String label) async {
          await tester.pumpWidget(
            MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: FilledButton(
                    onPressed: () async {
                      final result = await Navigator.push<Character>(
                        context,
                        MaterialPageRoute(builder: (_) => screen),
                      );
                      if (result != null) hero = result;
                    },
                    child: Text(label),
                  ),
                ),
              ),
            ),
          );
          await helpers.tap(tester, find.text(label));
        }

        await open(CharacterAdvancement(character: hero), 'Advance');
        await tester.enterText(
          find.byKey(const ValueKey('advancement-level')),
          '7',
        );
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        final picker = find.byWidgetPredicate(
          (w) => w is DropdownButtonFormField<BlessedStrikes>,
        );
        await tester.ensureVisible(picker);
        final form = tester.state<FormFieldState<BlessedStrikes>>(picker);
        expect(form.validate(), isFalse);
        await helpers.tap(tester, picker);
        await helpers.tap(tester, find.text(choice.label).last);
        await helpers.tap(
          tester,
          find.byKey(const ValueKey('save-advancement')),
        );
        expect(hero.blessedStrikes, choice);
        expect(hero.currentHp, 13);
        expect(hero.clericCantripIds, {flame.id});
        await open(CharacterEditor(character: hero), 'Edit');
        for (var i = 0; i < 8; i++) {
          tester.testTextInput.hide();
          await helpers.tap(
            tester,
            find.byKey(ValueKey('creator-continue-$i')),
          );
        }
        tester.testTextInput.hide();
        await helpers.tap(tester, find.byKey(const ValueKey('creator-save')));
        expect(find.byType(CharacterEditor), findsNothing);
        expect(hero.blessedStrikes, choice);
        expect(hero.clericCantripIds, {flame.id});
        expect(hero.currentHp, 13);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
