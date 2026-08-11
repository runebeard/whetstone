import 'package:flutter/material.dart';

class DeathSavePip extends StatelessWidget {
  final bool isFilled;

  const DeathSavePip({super.key, required this.isFilled});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isFilled ? Colors.white : Colors.transparent,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}
