import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/custom_interval.dart';
import 'package:flutter_application_1/models/streak_state.dart';

void main() {
  const a = CustomInterval(name: 'Приседания', workSeconds: 30, restSeconds: 15);
  const b = CustomInterval(name: 'Отжимания', workSeconds: 45, restSeconds: 10);

  group('План интервалов', () {
    test('два упражнения, один круг: работа, отдых, работа (без отдыха в конце)', () {
      final p = IntervalPhase.build([a, b], 1);
      expect(p.map((e) => (e.isRest, e.seconds, e.round)).toList(),
          [(false, 30, 1), (true, 15, 1), (false, 45, 2)]);
    });

    test('два круга: отдых между кругами есть, после последней работы нет', () {
      final p = IntervalPhase.build([a, b], 2);
      expect(p.length, 7);
      expect(p[2].isRest, false);
      expect(p[3].isRest, true); // отдых после «Отжиманий» между кругами
      expect(p[3].seconds, 10);
      expect(p.last.isRest, false);
      expect(p.last.round, 4);
    });

    test('нулевой отдых пропускается', () {
      final p = IntervalPhase.build([
        a.copyWith(restSeconds: 0),
        b,
      ], 1);
      expect(p.length, 2);
      expect(p.every((e) => !e.isRest), true);
    });

    test('общая длительность Табаты 8×(20/10) = 8*20 + 7*10 = 230 с', () {
      final tabata = List.generate(
          8, (_) => const CustomInterval(name: '', workSeconds: 20, restSeconds: 10));
      final total =
          IntervalPhase.build(tabata, 1).fold<int>(0, (s, p) => s + p.seconds);
      expect(total, 230);
    });
  });

  group('Сохранение круга', () {
    test('круг переживает toJson/fromJson', () {
      final s = const StreakState().copyWith(customCircuit: [a, b], customLaps: 3);
      final r = StreakState.fromJson(s.toJson());
      expect(r.customLaps, 3);
      expect(r.customCircuit.length, 2);
      expect(r.customCircuit[1].name, 'Отжимания');
      expect(r.customCircuit[1].workSeconds, 45);
      expect(r.customCircuit[1].restSeconds, 10);
    });

    test('старые данные без круга получают значения по умолчанию', () {
      final json = const StreakState().toJson()
        ..remove('custom_circuit')
        ..remove('custom_laps');
      final r = StreakState.fromJson(json);
      expect(r.customCircuit.isNotEmpty, true);
      expect(r.customLaps, 1);
    });

    test('некорректные значения из облака ограничиваются', () {
      final c = CustomInterval.fromJson({'name': 'x', 'work': 99999, 'rest': -4});
      expect(c.workSeconds, CustomInterval.maxWork);
      expect(c.restSeconds, CustomInterval.minRest);
    });
  });
}
