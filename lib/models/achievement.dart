import 'package:flutter/material.dart';

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final int requiredStreak;
  final bool isSecret;
  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    this.requiredStreak = 0,
    this.isSecret = false,
  });
}