# Whetstone Pack Authoring Kit

This kit helps you create reusable content libraries for Whetstone without
changing the app. A content pack can contain weapons, spells, resources,
features, and inventory items for any tabletop system or homebrew setting.

## Start here

1. Copy `pack-template.json` and give the copy a descriptive filename.
2. Replace all placeholder pack information and the example feature.
3. Add entries to any of the five content lists.
4. Keep lists you do not use as empty arrays (`[]`).
5. In Whetstone, open **Library**, choose **Import Pack**, paste the complete
   JSON, and review it before installing.

`example-pack.json` contains one valid entry of every currently supported
type. It uses fictional, system-agnostic content and can be imported directly.

## Pack information

| Field | Meaning |
| --- | --- |
| `id` | A stable, unique pack identifier. Lowercase words joined with hyphens are recommended. Do not change it when publishing an update. |
| `name` | The name players see in their Content Library. |
| `gameSystem` | The intended ruleset, edition, or `System Agnostic`. |
| `version` | Your pack version. `1.0.0` style versioning is recommended. |
| `author` | The person or group maintaining the pack. |
| `description` | A short explanation of what the pack contains. |

Only distribute material you have permission to share. Whetstone's format is
not a licence to redistribute another publisher's protected content.

## Entry types

### Weapons

Required fields: `id`, `name`, `attackModifier`, and `damage`.

- `attackModifier` is the complete modifier currently displayed and rolled.
- `damage` is player-facing text such as `1d8 + 2 slashing`.
- `damageFormula`, when present, enables Whetstone's damage roll button.
- `damageType` and `range` are optional display information.

### Spells

Required fields: `id`, `name`, `level`, `prepared`, and `summary`.

- Use level `0` for a cantrip or equivalent at-will spell.
- `rollModifier` enables a spell attack/check roll when present.
- `damageFormula` enables a damage roll when present.
- `damageType` is optional.
- `prepared` controls the initial value when the spell is copied to a
  character; players can edit their own copy afterward.

### Resources

Required fields: `id`, `name`, `maximum`, `initialValue`, and
`rechargePeriod`.

`rechargePeriod` must be one of:

- `shortRest`
- `longRest`
- `manual`

`maximum` must be at least 1. `initialValue` must be between 0 and `maximum`.

### Features

Required fields: `id`, `name`, and `summary`. Add `rollModifier` only if the
feature should be rollable.

### Items

Required fields: `name`, `quantity`, `weightPerItem`, and `category`.

`category` must be one of:

- `consumable`
- `equipment`
- `tool`
- `quest`
- `general`

## Dice expressions

Damage formulae use standard dice notation, for example:

- `1d6`
- `2d8 + 3`
- `1d10 - 1`

Keep damage type text outside the formula. Write `1d8 + 2` in
`damageFormula` and `slashing` in `damageType`.

## Identifiers and updates

- Give every weapon, spell, resource, and feature a non-empty ID.
- IDs must be unique within their own entry type in a pack.
- Treat IDs as permanent. Changing one in a later release makes it a new
  library entry.
- Installing, updating, or removing a pack does not rewrite characters.
  Content copied from the Library becomes an editable character-owned copy.

## Validation

Whetstone validates a pack during import and shows a preview before installing
it. Invalid dice expressions, duplicate IDs, incomplete metadata, impossible
resource values, and invalid item quantities are rejected.

`whetstone-content-pack.schema.json` can also provide immediate guidance in a
JSON-aware editor. In VS Code, add `$schema` before `format` at the top of a
working pack while editing:

```json
{
  "$schema": "./whetstone-content-pack.schema.json",
  "format": "whetstone-content-pack"
}
```

The rest of the pack still follows those opening fields. Whetstone ignores
the optional `$schema` editing hint when the pack is imported.

## Sharing packs

A pack is a single JSON document, so it can be hosted almost anywhere: a
website, a public code repository, a forum or subreddit post, or a shared
file. Authors should publish the pack name, supported system/edition, version,
licence or usage terms, and a brief change log alongside it.

The pack format is versioned independently from future ruleset automation.
Today's content packs will remain reusable when Whetstone later adds optional
rules modules for system-specific calculations and workflows.
