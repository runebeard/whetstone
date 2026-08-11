import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/weapon.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/widgets/combat_action_card.dart';

void main() {
  testWidgets('shows roll values on usable combat buttons at phone width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    var attackRolls = 0;
    var damageRolls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CombatActionCard(
            action: const Weapon(
              id: 'quarterstaff',
              name: 'Quarterstaff',
              attackModifier: 2,
              damage: '1d6 − 1 bludgeoning',
              damageFormula: '1d6 − 1',
              damageType: 'bludgeoning',
              range: 'Melee',
            ),
            isPinned: false,
            controlKeyPrefix: 'attacks',
            onDetails: () {},
            onAttack: () => attackRolls++,
            onDamage: () => damageRolls++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Hit +2'), findsOneWidget);
    expect(find.text('Dmg 1d6 − 1'), findsOneWidget);
    expect(find.text('Melee'), findsOneWidget);
    expect(find.textContaining('to hit'), findsNothing);
    expect(find.textContaining('bludgeoning'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('attack-attacks-weapon:quarterstaff')),
    );
    await tester.tap(
      find.byKey(const ValueKey('damage-attacks-weapon:quarterstaff')),
    );
    expect(attackRolls, 1);
    expect(damageRolls, 1);
  });

  testWidgets('keeps only useful spell context beside compact roll buttons', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CombatActionCard(
            action: const Spell(
              id: 'fire_bolt',
              name: 'Fire Bolt',
              level: 0,
              prepared: false,
              rollModifier: 7,
              damageFormula: '2d10',
              damageType: 'fire',
              summary: '+7 to hit • 2d10 fire • 120 ft',
            ),
            isPinned: true,
            controlKeyPrefix: 'attacks',
            onDetails: () {},
            onAttack: () {},
            onDamage: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Fire Bolt'), findsOneWidget);
    expect(find.text('120 ft'), findsOneWidget);
    expect(find.text('Hit +7'), findsOneWidget);
    expect(find.text('Dmg 2d10'), findsOneWidget);
    expect(find.textContaining('to hit'), findsNothing);
    expect(find.textContaining('2d10 fire'), findsNothing);
  });
}
