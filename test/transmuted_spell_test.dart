import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_resource.dart';
import 'package:whetstone/models/character_state.dart';
import 'package:whetstone/models/metamagic.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'draconic_spell_grants_test.dart' as helpers;
import 'metamagic_test.dart' as base;
import 'support/sequence_dice_roller.dart';

Spell makeSpell({bool attack = false}) => Spell(
  id: 'transmute-test',
  name: 'Element Test',
  level: 1,
  prepared: true,
  castingTime: 'Action',
  damageType: 'Fire',
  rollEffectOnCast: !attack,
  rollModifier: attack ? 5 : null,
  damageFormula: '1d6',
  summary: 'A fire spell.',
);

void main() {
  testWidgets(
    'Transmuted free cast preserves its slot and critical damage type',
    (tester) async {
      final spell = makeSpell(attack: true);
      var character = base.sorcerer().copyWith(
        spells: [spell],
        metamagicOptions: {Metamagic.transmuted},
        initiallyPinnedActionKeys: {spell.actionKey},
        resources: [
          ...fullCasterSlots(7),
          const CharacterResource(
            id: 'whetstone:free-cast:transmute-test',
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
            diceRoller: SequenceDiceRoller([20, 2, 3]),
            onCharacterChanged: (value) => character = value,
            onSessionChanged: (value) => session = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text(spell.name).first);
      await helpers.tap(tester, find.text('Transmuted Spell'));
      await helpers.tap(tester, find.text('Thunder'));
      await helpers.tap(tester, find.text('Use Free Cast'));
      await helpers.tap(tester, find.text(spell.name).first);
      await helpers.tap(tester, find.text('Roll Damage'));
      expect(session.timeline.first.title, 'Element Test Critical Damage: 5');
      expect(find.text('Thunder damage'), findsOneWidget);
      expect(session.characterState.resourceValues[sorceryPointsResourceId], 6);
      expect(session.characterState.resourceValues[spellSlotId(1)], 4);
      expect(
        session
            .characterState
            .resourceValues['whetstone:free-cast:transmute-test'],
        0,
      );
      expect(session.usedCombatActions, {CombatActionCost.action});
      expect(tester.takeException(), isNull);
    },
  );
  for (final type in ['Force', 'Healing', null]) {
    testWidgets('Transmuted excludes unsupported damage type $type', (
      tester,
    ) async {
      final spell = Spell(
        id: 'unsupported',
        name: 'Unsupported Spell',
        level: 0,
        prepared: true,
        castingTime: 'Action',
        damageType: type,
        summary: 'A spell.',
      );
      final character = base.sorcerer().copyWith(
        spells: [spell],
        metamagicOptions: {Metamagic.transmuted},
        initiallyPinnedActionKeys: {spell.actionKey},
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
      await helpers.tap(tester, find.text(spell.name));
      expect(find.text('Transmuted Spell'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  test(
    'Transmuted JSON accepts only elemental types and removes orphaned spell links',
    () {
      final spell = makeSpell();
      final character = base.sorcerer().copyWith(spells: [spell]);
      final json = CharacterState.fromCharacter(character).toJson();
      json['spellDamageTypes'] = {
        spell.id: ' cold ',
        'orphan': 'Fire',
        'invalid': 'Force',
        'bad': 1,
      };
      final state = CharacterState.fromJson(json);
      expect(state.spellDamageTypes, {spell.id: 'Cold', 'orphan': 'Fire'});
      expect(state.normalizeSpellDamageTypes(character).spellDamageTypes, {
        spell.id: 'Cold',
      });
      expect(
        state
            .normalizeSpellDamageTypes(character.copyWith(spells: []))
            .spellDamageTypes,
        isEmpty,
      );
      json.remove('spellDamageTypes');
      expect(CharacterState.fromJson(json).spellDamageTypes, isEmpty);
      expect(Metamagic.transmutedType('thunder'), 'Thunder');
      expect(Metamagic.transmutedType('Necrotic'), isNull);
    },
  );
  for (final attack in [true, false]) {
    testWidgets(
      'Transmuted attack=$attack persists into damage, reload and normal recast',
      (tester) async {
        final spell = makeSpell(attack: attack);
        var character = base.sorcerer().copyWith(
          spells: [spell],
          metamagicOptions: {Metamagic.transmuted},
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
        Widget app(int generation) => MaterialApp(
          home: CharacterOverview(
            key: ValueKey(generation),
            character: character,
            initialSession: session,
            diceRoller: SequenceDiceRoller([4, 4, 5, 6]),
            onCharacterChanged: (value) => character = value,
            onSessionChanged: (value) => session = value,
          ),
        );
        await tester.pumpWidget(app(0));
        await tester.pumpAndSettle();
        Future<void> begin() async {
          await helpers.tap(tester, find.text(spell.name).first);
          await helpers.tap(tester, find.text('Transmuted Spell'));
        }

        await begin();
        expect(find.text('Fire'), findsNothing);
        await helpers.tap(tester, find.text('Cancel'));
        expect(session.characterState.spellDamageTypes, isEmpty);
        await begin();
        await helpers.tap(tester, find.text('Cold'));
        await helpers.tap(tester, find.text('Cancel'));
        expect(session.characterState.spellDamageTypes, isEmpty);
        await begin();
        await helpers.tap(tester, find.text('Cold'));
        await helpers.tap(tester, find.text('Cast with Metamagic'));
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(session.characterState.spellDamageTypes, isEmpty);
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId] ?? 7,
          7,
        );
        await begin();
        await helpers.tap(tester, find.text('Cold'));
        await helpers.tap(tester, find.text('Cast with Metamagic'));
        await helpers.tap(tester, find.text('Level 1 · 4 remaining'));
        expect(session.characterState.spellDamageTypes, {spell.id: 'Cold'});
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId],
          6,
        );
        expect(session.characterState.resourceValues[spellSlotId(1)], 3);
        if (attack) {
          await helpers.tap(tester, find.text(spell.name).first);
          await helpers.tap(tester, find.text('Roll Damage'));
        }
        expect(find.text('Cold damage'), findsOneWidget);
        character = Character.fromJson(character.toJson());
        session = CharacterSession.fromJson(session.toJson());
        expect(character.spells.single.damageType, 'Fire');
        await tester.pumpWidget(app(1));
        await tester.pumpAndSettle();
        await helpers.tap(tester, find.text(spell.name).first);
        await helpers.tap(tester, find.text('Roll Damage'));
        expect(find.text('Cold damage'), findsOneWidget);
        await helpers.tap(tester, find.text('Next Turn'));
        await helpers.tap(tester, find.text(spell.name).first);
        await helpers.tap(tester, find.text('Cast').last);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(session.characterState.spellDamageTypes, {spell.id: 'Cold'});
        await helpers.tap(tester, find.text(spell.name).first);
        await helpers.tap(tester, find.text('Cast').last);
        await helpers.tap(tester, find.text('Level 1 · 3 remaining'));
        expect(session.characterState.spellDamageTypes, isEmpty);
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId],
          6,
        );
        if (attack) {
          await helpers.tap(tester, find.text(spell.name).first);
          await helpers.tap(tester, find.text('Roll Damage'));
        }
        expect(find.text('Fire damage'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final transmuteToAffinity in [true, false]) {
    testWidgets(
      'Elemental Affinity uses the transmuted type matching=$transmuteToAffinity',
      (tester) async {
        final spell = makeSpell();
        var character = base.sorcerer().copyWith(
          spells: [spell],
          metamagicOptions: {Metamagic.transmuted},
          subclasses: {'Sorcerer': 'Draconic Sorcery'},
          elementalAffinity: transmuteToAffinity
              ? DraconicAffinity.cold
              : DraconicAffinity.fire,
          abilityScores: {Ability.charisma: 16},
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
              diceRoller: SequenceDiceRoller([4]),
              onCharacterChanged: (value) => character = value,
              onSessionChanged: (value) => session = value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await helpers.tap(tester, find.text(spell.name).first);
        await helpers.tap(tester, find.text('Transmuted Spell'));
        await helpers.tap(tester, find.text('Cold'));
        await helpers.tap(tester, find.text('Cast with Metamagic'));
        await helpers.tap(tester, find.text('Level 1 · 4 remaining'));
        if (transmuteToAffinity) {
          await helpers.tap(tester, find.text('Apply Charisma bonus'));
        } else {
          expect(find.text('Apply Charisma bonus'), findsNothing);
        }
        expect(
          session.timeline.first.title,
          'Element Test Damage: ${transmuteToAffinity ? 7 : 4}',
        );
        expect(session.characterState.spellDamageTypes[spell.id], 'Cold');
        expect(tester.takeException(), isNull);
      },
    );
  }
}
