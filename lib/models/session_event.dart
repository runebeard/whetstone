enum SessionEventType {
  roll,
  health,
  resource,
  condition,
  rest,
  combat,
  inventory,
}

class SessionEvent {
  final String id;
  final DateTime occurredAt;
  final SessionEventType type;
  final String title;
  final String? detail;

  const SessionEvent({
    required this.id,
    required this.occurredAt,
    required this.type,
    required this.title,
    this.detail,
  });

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'occurredAt': occurredAt.toIso8601String(),
      'type': type.name,
      'title': title,
      'detail': detail,
    };
  }

  factory SessionEvent.fromJson(Map<String, Object?> json) {
    return SessionEvent(
      id: json['id'] as String,
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      type: SessionEventType.values.firstWhere(
        (type) => type.name == json['type'],
        orElse: () => SessionEventType.combat,
      ),
      title: json['title'] as String,
      detail: json['detail'] as String?,
    );
  }
}
