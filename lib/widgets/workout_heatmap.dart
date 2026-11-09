import 'package:flutter/material.dart';
import '../models/workout_session.dart';

class WorkoutHeatmap extends StatelessWidget {
  final List<WorkoutSession> sessions;
  final Color primaryColor;
  final Color backgroundColor;

  const WorkoutHeatmap({
    super.key,
    required this.sessions,
    required this.primaryColor,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Группируем тренировки по датам (ключ: "год-месяц-день")
    final Map<String, int> workoutCountByDate = {};
    for (var s in sessions) {
      final key = '${s.date.year}-${s.date.month}-${s.date.day}';
      workoutCountByDate[key] = (workoutCountByDate[key] ?? 0) + 1;
    }

    // 2. Вычисляем диапазон: последние 16 недель (примерно 4 месяца)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDate = today.subtract(const Duration(days: 7 * 16 - 1));
    // Находим понедельник той недели, с которой начинаем
    final startMonday = startDate.subtract(Duration(days: startDate.weekday - 1));

    final List<Widget> columns = [];

    // 3. Строим сетку по неделям
    for (int i = 0; i < 16; i++) {
      final weekStart = startMonday.add(Duration(days: i * 7));
      final List<Widget> days = [];

      for (int j = 0; j < 7; j++) {
        final currentDate = weekStart.add(Duration(days: j));
        
        // Если дата в будущем — рисуем пустое место
        if (currentDate.isAfter(today)) {
          days.add(Container(
            width: 14,
            height: 14,
            margin: const EdgeInsets.all(2),
            color: Colors.transparent,
          ));
          continue;
        }

        final key = '${currentDate.year}-${currentDate.month}-${currentDate.day}';
        final count = workoutCountByDate[key] ?? 0;

        Color boxColor;
        if (count == 0) {
          boxColor = backgroundColor;
        } else if (count == 1) {
          boxColor = primaryColor.withValues(alpha: 0.5);
        } else {
          boxColor = primaryColor; // 2 и более тренировок
        }

        days.add(Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: boxColor,
            borderRadius: BorderRadius.circular(3),
          ),
        ));
      }
      
      columns.add(Column(
        mainAxisSize: MainAxisSize.min,
        children: days,
      ));
    }

    // 4. Оборачиваем в горизонтальный скролл (как в GitHub)
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true, // Прокрутка по умолчанию к последней (текущей) неделе
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(children: columns),
    );
  }
}