part of 'home_screen.dart';

// Диалоги: заметка, новый уровень, достижение, сундук.
// Методы вынесены из home_screen.dart без изменения поведения
// (extension над _StreakHomeScreenState в той же библиотеке).
extension _HomeDialogs on _StreakHomeScreenState {
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
}
