# Autonomous Rebuild Rules

- **Execution Mode** — Work continuously through `PLANS.md` until every item is checked off. Do not pause between tasks for confirmation, interim summaries, or a request to continue. If a blocker genuinely requires user input, complete any independent work before reporting it.
- **Reference Source** — Use this recovery checkout (`./`, branch `recovery/beta5`) as the working baseline. Compare it with the Beta 5 evidence in `recovery/Beta5-Release-Notes.txt` and `RECOVERY.md`, and inspect the original APK when available. Record reconstructed behavior and any verification still needed when the evidence is incomplete.
- **Verification Loop** — After implementing each item in `PLANS.md`, run the check that exercises it. For the Flutter app, use `flutter analyze` and `flutter test`. For an Android build item, use `flutter build apk --debug` or the appropriate Gradle task. Read failures and fix them before moving on to dependent work.
- **Progress Tracking** — Check off each feature in `PLANS.md` as soon as it compiles cleanly and its relevant checks pass. Keep unverified items open and record the specific failing or blocked check.
