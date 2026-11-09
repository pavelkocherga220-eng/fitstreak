import 'dart:js_interop' as js;

AudioContext? _cachedContext;
AudioContext _getContext() => _cachedContext ??= AudioContext();

void playSound(String type) {
  try {
    final ctx = _getContext();
    final osc = ctx.createOscillator();
    final gain = ctx.createGain();

    osc.connect(gain);
    gain.connect(ctx.destination);

    final now = ctx.currentTime;

    switch (type) {
      case 'start':
        osc.frequency.setValueAtTime(440.0, now);
        osc.frequency.exponentialRampToValueAtTime(880.0, now + 0.15);
        gain.gain.setValueAtTime(0.1, now);
        gain.gain.exponentialRampToValueAtTime(0.01, now + 0.15);
        osc.start(now);
        osc.stop(now + 0.15);
      case 'finish':
        osc.frequency.setValueAtTime(523.25, now);
        osc.frequency.setValueAtTime(659.25, now + 0.1);
        osc.frequency.setValueAtTime(783.99, now + 0.2);
        gain.gain.setValueAtTime(0.15, now);
        gain.gain.exponentialRampToValueAtTime(0.01, now + 0.35);
        osc.start(now);
        osc.stop(now + 0.35);
      case 'achievement':
        osc.frequency.setValueAtTime(587.33, now);
        osc.frequency.setValueAtTime(880.0, now + 0.15);
        osc.frequency.setValueAtTime(1174.66, now + 0.3);
        gain.gain.setValueAtTime(0.2, now);
        gain.gain.exponentialRampToValueAtTime(0.01, now + 0.5);
        osc.start(now);
        osc.stop(now + 0.5);
    }
  } catch (_) {}
}

@js.JS('AudioContext')
extension type AudioContext._(js.JSObject _) implements js.JSObject {
  external AudioContext();
  external double get currentTime;
  external OscillatorNode createOscillator();
  external GainNode createGain();
  external AudioDestinationNode get destination;
}

@js.JS()
extension type OscillatorNode._(js.JSObject _) implements js.JSObject {
  external void connect(js.JSObject destination);
  external AudioParam get frequency;
  external void start([double when]);
  external void stop([double when]);
}

@js.JS()
extension type GainNode._(js.JSObject _) implements js.JSObject {
  external void connect(js.JSObject destination);
  external AudioParam get gain;
}

@js.JS()
extension type AudioDestinationNode._(js.JSObject _) implements js.JSObject {}

@js.JS()
extension type AudioParam._(js.JSObject _) implements js.JSObject {
  external void setValueAtTime(double value, double startTime);
  external void exponentialRampToValueAtTime(double value, double endTime);
}