import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:home_widget/home_widget.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/achievement.dart';
import '../models/app_theme.dart';
import '../models/custom_interval.dart';
import '../models/daily_quest.dart';
import '../models/streak_state.dart';
import '../providers/streak_provider.dart';
import '../services/notification_service.dart';
import '../services/voice_service.dart';
import '../sound/sound_player.dart';
import '../widgets/workout_heatmap.dart';
import '../widgets/widget_ui.dart';
import 'profile_screen.dart';
import 'league_screen.dart';

part 'home_screen_dialogs.dart';
part 'home_screen_sheets.dart';
part 'home_screen_data.dart';
part 'home_screen_helpers.dart';
part 'home_screen_circuit.dart';

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
  List<IntervalPhase> _phases = const [];
  int _phaseIdx = 0;
  int _totalRounds = 1;
  int _scheduledSeconds = 0;
  String _phaseLabel = '';

  final List<String> _weekDays = const ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    VoiceService.instance.load();
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
    VoiceService.instance.stop();
    try {
      WakelockPlus.disable();
    } catch (_) {}
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Приложение сворачивают: отправляем отложенные изменения в облако сразу
      ref.read(streakProvider.notifier).flushCloud();
    }
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

  // Конец текущей фазы интервальной тренировки. Фазы считаем по реальному
  // времени, а не по тикам таймера: при блокировке экрана тики пропускаются.
  DateTime? _phaseEndTime;

  int get _scheduledIntervalSeconds => _scheduledSeconds;

  /// Строит список фаз для выбранного режима.
  void _buildPhases() {
    final List<IntervalPhase> phases;
    if (_workoutMode == 'Свои раунды') {
      final st = ref.read(streakProvider);
      phases = IntervalPhase.build(st.customCircuit, st.customLaps);
    } else {
      phases = IntervalPhase.build(
        List.generate(
            _intervalRounds,
            (_) => CustomInterval(
                name: '',
                workSeconds: _intervalWorkTime,
                restSeconds: _intervalRestTime)),
        1,
      );
    }
    _phases = phases;
    _totalRounds = phases.isEmpty ? 1 : phases.last.round;
    _scheduledSeconds = phases.fold(0, (sum, p) => sum + p.seconds);
    _phaseIdx = 0;
    _applyPhase();
  }

  void _applyPhase() {
    if (_phases.isEmpty) return;
    final p = _phases[_phaseIdx];
    _isResting = p.isRest;
    _currentRound = p.round;
    _phaseLabel = p.label;
  }

  int get _firstPhaseSeconds => _phases.isEmpty ? 0 : _phases.first.seconds;

  /// Название следующего упражнения (для подсказки во время отдыха).
  String? get _nextExerciseLabel {
    for (var i = _phaseIdx + 1; i < _phases.length; i++) {
      if (!_phases[i].isRest) return _phases[i].label;
    }
    return null;
  }

  /// Небольшая пауза, чтобы голос не перекрывал звуковой сигнал.
  void _speakAfterBeep(String text) {
    Future.delayed(const Duration(milliseconds: 700), () {
      VoiceService.instance.speak(text);
    });
  }

  void _speakCurrentPhase() {
    if (_phases.isEmpty) return;
    final p = _phases[_phaseIdx];
    if (p.isRest) {
      final next = _nextExerciseLabel;
      _speakAfterBeep(next != null && next.isNotEmpty
          ? 'Отдых. Далее: $next'
          : 'Отдых');
    } else {
      _speakAfterBeep(p.label.isNotEmpty ? p.label : 'Раунд ${p.round}');
    }
  }

  void _signalPhaseChange() {
    Vibration.hasVibrator().then((hasVibrator) {
      if (hasVibrator == true) {
        Vibration.vibrate(pattern: [0, 500, 200, 500]);
      }
    });
    playSound('beep');
  }

  /// Переключает фазы, если время текущей истекло. Возвращает true, если
  /// тренировка завершена (последний рабочий интервал закончился).
  bool _advanceIntervalPhases() {
    final now = DateTime.now();
    var changed = false;

    while (_phaseEndTime != null && !now.isBefore(_phaseEndTime!)) {
      changed = true;
      if (_phaseIdx >= _phases.length - 1) {
        // Последняя рабочая фаза закончена: лишний отдых в конце не нужен
        _phaseEndTime = null;
        _phaseTimeLeft = 0;
        _signalPhaseChange();
        _speakAfterBeep('Тренировка завершена');
        return true;
      }
      _phaseIdx++;
      _applyPhase();
      _phaseEndTime =
          _phaseEndTime!.add(Duration(seconds: _phases[_phaseIdx].seconds));
    }

    if (changed) {
      _signalPhaseChange();
      _speakCurrentPhase();
    }

    if (_phaseEndTime != null) {
      final msLeft = _phaseEndTime!.difference(now).inMilliseconds;
      _phaseTimeLeft = (msLeft / 1000).ceil().clamp(0, 3600);
    }
    return false;
  }

  void _startWorkoutTimer() {
    playSound('countdown');
    _totalSecondsSpentInSession = 0;
    _currentRound = 1;
    _isResting = false;
    _workoutStartTime = null;
    _phaseEndTime = null;

    if (_workoutMode != 'Классический') {
      _buildPhases();
      _phaseTimeLeft = _firstPhaseSeconds;
    }

    // Не даём экрану погаснуть во время тренировки
    try {
      WakelockPlus.enable();
    } catch (e) {
      debugPrint('wakelock enable error: $e');
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
            if (_workoutMode != 'Классический') {
              _phaseEndTime = _workoutStartTime!
                  .add(Duration(seconds: _firstPhaseSeconds));
              _phaseTimeLeft = _firstPhaseSeconds;
              _speakCurrentPhase();
            }
          }
        });
        return;
      }
      // --------------------------------

      // --- ОСНОВНАЯ ТРЕНИРОВКА ---
      var finished = false;
      setState(() {
        if (_workoutStartTime != null) {
          _totalSecondsSpentInSession =
              DateTime.now().difference(_workoutStartTime!).inSeconds;
        }

        if (_workoutMode != 'Классический') {
          finished = _advanceIntervalPhases();
          if (finished) {
            // Засчитываем запланированную длительность, а не время «простоя»
            _totalSecondsSpentInSession = _scheduledIntervalSeconds;
          }
        }
      });
      if (finished) _finishWorkout();
    });
  }

  Future<void> _finishWorkout() async {
    _workoutTimer?.cancel();
    try {
      WakelockPlus.disable();
    } catch (_) {}
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
                    children: ['Классический', 'Интервалы', 'Табата', 'Свои раунды']
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
                  if (_workoutMode == 'Свои раунды') ...[
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24),
                    ..._buildCustomCircuitEditor(currentState, notifier,
                        () => setModalState(() {})),
                  ],
                  if (_workoutMode != 'Классический' &&
                      _workoutMode != 'Свои раунды') ...[
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
                  if (_workoutMode != 'Классический')
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Голосовые подсказки',
                          style: TextStyle(color: Colors.white)),
                      value: VoiceService.instance.enabled,
                      onChanged: (v) async {
                        await VoiceService.instance.setEnabled(v);
                        setModalState(() {});
                      },
                    ),
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
            currentAccountPicture: Builder(builder: (_) {
              final av = avatars[state.avatarIndex % avatars.length];
              final Color c = av['color'] as Color;
              return CircleAvatar(
                  backgroundColor: c.withValues(alpha: 0.25),
                  child: Icon(av['icon'] as IconData, size: 36, color: c));
            }),
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
                      if (_phaseLabel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(_phaseLabel,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                        ),
                      Text('Раунд $_currentRound из $_totalRounds',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.white54)),
                      if (_isResting && _nextExerciseLabel != null &&
                          _nextExerciseLabel!.isNotEmpty)
                        Text('Далее: $_nextExerciseLabel',
                            style: const TextStyle(
                                fontSize: 13, color: Colors.white70)),
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