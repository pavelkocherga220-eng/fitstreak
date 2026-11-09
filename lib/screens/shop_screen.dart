import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/streak_provider.dart';

class ShopScreen extends ConsumerWidget {
  final Color primaryColor;
  final Color secondaryColor;

  const ShopScreen({super.key, required this.primaryColor, required this.secondaryColor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(streakProvider);
    final notifier = ref.read(streakProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text('🛒 Магазин'),
        centerTitle: true,
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  const Icon(Icons.diamond, color: Colors.cyanAccent, size: 20),
                  const SizedBox(width: 4),
                  Text('${state.crystals}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.cyanAccent)),
                ],
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildShopItem(
            context: context,
            title: 'Заморозка стрика 🛡️',
            description: 'Спасает твой стрик, если ты пропустишь один день тренировок.',
            price: 100,
            icon: Icons.ac_unit,
            color: Colors.lightBlueAccent,
            isBought: false,
            onBuy: () async {
              final success = await notifier.buyItem('freeze');
              if (!context.mounted) return; // <-- ПРОВЕРКА
              _showMessage(context, success, 'Заморозка куплена!');
            },
          ),
          const SizedBox(height: 16),
          _buildShopItem(
            context: context,
            title: 'Двойной опыт (24ч) ⚡',
            description: 'Следующая тренировка принесет в 2 раза больше XP.',
            price: 150,
            icon: Icons.flash_on,
            color: Colors.amberAccent,
            isBought: state.hasXpBoost,
            onBuy: () async {
              final success = await notifier.buyItem('xp_boost');
              if (!context.mounted) return; // <-- ПРОВЕРКА
              _showMessage(context, success, 'Буст активирован!');
            },
          ),
        ],
      ),
    );
  }

  void _showMessage(BuildContext context, bool success, String successMsg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? successMsg : 'Недостаточно кристаллов!'),
        backgroundColor: success ? Colors.green : Colors.redAccent,
      ),
    );
  }

  Widget _buildShopItem({
    required BuildContext context,
    required String title,
    required String description,
    required int price,
    required IconData icon,
    required Color color,
    required bool isBought,
    required VoidCallback onBuy,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[850]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(description, style: const TextStyle(fontSize: 12, color: Colors.white54)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isBought ? Colors.grey[800] : primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: isBought ? null : onBuy,
              child: Text(
                isBought ? 'Уже активно' : 'Купить за $price 💎',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}