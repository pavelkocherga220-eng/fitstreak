import 'package:flutter/material.dart';
import '../models/streak_state.dart';

// Те же аватарки, что и в профиле
const List<Map<String, dynamic>> widgetAvatars = [
  {'icon': Icons.fitness_center, 'color': Colors.orange},
  {'icon': Icons.directions_run, 'color': Colors.lightBlueAccent},
  {'icon': Icons.self_improvement, 'color': Colors.green},
  {'icon': Icons.directions_bike, 'color': Colors.purpleAccent},
  {'icon': Icons.sports_martial_arts, 'color': Colors.redAccent},
  {'icon': Icons.sports_basketball, 'color': Colors.amber},
];

class FitStreakWidgetUI extends StatelessWidget {
  final StreakState state;
  final Color primaryColor;

  const FitStreakWidgetUI({super.key, required this.state, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    final avatar = widgetAvatars[state.avatarIndex % widgetAvatars.length];
    
    return Container(
      width: 400,
      height: 200,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: primaryColor.withValues(alpha: 0.5), width: 3),
      ),
      child: Row(
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: avatar['color'].withValues(alpha: 0.2),
              border: Border.all(color: avatar['color'], width: 3),
            ),
            child: Icon(avatar['icon'], color: avatar['color'], size: 40),
          ),
          const SizedBox(width: 20),
          
          Expanded( // <-- ОБЯЗАТЕЛЬНО EXPANDED, ЧТОБЫ ТЕКСТ НЕ ВЫЛЕЗАЛ
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  state.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.local_fire_department, color: Colors.orange, size: 28),
                    const SizedBox(width: 4),
                    Text(
                      '${state.streakCount} дней',
                      style: const TextStyle(color: Colors.orange, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.diamond, color: Colors.cyanAccent, size: 24),
                    const SizedBox(width: 4),
                    Text(
                      '${state.crystals}',
                      style: const TextStyle(color: Colors.cyanAccent, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}