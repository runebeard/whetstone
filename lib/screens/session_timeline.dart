import 'package:flutter/material.dart';

import '../models/session_event.dart';

class SessionTimeline extends StatelessWidget {
  final List<SessionEvent> events;
  final VoidCallback onClear;

  const SessionTimeline({
    super.key,
    required this.events,
    required this.onClear,
  });

  IconData iconFor(SessionEventType type) {
    return switch (type) {
      SessionEventType.roll => Icons.casino_outlined,
      SessionEventType.health => Icons.favorite_outline,
      SessionEventType.resource => Icons.battery_charging_full_outlined,
      SessionEventType.condition => Icons.health_and_safety_outlined,
      SessionEventType.rest => Icons.bedtime_outlined,
      SessionEventType.combat => Icons.shield_outlined,
      SessionEventType.inventory => Icons.backpack_outlined,
    };
  }

  String dateLabel(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);
    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  String timeLabel(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Timeline'),
        actions: [
          if (events.isNotEmpty)
            TextButton(
              key: const ValueKey('clear-session-timeline'),
              onPressed: onClear,
              child: const Text('Clear'),
            ),
        ],
      ),
      body: events.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Your session is ready',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Rolls and meaningful character changes will appear here.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                final showDate =
                    index == 0 ||
                    dateLabel(events[index - 1].occurredAt) !=
                        dateLabel(event.occurredAt);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (showDate)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                        child: Text(
                          dateLabel(event.occurredAt),
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                    Card(
                      key: ValueKey('session-event-${event.id}'),
                      child: ListTile(
                        leading: Icon(iconFor(event.type)),
                        title: Text(event.title),
                        subtitle: event.detail == null
                            ? null
                            : Text(event.detail!),
                        trailing: Text(
                          timeLabel(event.occurredAt),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
