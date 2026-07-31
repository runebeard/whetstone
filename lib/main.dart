import 'package:flutter/material.dart';
import 'screens/character_vault.dart';

void main() {
  runApp(const WhetstoneApp());
}

class WhetstoneApp extends StatelessWidget {
  const WhetstoneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whetstone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const CharacterVault(),
    );
  }
}

