import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsState { playing, paused, stopped }

class TtsService {
  static final TtsService instance = TtsService._internal();

  late FlutterTts _flutterTts;
  final ValueNotifier<TtsState> stateNotifier = ValueNotifier<TtsState>(TtsState.stopped);
  String? _lastSpokenText;
  String? _lastLanguageCode;

  TtsService._internal() {
    _initTts();
  }

  void _initTts() {
    _flutterTts = FlutterTts();

    _flutterTts.setStartHandler(() {
      stateNotifier.value = TtsState.playing;
    });

    _flutterTts.setCompletionHandler(() {
      stateNotifier.value = TtsState.stopped;
    });

    _flutterTts.setPauseHandler(() {
      stateNotifier.value = TtsState.paused;
    });

    _flutterTts.setContinueHandler(() {
      stateNotifier.value = TtsState.playing;
    });

    _flutterTts.setErrorHandler((msg) {
      stateNotifier.value = TtsState.stopped;
    });

    // Default rates and pitch
    _flutterTts.setSpeechRate(0.45);
    _flutterTts.setVolume(1.0);
    _flutterTts.setPitch(1.0);
  }

  static String mapLanguageCodeToTts(String langCode) {
    switch (langCode.toLowerCase()) {
      case 'hi':
        return 'hi-IN';
      case 'kn':
        return 'kn-IN';
      case 'ta':
        return 'ta-IN';
      case 'te':
        return 'te-IN';
      case 'ml':
        return 'ml-IN';
      case 'en':
      default:
        return 'en-US';
    }
  }

  Future<void> speak(String text, {String languageCode = 'en'}) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    // Stop any existing speech first
    await stop();

    _lastSpokenText = cleanText;
    _lastLanguageCode = languageCode;

    final ttsLang = mapLanguageCodeToTts(languageCode);

    try {
      bool isSupported = true;
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final available = await _flutterTts.isLanguageAvailable(ttsLang);
        if (available == false) {
          isSupported = false;
        }
      }

      if (isSupported) {
        await _flutterTts.setLanguage(ttsLang);
      } else {
        // Fallback to English if device voice engine lacks requested language
        await _flutterTts.setLanguage('en-US');
      }

      stateNotifier.value = TtsState.playing;
      await _flutterTts.speak(cleanText);
    } catch (_) {
      try {
        await _flutterTts.setLanguage('en-US');
        stateNotifier.value = TtsState.playing;
        await _flutterTts.speak(cleanText);
      } catch (_) {
        stateNotifier.value = TtsState.stopped;
      }
    }
  }

  Future<void> pause() async {
    try {
      if (stateNotifier.value == TtsState.playing) {
        final result = await _flutterTts.pause();
        if (result == 1) {
          stateNotifier.value = TtsState.paused;
        } else {
          // If native pause is not supported, stop speech
          await stop();
        }
      }
    } catch (_) {
      await stop();
    }
  }

  Future<void> resume() async {
    if (stateNotifier.value == TtsState.paused && _lastSpokenText != null) {
      try {
        stateNotifier.value = TtsState.playing;
        await _flutterTts.speak(_lastSpokenText!);
      } catch (_) {
        await stop();
      }
    } else if (_lastSpokenText != null) {
      await speak(_lastSpokenText!, languageCode: _lastLanguageCode ?? 'en');
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
    } catch (_) {}
    stateNotifier.value = TtsState.stopped;
  }
}
