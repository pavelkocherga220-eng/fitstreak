class WorkoutNote {
  final String type;
  final String text;
  final DateTime date;
  
  const WorkoutNote({
    required this.type,
    required this.text,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'text': text,
        'date': date.toIso8601String(),
      };

  factory WorkoutNote.fromJson(Map<String, dynamic> j) => WorkoutNote(
        type: j['type'] as String,
        text: j['text'] as String,
        date: DateTime.parse(j['date'] as String),
      );
}