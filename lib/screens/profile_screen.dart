import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/streak_provider.dart';
import '../models/achievement.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'shop_screen.dart';

const List<Map<String, dynamic>> avatars = [
  {'icon': Icons.fitness_center, 'color': Colors.orange},    
  {'icon': Icons.directions_run, 'color': Colors.lightBlueAccent}, 
  {'icon': Icons.self_improvement, 'color': Colors.green},   
  {'icon': Icons.directions_bike, 'color': Colors.purpleAccent}, 
  {'icon': Icons.sports_martial_arts, 'color': Colors.redAccent}, 
  {'icon': Icons.sports_basketball, 'color': Colors.amber},  
];

class ProfileScreen extends ConsumerStatefulWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final VoidCallback onExport;
  final VoidCallback onImport;
  final VoidCallback onTheme;

  const ProfileScreen({
    super.key,
    required this.primaryColor,
    required this.secondaryColor,
    required this.onExport,
    required this.onImport,
    required this.onTheme,
  });

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final Stream<User?> _userStream;

  @override
  void initState() {
    super.initState();
    _userStream = AuthService().userStream; 
  }

  String _formatTime(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    if (h > 0) return '$h ч $m мин';
    return '$m мин';
  }

  void _showEditNameDialog() {
    final state = ref.read(streakProvider);
    final controller = TextEditingController(text: state.userName);
    
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Ваше имя', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          maxLength: 15,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(filled: true, fillColor: Colors.black26, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogCtx), child: const Text('Отмена', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: widget.primaryColor),
            onPressed: () {
              ref.read(streakProvider.notifier).updateUserName(controller.text);
              Navigator.pop(dialogCtx);
            },
            child: const Text('Сохранить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showAvatarSelector() {
    final state = ref.read(streakProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetCtx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Выберите аватар', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16, runSpacing: 16, alignment: WrapAlignment.center,
              children: List.generate(avatars.length, (index) {
                final isSelected = state.avatarIndex == index;
                final avatar = avatars[index];
                return GestureDetector(
                  onTap: () {
                    ref.read(streakProvider.notifier).updateAvatar(index);
                    Navigator.pop(sheetCtx);
                  },
                  child: Container(
                    width: 70, height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: avatar['color'].withValues(alpha: isSelected ? 0.3 : 0.1),
                      border: Border.all(color: isSelected ? avatar['color'] : Colors.transparent, width: 3),
                    ),
                    child: Icon(avatar['icon'], color: avatar['color'], size: 32),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(streakProvider);
    final notifier = ref.read(streakProvider.notifier);
    final progress = notifier.levelProgress;
    final currentAvatar = avatars[state.avatarIndex % avatars.length];

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(title: const Text('👤 Мой профиль'), centerTitle: true, backgroundColor: const Color(0xFF1E1E1E)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // --- АВТОРИЗАЦИЯ ---
            StreamBuilder<User?>(
              stream: _userStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator()));
                }
                final user = snapshot.data;
                if (user == null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.login),
                      label: const Text('Войти через Google', style: TextStyle(fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white, foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12), minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final creds = await AuthService().signInWithGoogle();
                        if (creds == null) {
                          messenger.showSnackBar(const SnackBar(content: Text('Вход не выполнен. Попробуйте ещё раз.')));
                          return;
                        }
                        final switched = await ref.read(streakProvider.notifier).loadFromCloud();
                        // Облачные данные могли принести другие времена напоминаний
                        try {
                          await scheduleReminders(ref.read(streakProvider).reminderTimes);
                        } catch (_) {}
                        messenger.showSnackBar(SnackBar(
                          content: Text(switched
                              ? 'Вход под другим аккаунтом: загружен его прогресс. Прежние данные сохранены локально.'
                              : 'Успешный вход! Прогресс синхронизирован.'),
                        ));
                      },
                    ),
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Row(
                      children: [
                        user.photoURL != null && user.photoURL!.isNotEmpty
                            ? CircleAvatar(backgroundImage: NetworkImage(user.photoURL!))
                            : const CircleAvatar(child: Icon(Icons.person)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.displayName ?? 'Пользователь', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Text(user.email ?? '', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => AuthService().signOut(),
                          child: const Text('Выйти', style: TextStyle(color: Colors.redAccent)),
                        ),
                      ],
                    ),
                  );
                }
              },
            ),

            // --- АВАТАР И УРОВЕНЬ ---
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [currentAvatar['color'].withValues(alpha: 0.2), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: currentAvatar['color'].withValues(alpha: 0.5)),
              ),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _showAvatarSelector,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.8, end: 1.0), duration: const Duration(milliseconds: 500), curve: Curves.easeOutBack,
                      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(radius: 50, backgroundColor: currentAvatar['color'].withValues(alpha: 0.2), child: Icon(currentAvatar['icon'], size: 60, color: currentAvatar['color'])),
                          Container(padding: const EdgeInsets.all(6), decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle), child: const Icon(Icons.edit, size: 16, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _showEditNameDialog,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(child: Text(state.userName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white))),
                        const SizedBox(width: 8),
                        const Icon(Icons.edit, size: 16, color: Colors.white54),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('🏅 Уровень ${notifier.level}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.primaryColor)),
                  const SizedBox(height: 8),
                  Text('${notifier.currentLevelXp} / ${notifier.requiredLevelXp} XP', style: const TextStyle(color: Colors.white54, fontSize: 14)),
                  const SizedBox(height: 12),
                  ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: progress, minHeight: 10, backgroundColor: Colors.grey[800], valueColor: AlwaysStoppedAnimation<Color>(widget.secondaryColor))),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // --- СТАТИСТИКА ---
            const Align(alignment: Alignment.centerLeft, child: Text('📊 Общая статистика', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: _buildStatCard('Тренировок', '${state.totalWorkoutsCompleted}', Icons.fitness_center, widget.primaryColor)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Время', _formatTime(state.totalSecondsSpent), Icons.timer, Colors.lightBlueAccent)),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _buildStatCard('Рекорд стрика', '${state.maxStreak} дн.', Icons.local_fire_department, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Заморозки', '${state.streakFreezes}', Icons.ac_unit, Colors.lightBlueAccent)),
            ]),
            const SizedBox(height: 32),

            // --- ДОСТИЖЕНИЯ ---
            const Align(alignment: Alignment.centerLeft, child: Text('🏆 Достижения', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[850]!)),
              child: Wrap(
                spacing: 16, runSpacing: 16, alignment: WrapAlignment.center,
                children: notifier.achievements.map((ach) {
                  final isUnlocked = ach.isSecret ? state.unlockedAchievements.contains(ach.id) : state.regularUnlocked.contains(ach.id);
                  return _buildAchievementBadge(ach, isUnlocked);
                }).toList(),
              ),
            ),
            const SizedBox(height: 32),

            // --- НАСТРОЙКИ ---
            const Align(alignment: Alignment.centerLeft, child: Text('⚙️ Настройки и данные', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Material(
                color: const Color(0xFF1E1E1E),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.storefront, color: Colors.greenAccent),
                      title: const Text('Магазин', style: TextStyle(color: Colors.white)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ShopScreen(primaryColor: widget.primaryColor, secondaryColor: widget.secondaryColor))),
                    ),
                    const Divider(height: 1, color: Colors.black26),
                    ListTile(
                      leading: const Icon(Icons.palette_outlined, color: Colors.purpleAccent),
                      title: const Text('Тема оформления', style: TextStyle(color: Colors.white)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                      onTap: widget.onTheme,
                    ),
                    const Divider(height: 1, color: Colors.black26),
                    ListTile(
                      leading: const Icon(Icons.notifications_active, color: Colors.amberAccent),
                      title: const Text('Напоминания', style: TextStyle(color: Colors.white)),
                      subtitle: Text(
                        state.reminderTimes.map((t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}').join(', '),
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      trailing: IconButton(
                        icon: Icon(Icons.add, color: widget.primaryColor),
                        onPressed: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: const TimeOfDay(hour: 12, minute: 0),
                            builder: (context, child) => Theme(
                              data: ThemeData.dark().copyWith(
                                colorScheme: ColorScheme.dark(primary: widget.primaryColor, onPrimary: Colors.white, surface: const Color(0xFF1E1E1E), onSurface: Colors.white),
                              ),
                              child: child!,
                            ),
                          );
                          if (picked != null) {
                            final newTimes = [...state.reminderTimes, picked]..sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
                            ref.read(streakProvider.notifier).setReminderTimes(newTimes);
                            await scheduleReminders(newTimes);
                          }
                        },
                      ),
                    ),
                    ...state.reminderTimes.map((time) {
                      return ListTile(
                        leading: const SizedBox(width: 24),
                        title: Text('${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                          onPressed: () {
                            final newTimes = state.reminderTimes.where((t) => t != time).toList();
                            ref.read(streakProvider.notifier).setReminderTimes(newTimes);
                            scheduleReminders(newTimes);
                          },
                        ),
                      );
                    }),
                    const Divider(height: 1, color: Colors.black26),
                    ListTile(
                      leading: const Icon(Icons.upload, color: Colors.greenAccent),
                      title: const Text('Экспорт данных (Бэкап)', style: TextStyle(color: Colors.white)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                      onTap: widget.onExport,
                    ),
                    const Divider(height: 1, color: Colors.black26),
                    ListTile(
                      leading: const Icon(Icons.download, color: Colors.lightBlueAccent),
                      title: const Text('Импорт данных', style: TextStyle(color: Colors.white)),
                      trailing: const Icon(Icons.chevron_right, color: Colors.white54),
                      onTap: widget.onImport,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementBadge(Achievement ach, bool unlocked) {
    return SizedBox(
      width: 72,
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: unlocked ? widget.primaryColor.withValues(alpha: 0.2) : Colors.grey[800],
              border: Border.all(color: unlocked ? widget.primaryColor : Colors.grey[700]!, width: 2),
              boxShadow: unlocked ? [BoxShadow(color: widget.primaryColor.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 2)] : [],
            ),
            child: Icon(unlocked ? ach.icon : (ach.isSecret ? Icons.question_mark : Icons.lock_outline), color: unlocked ? widget.primaryColor : Colors.grey[500], size: 28),
          ),
          const SizedBox(height: 8),
          Text(unlocked ? ach.title : (ach.isSecret ? '???' : 'Закрыто'), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: unlocked ? Colors.white : Colors.grey[500], fontWeight: unlocked ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey[850]!)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      ),
    );
  }
}