import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/character_resource.dart';
import 'package:whetstone/widgets/resource_card.dart';

void main() {
  for (final maximum in [3, 70, 100]) {
    testWidgets('resource pool $maximum fits a narrow phone card', (
      tester,
    ) async {
      var tapped = false;
      var managed = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 145,
                height: 60,
                child: ResourceCard(
                  resource: CharacterResource(
                    id: 'pool',
                    name: 'Lay on Hands',
                    maximum: maximum,
                    initialValue: maximum,
                    rechargePeriod: RechargePeriod.longRest,
                  ),
                  currentValue: maximum - 1,
                  onTap: () => tapped = true,
                  onLongPress: () => managed = true,
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      if (maximum > 6) {
        expect(find.text('${maximum - 1}/$maximum'), findsOneWidget);
      }
      await tester.tap(find.byType(ResourceCard));
      expect(tapped, isTrue);
      await tester.longPress(find.byType(ResourceCard));
      expect(managed, isTrue);
    });
  }
}
