Content packs and ruleset automation are separate architectural layers.

A content pack supplies reusable player-facing data such as weapons, spells,
resources, features, and items. Characters receive editable copies of that
data. Packs remain useful without an automation module and must not assume a
single tabletop system.

A future ruleset module may supply system-specific calculations, validation,
and workflows such as derived initiative, proficiency, spellcasting, resource
recovery, or level advancement. A character will explicitly select a ruleset
module when automation is wanted; system-agnostic and manually managed
characters must remain supported.

Content-pack schema versions and ruleset-module versions evolve independently.
A pack may later declare optional compatibility with a ruleset module, but
installing content must never silently enable automation or rewrite existing
characters.

The first ruleset automation will target the D&D edition agreed for the first
implementation. Its design must not place D&D-specific assumptions in the
generic character, pack, inventory, or session layers.
