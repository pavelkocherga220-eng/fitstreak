import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/logic/streak_logic.dart';

void main() {
  // «Сегодня» — понедельник 16.11.2026
  final now = DateTime(2026, 11, 16, 12, 0);

  GapResult gap({
    required DateTime last,
    DateTime? processed,
    int streak = 10,
    int freezes = 0,
    DateTime? at,
  }) =>
      processGap(
        lastCompletion: last,
        lastGapProcessed: processed,
        now: at ?? now,
        streak: streak,
        freezes: freezes,
      );

  group('Пропущенные дни и заморозки', () {
    test('тренировка вчера — пропусков нет', () {
      final r = gap(last: DateTime(2026, 11, 15));
      expect(r.missed, 0);
      expect(r.streak, 10);
      expect(r.streakLost, false);
    });

    test('тренировка сегодня — пропусков нет', () {
      expect(gap(last: DateTime(2026, 11, 16)).missed, 0);
    });

    test('пропущен 1 день без заморозок — стрик сгорает', () {
      final r = gap(last: DateTime(2026, 11, 14));
      expect(r.missed, 1);
      expect(r.streak, 0);
      expect(r.freezes, 0);
      expect(r.streakLost, true);
    });

    test('пропущен 1 день, есть заморозки — тратится одна', () {
      final r = gap(last: DateTime(2026, 11, 14), freezes: 2);
      expect(r.missed, 1);
      expect(r.streak, 10);
      expect(r.freezes, 1);
      expect(r.streakLost, false);
    });

    test('пропущено 3 дня, заморозок ровно 3 — стрик жив, заморозок 0', () {
      final r = gap(last: DateTime(2026, 11, 12), freezes: 3);
      expect(r.missed, 3);
      expect(r.streak, 10);
      expect(r.freezes, 0);
    });

    test('пропущено 3 дня, заморозок 2 — стрик сгорает, заморозки обнуляются', () {
      final r = gap(last: DateTime(2026, 11, 12), freezes: 2);
      expect(r.missed, 3);
      expect(r.streak, 0);
      expect(r.freezes, 0);
      expect(r.streakLost, true);
    });

    test('повторная проверка в тот же день не списывает заморозку дважды', () {
      final r = gap(
        last: DateTime(2026, 11, 13),
        processed: DateTime(2026, 11, 16),
        freezes: 1,
      );
      expect(r.missed, 0);
      expect(r.freezes, 1);
    });

    test('день, уже учтённый вчера, не считается второй раз', () {
      // Пропуск 14.11 учтён 15.11; сегодня 16.11 пропущен только 15.11
      final r = gap(
        last: DateTime(2026, 11, 13),
        processed: DateTime(2026, 11, 15),
        freezes: 3,
      );
      expect(r.missed, 1);
      expect(r.freezes, 2);
    });

    test('время суток не влияет: 23:59 позавчера → один пропуск', () {
      final r = gap(
        last: DateTime(2026, 11, 14, 23, 59),
        at: DateTime(2026, 11, 16, 0, 1),
        freezes: 1,
      );
      expect(r.missed, 1);
      expect(r.freezes, 0);
    });

    test('смена месяца: 30.11 → 02.12 это один пропущенный день', () {
      final r = gap(
        last: DateTime(2026, 11, 30),
        at: DateTime(2026, 12, 2, 9),
        freezes: 1,
      );
      expect(r.missed, 1);
    });
  });

  group('Уровни и XP', () {
    test('порог XP по диапазонам уровней', () {
      expect(xpRequirement(1), 100);
      expect(xpRequirement(10), 1000);
      expect(xpRequirement(11), 1500);
      expect(xpRequirement(20), 6000);
      expect(xpRequirement(21), 7000);
    });

    test('0 XP — первый уровень', () {
      final i = levelFromXp(0);
      expect((i.level, i.currentXp, i.requiredXp), (1, 0, 100));
    });

    test('99 XP — ещё первый уровень, 100 XP — второй', () {
      expect(levelFromXp(99).level, 1);
      expect(levelFromXp(99).currentXp, 99);
      final i = levelFromXp(100);
      expect((i.level, i.currentXp, i.requiredXp), (2, 0, 200));
    });

    test('5500 XP — ровно начало 11 уровня', () {
      final i = levelFromXp(5500);
      expect((i.level, i.currentXp, i.requiredXp), (11, 0, 1500));
    });

    test('43000 XP — начало 21 уровня', () {
      final i = levelFromXp(43000);
      expect((i.level, i.currentXp, i.requiredXp), (21, 0, 7000));
    });

    test('отрицательный XP не ломает расчёт', () {
      expect(levelFromXp(-50).level, 1);
    });
  });

  group('Недели', () {
    test('понедельник — начало своей недели', () {
      expect(weekStart(DateTime(2026, 11, 16)), DateTime(2026, 11, 16));
    });

    test('среда и воскресенье той же недели', () {
      expect(weekStart(DateTime(2026, 11, 18)), DateTime(2026, 11, 16));
      expect(weekStart(DateTime(2026, 11, 22, 23, 59)), DateTime(2026, 11, 16));
    });

    test('следующий понедельник — новая неделя', () {
      expect(weekStart(DateTime(2026, 11, 23)), DateTime(2026, 11, 23));
    });

    test('граница месяца: 2 декабря → 30 ноября', () {
      expect(weekStart(DateTime(2026, 12, 2)), DateTime(2026, 11, 30));
    });

    test('сброс недельного XP: нет даты, прошлая неделя, текущая', () {
      final current = DateTime(2026, 11, 16);
      expect(needsWeekReset(null, current), true);
      expect(needsWeekReset(DateTime(2026, 11, 9), current), true);
      expect(needsWeekReset(DateTime(2026, 11, 16), current), false);
      expect(needsWeekReset(DateTime(2026, 11, 16, 15, 30), current), false);
    });
  });

  group('Лимит времени тренировки', () {
    test('обычное время не меняется', () {
      expect(clampWorkoutSeconds(1800), 1800);
    });

    test('отрицательное → 0, слишком большое → 3 часа', () {
      expect(clampWorkoutSeconds(-5), 0);
      expect(clampWorkoutSeconds(99999), 10800);
      expect(maxWorkoutSeconds, 10800);
    });
  });
}
