class JournalEntry {
  final String id;
  final String title;
  final String notes;
  final bool isCompleted;

  const JournalEntry({
    required this.id,
    required this.title,
    required this.notes,
    this.isCompleted = false,
  });

  JournalEntry copyWith({String? title, String? notes, bool? isCompleted}) {
    return JournalEntry(
      id: id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, Object> toJson() {
    return {
      'id': id,
      'title': title,
      'notes': notes,
      'isCompleted': isCompleted,
    };
  }

  factory JournalEntry.fromJson(Map<String, Object?> json) {
    return JournalEntry(
      id: json['id'] as String,
      title: json['title'] as String,
      notes: json['notes'] as String? ?? '',
      isCompleted: json['isCompleted'] as bool? ?? false,
    );
  }
}
