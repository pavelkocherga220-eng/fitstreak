/// Чистые правила стриков, XP, недель и лимитов: без Riverpod, Hive и Firebase,
/// чтобы их можно было проверять обычными unit-тестами.
library;

/// Максимум секунд, засчитываемых за одну тренировку.
const int maxWorkoutSeconds = 3 * 60 * 60;

int clampWorkoutSeconds(int seconds) => seconds.clamp(0, maxWorkoutSeconds);

/// Сколько XP нужно, чтобы перейти с уровня [level] на следующий.
int xpRequirement(int level) {
  if (level <= 10) return level * 100;
  if (level <= 20) return 1000 + (level - 10) * 500;
  return 6000 + (level - 20) * 1000;
}

({int level, int currentXp, int requiredXp}) levelFromXp(int xp) {
  var level = 1;
  var remaining = xp < 0 ? 0 : xp;
  while (true) {
    final req = xpRequirement(level);
    if (remaining >= req) {
      remaining -= req;
      level++;
    } else {
      return (level: level, currentXp: remaining, requiredXp: req);
    }
  }
}

/// Понедельник той недели, в которую попадает [now] (время 00:00).
DateTime weekStart(DateTime now) =>
    DateTime(now.year, now.month, now.day - (now.weekday - 1));

/// Нужно ли обнулить недельный XP: неделя не сохранена или уже прошла.
bool needsWeekReset(DateTime? savedWeekStart, DateTime currentWeekStart) {
  if (savedWeekStart == null) return true;
  final saved =
      DateTime(savedWeekStart.year, savedWeekStart.month, savedWeekStart.day);
  return saved.isBefore(currentWeekStart);
}

typedef GapResult = ({
  int missed, // сколько полных дней пропущено (0 — ничего)
  int streak,
  int freezes,
  bool streakLost, // стрик сгорел (заморозок не хватило)
});

/// Считает пропущенные дни и тратит заморозки либо сжигает стрик.
/// [lastCompletion] — дата последней тренировки, [lastGapProcessed] — день,
/// когда пропуски уже учитывались (чтобы не списывать заморозки дважды).
GapResult processGap({
  required DateTime lastCompletion,
  required DateTime? lastGapProcessed,
  required DateTime now,
  required int streak,
  required int freezes,
}) {
  DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);
  final today = dateOnly(now);
  final lastDay = dateOnly(lastCompletion);

  final charged = lastGapProcessed == null
      ? lastDay
      : dateOnly(lastGapProcessed).subtract(const Duration(days: 1));

  final anchor = charged.isAfter(lastDay) ? charged : lastDay;
  final missed = today.difference(anchor).inDays - 1;

  if (missed <= 0) {
    return (missed: 0, streak: streak, freezes: freezes, streakLost: false);
  }
  if (freezes >= missed) {
    return (
      missed: missed,
      streak: streak,
      freezes: freezes - missed,
      streakLost: false
    );
  }
  return (missed: missed, streak: 0, freezes: 0, streakLost: true);
}
