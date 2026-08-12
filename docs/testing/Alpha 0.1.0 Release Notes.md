# Whetstone Alpha 0.1.0 Release Notes

Build version: `0.1.0-alpha.1`

Android application ID: `com.runebeard.whetstone`

Android label: `Whetstone Alpha`

## Tester APK

Filename: `Whetstone-0.1.0-alpha.1-android.apk`

Size: 52,279,122 bytes

SHA-256: `734D5A32EBF7129ED615C6E59410B646F470EF71F8A7993F804DE40C2E357259`

The checksum lets a tester confirm that the APK they received is identical to
the one produced and verified in the Whetstone workspace.

## Scope

This private friend-test build includes the mode-led character experience,
combat and roll workflows, persistent live state, inventory, spellbook,
resources, journal, Session Timeline, character import/export, content packs,
full Vault Backup and Restore, first-launch onboarding, and sample characters.

## Privacy and connectivity

The Android artifact does not request internet permission. Whetstone contains
no account system, analytics, advertising, or tracking. See
`Privacy and Local Data.md` for storage and backup details.

## Signing and distribution

This APK is optimized for release behaviour but signed with the project's
current Android tester key. It is intended for direct private testing and is
not a Play Store production release. Permanent release signing must be set up
before public or store distribution.

## Verification completed

- 75 automated tests passed.
- Flutter analysis reported no issues.
- Small-phone toolbar and content-pack layouts passed.
- Package name, version, label, permissions, signing certificate, size, and
  checksum were inspected from the finished APK.

The physical-device checks in `Alpha Release Checklist.md` remain intentionally
open until this APK is installed on the first tester phone.
