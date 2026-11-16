part of 'home_screen.dart';

// Форматирование времени, карточка статистики, даты недели.
// Методы вынесены из home_screen.dart без изменения поведения
// (extension над _StreakHomeScreenState в той же библиотеке).
extension _HomeHelpers on _StreakHomeScreenState {
  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.black26,
          border: Border.all(color: Colors.grey[800]!),
          borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 12),
        Text(value,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        Text(title,
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ]),
    );
  }

  String _formatTime(int seconds) =>
      '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
  String _formatTotalTime(int s) => s >= 3600
      ? '${s ~/ 3600} ч ${(s % 3600) ~/ 60} мин'
      : '${s ~/ 60} мин';
  String _formatAverageTime(int s, int w) =>
      w == 0 ? '0 мин' : '${(s ~/ w) ~/ 60} мин';

  Set<String> _completedDatesThisWeek(StreakState state) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = DateTime(today.year, today.month, today.day - (now.weekday - 1));
    final result = <String>{};
    for (final s in state.sessions) {
      final d = DateTime(s.date.year, s.date.month, s.date.day);
      if (d.difference(monday).inDays >= 0 && d.difference(monday).inDays < 7) {
        result.add('${d.year}-${d.month}-${d.day}');
      }
    }
    return result;
  }
}
