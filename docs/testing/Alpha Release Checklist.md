# Alpha Release Checklist

## Automated release checks

- [x] Formatting is clean.
- [x] Flutter analysis reports no issues.
- [x] The complete automated test suite passes (75 tests).
- [x] The Android alpha APK builds successfully.
- [x] The APK reports the expected application ID and version.
- [x] A SHA-256 checksum is recorded for the distributed APK.

## Manual device checks

- [ ] Install on an Android phone that has never run Whetstone.
- [ ] Complete the first-launch character/sample choice.
- [ ] Close and reopen the app; verify character state persists.
- [ ] Confirm the layout at the tester's text-size setting.
- [ ] Create a Vault Backup and restore it on a second installation/device.
- [ ] Install the next alpha over this one and verify data survives the update.
- [ ] Confirm uninstall behaviour only after keeping a Vault Backup elsewhere.

## Distribution notes

- Share the APK and its matching SHA-256 checksum together.
- State the alpha version in every download post.
- Only distribute builds produced by the project owner.
- Keep a copy of each distributed APK so bugs can be tied to an exact build.
- Do not describe a debug-signed tester APK as a Play Store release.
