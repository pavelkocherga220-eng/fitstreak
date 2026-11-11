import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/streak_provider.dart';

class LeagueScreen extends ConsumerWidget {
  final Color primaryColor;
  final Color secondaryColor;

  const LeagueScreen({super.key, required this.primaryColor, required this.secondaryColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final state = ref.watch(streakProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('🏆 Лига FitStreak'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E1E1E),
      ),
      body: Column(
        children: [
          // Шапка лиги
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor.withValues(alpha: 0.3), Colors.transparent],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: Column(
              children: [
                const Icon(Icons.emoji_events, size: 60, color: Colors.amber),
                const SizedBox(height: 8),
                const Text('Бронзовая лига', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                const Text('Топ-3 переходят в Серебряную лигу', style: TextStyle(fontSize: 12, color: Colors.white70)),
                const SizedBox(height: 16),
                // Ваше место (для наглядности)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: primaryColor),
                  ),
                  child: Text(
                    'Ваш XP: ${state.xp}',
                    style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Список лидеров
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Берем топ-30 пользователей по общему XP
              stream: FirebaseFirestore.instance
                  .collection('leaderboard')
                  .orderBy('xp', descending: true)
                  .limit(30)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Пока нет участников. Начните тренироваться!', style: TextStyle(color: Colors.white54)));
                }

                final users = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final data = users[index].data() as Map<String, dynamic>;
                    final isMe = currentUser != null && users[index].id == currentUser.uid;
                    
                    // Цвета для топ-3
                    Color rankColor = Colors.white70;
                    IconData? medalIcon;
                    if (index == 0) { rankColor = Colors.amber; medalIcon = Icons.military_tech; }
                    else if (index == 1) { rankColor = Colors.grey[300]!; medalIcon = Icons.military_tech; }
                    else if (index == 2) { rankColor = Colors.brown[300]!; medalIcon = Icons.military_tech; }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isMe ? primaryColor.withValues(alpha: 0.15) : const Color(0xFF1E1E1E),
                        border: Border.all(color: isMe ? primaryColor : Colors.grey[850]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          // Место
                          SizedBox(
                            width: 30,
                            child: medalIcon != null 
                              ? Icon(medalIcon, color: rankColor)
                              : Text('${index + 1}', style: TextStyle(color: rankColor, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                          const SizedBox(width: 12),
                          
                          // Аватарка
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.grey[800],
                            child: Text(
                              (data['user_name'] as String? ?? 'A')[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          
                          // Имя
                          Expanded(
                            child: Text(
                              data['user_name'] as String? ?? 'Атлет',
                              style: TextStyle(
                                color: isMe ? primaryColor : Colors.white,
                                fontWeight: isMe ? FontWeight.bold : FontWeight.normal,
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                          // XP
                          Text(
                            '${data['xp'] ?? 0} XP',
                            style: TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}