import 'package:flutter/material.dart';

class GarraLevel {
  const GarraLevel({
    required this.name,
    required this.minPoints,
    required this.nextLevelMinPoints,
    required this.icon,
  });

  final String name;
  final int minPoints;
  final int? nextLevelMinPoints;
  final IconData icon;

  bool get isMaxLevel => nextLevelMinPoints == null;
}

class GamificationUtils {
  GamificationUtils._();

  static const GarraLevel novatoCrema = GarraLevel(
    name: 'Novato Crema',
    minPoints: 0,
    nextLevelMinPoints: 50,
    icon: Icons.sports_soccer_rounded,
  );

  static const GarraLevel hinchaFiel = GarraLevel(
    name: 'Hincha Fiel',
    minPoints: 50,
    nextLevelMinPoints: 150,
    icon: Icons.local_fire_department_rounded,
  );

  static const GarraLevel guerreroCrema = GarraLevel(
    name: 'Guerrero Crema',
    minPoints: 150,
    nextLevelMinPoints: 300,
    icon: Icons.shield_rounded,
  );

  static const GarraLevel leyendaCrema = GarraLevel(
    name: 'Leyenda Crema',
    minPoints: 300,
    nextLevelMinPoints: null,
    icon: Icons.emoji_events_rounded,
  );

  static GarraLevel levelForPoints(int points) {
    if (points >= 300) return leyendaCrema;
    if (points >= 150) return guerreroCrema;
    if (points >= 50) return hinchaFiel;
    return novatoCrema;
  }

  static GarraLevel? nextLevelForPoints(int points) {
    final level = levelForPoints(points);

    if (level == novatoCrema) return hinchaFiel;
    if (level == hinchaFiel) return guerreroCrema;
    if (level == guerreroCrema) return leyendaCrema;

    return null;
  }

  static int pointsToNextLevel(int points) {
    final level = levelForPoints(points);

    if (level.nextLevelMinPoints == null) {
      return 0;
    }

    final missing = level.nextLevelMinPoints! - points;
    return missing < 0 ? 0 : missing;
  }

  static double progressToNextLevel(int points) {
    final level = levelForPoints(points);

    if (level.nextLevelMinPoints == null) {
      return 1;
    }

    final currentRangeProgress = points - level.minPoints;
    final range = level.nextLevelMinPoints! - level.minPoints;

    if (range <= 0) {
      return 1;
    }

    final progress = currentRangeProgress / range;
    return progress.clamp(0, 1);
  }

  static String progressMessage(int points) {
    final level = levelForPoints(points);

    if (level.isMaxLevel) {
      return 'Nivel máximo alcanzado';
    }

    final nextLevel = nextLevelForPoints(points);
    final missing = pointsToNextLevel(points);

    if (nextLevel == null) {
      return 'Nivel máximo alcanzado';
    }

    return 'Te faltan $missing pts para subir a ${nextLevel.name}';
  }

  static String formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }

    return '${meters.toStringAsFixed(0)} m';
  }
}