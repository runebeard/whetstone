# Whetstone recovery

This working copy starts from Alpha 1, commit e5c688dcaff33ee3d63ed89d95225d4ece92402b. The Flutter implementation starts at that baseline and now preserves opaque saved class rules. The four WAV files in assets/sounds came from the Beta 5 APK and are staged for future audio integration. The release notes and the surviving offline builder HTML and CSS are in recovery/. The builder still needs builder-core.js and builder-ui.js.

## Beta 5 reconstruction

1. Compare Beta 5 exported JSON against the Alpha schema in pack-authoring-kit/ and the decoder in lib/persistence/portable_content_pack_document.dart. Preserve schema-v1 imports and old saves. Use the APK and release notes to confirm behavior where the newer JSON format is unavailable.
2. Add authored class rules to pack import and detailed level-1 character creation. Keep a snapshot with the Character definition so portable character and vault backups can carry the rules independently of the installed pack.
3. Add rules-driven advancement alongside the Alpha manual advancement path. Use the Lantern Warden example from the release notes to check Ward and three Sparks at level 1, then Mend/Gift, a required vocation, and a four-Spark maximum at level 2. Check advancement with a spent Spark, and reopen the character after removing the source pack. Compare exact resource arithmetic and choice behavior against the APK.
4. Compare the newer spell, weapon and action fields and the in-app authoring flow against the APK. Keep later class progression preview-only where the release notes describe that limit.

## Evidence from the Beta 5 binary

Printable strings in the ARM64 Flutter library include savedClassRules, PackClassSnapshot.capture, PackClassSnapshot.decode, PackClassDefinition.fromJson, PackClassRulesAdapter and OwnedClassFirstAdvancementScreen. They also include classes, featureIdsByLevel, hitDie, savingThrows, skillChoiceCount and skillOptions. These strings identify likely fields and subsystems. They do not establish the document nesting, versions, or the format of a saved snapshot.

The character model now carries savedClassRules through edits, copies and serialization as opaque JSON data. The portable character test uses synthetic snapshot data. Compatibility with an actual Beta 5 export remains unverified.

A Beta 5 exported pack and a portable character export for an authored class would resolve the remaining format questions. If a Beta 5 instance is available, exports from the same character before and after level 2 with a spent Spark would also establish the resource arithmetic.

## Milestone backups

Use a Git checkout of the upstream repository and bring the recovered files into the recovery/beta5 branch. This ZIP-derived copy does not contain Git history or an origin remote. The publishing script expects Git, Flutter, and an authenticated origin with write access.

After committing a milestone on recovery/beta5, run:

    ./scripts/Publish-Milestone.ps1 -Milestone recovery-baseline

The script runs Flutter analysis and tests, then atomically pushes the checked commit to the recovery branch and to the remote tag milestone/recovery-baseline. Use a fresh name for each milestone. This workflow has passed repeated full test/build/backup runs.

For an Android milestone, include `-BuildAndroid` and a dated milestone name, for example `./scripts/Publish-Milestone.ps1 -Milestone casting-recovery-2026-11-26 -BuildAndroid`. This also verifies the Recovery package, launcher label and signing certificate, preserves a uniquely named APK in the parent workspace's `outputs` folder, and writes its source commit, test count and SHA-256 record beside it. `Save-MilestoneApk.ps1` performs this preservation step after the build and clean-source check. A conflicting artifact or source record is rejected; choose a fresh milestone name. APKs remain local, while source and milestone tags are pushed to GitHub.

## Recovered Lantern authoring draft

recovery/pack-builder/lantern-homebrew.draft.json is a byte-for-byte copy of the supplied version-3 authoring draft. It provides a fixture for restoring standalone builder draft loading. Its entries cover a short-rest resource, a resource-funded timed state, two healing actions with a shared per-activation limit, a state-ending action, a finesse weapon, and a cantrip. Keep draft loading separate from app content-pack import. The draft has no class entry or level table, and it does not establish the exported pack layout.

## Recovered Lantern pack export

recovery/pack-builder/lantern-homebrew.pack.json is the matching standalone builder export. Its envelope uses format whetstone-content-pack and schemaVersion 22. Alpha's portable pack decoder currently accepts version 1 only.

The draft action entries become pack features with actionMenu.options. The menu references the generated resource ID. Ward activates a namespaced state for three turns, Mend and Gift require that state and share one stateUseId, and Lower Ward ends it. The resource exports an explicit initialValue of 3 and a shortRest rechargePeriod. The weapon exports attack ability, proficiency and damage modifier flags, an equipment bonus, category and finesse. The spell exports class IDs, components, casting details and roll settings. Preserve these fields when implementing version 22 rather than relaxing the version check and losing behavior.

This export has no classes collection, level progression or character-owned snapshot. A class-bearing pack or an exported authored character would provide the remaining format evidence.

## Recovered Deathstalker class export

recovery/pack-builder/deathstalker.pack.json supplies the class format. Its pack envelope uses schemaVersion 3, whereas the Lantern action pack uses 22. Keep the document version distinct from the pack metadata version and do not assume these two exports establish a single version-selection rule.

The class appears under pack.classes. The fixture covers hitDie, savingThrows, skillChoiceCount, skillOptions, subclassLevels, featureIdsByLevel, resources.grantLevels, resources.scaling and entryRules (including initialTraining and equipmentOptions). Verified that its class references resolve to exported features, the Deathmarks resource and the Deathblade item.

Use the fixture to check that Silent hunter appears at level 1 and Shadow step at level 2. Mark prey and Deathmarks are level-3 data, with the resource maximum changing again at level 5. The choices array is empty. The skill bonus in Silent hunter and the teleport and recharge text in Shadow step are prose in this export. Preserve that prose without inventing automation. The fixture does not show a populated choice or a character-owned savedClassRules snapshot.

Schema-3 packs with class definitions can now be installed as library previews. Their full payload survives catalog reload and portable re-encoding. The preview does not expose partial combat entries to the character editor. Schema 22 and playable class creation and advancement remain open.

The character editor now offers a first playable slice for noncasting schema-3 classes with descriptive level-1 and level-2 grants, no early resource grants or progression choices, and at most one starting equipment option. It uses the existing proficiency controls for class skill picks, stores a recovery-format snapshot, and uses a fixed-average hit point increase at level 2. Starting gold is a zero-weight inventory entry and linked equipment is represented as inventory. Training enforcement, early resource progression, choices, action automation and schema 22 remain open. These changes have not been built or run.

Authored class creation and first advancement now handle grantLevels and baseByLevel. A maximum change preserves the number of spent uses. The advancement dialog previews later feature grants and resource changes, including Deathstalker's Mark Prey and Deathmarks. Levels 3–20 have no save path. Advanced choices, training and action rules still need implementation.
