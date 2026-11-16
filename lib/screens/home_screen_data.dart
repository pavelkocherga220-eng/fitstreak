part of 'home_screen.dart';

// Экспорт, импорт и свои типы тренировок.
// Методы вынесены из home_screen.dart без изменения поведения
// (extension над _StreakHomeScreenState в той же библиотеке).
extension _HomeData on _StreakHomeScreenState {
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
}
