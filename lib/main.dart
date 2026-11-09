import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'models/app_theme.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';

void main() async {
  // Обязательная инициализация для Hive и Flutter
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  
  // Инициализируем Firebase только для мобильных платформ (Android/iOS).
  // Для Web-версии мы временно отключаем его, чтобы не было белого экрана,
  // так как google-services.json не содержит конфигурации для веба.
  if (!kIsWeb) {
    await Firebase.initializeApp();
  } else {
    debugPrint('Web версия: Firebase отключен (нет конфигурации для Web)');
  }

  await initNotifications();
  
  runApp(const ProviderScope(child: FitStreakApp()));
}

class FitStreakApp extends StatefulWidget {
  const FitStreakApp({super.key});

  @override
  State<FitStreakApp> createState() => _FitStreakAppState();
}

class _FitStreakAppState extends State<FitStreakApp> {
  int _selectedThemeIndex = 0;

  final List<AppThemeData> _themes = const [
    AppThemeData(name: 'Классический огонь 🔥', primary: Colors.orange, secondary: Colors.deepOrange, background: Color(0xFF121212)),
    AppThemeData(name: 'Неоновый киберпанк ⚡', primary: Colors.purpleAccent, secondary: Colors.cyanAccent, background: Color(0xFF0F0C1B)),
    AppThemeData(name: 'Лесная свежесть 🌿', primary: Colors.teal, secondary: Colors.green, background: Color(0xFF0A140E)),
  ];

  @override
  void initState() {
    super.initState();
    _loadThemeIndex();
  }

  Future<void> _loadThemeIndex() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      final saved = prefs.getInt('theme_index') ?? 0;
      _selectedThemeIndex = saved.clamp(0, _themes.length - 1);
    });
  }

  Future<void> _changeTheme(int index) async {
    setState(() => _selectedThemeIndex = index);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_index', index);
  }

  @override
  Widget build(BuildContext context) {
    final currentTheme = _themes[_selectedThemeIndex];

    return MaterialApp(
      title: 'FitStreak',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: currentTheme.background,
        primaryColor: currentTheme.primary,
        useMaterial3: true,
      ),
      home: StreakHomeScreen(
        currentTheme: currentTheme,
        themes: _themes,
        selectedThemeIndex: _selectedThemeIndex,
        onThemeChanged: _changeTheme,
      ),
    );
  }
}