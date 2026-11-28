import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/ability.dart';
import 'package:whetstone/models/character.dart';
import 'package:whetstone/models/character_session.dart';
import 'package:whetstone/models/skill.dart';
import 'package:whetstone/persistence/portable_character_document.dart';
import 'package:whetstone/screens/character_advancement.dart';
import 'package:whetstone/screens/character_editor.dart';
import 'package:whetstone/screens/character_overview.dart';
import 'cleric_channel_divinity_test.dart' as fixtures;
import 'draconic_spell_grants_test.dart' as helpers;

void main() {
  for (final (wisdom, bonus) in [(16, 3), (8, 1)]) {
    test(
      'Thaumaturge Wisdom $wisdom adds once while preserving proficiency and Expertise',
      () {
        final character = fixtures
            .cleric(3, wisdom: wisdom)
            .copyWith(
              divineOrder: DivineOrder.thaumaturge,
              abilityScores: {Ability.intelligence: 14, Ability.wisdom: wisdom},
              proficiencyBonus: 3,
              skillProficiencies: {
                'arcana': SkillProficiency.expertise,
                'religion': SkillProficiency.proficient,
              },
            );
        int modifier(String id) => character.modifierFor(
          standardSkills.singleWhere((s) => s.id == id),
        );
        expect(modifier('arcana'), 8 + bonus);
        expect(modifier('religion'), 5 + bonus);
        expect(modifier('nature'), 2);
        expect(
          character.modifierFor(
            const Skill(id: 'arcana', name: 'Arcana', ability: Ability.wisdom),
          ),
          character.abilityModifierFor(Ability.wisdom) + 6,
        );
      },
    );
  }
  for (final order in DivineOrder.values) {
    test('$order persists through copy and portable character export', () {
      final character = fixtures.cleric(3).copyWith(divineOrder: order);
      final document = PortableCharacterDocument(
        character: character,
        session: CharacterSession.fromCharacter(character),
      );
      final restored = PortableCharacterDocument.decode(
        document.encode(),
      ).character;
      expect(restored.divineOrder, order);
      expect(restored.copyWith(name: 'Edited').divineOrder, order);
      expect(restored.copyWith(clearDivineOrder: true).divineOrder, isNull);
    });
  }
  test('Unknown and legacy orders remain unselected', () {
    final json = fixtures.cleric(3).toJson();
    expect(Character.fromJson(json).divineOrder, isNull);
    expect(
      Character.fromJson({...json, 'divineOrder': 'future'}).divineOrder,
      isNull,
    );
  });
  test('Protector and dormant Thaumaturge do not grant check bonuses', () {
    final arcana = standardSkills.singleWhere((s) => s.id == 'arcana');
    final original = fixtures.cleric(3).copyWith(skillProficiencies: {});
    expect(
      original.copyWith(divineOrder: DivineOrder.protector).modifierFor(arcana),
      original.modifierFor(arcana),
    );
    expect(
      original
          .copyWith(
            characterClass: 'Fighter',
            divineOrder: DivineOrder.thaumaturge,
          )
          .modifierFor(arcana),
      original.modifierFor(arcana),
    );
  });
  test('Multiclass Thaumaturge and Magician remain separate named bonuses', () {
    final character = fixtures
        .cleric(3)
        .copyWith(
          additionalClassLevels: {'Druid': 1},
          divineOrder: DivineOrder.thaumaturge,
          primalOrder: PrimalOrder.magician,
          abilityScores: {Ability.intelligence: 14, Ability.wisdom: 16},
          skillProficiencies: {},
        );
    expect(
      character.modifierFor(
        standardSkills.singleWhere((s) => s.id == 'arcana'),
      ),
      8,
    );
    expect(
      character.modifierFor(
        standardSkills.singleWhere((s) => s.id == 'religion'),
      ),
      5,
    );
    expect(
      character.modifierFor(
        standardSkills.singleWhere((s) => s.id == 'nature'),
      ),
      5,
    );
  });
  testWidgets(
    'New built-in Cleric requires Divine Order and previews guidance',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: CharacterEditor()));
      await tester.pumpAndSettle();
      await helpers.tap(
        tester,
        find.byKey(const ValueKey('built-in-class-picker')),
      );
      await helpers.tap(tester, find.text('Cleric').last);
      final picker = find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField<DivineOrder>,
      );
      final state = tester.state<FormFieldState<DivineOrder>>(picker);
      expect(state.validate(), isFalse);
      await tester.pumpAndSettle();
      expect(find.text('Choose a Divine Order'), findsOneWidget);
      await helpers.tap(tester, picker);
      await helpers.tap(tester, find.text('Thaumaturge').last);
      expect(state.validate(), isTrue);
      await tester.pumpAndSettle();
      expect(find.text(DivineOrder.thaumaturge.guidance), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final order in DivineOrder.values) {
    testWidgets('Advance and edit retain $order and live character values', (
      tester,
    ) async {
      var character = fixtures
          .cleric(3)
          .copyWith(
            currentHp: 13,
            divineOrder: DivineOrder.protector,
            weapons: [],
            spells: [],
            features: [],
            initialInventory: [],
          );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  final result = await Navigator.push<Character>(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CharacterAdvancement(character: character),
                    ),
                  );
                  if (result != null) character = result;
                },
                child: const Text('Advance'),
              ),
            ),
          ),
        ),
      );
      await helpers.tap(tester, find.text('Advance'));
      final picker = find.byWidgetPredicate(
        (w) => w is DropdownButtonFormField<DivineOrder>,
      );
      await helpers.tap(tester, picker);
      await helpers.tap(tester, find.text(order.label).last);
      await helpers.tap(tester, find.byKey(const ValueKey('save-advancement')));
      expect(character.divineOrder, order);
      expect(character.currentHp, 13);
      final resources = character.toJson()['resources'];
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () async {
                  final result = await Navigator.push<Character>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CharacterEditor(character: character),
                    ),
                  );
                  if (result != null) character = result;
                },
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      );
      await helpers.tap(tester, find.text('Edit'));
      for (var i = 0; i < 8; i++) {
        tester.testTextInput.hide();
        await helpers.tap(tester, find.byKey(ValueKey('creator-continue-$i')));
        expect(tester.widget<Stepper>(find.byType(Stepper)).currentStep, i + 1);
      }
      tester.testTextInput.hide();
      await helpers.tap(tester, find.byKey(const ValueKey('creator-save')));
      expect(find.byType(CharacterEditor), findsNothing);
      expect(character.divineOrder, order);
      expect(character.currentHp, 13);
      expect(character.toJson()['resources'], resources);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'Profile shows the saved order and its equipment/cantrip guidance',
    (tester) async {
      final character = fixtures
          .cleric(3)
          .copyWith(divineOrder: DivineOrder.thaumaturge);
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
      await helpers.tap(tester, find.text('Profile'));
      expect(find.text('Divine Order · Thaumaturge'), findsOneWidget);
      expect(find.text(DivineOrder.thaumaturge.guidance), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
