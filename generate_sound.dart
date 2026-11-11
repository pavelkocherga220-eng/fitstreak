import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

const int sampleRate = 44100;

List<double> generateThud(double duration, double freq, double amplitude, double decayRate) {
  final n = (duration * sampleRate).toInt();
  final samples = <double>[];
  for (int i = 0; i < n; i++) {
    final t = i / sampleRate;
    final envelope = exp(-decayRate * t);
    final sample = amplitude * envelope * (
      sin(2 * pi * freq * t) + 0.4 * sin(2 * pi * freq * 2 * t)
    );
    samples.add(sample);
  }
  return samples;
}

List<double> generateBell(double duration, double freq, double amplitude) {
  final n = (duration * sampleRate).toInt();
  final samples = <double>[];
  for (int i = 0; i < n; i++) {
    final t = i / sampleRate;
    final envelope = exp(-3 * t);
    final sample = amplitude * envelope * (
      sin(2 * pi * freq * t) * 1.0 +
      sin(2 * pi * freq * 2 * t) * 0.6 +
      sin(2 * pi * freq * 3 * t) * 0.3 +
      sin(2 * pi * freq * 4 * t) * 0.15
    );
    samples.add(sample);
  }
  return samples;
}

List<double> generateBeep() {
  const duration = 0.15;
  final n = (duration * sampleRate).toInt();
  final samples = <double>[];
  for (int i = 0; i < n; i++) {
    final t = i / sampleRate;
    final envelope = exp(-15 * t);
    final sample = 0.7 * envelope * (
      sin(2 * pi * 900 * t) + 0.5 * sin(2 * pi * 1800 * t)
    );
    samples.add(sample);
  }
  return samples;
}

void writeWav(String filename, List<double> track) {
  final bytes = BytesBuilder();
  final dataSize = track.length * 2;
  final fileSize = 36 + dataSize;

  bytes.add('RIFF'.codeUnits);
  bytes.add(_int32(fileSize));
  bytes.add('WAVE'.codeUnits);
  bytes.add('fmt '.codeUnits);
  bytes.add(_int32(16));
  bytes.add(_int16(1));
  bytes.add(_int16(1));
  bytes.add(_int32(sampleRate));
  bytes.add(_int32(sampleRate * 2));
  bytes.add(_int16(2));
  bytes.add(_int16(16));
  bytes.add('data'.codeUnits);
  bytes.add(_int32(dataSize));

  for (final sample in track) {
    final clamped = sample.clamp(-1.0, 1.0);
    bytes.add(_int16((clamped * 32767).toInt()));
  }

  final file = File(filename);
  file.writeAsBytesSync(bytes.toBytes());
  // ignore: avoid_print
  print('SUCCESS! $filename создан (${file.lengthSync()} байт)');
}

void main() {
  // === COUNTDOWN ===
  const totalDuration = 4.5;
  final totalSamples = (totalDuration * sampleRate).toInt();
  final track = List<double>.filled(totalSamples, 0.0);

  final thud1 = generateThud(0.15, 200, 0.7, 25);
  final thud2 = generateThud(0.15, 200, 0.7, 25);
  final bell = generateBell(1.5, 800, 0.8);

  void mixInto(List<double> sound, double startTime) {
    final startIdx = (startTime * sampleRate).toInt();
    for (int i = 0; i < sound.length; i++) {
      if (startIdx + i < track.length) {
        track[startIdx + i] += sound[i];
      }
    }
  }

  mixInto(thud1, 1.0);
  mixInto(thud2, 2.0);
  mixInto(bell, 3.0);

  writeWav('countdown.wav', track);

  // === BEEP (для смены фаз в Табате) ===
  writeWav('beep.wav', generateBeep());
}

Uint8List _int32(int value) {
  final data = ByteData(4)..setInt32(0, value, Endian.little);
  return data.buffer.asUint8List();
}

Uint8List _int16(int value) {
  final data = ByteData(2)..setInt16(0, value, Endian.little);
  return data.buffer.asUint8List();
}