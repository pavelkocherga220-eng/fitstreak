class WorkoutSession {
  final DateTime date;
  final String type;
  final int durationSeconds;
  
  const WorkoutSession({
    required this.date,
    required this.type,
    required this.durationSeconds,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'type': type,
        'durationSeconds': durationSeconds,
      };

  factory WorkoutSession.fromJson(Map<String, dynamic> j) => WorkoutSession(
        date: DateTime.parse(j['date'] as String),
        type: j['type'] as String,
        durationSeconds: (j['durationSeconds'] as num?)?.toInt() ?? 0,
      );
}