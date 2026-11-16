/// Одно упражнение круга: своё название и своё время работы/отдыха.
class CustomInterval {
  static const int minWork = 5;
  static const int maxWork = 600;
  static const int minRest = 0;
  static const int maxRest = 300;
  static const int maxNameLength = 30;

  final String name;
  final int workSeconds;
  final int restSeconds;

  const CustomInterval({
    required this.name,
    required this.workSeconds,
    required this.restSeconds,
  });

  CustomInterval copyWith({String? name, int? workSeconds, int? restSeconds}) =>
      CustomInterval(
        name: name ?? this.name,
        workSeconds: workSeconds ?? this.workSeconds,
        restSeconds: restSeconds ?? this.restSeconds,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'work': workSeconds,
        'rest': restSeconds,
      };

  factory CustomInterval.fromJson(Map<String, dynamic> json) {
    final name = (json['name'] as String?) ?? '';
    final work = (json['work'] as num?)?.toInt() ?? 30;
    final rest = (json['rest'] as num?)?.toInt() ?? 15;
    return CustomInterval(
      name: name.length > maxNameLength ? name.substring(0, maxNameLength) : name,
      workSeconds: work.clamp(minWork, maxWork),
      restSeconds: rest.clamp(minRest, maxRest),
    );
  }

  static const List<CustomInterval> defaults = [
    CustomInterval(name: 'Упражнение 1', workSeconds: 30, restSeconds: 15),
    CustomInterval(name: 'Упражнение 2', workSeconds: 45, restSeconds: 10),
  ];
}

/// Одна фаза интервальной тренировки (работа или отдых).
class IntervalPhase {
  final String label; // название упражнения (может быть пустым)
  final int seconds;
  final bool isRest;
  final int round; // номер раунда, с 1

  const IntervalPhase({
    required this.label,
    required this.seconds,
    required this.isRest,
    required this.round,
  });

  /// Строит план: работа, отдых, работа, ... Отдых после самой последней
  /// работы не добавляется; фазы отдыха нулевой длины пропускаются.
  static List<IntervalPhase> build(List<CustomInterval> exercises, int laps) {
    final phases = <IntervalPhase>[];
    var round = 0;
    for (var lap = 0; lap < laps; lap++) {
      for (var i = 0; i < exercises.length; i++) {
        round++;
        final e = exercises[i];
        phases.add(IntervalPhase(
            label: e.name, seconds: e.workSeconds, isRest: false, round: round));
        final isLast = lap == laps - 1 && i == exercises.length - 1;
        if (!isLast && e.restSeconds > 0) {
          phases.add(IntervalPhase(
              label: e.name, seconds: e.restSeconds, isRest: true, round: round));
        }
      }
    }
    return phases;
  }
}
