import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/sample_characters.dart';
import 'package:whetstone/models/built_in_class.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/character_resource.dart';
import 'package:whetstone/models/metamagic.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/models/spell_slots.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'draconic_spell_grants_test.dart' as helpers;
import 'support/sequence_dice_roller.dart';

const glow = Spell(
  id: 'glow',
  name: 'Glow',
  level: 0,
  prepared: true,
  castingTime: 'Action',
  summary: 'A utility cantrip.',
);
const ward = Spell(
  id: 'ward',
  name: 'Ward',
  level: 1,
  prepared: true,
  castingTime: 'Action',
  concentration: true,
  summary: 'A protective spell.',
);
const ray = Spell(
  id: 'ray',
  name: 'Ray',
  level: 1,
  prepared: true,
  castingTime: 'Action',
  rollModifier: 5,
  damageFormula: '1d6',
  summary: 'A spell attack.',
);
const burst = Spell(
  id: 'burst',
  name: 'Burst',
  level: 1,
  prepared: true,
  castingTime: 'Action',
  rollEffectOnCast: true,
  damageFormula: '1d6',
  summary: 'An effect roll.',
);

Character sorcerer({int level = 7}) => seedCharacters.first.copyWith(
  characterClass: 'Sorcerer',
  level: level,
  subclasses: {},
  metamagicOptions: {Metamagic.quickened, Metamagic.subtle},
  resources: fullCasterSlots(level),
  spells: [glow, ward, ray, burst],
  initiallyPinnedActionKeys: {
    glow.actionKey,
    ward.actionKey,
    ray.actionKey,
    burst.actionKey,
  },
);

void main() {
  for (final (level, points, usedBonus, incapacitated, visible) in [
    (1, 2, false, false, false),
    (7, 1, false, false, false),
    (7, 7, true, false, false),
    (7, 7, false, true, false),
    (7, 2, false, false, true),
  ]) {
    testWidgets(
      'Quickened eligibility level=$level points=$points bonus=$usedBonus incapacitated=$incapacitated',
      (tester) async {
        final character = sorcerer(level: level);
        var session = CharacterSession(
          characterState: CharacterSession.fromCharacter(character)
              .characterState
              .copyWith(
                resourceValues: {sorceryPointsResourceId: points},
                activeConditions: incapacitated ? {'Stunned'} : {},
              ),
          inventory: [],
          archivedInventory: [],
          isInCombat: true,
          usedCombatActions: usedBonus ? {CombatActionCost.bonusAction} : {},
        );
        await tester.pumpWidget(
          MaterialApp(
            home: CharacterOverview(
              character: character,
              initialSession: session,
              onCharacterChanged: (_) {},
              onSessionChanged: (value) => session = value,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await helpers.tap(tester, find.text('Glow').first);
        expect(
          find.text('Quickened Spell'),
          visible ? findsOneWidget : findsNothing,
        );
        if (visible) {
          await helpers.tap(tester, find.text('Quickened Spell'));
          expect(
            session.characterState.resourceValues[sorceryPointsResourceId],
            0,
          );
          expect(session.usedCombatActions, {CombatActionCost.bonusAction});
        } else {
          await helpers.tap(tester, find.text('Done'));
          expect(
            session.characterState.resourceValues[sorceryPointsResourceId],
            points,
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'Quickened free cast spends its use and points without a spell slot',
    (tester) async {
      var character = sorcerer();
      character = character.copyWith(
        resources: [
          ...character.resources,
          const CharacterResource(
            id: 'whetstone:free-cast:ward',
            name: 'Ward Free Cast',
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
      await helpers.tap(tester, find.text('Ward').first);
      await helpers.tap(tester, find.text('Quickened Spell · Free cast'));
      expect(
        session.characterState.resourceValues['whetstone:free-cast:ward'],
        0,
      );
      expect(session.characterState.resourceValues[sorceryPointsResourceId], 5);
      expect(session.characterState.resourceValues[spellSlotId(1)], 4);
      expect(session.characterState.concentrationSpellId, ward.id);
      expect(session.levelledSpellCastThisTurn, isTrue);
      expect(session.usedCombatActions, {CombatActionCost.bonusAction});
      expect(tester.takeException(), isNull);
    },
  );
  test(
    'Known option capacity follows Sorcerer class levels and survives JSON',
    () {
      for (final (level, capacity) in [
        (1, 0),
        (2, 2),
        (9, 2),
        (10, 4),
        (16, 4),
        (17, 6),
      ]) {
        expect(Metamagic.capacity(level), capacity);
        final character = Character.fromJson(sorcerer(level: level).toJson());
        expect(character.metamagicOptions, {
          Metamagic.quickened,
          Metamagic.subtle,
        });
        expect(character.knowsMetamagic(Metamagic.quickened), level >= 2);
        expect(
          character.copyWith(name: 'Edited').metamagicOptions,
          character.metamagicOptions,
        );
      }
      final json = sorcerer().toJson();
      json['metamagicOptions'] = ['quickened', 'future-option', 'quickened'];
      expect(Character.fromJson(json).metamagicOptions, {Metamagic.quickened});
      json.remove('metamagicOptions');
      expect(Character.fromJson(json).metamagicOptions, isEmpty);
      expect(
        sorcerer(level: 2)
            .copyWith(metamagicOptions: Metamagic.values.toSet())
            .knowsMetamagic(Metamagic.quickened),
        isFalse,
      );
    },
  );
  testWidgets(
    'Known options cap selection, cancel safely and reload without changing live HP',
    (tester) async {
      var character = sorcerer(level: 2).copyWith(metamagicOptions: {});
      var session = CharacterSession.fromCharacter(character);
      Widget app(int generation) => MaterialApp(
        home: CharacterOverview(
          key: ValueKey(generation),
          character: character,
          initialSession: session,
          onCharacterChanged: (value) => character = value,
          onSessionChanged: (value) => session = value,
        ),
      );
      await tester.pumpWidget(app(0));
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text('Profile'));
      await helpers.tap(tester, find.byKey(const ValueKey('choose-metamagic')));
      await helpers.tap(
        tester,
        find.byKey(const ValueKey('metamagic-careful')),
      );
      await helpers.tap(
        tester,
        find.byKey(const ValueKey('metamagic-distant')),
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('metamagic-empowered')),
            )
            .onChanged,
        isNull,
      );
      await helpers.tap(tester, find.text('Cancel'));
      expect(character.metamagicOptions, isEmpty);
      await helpers.tap(tester, find.byKey(const ValueKey('choose-metamagic')));
      await helpers.tap(
        tester,
        find.byKey(const ValueKey('metamagic-quickened')),
      );
      await helpers.tap(tester, find.text('Save Metamagic'));
      character = Character.fromJson(character.toJson());
      final hp = session.characterState.currentHp;
      await tester.pumpWidget(app(1));
      await tester.pumpAndSettle();
      expect(character.metamagicOptions, {Metamagic.quickened});
      expect(session.characterState.currentHp, hp);
      expect(tester.takeException(), isNull);
    },
  );
  for (final spell in [glow, ward, ray, burst]) {
    testWidgets('Quickened ${spell.name} spends points and Bonus Action once', (
      tester,
    ) async {
      var character = sorcerer();
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
            diceRoller: SequenceDiceRoller([10, 4, 5, 6]),
            onCharacterChanged: (value) => character = value,
            onSessionChanged: (value) => session = value,
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> quicken() async {
        await tester.ensureVisible(find.text(spell.name).first);
        await helpers.tap(tester, find.text(spell.name).first);
        await tester.pumpAndSettle();
        await helpers.tap(tester, find.text('Quickened Spell'));
      }

      if (!spell.isCantrip) {
        await quicken();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(session.usedCombatActions, isEmpty);
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId] ?? 7,
          7,
        );
        expect(session.characterState.resourceValues[spellSlotId(1)], 4);
      }
      await quicken();
      if (!spell.isCantrip) {
        await helpers.tap(tester, find.text('Level 1 · 4 remaining'));
      }
      expect(session.usedCombatActions, {CombatActionCost.bonusAction});
      expect(session.characterState.resourceValues[sorceryPointsResourceId], 5);
      expect(
        session.characterState.resourceValues[spellSlotId(1)],
        spell.isCantrip ? 4 : 3,
      );
      expect(session.quickenedSpellUsedThisTurn, isTrue);
      expect(session.levelledSpellCastThisTurn, !spell.isCantrip);
      expect(
        CharacterSession.fromJson(session.toJson()).quickenedSpellUsedThisTurn,
        isTrue,
      );
      if (spell == ward) {
        expect(session.characterState.concentrationSpellId, ward.id);
      }
      if (spell == ray) {
        await helpers.tap(tester, find.text(ray.name).first);
        await helpers.tap(tester, find.text('Roll Damage').last);
        expect(
          session.characterState.resourceValues[sorceryPointsResourceId],
          5,
        );
        expect(session.characterState.resourceValues[spellSlotId(1)], 3);
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Quickened turn restriction survives reload and resets on Next Turn',
    (tester) async {
      var character = sorcerer();
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
          onCharacterChanged: (value) => character = value,
          onSessionChanged: (value) => session = value,
        ),
      );
      await tester.pumpWidget(app(0));
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text('Glow').first);
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text('Quickened Spell'));
      session = CharacterSession.fromJson(session.toJson());
      await tester.pumpWidget(app(1));
      await tester.pumpAndSettle();
      await helpers.tap(tester, find.text('Ward').first);
      await helpers.tap(tester, find.text('Cast').last);
      expect(find.text('Ward slot level'), findsNothing);
      expect(session.characterState.resourceValues[spellSlotId(1)], 4);
      await helpers.tap(tester, find.text('Glow').first);
      await helpers.tap(tester, find.text('Cast').last);
      expect(session.usedCombatActions, {
        CombatActionCost.bonusAction,
        CombatActionCost.action,
      });
      await helpers.tap(tester, find.text('Next Turn'));
      expect(session.quickenedSpellUsedThisTurn, isFalse);
      await helpers.tap(tester, find.text('Ward').first);
      await helpers.tap(tester, find.text('Cast').last);
      await helpers.tap(tester, find.text('Level 1 · 4 remaining'));
      expect(session.levelledSpellCastThisTurn, isTrue);
      await helpers.tap(tester, find.text('Glow').first);
      await tester.pumpAndSettle();
      expect(find.text('Quickened Spell'), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(session.characterState.resourceValues[sorceryPointsResourceId], 5);
      expect(tester.takeException(), isNull);
    },
  );
}
