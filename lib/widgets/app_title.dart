import 'package:flutter/material.dart';

import '../app_info.dart';

class WhetstoneAppTitle extends StatelessWidget {
  const WhetstoneAppTitle({super.key});

  @override
  Widget build(BuildContext context) {
    return const Tooltip(
      message: appBuildLabel,
      child: Text('$appName α', key: ValueKey('alpha-release-badge')),
    );
  }
}
