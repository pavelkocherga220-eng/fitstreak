part of 'home_screen.dart';

/// Редактор своего круга: у каждого упражнения своё название,
/// время работы и время отдыха.
extension _HomeCircuit on _StreakHomeScreenState {
  List<Widget> _buildCustomCircuitEditor(
      StreakState st, StreakNotifier notifier, VoidCallback refresh) {
    final circuit = st.customCircuit;
    final total = IntervalPhase.build(circuit, st.customLaps)
        .fold<int>(0, (sum, p) => sum + p.seconds);

    return [
      const SizedBox(height: 12),
      for (var i = 0; i < circuit.length; i++)
        Card(
          color: const Color(0xFF2A2A2A),
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            onTap: () async {
              await _editExerciseDialog(
                  circuit, i, st.customLaps, notifier, refresh);
            },
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: widget.currentTheme.primary,
              child: Text('${i + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
            title: Text(circuit[i].name.isEmpty ? 'Без названия' : circuit[i].name,
                style: const TextStyle(color: Colors.white)),
            subtitle: Text(
                'Работа ${circuit[i].workSeconds} с · Отдых ${circuit[i].restSeconds} с',
                style: const TextStyle(color: Colors.white60)),
            trailing: circuit.length > 1
                ? IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                    onPressed: () {
                      final copy = List<CustomInterval>.from(circuit)
                        ..removeAt(i);
                      notifier.setCustomCircuit(copy, st.customLaps);
                      refresh();
                    },
                  )
                : null,
          ),
        ),
      if (circuit.length < 20)
        OutlinedButton.icon(
          onPressed: () async {
            final last = circuit.last;
            final copy = List<CustomInterval>.from(circuit)
              ..add(CustomInterval(
                  name: 'Упражнение ${circuit.length + 1}',
                  workSeconds: last.workSeconds,
                  restSeconds: last.restSeconds));
            notifier.setCustomCircuit(copy, st.customLaps);
            refresh();
            await _editExerciseDialog(
                copy, copy.length - 1, st.customLaps, notifier, refresh);
          },
          icon: const Icon(Icons.add),
          label: const Text('Добавить упражнение'),
        ),
      const SizedBox(height: 12),
      Text('Кругов: ${st.customLaps}',
          style: const TextStyle(color: Colors.white)),
      Slider(
        value: st.customLaps.toDouble(),
        min: 1,
        max: 10,
        divisions: 9,
        activeColor: widget.currentTheme.secondary,
        onChanged: (v) {
          notifier.setCustomCircuit(circuit, v.toInt());
          refresh();
        },
      ),
      Text('Всего: ${_formatTime(total)}',
          style: const TextStyle(color: Colors.white54, fontSize: 13)),
    ];
  }

  Future<void> _editExerciseDialog(List<CustomInterval> circuit, int index,
      int laps, StreakNotifier notifier, VoidCallback refresh) async {
    final item = circuit[index];
    final nameCtrl = TextEditingController(text: item.name);
    final workCtrl = TextEditingController(text: '${item.workSeconds}');
    final restCtrl = TextEditingController(text: '${item.restSeconds}');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Раунд ${index + 1}',
            style: const TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: nameCtrl,
              maxLength: CustomInterval.maxNameLength,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            TextField(
              controller: workCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                  labelText: 'Работа, сек',
                  helperText:
                      '${CustomInterval.minWork}–${CustomInterval.maxWork}'),
            ),
            TextField(
              controller: restCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                  labelText: 'Отдых, сек',
                  helperText:
                      '${CustomInterval.minRest}–${CustomInterval.maxRest}'),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Отмена')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Сохранить')),
        ],
      ),
    );

    if (ok == true) {
      final work = (int.tryParse(workCtrl.text) ?? item.workSeconds)
          .clamp(CustomInterval.minWork, CustomInterval.maxWork);
      final rest = (int.tryParse(restCtrl.text) ?? item.restSeconds)
          .clamp(CustomInterval.minRest, CustomInterval.maxRest);
      final copy = List<CustomInterval>.from(circuit);
      copy[index] = item.copyWith(
          name: nameCtrl.text.trim(), workSeconds: work, restSeconds: rest);
      notifier.setCustomCircuit(copy, laps);
      refresh();
    }
    // Контроллеры не удаляем сразу: диалог ещё проигрывает анимацию закрытия
    // и обращается к ним (dispose здесь вызывал ошибку после «Сохранить»).
  }
}
