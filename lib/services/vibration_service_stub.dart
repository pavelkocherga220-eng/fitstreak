import 'package:flutter/services.dart';

void vibrate() {
  // На мобильных устройствах используем стандартную вибрацию Flutter
  HapticFeedback.heavyImpact();
}