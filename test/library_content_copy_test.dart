import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/content/starter_content_pack.dart';
import 'package:whetstone/models/library_content_copy.dart';

void main() {
  test(
    'library entries become independent, collision-safe character copies',
    () {
      final source = starterContentPack.weapons.single;
      final first = LibraryContentCopy.weapon(source, const []);
      final second = LibraryContentCopy.weapon(source, [first]);

      expect(first, isNot(same(source)));
      expect(first.id, source.id);
      expect(second.id, isNot(first.id));
      expect(second.name, source.name);
      expect(second.damageFormula, source.damageFormula);
      expect(source.id, 'training_sword');
    },
  );

  test('every starter entry type can be copied into character-owned data', () {
    final spell = LibraryContentCopy.spell(
      starterContentPack.spells.single,
      const [],
    );
    final resource = LibraryContentCopy.resource(
      starterContentPack.resources.single,
      const [],
    );
    final feature = LibraryContentCopy.feature(
      starterContentPack.features.single,
      const [],
    );
    final item = LibraryContentCopy.item(starterContentPack.items.single);

    expect(spell, isNot(same(starterContentPack.spells.single)));
    expect(resource, isNot(same(starterContentPack.resources.single)));
    expect(feature, isNot(same(starterContentPack.features.single)));
    expect(item, isNot(same(starterContentPack.items.single)));
    expect(spell.name, 'Ember Bolt');
    expect(resource.name, 'Heroic Effort');
    expect(feature.name, 'Rally');
    expect(item.name, 'Healing Draught');
  });
}
