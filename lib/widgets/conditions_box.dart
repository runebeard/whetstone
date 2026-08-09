import 'package:flutter/material.dart';

class ConditionsBox extends StatelessWidget {
  final Set<String> activeConditions;
  final VoidCallback onTap;

  const ConditionsBox({
    super.key,
    required this.activeConditions,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final conditions = activeConditions.toList()..sort();

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Conditions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: conditions.isEmpty
                    ? const Center(
                        child: Text(
                          'None',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: conditions.length,
                        itemBuilder: (context, index) {
                          return Text(
                            '• ${conditions[index]}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
