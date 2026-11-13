import 'package:flutter/material.dart';
import 'daily_quest.dart';
import 'workout_note.dart';
import 'workout_session.dart';

class StreakState {
  final int streakCount;
  final int maxStreak;
  final int streakFreezes;
  final DateTime? lastCompletionDate;
  final DateTime? lastGapProcessedDate;
  final int todayWorkoutsCount;
  final int totalWorkoutsCompleted;
  final int totalSecondsSpent;
  final int xp;
  final int crystals;
  final int weeklyXp;
  final DateTime? weekStartDate; // <-- НОВОЕ: дата начала текущей недели
  final bool hasXpBoost;
  final List<TimeOfDay> reminderTimes;
  final List<DailyQuest> dailyQuests;
  final String questDate;
  final String selectedWorkoutType;
  final List<WorkoutSession> sessions;
  final List<WorkoutNote> notes;
  final Map<int, String> plannedWorkouts;
  final Set<String> customWorkoutTypes;
  final Set<String> unlockedAchievements;
  final Set<String> regularUnlocked;
  final Map<String, int> workoutTypeCounts;
  final String userName;
  final int avatarIndex;

  const StreakState({
    this.streakCount = 0,
    this.maxStreak = 0,
    this.streakFreezes = 1,
    this.lastCompletionDate,
    this.lastGapProcessedDate,
    this.todayWorkoutsCount = 0,
    this.totalWorkoutsCompleted = 0,
    this.totalSecondsSpent = 0,
    this.xp = 0,
    this.crystals = 0,
    this.weeklyXp = 0,
    this.weekStartDate,
    this.hasXpBoost = false,
    this.reminderTimes = const [TimeOfDay(hour: 19, minute: 30)],
    this.dailyQuests = const [],
    this.questDate = '',
    this.selectedWorkoutType = 'Силовая',
    this.sessions = const [],
    this.notes = const [],
    this.plannedWorkouts = const {},
    this.customWorkoutTypes = const {},
    this.unlockedAchievements = const {},
    this.regularUnlocked = const {},
    this.workoutTypeCounts = const {},
    this.userName = 'Атлет',
    this.avatarIndex = 0,
  });

  StreakState copyWith({
    int? streakCount,
    int? maxStreak,
    int? streakFreezes,
    DateTime? lastCompletionDate,
    DateTime? lastGapProcessedDate,
    int? todayWorkoutsCount,
    int? totalWorkoutsCompleted,
    int? totalSecondsSpent,
    int? xp,
    int? crystals,
    int? weeklyXp,
    DateTime? weekStartDate,
    bool? hasXpBoost,
    List<TimeOfDay>? reminderTimes,
    List<DailyQuest>? dailyQuests,
    String? questDate,
    String? selectedWorkoutType,
    List<WorkoutSession>? sessions,
    List<WorkoutNote>? notes,
    Map<int, String>? plannedWorkouts,
    Set<String>? customWorkoutTypes,
    Set<String>? unlockedAchievements,
    Set<String>? regularUnlocked,
    Map<String, int>? workoutTypeCounts,
    String? userName,
    int? avatarIndex,
  }) {
    return StreakState(
      streakCount: streakCount ?? this.streakCount,
      maxStreak: maxStreak ?? this.maxStreak,
      streakFreezes: streakFreezes ?? this.streakFreezes,
      lastCompletionDate: lastCompletionDate ?? this.lastCompletionDate,
      lastGapProcessedDate: lastGapProcessedDate ?? this.lastGapProcessedDate,
      todayWorkoutsCount: todayWorkoutsCount ?? this.todayWorkoutsCount,
      totalWorkoutsCompleted: totalWorkoutsCompleted ?? this.totalWorkoutsCompleted,
      totalSecondsSpent: totalSecondsSpent ?? this.totalSecondsSpent,
      xp: xp ?? this.xp,
      crystals: crystals ?? this.crystals,
      weeklyXp: weeklyXp ?? this.weeklyXp,
      weekStartDate: weekStartDate ?? this.weekStartDate,
      hasXpBoost: hasXpBoost ?? this.hasXpBoost,
      reminderTimes: reminderTimes ?? this.reminderTimes,
      dailyQuests: dailyQuests ?? this.dailyQuests,
      questDate: questDate ?? this.questDate,
      selectedWorkoutType: selectedWorkoutType ?? this.selectedWorkoutType,
      sessions: sessions ?? this.sessions,
      notes: notes ?? this.notes,
      plannedWorkouts: plannedWorkouts ?? this.plannedWorkouts,
      customWorkoutTypes: customWorkoutTypes ?? this.customWorkoutTypes,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
      regularUnlocked: regularUnlocked ?? this.regularUnlocked,
      workoutTypeCounts: workoutTypeCounts ?? this.workoutTypeCounts,
      userName: userName ?? this.userName,
      avatarIndex: avatarIndex ?? this.avatarIndex,
    );
  }

  Map<String, dynamic> toJson() => {
        'streak_count': streakCount,
        'max_streak': maxStreak,
        'streak_freezes': streakFreezes,
        'last_completion_date': lastCompletionDate?.toIso8601String(),
        'last_gap_processed_date': lastGapProcessedDate?.toIso8601String(),
        'today_workouts_count': todayWorkoutsCount,
        'total_workouts_completed': totalWorkoutsCompleted,
        'total_seconds_spent': totalSecondsSpent,
        'xp': xp,
        'crystals': crystals,
        'weekly_xp': weeklyXp,
        'week_start_date': weekStartDate?.toIso8601String(),
        'has_xp_boost': hasXpBoost,
        'user_name': userName,
        'avatar_index': avatarIndex,
        'reminder_times': reminderTimes.map((t) => {'hour': t.hour, 'minute': t.minute}).toList(),
        'quest_date': questDate,
        'daily_quests': dailyQuests.map((q) => q.toJson()).toList(),
        'selected_workout_type': selectedWorkoutType,
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'notes': notes.map((n) => n.toJson()).toList(),
        'planned_workouts': plannedWorkouts.map((k, v) => MapEntry(k.toString(), v)),
        'custom_workout_types': customWorkoutTypes.toList(),
        'unlocked_achievements': unlockedAchievements.toList(),
        'regular_achievements': regularUnlocked.toList(),
        'workout_type_counts': workoutTypeCounts,
      };

  factory StreakState.fromJson(Map<String, dynamic> data) {
    // Логика миграции старых напоминаний
    List<TimeOfDay> reminderTimes;
    final list = (data['reminder_times'] as List?) ?? [];
    if (list.isNotEmpty) {
      reminderTimes = list
          .map((e) => TimeOfDay(hour: e['hour'], minute: e['minute']))
          .toList();
    } else {
      final h = (data['reminder_hour'] as num?)?.toInt();
      final m = (data['reminder_minute'] as num?)?.toInt();
      reminderTimes = (h != null && m != null)
          ? [TimeOfDay(hour: h, minute: m)]
          : const [TimeOfDay(hour: 19, minute: 30)];
    }

    return StreakState(
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
      weekStartDate: data['week_start_date'] != null
          ? DateTime.tryParse(data['week_start_date'])
          : null,
      hasXpBoost: data['has_xp_boost'] as bool? ?? false,
      reminderTimes: reminderTimes,
      questDate: (data['quest_date'] as String?) ?? '',
      dailyQuests: ((data['daily_quests'] as List?) ?? [])
          .map((e) => DailyQuest.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      selectedWorkoutType: (data['selected_workout_type'] as String?) ?? 'Силовая',
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
      userName: (data['user_name'] as String?) ?? 'Атлет',
      avatarIndex: (data['avatar_index'] as num?)?.toInt() ?? 0,
    );
  }
}