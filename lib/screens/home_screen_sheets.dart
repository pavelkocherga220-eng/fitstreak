part of 'home_screen.dart';

// Нижние листы и экраны: тема, заметки, календарь, достижения, статистика.
// Методы вынесены из home_screen.dart без изменения поведения
// (extension над _StreakHomeScreenState в той же библиотеке).
extension _HomeSheets on _StreakHomeScreenState {
  void _openThemeSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎨 Тема оформления',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 20),
          ...List.generate(widget.themes.length, (i) {
            final theme = widget.themes[i];
            final selected = widget.selectedThemeIndex == i;
            return ListTile(
              leading:
                  CircleAvatar(backgroundColor: theme.primary, radius: 14),
              title: Text(theme.name,
                  style: TextStyle(
                      color: selected ? theme.primary : Colors.white,
                      fontWeight:
                          selected ? FontWeight.bold : FontWeight.normal)),
              trailing:
                  selected ? Icon(Icons.check_circle, color: theme.primary) : null,
              onTap: () {
                widget.onThemeChanged(i);
                Navigator.pop(sheetCtx);
              },
            );
          }),
        ]),
      ),
    );
  }

  void _openNotesHistory() {
    final state = ref.read(streakProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('📝 Ваши заметки',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 16),
          if (state.notes.isEmpty)
            const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Пока нет ни одной заметки.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54)))
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: state.notes.length,
                itemBuilder: (_, i) {
                  final note = state.notes[i];
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[800]!)),
                    child:
                        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(note.type,
                                style: TextStyle(
                                    color: widget.currentTheme.primary,
                                    fontWeight: FontWeight.bold)),
                            Text(
                                '${note.date.day}.${note.date.month}.${note.date.year}',
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 12)),
                          ]),
                      const SizedBox(height: 6),
                      Text(note.text,
                          style: const TextStyle(color: Colors.white70)),
                    ]),
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }

  void _openCalendarPlanner() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setModalState) {
          final state = ref.read(streakProvider);
          final dates = _completedDatesThisWeek(state);
          return Padding(
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                        child: Text('📅 Календарь и цели недели',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white))),
                    const SizedBox(height: 20),
                    ...List.generate(7, (i) {
                      final monday = DateTime.now().subtract(
                          Duration(days: DateTime.now().weekday - 1));
                      final target =
                          DateTime(monday.year, monday.month, monday.day + i);
                      final isDone = dates.contains(
                          '${target.year}-${target.month}-${target.day}');
                      final isToday = i == (DateTime.now().weekday - 1);
                      final plan = state.plannedWorkouts[i];
                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isToday
                              ? widget.currentTheme.primary
                                  .withValues(alpha: 0.15)
                              : Colors.black26,
                          border: Border.all(
                              color: isToday
                                  ? widget.currentTheme.primary
                                  : Colors.grey[800]!),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(children: [
                                Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                        color: isDone
                                            ? widget.currentTheme.primary
                                            : Colors.grey[800],
                                        borderRadius: BorderRadius.circular(8)),
                                    child: Text(_weekDays[i],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white))),
                                const SizedBox(width: 16),
                                Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          isToday
                                              ? 'Сегодня'
                                              : 'День #${i + 1}',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: isToday
                                                  ? widget.currentTheme.primary
                                                  : Colors.grey)),
                                      const SizedBox(height: 2),
                                      Text(
                                          plan != null
                                              ? '🎯 Цель: $plan'
                                              : '✨ Цель не задана',
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: plan != null
                                                  ? Colors.white
                                                  : Colors.white60)),
                                    ]),
                              ]),
                              Row(children: [
                                Icon(
                                    isDone
                                        ? Icons.check_circle
                                        : Icons.radio_button_unchecked,
                                    color: isDone
                                        ? widget.currentTheme.primary
                                        : Colors.grey,
                                    size: 22),
                                IconButton(
                                    icon: const Icon(Icons.edit,
                                        size: 20, color: Colors.lightBlueAccent),
                                    onPressed: () => _showSelectPlanDialog(
                                        i, () => setModalState(() {}))),
                              ]),
                            ]),
                      );
                    }),
                  ]),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showSelectPlanDialog(
      int dayIndex, VoidCallback onUpdated) async {
    final notifier = ref.read(streakProvider.notifier);
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('План на ${_weekDays[dayIndex]}',
            style: const TextStyle(color: Colors.white)),
        content: Column(
            mainAxisSize: MainAxisSize.min,
            children: notifier.workoutTypes.map((type) {
              return ListTile(
                  title: Text(type,
                      style: const TextStyle(color: Colors.white70)),
                  onTap: () async {
                    notifier.planWorkout(dayIndex, type);
                    if (!dialogCtx.mounted) return;
                    Navigator.pop(dialogCtx);
                    onUpdated();
                  });
            }).toList()),
        actions: [
          TextButton(
              child: const Text('Сбросить',
                  style: TextStyle(color: Colors.redAccent)),
              onPressed: () async {
                notifier.planWorkout(dayIndex, null);
                if (!dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);
                onUpdated();
              })
        ],
      ),
    );
  }

  void _openAchievementsList() {
    final notifier = ref.read(streakProvider.notifier);
    final state = ref.read(streakProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🏆 Достижения',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: notifier.achievements.length,
              itemBuilder: (_, i) {
                final ach = notifier.achievements[i];
                final unlocked = ach.isSecret
                    ? state.unlockedAchievements.contains(ach.id)
                    : state.regularUnlocked.contains(ach.id);
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: unlocked
                          ? widget.currentTheme.primary.withValues(alpha: 0.15)
                          : Colors.black26,
                      border: Border.all(
                          color: unlocked
                              ? widget.currentTheme.primary
                              : Colors.grey[800]!),
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Icon(unlocked ? ach.icon : Icons.lock_outline,
                        size: 32,
                        color: unlocked
                            ? widget.currentTheme.primary
                            : Colors.grey[700]),
                    const SizedBox(width: 16),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(
                              (ach.isSecret && !unlocked)
                                  ? '🔒 Секретное достижение'
                                  : ach.title,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: unlocked ? Colors.white : Colors.grey)),
                          Text(
                              (ach.isSecret && !unlocked)
                                  ? 'Выполните скрытое условие'
                                  : ach.description,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: unlocked
                                      ? Colors.white70
                                      : Colors.grey[600])),
                        ])),
                    Icon(unlocked ? Icons.check_circle : Icons.lock,
                        color: unlocked
                            ? widget.currentTheme.primary
                            : Colors.grey[700],
                        size: 20),
                  ]),
                );
              },
            ),
          ),
        ]),
      ),
    );
  }

  void _openStatistics() {
    final notifier = ref.read(streakProvider.notifier);
    final state = ref.read(streakProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(
                    child: Text('📊 Аналитика',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white))),
                const SizedBox(height: 24),
                Row(children: [
                  Expanded(
                      child: _buildStatCard(
                          'Тренировок',
                          '${state.totalWorkoutsCompleted}',
                          Icons.fitness_center,
                          widget.currentTheme.primary)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildStatCard(
                          'Рекорд стрика',
                          '${state.maxStreak} дн.',
                          Icons.local_fire_department,
                          widget.currentTheme.secondary)),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                      child: _buildStatCard(
                          'Общее время',
                          _formatTotalTime(state.totalSecondsSpent),
                          Icons.timer,
                          Colors.lightBlueAccent)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _buildStatCard(
                          'Среднее',
                          _formatAverageTime(state.totalSecondsSpent,
                              state.totalWorkoutsCompleted),
                          Icons.hourglass_bottom,
                          Colors.amberAccent)),
                ]),
                const SizedBox(height: 24),
                const Text('📅 Карта активности:',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70)),
                const SizedBox(height: 12),
                Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[850]!)),
                    child: WorkoutHeatmap(
                        sessions: state.sessions,
                        primaryColor: widget.currentTheme.primary,
                        backgroundColor: Colors.grey[850]!)),
                const SizedBox(height: 24),
                const Text('📈 Распределение нагрузок:',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white70)),
                const SizedBox(height: 16),
                ...notifier.workoutTypes.map((type) {
                  final count = state.workoutTypeCounts[type] ?? 0;
                  final percentage = state.totalWorkoutsCompleted > 0
                      ? count / state.totalWorkoutsCompleted
                      : 0.0;
                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[800]!)),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(type,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                Text(
                                    '$count раз (${(percentage * 100).toStringAsFixed(0)}%)',
                                    style: TextStyle(
                                        color: widget.currentTheme.primary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                              ]),
                          const SizedBox(height: 8),
                          ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                  value: percentage,
                                  minHeight: 8,
                                  backgroundColor: Colors.grey[800],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      widget.currentTheme.primary))),
                        ]),
                  );
                }),
              ]),
        ),
      ),
    );
  }
}
