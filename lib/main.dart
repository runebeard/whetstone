import 'package:flutter/material.dart';

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

class CharacterVault extends StatelessWidget {
  const CharacterVault({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Whetstone'),
      ),
      body: const Center(
        child: Text(
          'Your Characters',
          style: TextStyle(fontSize: 28),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}