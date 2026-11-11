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
    final Map<String, int> workoutCountByDate = {};
    for (var s in sessions) {
      final key = '${s.date.year}-${s.date.month}-${s.date.day}';
      workoutCountByDate[key] = (workoutCountByDate[key] ?? 0) + 1;
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final startDate = DateTime(today.year, today.month, today.day - 111);
    final startMonday = DateTime(startDate.year, startDate.month, startDate.day - (startDate.weekday - 1));

    final List<Widget> columns = [];

    for (int i = 0; i < 16; i++) {
      final weekStart = DateTime(startMonday.year, startMonday.month, startMonday.day + (i * 7));
      final List<Widget> days = [];

      for (int j = 0; j < 7; j++) {
        final currentDate = DateTime(weekStart.year, weekStart.month, weekStart.day + j);
        
        if (currentDate.isAfter(today)) {
          days.add(Container(width: 14, height: 14, margin: const EdgeInsets.all(2), color: Colors.transparent));
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
          boxColor = primaryColor;
        }

        days.add(Container(
          width: 14,
          height: 14,
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: boxColor, borderRadius: BorderRadius.circular(3)),
        ));
      }
      
      columns.add(Column(mainAxisSize: MainAxisSize.min, children: days));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(children: columns),
    );
  }
}