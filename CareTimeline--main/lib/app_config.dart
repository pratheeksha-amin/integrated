// ============================================================
// CareTimeline - App Configuration
// ============================================================

class AppConfig {
  /// Integrated AI Key (left empty: API keys must never be hardcoded)
  static const String defaultApiKey = '';

  /// Compile-time API key if provided via --dart-define
  static const String groqDefineApiKey = String.fromEnvironment('GROQ_API_KEY');
  static const String geminiDefineApiKey = String.fromEnvironment('GEMINI_API_KEY');

  static String get dartDefineApiKey {
    if (groqDefineApiKey.trim().isNotEmpty) return groqDefineApiKey.trim();
    if (geminiDefineApiKey.trim().isNotEmpty) return geminiDefineApiKey.trim();
    return '';
  }

  /// Groq API Endpoint & Active Models
  static const String groqBaseUrl = 'https://api.groq.com/openai/v1/chat/completions';
  static const List<String> groqModels = [
    'llama-3.3-70b-versatile',
    'llama-3.1-8b-instant',
    'mixtral-8x7b-32768',
    'gemma2-9b-it',
  ];

  /// Gemini API Endpoint & Active Models
  static const List<String> geminiModels = [
    'gemini-1.5-flash',
    'gemini-2.0-flash',
    'gemini-1.5-pro',
  ];

  static const String geminiModel = 'gemini-1.5-flash';
  static const String geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  static String geminiEndpointWithKey(String apiKey, {String model = geminiModel}) =>
      '$geminiBaseUrl/$model:generateContent?key=$apiKey';

  static bool get hasDefaultApiKey => defaultApiKey.trim().isNotEmpty;
}
