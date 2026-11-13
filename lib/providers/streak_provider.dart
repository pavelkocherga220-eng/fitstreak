import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/achievement.dart';
import '../models/daily_quest.dart';
import '../models/streak_state.dart';
import '../models/workout_note.dart';
import '../models/workout_session.dart';

final streakProvider = NotifierProvider<StreakNotifier, StreakState>(StreakNotifier.new);

class StreakNotifier extends Notifier<StreakState> {
  static const List<String> defaultWorkoutTypes = ['Силовая', 'Кардио', 'Йога', 'Растяжка'];
  
  final List<Achievement> achievements = const [
    Achievement(id: 'first', title: 'Первый шаг', description: 'Завершите 1 тренировку', icon: Icons.flag, requiredStreak: 1),
    Achievement(id: 'week', title: 'Недельный ритм', description: 'Стрик в 7 дней подряд', icon: Icons.local_fire_department, requiredStreak: 7),
    Achievement(id: 'two_weeks', title: 'Железная воля', description: 'Стрик в 14 дней подряд', icon: Icons.bolt, requiredStreak: 14),
    Achievement(id: 'month', title: 'Легенда фитнеса', description: 'Стрик в 30 дней подряд', icon: Icons.military_tech, requiredStreak: 30),
    Achievement(id: 'night_owl', title: '🌙 Ночная мотивация', description: 'Выполните тренировку с 22:00 до 04:00', icon: Icons.nightlight_round, isSecret: true),
    Achievement(id: 'marathoner', title: '🚀 Марафонец', description: 'Выполните 2 тренировки за один день', icon: Icons.flash_on, isSecret: true),
  ];

  @override
  StreakState build() {
    _loadData();
    return const StreakState();
  }

  List<String> get workoutTypes => [...defaultWorkoutTypes, ...state.customWorkoutTypes];

  // ============================================================
  // МИГРАЦИЯ НАПОМИНАНИЙ
  // ============================================================

  List<TimeOfDay> _migrateReminderTimes(Map<String, dynamic> data) {
    final list = (data['reminder_times'] as List?) ?? [];
    if (list.isNotEmpty) {
      return list
          .map((e) => TimeOfDay(hour: e['hour'], minute: e['minute']))
          .toList();
    }

    // миграция со старого формата (одно время)
    final h = (data['reminder_hour'] as num?)?.toInt();
    final m = (data['reminder_minute'] as num?)?.toInt();
    if (h != null && m != null) {
      return [TimeOfDay(hour: h, minute: m)];
    }

    // значение по умолчанию
    return const [TimeOfDay(hour: 19, minute: 30)];
  }

  // ============================================================
  // УРОВНИ И ОПЫТ
  // ============================================================

  int _getXpRequirement(int level) {
    if (level <= 10) return level * 100;
    if (level <= 20) return 1000 + (level - 10) * 500;
    return 6000 + (level - 20) * 1000;
  }

  ({int level, int currentXp, int requiredXp}) get levelInfo {
    int level = 1;
    int xpRemaining = state.xp;
    while (true) {
      final req = _getXpRequirement(level);
      if (xpRemaining >= req) {
        xpRemaining -= req;
        level++;
      } else {
        return (level: level, currentXp: xpRemaining, requiredXp: req);
      }
    }
  }

  int get level => levelInfo.level;
  int get currentLevelXp => levelInfo.currentXp;
  int get requiredLevelXp => levelInfo.requiredXp;
  double get levelProgress => currentLevelXp / requiredLevelXp;

  // ============================================================
  // ЗАГРУЗКА И СОХРАНЕНИЕ
  // ============================================================

  Future<void> _loadData() async {
    final box = await Hive.openBox('fitstreak_box');
    final raw = box.get('fitstreak_data');
    bool loadedSuccessfully = false;

    if (raw != null) {
      try {
        final data = Map<String, dynamic>.from(raw);
        state = StreakState(
          streakCount: (data['streak_count'] as num?)?.toInt() ?? 0,
          maxStreak: (data['max_streak'] as num?)?.toInt() ?? 0,
          streakFreezes: (data['streak_freezes'] as num?)?.toInt() ?? 1,
          lastCompletionDate: data['last_completion_date'] != null
              ? DateTime.tryParse(data['last_completion_date'])
              : null,
          lastGapProcessedDate: data['last_gap_processed_date'] != null
              ? DateTime.tryParse(data['last_gap_processed_date'])
              : null,
          todayWorkoutsCount: (data['today_workouts_count'] as num?)?.toInt() ?? 0,
          totalWorkoutsCompleted: (data['total_workouts_completed'] as num?)?.toInt() ?? 0,
          totalSecondsSpent: (data['total_seconds_spent'] as num?)?.toInt() ?? 0,
          xp: (data['xp'] as num?)?.toInt() ?? 0,
          crystals: (data['crystals'] as num?)?.toInt() ?? 0,
          weeklyXp: (data['weekly_xp'] as num?)?.toInt() ?? 0,
          hasXpBoost: data['has_xp_boost'] as bool? ?? false,
          userName: (data['user_name'] as String?) ?? 'Атлет',
          avatarIndex: (data['avatar_index'] as num?)?.toInt() ?? 0,
          reminderTimes: _migrateReminderTimes(data),
          questDate: (data['quest_date'] as String?) ?? '',
          dailyQuests: ((data['daily_quests'] as List?) ?? [])
              .map((e) => DailyQuest.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
          selectedWorkoutType: (data['selected_workout_type'] as String?) ?? defaultWorkoutTypes.first,
          sessions: ((data['sessions'] as List?) ?? [])
              .map((e) => WorkoutSession.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
          notes: ((data['notes'] as List?) ?? [])
              .map((e) => WorkoutNote.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
          plannedWorkouts: ((data['planned_workouts'] as Map?) ?? {})
              .map((k, v) => MapEntry(int.parse(k.toString()), v.toString())),
          customWorkoutTypes: ((data['custom_workout_types'] as List?) ?? [])
              .map((e) => e.toString())
              .toSet(),
          unlockedAchievements: ((data['unlocked_achievements'] as List?) ?? [])
              .map((e) => e.toString())
              .toSet(),
          regularUnlocked: ((data['regular_achievements'] as List?) ?? [])
              .map((e) => e.toString())
              .toSet(),
          workoutTypeCounts: ((data['workout_type_counts'] as Map?) ?? {})
              .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        );
        loadedSuccessfully = true;
      } catch (e) {
        debugPrint('Ошибка загрузки данных (не перезаписываем!): $e');
        return; // НЕ вызываем saveAll, чтобы не стереть базу
      }
    } else {
      loadedSuccessfully = true;
    }

    if (loadedSuccessfully) {
      processGapIfNeeded();
      generateDailyQuests();
    }
  }

  Future<void> saveAll() async {
    final box = await Hive.openBox('fitstreak_box');
    final data = {
      'streak_count': state.streakCount,
      'max_streak': state.maxStreak,
      'streak_freezes': state.streakFreezes,
      'last_completion_date': state.lastCompletionDate?.toIso8601String(),
      'last_gap_processed_date': state.lastGapProcessedDate?.toIso8601String(),
      'today_workouts_count': state.todayWorkoutsCount,
      'total_workouts_completed': state.totalWorkoutsCompleted,
      'total_seconds_spent': state.totalSecondsSpent,
      'xp': state.xp,
      'crystals': state.crystals,
      'weekly_xp': state.weeklyXp,
      'has_xp_boost': state.hasXpBoost,
      'user_name': state.userName,
      'avatar_index': state.avatarIndex,
      'reminder_times': state.reminderTimes
          .map((t) => {'hour': t.hour, 'minute': t.minute})
          .toList(),
      'quest_date': state.questDate,
      'daily_quests': state.dailyQuests.map((q) => q.toJson()).toList(),
      'selected_workout_type': state.selectedWorkoutType,
      'sessions': state.sessions.map((s) => s.toJson()).toList(),
      'notes': state.notes.map((n) => n.toJson()).toList(),
      'planned_workouts': state.plannedWorkouts.map((k, v) => MapEntry(k.toString(), v)),
      'custom_workout_types': state.customWorkoutTypes.toList(),
      'unlocked_achievements': state.unlockedAchievements.toList(),
      'regular_achievements': state.regularUnlocked.toList(),
      'workout_type_counts': state.workoutTypeCounts,
    };

    await box.put('fitstreak_data', data);

    if (Firebase.apps.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(data, SetOptions(merge: true));

        await FirebaseFirestore.instance
            .collection('leaderboard')
            .doc(user.uid)
            .set({
              'user_name': state.userName,
              'xp': state.xp,
              'avatar_index': state.avatarIndex,
            }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Ошибка сохранения в облако: $e');
      }
    }
  }

  Future<void> loadFromCloud() async {
    if (Firebase.apps.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && doc.data() != null) {
        final cloudData = doc.data()!;
        final box = await Hive.openBox('fitstreak_box');
        await box.put('fitstreak_data', cloudData);
        await _loadData();
        debugPrint('Данные успешно загружены из облака');
      } else {
        await saveAll();
        debugPrint('Облако пустое. Локальные данные отправлены в облако.');
      }
    } catch (e) {
      debugPrint('Ошибка загрузки из облака: $e');
    }
  }

  // ============================================================
  // СТРИКИ И ЗАМОРОЗКИ
  // ============================================================

  void processGapIfNeeded() {
    if (state.lastCompletionDate == null) return;

    DateTime dateOnly(DateTime d) => DateTime.utc(d.year, d.month, d.day);
    final today = dateOnly(DateTime.now());
    final lastDay = dateOnly(state.lastCompletionDate!);

    final charged = state.lastGapProcessedDate == null
        ? lastDay
        : dateOnly(state.lastGapProcessedDate!).subtract(const Duration(days: 1));

    final anchor = charged.isAfter(lastDay) ? charged : lastDay;
    final missed = today.difference(anchor).inDays - 1;

    if (missed > 0) {
      int newStreak = state.streakCount;
      int newFreezes = state.streakFreezes;
      final newPlanned = Map<int, String>.from(state.plannedWorkouts);

      if (newFreezes >= missed) {
        newFreezes -= missed;
      } else {
        newStreak = 0;
        newFreezes = 0;
        newPlanned.clear();
      }

      state = state.copyWith(
        streakCount: newStreak,
        streakFreezes: newFreezes,
        plannedWorkouts: newPlanned,
        lastGapProcessedDate: today,
        todayWorkoutsCount: 0,
      );
      saveAll();
    } else if (state.lastGapProcessedDate == null ||
        !dateOnly(state.lastGapProcessedDate!).isAtSameMomentAs(today)) {
      state = state.copyWith(lastGapProcessedDate: today);
      saveAll();
    }
  }

  // ============================================================
  // КВЕСТЫ
  // ============================================================

  void generateDailyQuests() {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month}-${now.day}';
    if (state.questDate == todayStr && state.dailyQuests.length == 3) return;

    final pool = [
      {'id': 'min_15', 'title': 'Тренируйся 15 минут', 'xp': 50},
      {'id': 'min_30', 'title': 'Тренируйся 30 минут', 'xp': 100},
      {'id': 'double', 'title': 'Заверши 2 тренировки за день', 'xp': 150},
      {'id': 'early', 'title': 'Заверши тренировку до 12:00', 'xp': 50},
      {'id': 'night', 'title': 'Заверши тренировку после 20:00', 'xp': 50},
    ];
    pool.shuffle(Random());

    final newQuests = [
      DailyQuest(id: pool[0]['id'] as String, title: pool[0]['title'] as String, xpReward: pool[0]['xp'] as int),
      DailyQuest(id: pool[1]['id'] as String, title: pool[1]['title'] as String, xpReward: pool[1]['xp'] as int),
    ];

    final randomType = workoutTypes[Random().nextInt(workoutTypes.length)];
    newQuests.add(DailyQuest(id: 'type_$randomType', title: 'Попробуй тип "$randomType"', xpReward: 50));

    state = state.copyWith(questDate: todayStr, dailyQuests: newQuests);
    saveAll();
  }

  void evaluateQuests() {
    bool changed = false;
    final today = DateTime.now();
    final todaySessions = state.sessions
        .where((s) => s.date.year == today.year && s.date.month == today.month && s.date.day == today.day)
        .toList();
    final todaySeconds = todaySessions.fold(0, (total, s) => total + s.durationSeconds);
    final todayCount = todaySessions.length;

    final updatedQuests = state.dailyQuests.map((quest) {
      if (quest.isCompleted) return quest;

      bool completed = false;
      if (quest.id == 'min_15') {
        completed = todaySeconds >= 15 * 60;
      } else if (quest.id == 'min_30') {
        completed = todaySeconds >= 30 * 60;
      } else if (quest.id == 'double') {
        completed = todayCount >= 2;
      } else if (quest.id == 'early') {
        completed = todaySessions.any((s) => s.date.hour < 12);
      } else if (quest.id == 'night') {
        completed = todaySessions.any((s) => s.date.hour >= 20);
      } else if (quest.id.startsWith('type_')) {
        final typeName = quest.id.substring(5);
        completed = todaySessions.any((s) => s.type == typeName);
      }

      if (completed) {
        quest.isCompleted = true;
        final rand = Random().nextDouble();
        if (rand < 0.05) {
          quest.chestRarity = ChestRarity.legendary;
        } else if (rand < 0.20) {
          quest.chestRarity = ChestRarity.epic;
        } else if (rand < 0.50) {
          quest.chestRarity = ChestRarity.rare;
        } else {
          quest.chestRarity = ChestRarity.common;
        }
        changed = true;
      }
      return quest;
    }).toList();

    if (changed) {
      state = state.copyWith(dailyQuests: updatedQuests);
      saveAll();
    }
  }

  // ============================================================
  // ЗАВЕРШЕНИЕ ТРЕНИРОВКИ
  // ============================================================

  Future<({bool leveledUp, List<Achievement> newAchievements, bool boostApplied})>
      finishWorkout(int seconds, String note, {required String type}) async {
    final oldLevel = level;
    final now = DateTime.now();
    final wasCompletedToday = state.lastCompletionDate != null &&
        state.lastCompletionDate!.year == now.year &&
        state.lastCompletionDate!.month == now.month &&
        state.lastCompletionDate!.day == now.day;

    final newSession = WorkoutSession(date: now, type: type, durationSeconds: seconds);
    final newSessions = [...state.sessions, newSession];
    if (newSessions.length > 365) newSessions.removeAt(0);

    int baseXp = 10 + (seconds ~/ 60) * 10;
    int earnedXp = baseXp;
    bool boostApplied = state.hasXpBoost;
    if (boostApplied) earnedXp *= 2;

    final newNotes = note.trim().isNotEmpty
        ? [WorkoutNote(type: type, text: note.trim(), date: now), ...state.notes]
        : state.notes;

    final counts = Map<String, int>.from(state.workoutTypeCounts);
    counts[type] = (counts[type] ?? 0) + 1;

    state = state.copyWith(
      streakCount: wasCompletedToday ? state.streakCount : state.streakCount + 1,
      lastCompletionDate: now,
      totalWorkoutsCompleted: state.totalWorkoutsCompleted + 1,
      totalSecondsSpent: state.totalSecondsSpent + seconds,
      xp: state.xp + earnedXp,
      weeklyXp: state.weeklyXp + earnedXp,
      hasXpBoost: false,
      sessions: newSessions,
      notes: newNotes,
      todayWorkoutsCount: wasCompletedToday ? state.todayWorkoutsCount + 1 : 1,
      workoutTypeCounts: counts,
    );

    evaluateQuests();

    final newlyUnlocked = <Achievement>[];
    final nowTime = DateTime.now();

    final regUnlocked = Set<String>.from(state.regularUnlocked);
    for (var ach in achievements) {
      if (ach.isSecret) continue;
      if (state.streakCount >= ach.requiredStreak && !regUnlocked.contains(ach.id)) {
        regUnlocked.add(ach.id);
        newlyUnlocked.add(ach);
      }
    }

    final secUnlocked = Set<String>.from(state.unlockedAchievements);
    if ((nowTime.hour >= 22 || nowTime.hour < 4) && !secUnlocked.contains('night_owl')) {
      secUnlocked.add('night_owl');
      newlyUnlocked.add(achievements.firstWhere((a) => a.id == 'night_owl'));
    }
    if (state.todayWorkoutsCount >= 2 && !secUnlocked.contains('marathoner')) {
      secUnlocked.add('marathoner');
      newlyUnlocked.add(achievements.firstWhere((a) => a.id == 'marathoner'));
    }

    state = state.copyWith(regularUnlocked: regUnlocked, unlockedAchievements: secUnlocked);

    if (state.streakCount > state.maxStreak) {
      state = state.copyWith(maxStreak: state.streakCount);
    }

    await saveAll();
    return (leveledUp: level > oldLevel, newAchievements: newlyUnlocked, boostApplied: boostApplied);
  }

  // ============================================================
  // СУНДУКИ И МАГАЗИН
  // ============================================================

  Future<int> openChest(DailyQuest quest) async {
    if (quest.chestRarity == null || quest.isRewardClaimed) return 0;

    int gems = 0;
    switch (quest.chestRarity!) {
      case ChestRarity.common:
        gems = 10 + Random().nextInt(11);
        break;
      case ChestRarity.rare:
        gems = 30 + Random().nextInt(21);
        break;
      case ChestRarity.epic:
        gems = 80 + Random().nextInt(41);
        break;
      case ChestRarity.legendary:
        gems = 200 + Random().nextInt(101);
        break;
    }

    quest.isRewardClaimed = true;
    state = state.copyWith(crystals: state.crystals + gems, xp: state.xp + quest.xpReward);
    await saveAll();
    return gems;
  }

  Future<bool> buyItem(String itemId) async {
    if (itemId == 'freeze') {
      if (state.crystals < 100) return false;
      state = state.copyWith(
        crystals: state.crystals - 100,
        streakFreezes: state.streakFreezes + 1,
      );
      await saveAll();
      return true;
    }

    if (itemId == 'xp_boost') {
      if (state.crystals < 150 || state.hasXpBoost) return false;
      state = state.copyWith(crystals: state.crystals - 150, hasXpBoost: true);
      await saveAll();
      return true;
    }

    return false;
  }

  // ============================================================
  // ПРОЧИЕ СЕТТЕРЫ
  // ============================================================

  void setReminderTimes(List<TimeOfDay> times) {
    state = state.copyWith(reminderTimes: times);
    saveAll();
  }

  void selectWorkoutType(String type) {
    state = state.copyWith(selectedWorkoutType: type);
    saveAll();
  }

  void planWorkout(int dayIndex, String? type) {
    final newMap = Map<int, String>.from(state.plannedWorkouts);
    if (type == null) {
      newMap.remove(dayIndex);
    } else {
      newMap[dayIndex] = type;
    }
    state = state.copyWith(plannedWorkouts: newMap);
    saveAll();
  }

  void addCustomWorkoutType(String type) {
    if (type.isEmpty || workoutTypes.contains(type)) return;
    final newSet = Set<String>.from(state.customWorkoutTypes)..add(type);
    final counts = Map<String, int>.from(state.workoutTypeCounts)..[type] = 0;
    state = state.copyWith(customWorkoutTypes: newSet, workoutTypeCounts: counts, selectedWorkoutType: type);
    saveAll();
  }

  void updateUserName(String name) {
    if (name.trim().isEmpty) return;
    state = state.copyWith(userName: name.trim());
    saveAll();
  }

  void updateAvatar(int index) {
    state = state.copyWith(avatarIndex: index);
    saveAll();
  }

  // ============================================================
  // ЭКСПОРТ / ИМПОРТ
  // ============================================================

  String exportJson() {
    final data = {
      'streak_count': state.streakCount,
      'max_streak': state.maxStreak,
      'streak_freezes': state.streakFreezes,
      'last_completion_date': state.lastCompletionDate?.toIso8601String(),
      'last_gap_processed_date': state.lastGapProcessedDate?.toIso8601String(),
      'today_workouts_count': state.todayWorkoutsCount,
      'total_workouts_completed': state.totalWorkoutsCompleted,
      'total_seconds_spent': state.totalSecondsSpent,
      'xp': state.xp,
      'crystals': state.crystals,
      'weekly_xp': state.weeklyXp,
      'has_xp_boost': state.hasXpBoost,
      'user_name': state.userName,
      'avatar_index': state.avatarIndex,
      'reminder_times': state.reminderTimes
          .map((t) => {'hour': t.hour, 'minute': t.minute})
          .toList(),
      'quest_date': state.questDate,
      'daily_quests': state.dailyQuests.map((q) => q.toJson()).toList(),
      'selected_workout_type': state.selectedWorkoutType,
      'sessions': state.sessions.map((s) => s.toJson()).toList(),
      'notes': state.notes.map((n) => n.toJson()).toList(),
      'planned_workouts': state.plannedWorkouts.map((k, v) => MapEntry(k.toString(), v)),
      'custom_workout_types': state.customWorkoutTypes.toList(),
      'unlocked_achievements': state.unlockedAchievements.toList(),
      'regular_achievements': state.regularUnlocked.toList(),
      'workout_type_counts': state.workoutTypeCounts,
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> importJson(String jsonString) async {
    final data = jsonDecode(jsonString) as Map<String, dynamic>;
    state = StreakState(
      streakCount: (data['streak_count'] as num?)?.toInt() ?? 0,
      maxStreak: (data['max_streak'] as num?)?.toInt() ?? 0,
      streakFreezes: (data['streak_freezes'] as num?)?.toInt() ?? 1,
      lastCompletionDate: data['last_completion_date'] != null
          ? DateTime.tryParse(data['last_completion_date'])
          : null,
      lastGapProcessedDate: data['last_gap_processed_date'] != null
          ? DateTime.tryParse(data['last_gap_processed_date'])
          : null,
      todayWorkoutsCount: (data['today_workouts_count'] as num?)?.toInt() ?? 0,
      totalWorkoutsCompleted: (data['total_workouts_completed'] as num?)?.toInt() ?? 0,
      totalSecondsSpent: (data['total_seconds_spent'] as num?)?.toInt() ?? 0,
      xp: (data['xp'] as num?)?.toInt() ?? 0,
      crystals: (data['crystals'] as num?)?.toInt() ?? 0,
      weeklyXp: (data['weekly_xp'] as num?)?.toInt() ?? 0,
      hasXpBoost: data['has_xp_boost'] as bool? ?? false,
      userName: (data['user_name'] as String?) ?? 'Атлет',
      avatarIndex: (data['avatar_index'] as num?)?.toInt() ?? 0,
      reminderTimes: _migrateReminderTimes(data),
      questDate: (data['quest_date'] as String?) ?? '',
      dailyQuests: ((data['daily_quests'] as List?) ?? [])
          .map((e) => DailyQuest.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      selectedWorkoutType: (data['selected_workout_type'] as String?) ?? defaultWorkoutTypes.first,
      sessions: ((data['sessions'] as List?) ?? [])
          .map((e) => WorkoutSession.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      notes: ((data['notes'] as List?) ?? [])
          .map((e) => WorkoutNote.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      plannedWorkouts: ((data['planned_workouts'] as Map?) ?? {})
          .map((k, v) => MapEntry(int.parse(k.toString()), v.toString())),
      customWorkoutTypes: ((data['custom_workout_types'] as List?) ?? [])
          .map((e) => e.toString())
          .toSet(),
      unlockedAchievements: ((data['unlocked_achievements'] as List?) ?? [])
          .map((e) => e.toString())
          .toSet(),
      regularUnlocked: ((data['regular_achievements'] as List?) ?? [])
          .map((e) => e.toString())
          .toSet(),
      workoutTypeCounts: ((data['workout_type_counts'] as Map?) ?? {})
          .map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
    );
    await saveAll();
  }
}