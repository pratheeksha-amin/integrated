import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontSizeService {
  static final FontSizeService instance = FontSizeService._internal();
  FontSizeService._internal() {
    _loadSavedFontSize();
  }

  static const double defaultFontSize = 14.0;
  static const double minFontSize = 10.0;
  static const double maxFontSize = 24.0;
  static const double step = 2.0;

  final ValueNotifier<double> fontSizeNotifier = ValueNotifier<double>(defaultFontSize);

  double get currentFontSize => fontSizeNotifier.value;

  /// Returns scale factor relative to default (14.0)
  double get scaleFactor => fontSizeNotifier.value / defaultFontSize;

  Future<void> _loadSavedFontSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble('accessibility_font_size');
      if (saved != null && saved >= minFontSize && saved <= maxFontSize) {
        fontSizeNotifier.value = saved;
      }
    } catch (_) {}
  }

  Future<void> increaseFontSize() async {
    if (fontSizeNotifier.value + step <= maxFontSize) {
      fontSizeNotifier.value += step;
      await _saveFontSize();
    }
  }

  Future<void> decreaseFontSize() async {
    if (fontSizeNotifier.value - step >= minFontSize) {
      fontSizeNotifier.value -= step;
      await _saveFontSize();
    }
  }

  Future<void> resetFontSize() async {
    fontSizeNotifier.value = defaultFontSize;
    await _saveFontSize();
  }

  Future<void> _saveFontSize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('accessibility_font_size', fontSizeNotifier.value);
    } catch (_) {}
  }
}
