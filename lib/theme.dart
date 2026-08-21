import 'package:flutter/material.dart';

/// The app has two materials and keeps them apart: the book is serif on warm
/// paper, the interface is the system face. These are the paper side.
abstract final class Paper {
  static const ground = Color(0xFFFAF7F1);
  static const ink = Color(0xFF1B1915);
  static const soft = Color(0xFF6E6559);
  static const rule = Color(0xFFE2DACB);

  /// Ballpoint blue: the app did something for you.
  static const pen = Color(0xFF2C55A6);

  /// Highlighter amber: you did something.
  static const marker = Color(0xFFE3B23C);
}

ThemeData bookerizeTheme() {
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Paper.pen,
      surface: Paper.ground,
    ),
    scaffoldBackgroundColor: Paper.ground,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: Paper.ground,
      foregroundColor: Paper.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
  );
}
