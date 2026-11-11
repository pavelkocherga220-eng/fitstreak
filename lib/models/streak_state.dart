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
  final bool hasXpBoost;
  final List<TimeOfDay> reminderTimes; // <-- список
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
    this.hasXpBoost = false,
    this.reminderTimes = const [TimeOfDay(hour: 19, minute: 30)], // <-- по умолчанию
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
    bool? hasXpBoost,
    List<TimeOfDay>? reminderTimes, // <-- список
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
}