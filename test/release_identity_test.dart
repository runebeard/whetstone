import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:whetstone/app_info.dart';

void main() {
  test('friend-test build has the expected alpha identity', () async {
    expect(appName, 'Whetstone');
    expect(appBuildLabel, 'Alpha 0.1.0');

    final pubspec = await File('pubspec.yaml').readAsString();
    final androidBuild = await File(
      'android/app/build.gradle.kts',
    ).readAsString();
    final manifest = await File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsString();

    expect(pubspec, contains('version: 0.1.0-alpha.1+1'));
    expect(androidBuild, contains('com.runebeard.whetstone'));
    expect(manifest, contains('android:label="Whetstone Alpha"'));
    expect(manifest, isNot(contains('android.permission.INTERNET')));
  });
}
