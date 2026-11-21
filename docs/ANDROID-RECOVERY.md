# Android recovery builds

Run these commands in PowerShell from the recovery checkout.

```powershell
.\scripts\Build-Android.ps1
```

The script uses the sibling `flutter-sdk` and `android-sdk` directories, Android Studio's bundled Java runtime (or a valid `JAVA_HOME`), and workspace-local caches. It restores the calling process's environment afterward. If package configuration or Flutter plugin metadata is missing, it runs `pub get`; use `-RefreshDependencies` to request that explicitly.

The app uses platform 36, build tools 36.0.0, and NDK 28.2.13676358. JNI plugin builds also require platform 35 and CMake 3.22.1, which Gradle can provision. SDK and Flutter downloads are local build prerequisites, not repository contents.

The debug APK is written to `build/app/outputs/flutter-apk/app-debug.apk`. The debug package is `com.runebeard.whetstone.recovery` with launcher label **Whetstone Recovery**, so it can coexist with the original Beta 5 package. Its data is separate. Debug signing uses this workspace's Android user directory. Verify device and upgrade compatibility separately; a successful build does not establish Beta 5 parity.

After committing a milestone, verify and back it up with:

```powershell
.\scripts\Publish-Milestone.ps1 -Milestone my-milestone -BuildAndroid
```

Publishing requires branch `recovery/beta5` and a clean working tree. It runs analysis and tests, optionally builds Android, checks that the checkout stayed unchanged, then atomically pushes the commit and milestone tag. A failed check prevents the push. Without `-BuildAndroid`, it runs analysis and tests only. An available sibling Flutter SDK is preferred over the system command.

The original user-provided Beta 5 APK is preserved locally at `../beta5-evidence/Whetstone-0.1.0-beta.5-android.apk`. Its SHA-256 and size are recorded in [`Beta5-APK-Evidence.json`](../recovery/Beta5-APK-Evidence.json). The original APK is separate from rebuilt artifacts.
