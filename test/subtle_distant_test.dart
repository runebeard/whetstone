import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_resource.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/metamagic.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'draconic_spell_grants_test.dart' as helpers;
import 'metamagic_test.dart' as base;
import 'support/sequence_dice_roller.dart';

Spell spellWith({
  String? components,
  String? range,
  int? attack,
  bool effect = false,
}) => Spell(
  id: 'test-spell',
  name: 'Test Spell',
  level: 1,
  prepared: true,
  concentration: true,
  castingTime: 'Action',
  range: range,
  components: components,
  rollModifier: attack,
  rollEffectOnCast: effect,
  damageFormula: attack != null || effect ? '1d6' : null,
  summary: 'A test spell.',
);

void main() {
  test(
    'Distant range supports feet and Touch without enlarging Self areas',
    () {
      for (final (range, result) in [
        ('Touch', '30 feet'),
        ('120 feet', '240 feet'),
        ('5 ft.', '10 feet'),
        (' 30 FT ', '60 feet'),
        ('Self (30-foot Cone)', null),
        ('Sight', null),
        ('1 foot', null),
        ('Unlimited', null),
        (null, null),
      ]) {
        expect(Metamagic.distantRange(range), result);
      }
    },
  );
  test(
    'Subtle preserves priced and consumed materials including plus-priced components',
    () {
      for (final components in [
        'V, S, M (a diamond worth 50+ GP)',
        'V, S, M (incense worth 250 GP, consumed)',
        'V, M (a herb, which the spell consumes)',
      ]) {
        final spell = spellWith(components: components);
        expect(spell.hasCostlyOrConsumedMaterial, isTrue);
        expect(Metamagic.subtleComponents(spell), startsWith('M ('));
        expect(Metamagic.subtleComponents(spell), isNot(contains('V,')));
      }
      for (final components in [
        'V, S',
        'V, S, M (a feather)',
        'V, S, M (a feather, which is not consumed)',
      ]) {
        expect(
          Metamagic.subtleComponents(spellWith(components: components)),
          'None',
        );
      }
      expect(
        Metamagic.subtleComponents(spellWith()),
        contains('Verify Material requirements'),
      );
    },
  );
  for (final option in [Metamagic.subtle, Metamagic.distant]) {
    for (final kind in ['utility', 'attack', 'damage']) {
      testWidgets(
        '${option.label} $kind preview and slot cancellation are safe; cast costs once',
        (tester) async {
          final spell = spellWith(
            components: 'V, S, M (a feather)',
            range: '60 feet',
            attack: kind == 'attack' ? 5 : null,
            effect: kind == 'damage',
          );
          var character = base.sorcerer().copyWith(
            spells: [spell],
            metamagicOptions: {option},
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
                diceRoller: SequenceDiceRoller([10, 4, 5]),
                onCharacterChanged: (value) => character = value,
                onSessionChanged: (value) => session = value,
              ),
            ),
          );
          await tester.pumpAndSettle();
          Future<void> preview() async {
            await helpers.tap(tester, find.text('Test Spell').first);
            await helpers.tap(tester, find.text(option.label));
            expect(
              find.textContaining(
                option == Metamagic.subtle
                    ? 'Components for this casting: None'
                    : 'Range for this casting: 120 feet',
              ),
              findsOneWidget,
            );
          }

          await preview();
          await helpers.tap(tester, find.text('Cancel'));
          expect(session.usedCombatActions, isEmpty);
          expect(
            session.characterState.resourceValues[sorceryPointsResourceId] ?? 7,
            7,
          );
          await preview();
          await helpers.tap(tester, find.text('Cast with Metamagic'));
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(session.usedCombatActions, isEmpty);
          expect(
            session.characterState.resourceValues[sorceryPointsResourceId] ?? 7,
            7,
          );
          expect(session.characterState.resourceValues[spellSlotId(1)], 4);
          await preview();
          await helpers.tap(tester, find.text('Cast with Metamagic'));
          await helpers.tap(tester, find.text('Level 1 · 4 remaining'));
          expect(session.usedCombatActions, {CombatActionCost.action});
          expect(
            session.characterState.resourceValues[sorceryPointsResourceId],
            6,
          );
          expect(session.characterState.resourceValues[spellSlotId(1)], 3);
          expect(session.characterState.concentrationSpellId, spell.id);
          expect(session.quickenedSpellUsedThisTurn, isFalse);
          final saved = Character.fromJson(character.toJson()).spells.single;
          expect(saved.range, '60 feet');
          expect(saved.components, 'V, S, M (a feather)');
          expect(
            session.timeline.any(
              (event) => event.title == '${option.label} · Test Spell',
            ),
            isTrue,
          );
          if (kind == 'attack') {
            await helpers.tap(tester, find.text('Test Spell').first);
            await helpers.tap(tester, find.text('Roll Damage'));
            expect(
              session.characterState.resourceValues[sorceryPointsResourceId],
              6,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'Distant paid Metamagic can use a tracked free cast without spending a slot',
    (tester) async {
      final spell = spellWith(components: 'V, S', range: 'Touch');
      var character = base.sorcerer().copyWith(
        spells: [spell],
        metamagicOptions: {Metamagic.distant},
        initiallyPinnedActionKeys: {spell.actionKey},
        resources: [
          ...fullCasterSlots(7),
          const CharacterResource(
            id: 'whetstone:free-cast:test-spell',
            name: 'Free cast',
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
      await helpers.tap(tester, find.text('Test Spell').first);
      await helpers.tap(tester, find.text('Distant Spell'));
      expect(
        find.textContaining('Range for this casting: 30 feet'),
        findsOneWidget,
      );
      await helpers.tap(tester, find.text('Use Free Cast'));
      expect(
        session.characterState.resourceValues['whetstone:free-cast:test-spell'],
        0,
      );
      expect(session.characterState.resourceValues[sorceryPointsResourceId], 6);
      expect(session.characterState.resourceValues[spellSlotId(1)], 4);
      expect(session.usedCombatActions, {CombatActionCost.action});
      expect(tester.takeException(), isNull);
    },
  );
}
