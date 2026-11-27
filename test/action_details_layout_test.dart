import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/models/spell.dart';
import 'package:whetstone/widgets/action_details_dialog.dart';

void main() {
  for (final (size, scale) in [
    (const Size(360, 640), 1.0),
    (const Size(320, 568), 1.6),
  ]) {
    testWidgets(
      'Spell controls remain reachable at $size and text scale $scale',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final used = <String>[];
        VoidCallback record(String label) =>
            () => used.add(label);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => ActionDetailsDialog(
                        action: const Spell(
                          id: 'layout',
                          name: 'Versatile Spell',
                          level: 1,
                          prepared: true,
                          concentration: true,
                          duration: 'Concentration, up to 1 minute',
                          castingTime: 'Action',
                          range: '60 feet',
                          components: 'V, S, M (a feather)',
                          summary:
                              'Review this spell and choose how to cast it.',
                        ),
                        onSubtlePair: record('Subtle + another option'),
                        onDistantPair: record('Distant + another option'),
                        onExtendedPair: record('Extended + another option'),
                        onEffectPair: record('Other Metamagic combinations'),
                        onQuickenedPair: record('Quickened + another option'),
                        onArcaneApotheosis: record(
                          'My turn · Arm free Metamagic',
                        ),
                        onCastCareful: record('Careful Spell'),
                        onCastHeightened: record('Heightened Spell'),
                        onCastTransmuted: record('Transmuted Spell'),
                        onCastExtended: record('Extended Spell'),
                        onCastSubtle: record('Subtle Spell'),
                        onCastDistant: record('Distant Spell'),
                        onCastQuickened: record('Quickened Spell'),
                        onRollDamage: record('Roll Damage'),
                        onCast: record('Cast'),
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final label in [
          'Subtle + another option',
          'Distant + another option',
          'Extended + another option',
          'Other Metamagic combinations',
          'Quickened + another option',
          'My turn · Arm free Metamagic',
          'Careful Spell',
          'Heightened Spell',
          'Transmuted Spell',
          'Extended Spell',
          'Subtle Spell',
          'Distant Spell',
          'Quickened Spell',
          'Roll Damage',
          'Cast',
        ]) {
          await tester.ensureVisible(find.text(label));
          await tester.pumpAndSettle();
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
          expect(used.last, label);
        }
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(find.byType(ActionDetailsDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
