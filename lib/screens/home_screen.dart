import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:home_widget/home_widget.dart';
import 'package:vibration/vibration.dart';

import '../models/achievement.dart';
import '../models/app_theme.dart';
import '../models/daily_quest.dart';
import '../models/streak_state.dart';
import '../providers/streak_provider.dart';
import '../services/notification_service.dart';
import '../sound/sound_player.dart';
import '../widgets/workout_heatmap.dart';
import '../widgets/widget_ui.dart';
import 'profile_screen.dart';
import 'league_screen.dart';

bool _isSameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return false;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

class StreakHomeScreen extends ConsumerStatefulWidget {
  final AppThemeData currentTheme;
  final List<AppThemeData> themes;
  final int selectedThemeIndex;
  final ValueChanged<int> onThemeChanged;

  const StreakHomeScreen({
    super.key,
    required this.currentTheme,
    required this.themes,
    required this.selectedThemeIndex,
    required this.onThemeChanged,
  });

  @override
  ConsumerState<StreakHomeScreen> createState() => _StreakHomeScreenState();
}

class _StreakHomeScreenState extends ConsumerState<StreakHomeScreen>
    with WidgetsBindingObserver {
  bool _isWorkoutActive = false;
  bool _isPreparing = false;
  int _prepareCountdown = 5;
  DateTime? _workoutStartTime;
  Timer? _workoutTimer;

  String _workoutMode = 'Классический';
  int _intervalWorkTime = 30;
  int _intervalRestTime = 15;
  int _intervalRounds = 8;
  int _totalSecondsSpentInSession = 0;
  int _phaseTimeLeft = 0;
  bool _isResting = false;
  int _currentRound = 1;

  final List<String> _weekDays = const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // initNotifications() уже вызван в main.dart — здесь не дублируем.
    _onAppStart();
  }

  // Ждём реальной загрузки Hive (а не фиксированную задержку), затем
  // планируем напоминания и один раз проверяем «стрик под угрозой».
  Future<void> _onAppStart() async {
    await ref.read(streakProvider.notifier).ready;
    if (!mounted) return;
    await _rescheduleReminders();
    _showAutoClaimed();
    _checkSmartReminder();
  }

  // Сводка автоначисленных наград за неоткрытые сундуки прошлого дня
  void _showAutoClaimed() {
    if (!mounted) return;
    final r = ref.read(streakProvider.notifier).takeAutoClaimed();
    if (r == null) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
          '🎁 Неоткрытые сундуки засчитаны: +${r.gems} 💎, +${r.xp} XP'),
      backgroundColor: Colors.green,
    ));
  }

  Future<void> _rescheduleReminders() async {
    if (!mounted) return;
    final state = ref.read(streakProvider);
    try {
      await scheduleReminders(state.reminderTimes);
    } catch (e) {
      debugPrint('scheduleReminders error: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _workoutTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // Смена дня / недели / квестов / заморозок после сворачивания
      // Без smart-проверки: пользователь уже в приложении, уведомление было бы спамом
      () async {
        await ref.read(streakProvider.notifier).reloadState();
        await _rescheduleReminders();
        _showAutoClaimed();
      }();
    }
  }

  void _checkSmartReminder() {
    if (!mounted) return;
    final state = ref.read(streakProvider);
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    for (final time in state.reminderTimes) {
      final targetMinutes = time.hour * 60 + time.minute;
      if (currentMinutes >= targetMinutes &&
          !_isSameDay(state.lastCompletionDate, now)) {
        showNotification('⚠️ Стрик под угрозой!',
            'Ты еще не тренировался сегодня. Самое время размяться! 🔥');
        break;
      }
    }
  }

  void _startWorkoutTimer() {
    playSound('countdown');
    _totalSecondsSpentInSession = 0;
    _currentRound = 1;
    _isResting = false;
    _workoutStartTime = null;

    if (_workoutMode != 'Классический') {
      _phaseTimeLeft = _intervalWorkTime;
    }

    setState(() {
      _isWorkoutActive = true;
      _isPreparing = true;
      _prepareCountdown = 5;
    });

    _workoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      // --- 5-СЕКУНДНАЯ ПОДГОТОВКА ---
      if (_isPreparing) {
        setState(() {
          _prepareCountdown--;
          if (_prepareCountdown <= 0) {
            _isPreparing = false;
            _workoutStartTime = DateTime.now();
          }
        });
        return;
      }
      // --------------------------------

      // --- ОСНОВНАЯ ТРЕНИРОВКА ---
      setState(() {
        if (_workoutStartTime != null) {
          _totalSecondsSpentInSession =
              DateTime.now().difference(_workoutStartTime!).inSeconds;
        } else {
          _totalSecondsSpentInSession++;
        }

        if (_workoutMode != 'Классический') {
          _phaseTimeLeft--;

          if (_phaseTimeLeft <= 0) {
            Vibration.hasVibrator().then((hasVibrator) {
              if (hasVibrator == true) {
                Vibration.vibrate(pattern: [0, 500, 200, 500]);
              }
            });
            playSound('beep');

            if (_isResting) {
              _isResting = false;
              _currentRound++;

              if (_currentRound > _intervalRounds) {
                _finishWorkout();
                return;
              }
              _phaseTimeLeft = _intervalWorkTime;
            } else {
              _isResting = true;
              _phaseTimeLeft = _intervalRestTime;
            }
          }
        }
      });
    });
  }

  Future<void> _finishWorkout() async {
    _workoutTimer?.cancel();
    playSound('finish');

    final sessionSeconds = _totalSecondsSpentInSession;
    final wasCapped = sessionSeconds > StreakNotifier.maxWorkoutSeconds;

    if (sessionSeconds < 10) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Тренировка слишком короткая (менее 10 сек), не засчитана.')));
      }
      setState(() {
        _isWorkoutActive = false;
        _isPreparing = false;
        _workoutStartTime = null;
      });
      return;
    }

    setState(() {
      _isWorkoutActive = false;
      _isPreparing = false;
      _workoutStartTime = null;
    });

    final note = await _showNoteInputDialog();
    if (!mounted) return;

    final state = ref.read(streakProvider);
    final result = await ref.read(streakProvider.notifier).finishWorkout(
          sessionSeconds,
          note ?? '',
          type: state.selectedWorkoutType,
        );

    if (!mounted) return;

    if (wasCapped) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Время тренировки ограничено 3 часами (таймер работал слишком долго).')));
    }

    if (result.boostApplied) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('⚡ Двойной опыт применен!'),
            backgroundColor: Colors.amber),
      );
    }

    if (result.leveledUp) {
      playSound('achievement');
      await _showLevelUpDialog();
    }

    for (var ach in result.newAchievements) {
      if (!mounted) break;
      playSound('achievement');
      await _showAchievementDialog(ach);
    }
  }

  void _showStartWorkoutSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (_, setModalState) {
          final currentState = ref.watch(streakProvider);
          final notifier = ref.read(streakProvider.notifier);

          return Padding(
            padding:
                EdgeInsets.only(bottom: MediaQuery.of(sheetCtx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Выберите направление',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white)),
                      IconButton(
                        icon: Icon(Icons.add_circle_outline,
                            color: widget.currentTheme.primary),
                        onPressed: () {
                          Navigator.pop(sheetCtx);
                          _showAddCustomWorkoutDialog();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: notifier.workoutTypes.map((type) {
                      final isSelected =
                          currentState.selectedWorkoutType == type;
                      return ChoiceChip(
                        label: Text(type),
                        selected: isSelected,
                        selectedColor: widget.currentTheme.primary,
                        backgroundColor: const Color(0xFF1E1E1E),
                        labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.bold),
                        onSelected: (_) {
                          notifier.selectWorkoutType(type);
                          setModalState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  const Text('Режим тренировки:',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Классический', 'Интервалы', 'Табата']
                        .map((mode) {
                      final isSelected = _workoutMode == mode;
                      return ChoiceChip(
                        label: Text(mode),
                        selected: isSelected,
                        selectedColor: widget.currentTheme.secondary,
                        backgroundColor: const Color(0xFF1E1E1E),
                        labelStyle: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontWeight: FontWeight.bold),
                        onSelected: (_) {
                          setModalState(() {
                            _workoutMode = mode;
                            if (mode == 'Табата') {
                              _intervalWorkTime = 20;
                              _intervalRestTime = 10;
                              _intervalRounds = 8;
                            } else if (mode == 'Интервалы') {
                              _intervalWorkTime = 30;
                              _intervalRestTime = 15;
                              _intervalRounds = 10;
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (_workoutMode != 'Классический') ...[
                    const SizedBox(height: 24),
                    const Divider(color: Colors.white24),
                    const SizedBox(height: 16),
                    Text('Время работы: $_intervalWorkTime сек',
                        style: const TextStyle(color: Colors.white)),
                    Slider(
                        value: _intervalWorkTime.toDouble(),
                        min: 10,
                        max: 120,
                        divisions: 22,
                        activeColor: widget.currentTheme.primary,
                        onChanged: (v) =>
                            setModalState(() => _intervalWorkTime = v.toInt())),
                    Text('Время отдыха: $_intervalRestTime сек',
                        style: const TextStyle(color: Colors.white)),
                    Slider(
                        value: _intervalRestTime.toDouble(),
                        min: 5,
                        max: 60,
                        divisions: 11,
                        activeColor: Colors.blueAccent,
                        onChanged: (v) =>
                            setModalState(() => _intervalRestTime = v.toInt())),
                    Text('Раунды: $_intervalRounds',
                        style: const TextStyle(color: Colors.white)),
                    Slider(
                        value: _intervalRounds.toDouble(),
                        min: 1,
                        max: 20,
                        divisions: 19,
                        activeColor: widget.currentTheme.secondary,
                        onChanged: (v) =>
                            setModalState(() => _intervalRounds = v.toInt())),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _startWorkoutTimer();
                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Поехали!'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: widget.currentTheme.primary,
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<String?> _showNoteInputDialog() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text('📝 Заметка к тренировке',
              style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: controller,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
                hintText: 'Например: Сделал 3 подхода...',
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
          actions: [
            TextButton(
                child: const Text('Пропустить',
                    style: TextStyle(color: Colors.grey)),
                onPressed: () => Navigator.pop(dialogCtx, null)),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: widget.currentTheme.primary),
                child:
                    const Text('Сохранить', style: TextStyle(color: Colors.white)),
                onPressed: () => Navigator.pop(dialogCtx, controller.text)),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _showLevelUpDialog() async {
    final notifier = ref.read(streakProvider.notifier);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(children: [
          Icon(Icons.auto_awesome, size: 60, color: widget.currentTheme.secondary),
          const SizedBox(height: 12),
          const Text('🎉 Новый уровень!',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Уровень ${notifier.level}',
              style: TextStyle(
                  color: widget.currentTheme.primary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Отличная работа! Вы становитесь сильнее.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 14)),
        ]),
        actions: [
          Center(
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: widget.currentTheme.secondary),
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Продолжаем!',
                      style: TextStyle(color: Colors.white))))
        ],
      )
          .animate()
          .scaleXY(begin: 0.5, duration: 400.ms, curve: Curves.elasticOut)
          .fadeIn(duration: 200.ms),
    );
  }

  Future<void> _showAchievementDialog(Achievement ach) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Column(children: [
          const Icon(Icons.emoji_events, size: 50, color: Colors.amber),
          const SizedBox(height: 12),
          const Text('Новое достижение!',
              style: TextStyle(color: Colors.white, fontSize: 20)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(ach.title,
              style: TextStyle(
                  color: widget.currentTheme.primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(ach.description,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
        ]),
        actions: [
          Center(
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: widget.currentTheme.primary),
                  onPressed: () => Navigator.pop(dialogCtx),
                  child:
                      const Text('Круто!', style: TextStyle(color: Colors.white))))
        ],
      )
          .animate()
          .scaleXY(begin: 0.5, duration: 400.ms, curve: Curves.elasticOut)
          .fadeIn(duration: 200.ms),
    );
  }

  void _openChest(DailyQuest quest) async {
    final gems = await ref.read(streakProvider.notifier).openChest(quest);
    if (gems == 0 || !mounted) return;

    playSound('achievement');
    Color color = quest.chestRarity == ChestRarity.legendary
        ? Colors.amber
        : quest.chestRarity == ChestRarity.epic
            ? Colors.purpleAccent
            : quest.chestRarity == ChestRarity.rare
                ? Colors.blueAccent
                : Colors.grey[400]!;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: color, width: 2)),
        title: Column(children: [
          Icon(Icons.card_giftcard, size: 60, color: color),
          const SizedBox(height: 12),
          Text('Сундук открыт!',
              style: TextStyle(
                  color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Вы получили:',
              style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Column(children: [
              const Icon(Icons.diamond, color: Colors.cyanAccent, size: 32),
              Text('+$gems',
                  style: const TextStyle(
                      color: Colors.cyanAccent,
                      fontSize: 24,
                      fontWeight: FontWeight.bold))
            ]),
            const SizedBox(width: 32),
            Column(children: [
              const Icon(Icons.star, color: Colors.amber, size: 32),
              Text('+${quest.xpReward}',
                  style: const TextStyle(
                      color: Colors.amber,
                      fontSize: 24,
                      fontWeight: FontWeight.bold))
            ]),
          ]),
        ]),
        actions: [
          Center(
              child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: color),
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: const Text('Забрать!',
                      style: TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold))))
        ],
      )
          .animate()
          .scaleXY(begin: 0.0, duration: 500.ms, curve: Curves.elasticOut)
          .fadeIn(duration: 200.ms),
    );
  }

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

  Future<void> _exportData() async {
    final jsonString = ref.read(streakProvider.notifier).exportJson();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: jsonString);

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('💾 Экспорт данных',
            style: TextStyle(color: Colors.white)),
        content: TextField(
            readOnly: true,
            maxLines: 8,
            controller: controller,
            style: const TextStyle(color: Colors.greenAccent, fontSize: 11),
            decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black38,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)))),
        actions: [
          TextButton(
              child: const Text('Копировать',
                  style: TextStyle(color: Colors.lightBlueAccent)),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: jsonString));
                if (!dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);
                messenger.showSnackBar(
                    const SnackBar(content: Text('Бэкап скопирован')));
              }),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: widget.currentTheme.primary),
              child: const Text('Закрыть',
                  style: TextStyle(color: Colors.white)),
              onPressed: () => Navigator.pop(dialogCtx)),
        ],
      ),
    );
    controller.dispose();
  }

  Future<void> _importDataDialog() async {
    final importController = TextEditingController();
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('📥 Импорт данных',
            style: TextStyle(color: Colors.white)),
        content: TextField(
            controller: importController,
            maxLines: 8,
            style: const TextStyle(color: Colors.white, fontSize: 11),
            decoration: InputDecoration(
                hintText: 'Вставьте код...',
                filled: true,
                fillColor: Colors.black38,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)))),
        actions: [
          TextButton(
              child:
                  const Text('Отмена', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.pop(dialogCtx)),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text('Восстановить',
                  style: TextStyle(color: Colors.white)),
              onPressed: () async {
                try {
                  await ref
                      .read(streakProvider.notifier)
                      .importJson(importController.text);
                  if (!dialogCtx.mounted) return;
                  Navigator.pop(dialogCtx);
                  messenger.showSnackBar(
                      const SnackBar(content: Text('Данные восстановлены')));
                } catch (_) {
                  messenger.showSnackBar(
                      const SnackBar(content: Text('Ошибка импорта')));
                }
              }),
        ],
      ),
    );
    importController.dispose();
  }

  Future<void> _showAddCustomWorkoutDialog() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('➕ Новое направление',
            style: TextStyle(color: Colors.white)),
        content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
                hintText: 'Пилатес, Бег...',
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)))),
        actions: [
          TextButton(
              child:
                  const Text('Отмена', style: TextStyle(color: Colors.grey)),
              onPressed: () => Navigator.pop(dialogCtx)),
          ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: widget.currentTheme.primary),
              child:
                  const Text('Добавить', style: TextStyle(color: Colors.white)),
              onPressed: () async {
                ref
                    .read(streakProvider.notifier)
                    .addCustomWorkoutType(controller.text.trim());
                if (!dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);
              }),
        ],
      ),
    );
    controller.dispose();
  }

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

  Widget _buildLoadFailedBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠️ Не удалось прочитать сохранённые данные',
              style: TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text(
              'Прогресс в этой сессии не сохраняется, чтобы не затереть старые данные. '
              'Скопируйте резервную копию и сохраните её, затем восстановите через импорт.',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Скопировать резервную копию'),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final json =
                  await ref.read(streakProvider.notifier).readBackupJson();
              if (json == null) {
                messenger.showSnackBar(
                    const SnackBar(content: Text('Резервная копия не найдена')));
                return;
              }
              await Clipboard.setData(ClipboardData(text: json));
              messenger.showSnackBar(
                  const SnackBar(content: Text('Резервная копия скопирована')));
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(streakProvider);
    final notifier = ref.read(streakProvider.notifier);
    final completedDates = _completedDatesThisWeek(state);
    final todayIndex = (DateTime.now().weekday - 1).clamp(0, 6);

    if (!kIsWeb) {
      ref.listen(streakProvider, (previous, next) {
        HomeWidget.renderFlutterWidget(
          FitStreakWidgetUI(
              state: next, primaryColor: widget.currentTheme.primary),
          logicalSize: const Size(400, 200),
          key: 'widget_image',
        ).then((_) {
          HomeWidget.updateWidget(
              name: 'FitStreakWidget', androidName: 'FitStreakWidget');
        }).catchError((e) => debugPrint('Ошибка виджета: $e'));
      });
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('🔥 FitStreak'),
        centerTitle: true,
        actions: [
          Center(
              child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.diamond,
                        size: 16, color: Colors.cyanAccent),
                    const SizedBox(width: 4),
                    Text('${state.crystals}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.cyanAccent)),
                  ]))),
          IconButton(
              icon: const Icon(Icons.person, color: Colors.white),
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => ProfileScreen(
                              primaryColor: widget.currentTheme.primary,
                              secondaryColor: widget.currentTheme.secondary,
                              onExport: _exportData,
                              onImport: _importDataDialog,
                              onTheme: _openThemeSelector,
                            )));
              }),
        ],
      ),
      drawer: Drawer(
        backgroundColor: const Color(0xFF1E1E1E),
        child: ListView(padding: EdgeInsets.zero, children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [
                      widget.currentTheme.primary,
                      widget.currentTheme.secondary
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight)),
            currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white24,
                child: const Icon(Icons.person, size: 40, color: Colors.white)),
            accountName: Text(state.userName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            accountEmail: Text('Уровень ${notifier.level}',
                style: const TextStyle(color: Colors.white70, fontSize: 14)),
          ),
          ListTile(
              leading: const Icon(Icons.emoji_events, color: Colors.amber),
              title: const Text('Достижения',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _openAchievementsList();
              }),
          ListTile(
              leading:
                  const Icon(Icons.leaderboard, color: Colors.lightGreenAccent),
              title:
                  const Text('Лига (Лидеры)', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => LeagueScreen(
                            primaryColor: widget.currentTheme.primary,
                            secondaryColor: widget.currentTheme.secondary)));
              }),
          ListTile(
              leading:
                  const Icon(Icons.calendar_month, color: Colors.lightBlueAccent),
              title: const Text('Календарь',
                  style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _openCalendarPlanner();
              }),
          ListTile(
              leading: Icon(Icons.bar_chart, color: widget.currentTheme.primary),
              title:
                  const Text('Аналитика', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _openStatistics();
              }),
          ListTile(
              leading:
                  const Icon(Icons.note_alt_outlined, color: Colors.amberAccent),
              title:
                  const Text('Заметки', style: TextStyle(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                _openNotesHistory();
              }),
          const Divider(color: Colors.white24),
          ListTile(
              leading: const Icon(Icons.ac_unit, color: Colors.lightBlueAccent),
              title:
                  const Text('Заморозки', style: TextStyle(color: Colors.white)),
              trailing: Text('${state.streakFreezes}',
                  style: const TextStyle(
                      color: Colors.lightBlueAccent,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              onTap: () => Navigator.pop(context)),
        ]),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (ref.watch(loadFailedProvider)) _buildLoadFailedBanner(),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 20),
                  child: Text('Привет, ${state.userName}! 👋',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white))),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [
                    widget.currentTheme.primary,
                    widget.currentTheme.secondary
                  ]),
                  boxShadow: [
                    BoxShadow(
                        color: widget.currentTheme.primary
                            .withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 5)
                  ]),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.local_fire_department,
                    size: 60, color: Colors.white),
                Text('${state.streakCount}',
                    style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const Text('дней подряд',
                    style: TextStyle(fontSize: 14, color: Colors.white70)),
              ]),
            )
                .animate(
                    onPlay: (controller) => controller.repeat(reverse: true))
                .scaleXY(
                    begin: 0.95,
                    end: 1.05,
                    duration: 2000.ms,
                    curve: Curves.easeInOut)
                .shimmer(duration: 3000.ms, color: Colors.white24),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('🏅 Уровень ${notifier.level}',
                      style: TextStyle(
                          color: widget.currentTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  Text(
                      '${notifier.currentLevelXp} / ${notifier.requiredLevelXp} XP',
                      style:
                          const TextStyle(color: Colors.white54, fontSize: 13)),
                ]),
                const SizedBox(height: 8),
                ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                        value: notifier.levelProgress,
                        minHeight: 12,
                        backgroundColor: Colors.grey[800],
                        valueColor: AlwaysStoppedAnimation<Color>(
                            widget.currentTheme.secondary))),
              ]),
            ),
            const SizedBox(height: 16),
            Text('🛡️ Заморозок: ${state.streakFreezes}',
                style: const TextStyle(
                    fontSize: 13, color: Colors.lightBlueAccent)),
            const SizedBox(height: 20),

            if (_isWorkoutActive) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                decoration: BoxDecoration(
                  color: _isPreparing
                      ? Colors.orange.withValues(alpha: 0.2)
                      : (_workoutMode != 'Классический' && _isResting
                          ? Colors.blueAccent.withValues(alpha: 0.2)
                          : widget.currentTheme.primary.withValues(alpha: 0.2)),
                  border: Border.all(
                      color: _isPreparing
                          ? Colors.orange
                          : (_workoutMode != 'Классический' && _isResting
                              ? Colors.blueAccent
                              : widget.currentTheme.primary)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  if (_isPreparing) ...[
                    const Text('ПРИГОТОВЬТЕСЬ',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.orange,
                            letterSpacing: 2)),
                    const SizedBox(height: 8),
                    Text('$_prepareCountdown',
                        style: const TextStyle(
                            fontSize: 64,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ] else ...[
                    if (_workoutMode != 'Классический') ...[
                      Text(_isResting ? 'ОТДЫХ' : 'РАБОТА',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _isResting
                                  ? Colors.blueAccent
                                  : widget.currentTheme.primary,
                              letterSpacing: 2)),
                      Text('Раунд $_currentRound из $_intervalRounds',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white54)),
                      const SizedBox(height: 8),
                    ],
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.timer,
                          color: _isResting
                              ? Colors.blueAccent
                              : widget.currentTheme.primary,
                          size: 32),
                      const SizedBox(width: 12),
                      Text(
                          _workoutMode == 'Классический'
                              ? _formatTime(_totalSecondsSpentInSession)
                              : _formatTime(_phaseTimeLeft),
                          style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 2)),
                    ]),
                  ],
                ]),
              ),
              const SizedBox(height: 20),
            ],

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_weekDays.length, (index) {
                final monday = DateTime.now()
                    .subtract(Duration(days: DateTime.now().weekday - 1));
                final target =
                    DateTime(monday.year, monday.month, monday.day + index);
                final isDone = completedDates
                    .contains('${target.year}-${target.month}-${target.day}');
                final isToday = index == todayIndex;
                final hasPlan = state.plannedWorkouts.containsKey(index);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                      color: isDone
                          ? widget.currentTheme.primary.withValues(alpha: 0.25)
                          : const Color(0xFF1E1E1E),
                      border: Border.all(
                          color: isToday
                              ? widget.currentTheme.primary
                              : (hasPlan
                                  ? Colors.lightBlueAccent
                                  : (isDone
                                      ? widget.currentTheme.primary
                                      : Colors.grey[800]!)),
                          width: isToday ? 2.5 : 1.5),
                      borderRadius: BorderRadius.circular(12)),
                  child: Column(children: [
                    Text(_weekDays[index],
                        style: TextStyle(
                            fontSize: 11,
                            color: isDone || isToday
                                ? widget.currentTheme.primary
                                : (hasPlan
                                    ? Colors.lightBlueAccent
                                    : Colors.grey),
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Icon(
                        isDone
                            ? Icons.check_circle
                            : (hasPlan
                                ? Icons.bookmark
                                : Icons.radio_button_unchecked),
                        size: 16,
                        color: isDone
                            ? widget.currentTheme.primary
                            : (hasPlan
                                ? Colors.lightBlueAccent
                                : (isToday
                                    ? widget.currentTheme.primary
                                    : Colors.grey[700]))),
                  ]),
                );
              }),
            ),
            const SizedBox(height: 28),
            Align(
                alignment: Alignment.centerLeft,
                child: Text('🎯 Ежедневные квесты:',
                    style:
                        TextStyle(fontSize: 14, color: Colors.white70))),
            const SizedBox(height: 8),
            ...state.dailyQuests.map((quest) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: quest.isCompleted
                        ? widget.currentTheme.primary.withValues(alpha: 0.15)
                        : const Color(0xFF1E1E1E),
                    border: Border.all(
                        color: quest.isCompleted
                            ? widget.currentTheme.primary
                            : Colors.grey[850]!),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Icon(
                      quest.isCompleted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: quest.isCompleted
                          ? widget.currentTheme.primary
                          : Colors.grey,
                      size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(quest.title,
                          style: TextStyle(
                              color: quest.isCompleted
                                  ? Colors.white54
                                  : Colors.white,
                              decoration: quest.isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                              fontSize: 14))),
                  if (quest.isCompleted &&
                      !quest.isRewardClaimed &&
                      quest.chestRarity != null)
                    ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: quest.chestRarity ==
                                    ChestRarity.legendary
                                ? Colors.amber
                                : quest.chestRarity == ChestRarity.epic
                                    ? Colors.purpleAccent
                                    : quest.chestRarity == ChestRarity.rare
                                        ? Colors.blueAccent
                                        : Colors.grey[700],
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        onPressed: () => _openChest(quest),
                        child: const Text('Открыть',
                            style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.bold)))
                  else
                    Text(
                        quest.isRewardClaimed
                            ? 'Получено'
                            : '+${quest.xpReward} XP',
                        style: TextStyle(
                            color: quest.isRewardClaimed
                                ? Colors.white38
                                : Colors.amberAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                ]),
              )
                  .animate(delay: 100.ms)
                  .fadeIn(duration: 400.ms, curve: Curves.easeOut)
                  .slideX(begin: 0.2, curve: Curves.easeOutBack);
            }),
            const SizedBox(height: 32),
            Text(
              _isWorkoutActive
                  ? '⚡ Идёт тренировка «${state.selectedWorkoutType}»...'
                  : (_isSameDay(state.lastCompletionDate, DateTime.now())
                      ? '🎉 Тренировка «${state.selectedWorkoutType}» засчитана!'
                      : '💪 Готовы к тренировке?'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  color: _isWorkoutActive
                      ? widget.currentTheme.primary
                      : (_isSameDay(state.lastCompletionDate, DateTime.now())
                          ? Colors.greenAccent
                          : Colors.white70),
                  fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            if (!_isWorkoutActive)
              ElevatedButton.icon(
                onPressed: _showStartWorkoutSheet,
                icon: const Icon(Icons.play_arrow),
                label: Text(
                    _isSameDay(state.lastCompletionDate, DateTime.now())
                        ? 'Ещё тренировку'
                        : 'Начать тренировку'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: widget.currentTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
              ).animate().shimmer(duration: 2000.ms, color: Colors.white24)
            else
              ElevatedButton.icon(
                onPressed: _finishWorkout,
                icon: const Icon(Icons.stop),
                label: const Text('Завершить тренировку'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16))),
              ),
          ]),
        ),
      ),
    );
  }
}