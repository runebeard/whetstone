Character imports use an explicit, versioned Whetstone package format.

Portable character packages contain both the character definition and the
current live session state. Transport is separate from the package format:
copy and paste is supported first, while files, sharing, QR codes, and content
packs can use the same validation layer later.

Imports must be previewed before saving. An imported package never silently
overwrites an existing character; identity collisions create a separate copy.

Content packs will be versioned documents of reusable game content rather than
hidden application seed data. They must remain compatible with homebrew and
offline use.

Installed packs live in a persistent Content Library. Packs may contain
weapons, spells, resources, features, and inventory items. Installing or
removing a pack never mutates existing characters; adding library content to a
character creates an editable copy owned by that character.
