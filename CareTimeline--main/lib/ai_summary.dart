import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'app_config.dart';

enum AiFailureCategory {
  missingConfiguration,
  authentication,
  quotaExceeded,
  timeout,
  network,
  invalidResponse,
  emptyRecords,
  unknown,
}

class AiSummaryException implements Exception {
  final AiFailureCategory category;
  final String message;
  final String diagnostic;

  const AiSummaryException({
    required this.category,
    required this.message,
    this.diagnostic = '',
  });

  String get userMessage => '[${categoryLabel(category)}] $message';

  static String categoryLabel(AiFailureCategory category) {
    switch (category) {
      case AiFailureCategory.missingConfiguration:
        return 'Missing configuration';
      case AiFailureCategory.authentication:
        return 'Authentication failure';
      case AiFailureCategory.quotaExceeded:
        return 'Quota exceeded';
      case AiFailureCategory.timeout:
        return 'Timeout';
      case AiFailureCategory.network:
        return 'Network error';
      case AiFailureCategory.invalidResponse:
        return 'Invalid response';
      case AiFailureCategory.emptyRecords:
        return 'Empty records';
      case AiFailureCategory.unknown:
        return 'Unknown error';
    }
  }

  @override
  String toString() => userMessage;
}

class LlmSummaryResult {
  final String text;
  final String model;
  final bool fromLlm;

  const LlmSummaryResult({
    required this.text,
    required this.model,
    this.fromLlm = true,
  });
}

class GeminiAiService {
  static final GeminiAiService instance = GeminiAiService._internal();
  GeminiAiService._internal();

  static const _storage = FlutterSecureStorage();
  static const _apiKeyStorageKey = 'gemini_api_key';
  static const _groqApiKeyStorageKey = 'groq_api_key';
  static const _requestTimeout = Duration(seconds: 25);

  http.Client _client = http.Client();
  String? _debugApiKeyOverride;

  @visibleForTesting
  void debugSetHttpClient(http.Client client) {
    _client = client;
  }

  @visibleForTesting
  void debugSetApiKeyOverride(String? key) {
    _debugApiKeyOverride = key;
  }

  static String? _cleanKey(String? raw) {
    if (raw == null) return null;
    var cleaned = raw.trim();
    while ((cleaned.startsWith('"') && cleaned.endsWith('"')) ||
        (cleaned.startsWith("'") && cleaned.endsWith("'"))) {
      cleaned = cleaned.substring(1, cleaned.length - 1).trim();
    }
    if (cleaned.isEmpty ||
        cleaned.toUpperCase().contains('PASTE_YOUR') ||
        cleaned.toUpperCase().contains('REPLACE_WITH') ||
        cleaned.toUpperCase().contains('YOUR_GROQ_API_KEY') ||
        cleaned.toUpperCase().contains('YOUR_GEMINI_API_KEY')) {
      return null;
    }
    return cleaned;
  }

  // -- Key management ---------------------------------------------------------

  Future<String?> getStoredOverrideKey() async {
    try {
      final groqKey = _cleanKey(await _storage.read(key: _groqApiKeyStorageKey));
      if (groqKey != null) {
        return groqKey;
      }
      final key = _cleanKey(await _storage.read(key: _apiKeyStorageKey));
      if (key != null) {
        return key;
      }
    } catch (_) {}
    return null;
  }

  Future<String?> getApiKey() async {
    if (_debugApiKeyOverride != null) {
      final override = _cleanKey(_debugApiKeyOverride);
      return override;
    }
    // 1. User-configured key in secure storage takes top priority
    final storedKey = await getStoredOverrideKey();
    if (storedKey != null) {
      return storedKey;
    }
    // 2. Compile-time environment define (--dart-define)
    final compileTimeKey = _cleanKey(AppConfig.dartDefineApiKey);
    if (compileTimeKey != null) return compileTimeKey;

    // 3. Local env.json configuration file fallback (for development)
    try {
      if (!kIsWeb) {
        final envFile = File('env.json');
        if (envFile.existsSync()) {
          final content = envFile.readAsStringSync();
          final map = jsonDecode(content);
          if (map is Map) {
            final groqKey = _cleanKey(map['GROQ_API_KEY']?.toString());
            if (groqKey != null) return groqKey;
            final geminiKey = _cleanKey(map['GEMINI_API_KEY']?.toString());
            if (geminiKey != null) return geminiKey;
          }
        }
      }
    } catch (_) {}

    // 4. System environment variable fallback
    try {
      if (!kIsWeb) {
        final envGroq = _cleanKey(Platform.environment['GROQ_API_KEY']);
        if (envGroq != null) return envGroq;
        final envGemini = _cleanKey(Platform.environment['GEMINI_API_KEY']);
        if (envGemini != null) return envGemini;
      }
    } catch (_) {}

    // 5. Default key if configured (must never be hardcoded)
    return _cleanKey(AppConfig.defaultApiKey);
  }

  Future<void> saveApiKey(String key) async {
    try {
      final cleaned = _cleanKey(key);
      if (cleaned == null) {
        await clearApiKey();
        return;
      }
      if (cleaned.startsWith('gsk_') || cleaned.contains('gsk_')) {
        await _storage.write(key: _groqApiKeyStorageKey, value: cleaned);
        await _storage.delete(key: _apiKeyStorageKey);
      } else {
        await _storage.write(key: _apiKeyStorageKey, value: cleaned);
        await _storage.delete(key: _groqApiKeyStorageKey);
      }
    } catch (_) {}
  }

  Future<void> clearApiKey() async {
    try {
      await _storage.delete(key: _groqApiKeyStorageKey);
      await _storage.delete(key: _apiKeyStorageKey);
    } catch (_) {}
  }

  // -- Prompt / parsing helpers (testable) ------------------------------------

  @visibleForTesting
  static List<Map<String, dynamic>> anonymizeRecords(
    List<Map<String, dynamic>> records,
  ) {
    final chronological = List<Map<String, dynamic>>.from(records)
      ..sort((a, b) => '${a['recordDate']}'.compareTo('${b['recordDate']}'));

    return chronological.map((r) {
      return {
        'date': r['recordDate'],
        'symptom': r['symptomName'],
        'severity': '${r['severity']}/10',
        'description': (r['description'] ?? '').toString().trim().isEmpty
            ? null
            : r['description'],
        'medicine': (r['medicineName'] ?? '').toString().trim().isEmpty
            ? 'None recorded'
            : r['medicineName'],
        'medicine_taken': (r['medicineTaken'] == 1) ? 'Yes' : 'No',
        'observed_effects': (r['observedEffects'] ?? '').toString().trim().isEmpty
            ? 'None recorded'
            : r['observedEffects'],
        'notes': (r['notes'] ?? '').toString().trim().isEmpty ? null : r['notes'],
      }..removeWhere((key, value) => value == null);
    }).toList();
  }

  @visibleForTesting
  static String buildSummaryPrompt(List<Map<String, dynamic>> records) {
    final payload = anonymizeRecords(records);
    return '''
You are a factual clinical summarization assistant for CareTimeline.
The records below are patient-reported logs, not verified medical facts.

Strict rules:
- Never invent symptoms, medicines, dates, diagnoses, or patient history.
- If information is missing or too sparse, say so explicitly.
- Distinguish patient-reported observations from verified medical facts.
- Do not diagnose the patient.
- Do not independently recommend medication changes or new treatments.
- Treat this output as informational support for a doctor, not a substitute for professional judgement.
- Use only the records provided.

Patient-reported health timeline (JSON):
${const JsonEncoder.withIndent('  ').convert(payload)}

Write a concise, readable summary with exactly these section headings:
Overview:
Symptom patterns:
Medication observations:
Points for the doctor:

Keep the language factual. If a section has no supporting records, state that the available information is insufficient.
''';
  }

  @visibleForTesting
  static String? extractGeneratedText(dynamic decoded) {
    if (decoded is! Map) return null;
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;

    final first = candidates.first;
    if (first is! Map) return null;
    final content = first['content'];
    if (content is! Map) return null;
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) return null;

    final texts = <String>[];
    for (final part in parts) {
      if (part is! Map) continue;
      if (part['thought'] == true) continue;
      final text = part['text'];
      if (text is String && text.trim().isNotEmpty) {
        texts.add(text.trim());
      }
    }
    if (texts.isEmpty) return null;
    return texts.join('\n\n');
  }

  @visibleForTesting
  static AiSummaryException classifyHttpError({
    required int statusCode,
    required String body,
    required String model,
  }) {
    final sanitized = _sanitizeForLog(body);
    final lower = sanitized.toLowerCase();

    if (statusCode == 401) {
      return AiSummaryException(
        category: AiFailureCategory.authentication,
        message: 'Authentication failure: The AI service rejected the configured API key.',
        diagnostic: 'HTTP 401 model=$model',
      );
    }

    if (statusCode == 403) {
      if (lower.contains('quota') || lower.contains('exceed')) {
        return AiSummaryException(
          category: AiFailureCategory.quotaExceeded,
          message: 'Quota exceeded for this API key (HTTP 403).',
          diagnostic: 'HTTP 403 model=$model',
        );
      }
      return AiSummaryException(
        category: AiFailureCategory.authentication,
        message: 'API permission or access issue (HTTP 403). Check project access or API key permissions.',
        diagnostic: 'HTTP 403 model=$model',
      );
    }

    if (statusCode == 400) {
      if (lower.contains('api key') ||
          lower.contains('api_key') ||
          lower.contains('unauthenticated') ||
          lower.contains('invalid_api_key')) {
        return AiSummaryException(
          category: AiFailureCategory.authentication,
          message: 'Authentication failure: The AI service rejected the configured API key.',
          diagnostic: 'HTTP 400 model=$model',
        );
      }
      return AiSummaryException(
        category: AiFailureCategory.invalidResponse,
        message: 'Invalid request format, model, or parameters (HTTP 400).',
        diagnostic: 'HTTP 400 model=$model',
      );
    }

    if (statusCode == 429) {
      return AiSummaryException(
        category: AiFailureCategory.quotaExceeded,
        message: 'Rate limit or quota exceeded (HTTP 429). Please try again later.',
        diagnostic: 'HTTP 429 model=$model',
      );
    }

    if (statusCode == 404) {
      return AiSummaryException(
        category: AiFailureCategory.invalidResponse,
        message: 'Model "$model" is not available for this key (HTTP 404).',
        diagnostic: 'HTTP 404 model=$model',
      );
    }

    if (statusCode >= 500) {
      return AiSummaryException(
        category: AiFailureCategory.network,
        message: 'AI provider server error (HTTP $statusCode). Please try again later.',
        diagnostic: 'HTTP $statusCode model=$model',
      );
    }

    return AiSummaryException(
      category: AiFailureCategory.unknown,
      message: 'AI service returned HTTP $statusCode while generating summary.',
      diagnostic: 'HTTP $statusCode model=$model',
    );
  }

  static String _sanitizeForLog(String raw) {
    var text = raw.replaceAll(RegExp(r'gsk_[0-9A-Za-z\-_]{10,}'), '[REDACTED_KEY]');
    text = text.replaceAll(RegExp(r'AIza[0-9A-Za-z\-_]{10,}'), '[REDACTED_KEY]');
    text = text.replaceAll(RegExp(r'key=[^&\s"]+'), 'key=[REDACTED]');
    return text;
  }

  // -- Groq API Call -----------------------------------------------------------

  Future<LlmSummaryResult> _callGroqSummary({
    required String apiKey,
    required List<Map<String, dynamic>> records,
  }) async {
    final prompt = buildSummaryPrompt(records);
    final url = Uri.parse(AppConfig.groqBaseUrl);
    final cleanApiKey = apiKey.trim();
    AiSummaryException? lastException;

    for (final model in AppConfig.groqModels) {
      try {
        final requestBody = jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'system',
              'content': 'You are CareTimeline AI, a factual clinical health summarization assistant.'
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.2,
          'max_tokens': 1000,
        });

        final response = await _client
            .post(
              url,
              headers: {
                'Authorization': 'Bearer $cleanApiKey',
                'Content-Type': 'application/json',
              },
              body: requestBody,
            )
            .timeout(_requestTimeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final text = choices[0]['message']?['content'] as String?;
            if (text != null && text.trim().isNotEmpty) {
              return LlmSummaryResult(
                text: _formatLlmSummary(text.trim(), model),
                model: model,
              );
            }
          }
          throw const AiSummaryException(
            category: AiFailureCategory.invalidResponse,
            message: 'Groq returned an empty or unreadable summary.',
          );
        } else {
          final classified = classifyHttpError(
            statusCode: response.statusCode,
            body: response.body,
            model: model,
          );
          if (classified.category == AiFailureCategory.authentication) {
            throw classified;
          }
          lastException = classified;
          continue;
        }
      } on AiSummaryException catch (e) {
        if (e.category == AiFailureCategory.authentication) {
          rethrow;
        }
        lastException = e;
      } on TimeoutException {
        lastException = const AiSummaryException(
          category: AiFailureCategory.timeout,
          message: 'The AI request timed out.',
        );
      } on SocketException catch (e) {
        throw AiSummaryException(
          category: AiFailureCategory.network,
          message: 'Could not reach AI service. Check internet connection.',
          diagnostic: e.osError?.message ?? e.message,
        );
      } on http.ClientException catch (e) {
        throw AiSummaryException(
          category: AiFailureCategory.network,
          message: 'Could not reach AI service. Check internet connection.',
          diagnostic: e.message,
        );
      } catch (e) {
        lastException = AiSummaryException(
          category: AiFailureCategory.unknown,
          message: 'Error calling Groq service: $e',
          diagnostic: 'model=$model',
        );
      }
    }

    throw lastException ??
        const AiSummaryException(
          category: AiFailureCategory.network,
          message: 'Groq LLM service failed to generate summary.',
        );
  }

  static String _formatLlmSummary(String text, String model) {
    return '=== CARETIMELINE LLM-GENERATED SUMMARY ===\n'
        'Source: AI Model ($model)\n'
        'Note: Patient-reported records were processed by CareTimeline AI.\n'
        '----------------------------------------------------\n'
        '$text\n'
        '----------------------------------------------------\n'
        'Disclaimer: Informational support for a doctor. Not a diagnosis or a substitute for professional judgement.';
  }

  // -- Core summary generator --------------------------------------------------

  Future<LlmSummaryResult> generateSummary({
    required List<Map<String, dynamic>> records,
  }) async {
    if (records.isEmpty) {
      throw const AiSummaryException(
        category: AiFailureCategory.emptyRecords,
        message: 'No health records are available to summarize.',
      );
    }

    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const AiSummaryException(
        category: AiFailureCategory.missingConfiguration,
        message: 'No AI key is configured.',
      );
    }

    final cleanKey = _cleanKey(apiKey) ?? apiKey.trim();
    if (cleanKey.startsWith('gsk_') || cleanKey.contains('gsk_')) {
      return await _callGroqSummary(apiKey: cleanKey, records: records);
    }

    final prompt = buildSummaryPrompt(records);
    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.2,
        'maxOutputTokens': 1200,
      }
    });

    for (final model in AppConfig.geminiModels) {
      final url = Uri.parse(AppConfig.geminiEndpointWithKey(apiKey, model: model));

      try {
        final response = await _client
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': apiKey,
              },
              body: requestBody,
            )
            .timeout(_requestTimeout);

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final text = extractGeneratedText(decoded);
          if (text != null && text.trim().isNotEmpty) {
            return LlmSummaryResult(
              text: _formatLlmSummary(text.trim(), model),
              model: model,
            );
          }
          throw const AiSummaryException(
            category: AiFailureCategory.invalidResponse,
            message: 'Gemini returned an empty or unreadable summary.',
          );
        }

        final classified = classifyHttpError(
          statusCode: response.statusCode,
          body: response.body,
          model: model,
        );
        if (response.statusCode == 404) continue;
        throw classified;
      } on AiSummaryException {
        rethrow;
      } on TimeoutException {
        throw const AiSummaryException(
          category: AiFailureCategory.timeout,
          message: 'The AI request timed out.',
        );
      } on SocketException catch (e) {
        throw AiSummaryException(
          category: AiFailureCategory.network,
          message: 'Could not reach AI service. Check internet connection.',
          diagnostic: e.osError?.message ?? e.message,
        );
      } on http.ClientException catch (e) {
        throw AiSummaryException(
          category: AiFailureCategory.network,
          message: 'Could not reach AI service. Check internet connection.',
          diagnostic: e.message,
        );
      } catch (e) {
        if (e is AiSummaryException) rethrow;
      }
    }

    throw const AiSummaryException(
      category: AiFailureCategory.unknown,
      message: 'Failed to generate LLM summary.',
    );
  }

  /// Tries LLM only.
  Future<(String, bool)> generateSummaryWithFallback({
    required List<Map<String, dynamic>> records,
  }) async {
    final result = await generateSummary(records: records);
    return (result.text, true);
  }

  // -- Interactive AI Health Assistant -----------------------------------------

  Future<String> askAiAssistant({
    required List<Map<String, dynamic>> records,
    required String question,
  }) async {
    final apiKey = await getApiKey();
    if (apiKey == null || apiKey.trim().isEmpty) {
      throw const AiSummaryException(
        category: AiFailureCategory.missingConfiguration,
        message: 'No AI key is configured for the assistant.',
      );
    }

    final prompt = '''
You are CareTimeline AI, a factual clinical health-timeline assistant.
Answer using only the patient-reported records below.
Do not diagnose or recommend medication changes.
If the records are insufficient, say so.

User Question: "$question"

Health Records:
${const JsonEncoder.withIndent('  ').convert(anonymizeRecords(records))}
''';

    final cleanApiKey = _cleanKey(apiKey) ?? apiKey.trim();
    if (cleanApiKey.startsWith('gsk_') || cleanApiKey.contains('gsk_')) {
      final url = Uri.parse(AppConfig.groqBaseUrl);
      for (final model in AppConfig.groqModels) {
        try {
          final requestBody = jsonEncode({
            'model': model,
            'messages': [
              {
                'role': 'system',
                'content': 'You are CareTimeline AI, an intelligent clinical health assistant.'
              },
              {'role': 'user', 'content': prompt},
            ],
            'temperature': 0.3,
            'max_tokens': 700,
          });

          final response = await _client
              .post(
                url,
                headers: {
                  'Authorization': 'Bearer $cleanApiKey',
                  'Content-Type': 'application/json',
                },
                body: requestBody,
              )
              .timeout(_requestTimeout);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            final choices = data['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final text = choices[0]['message']?['content'] as String?;
              if (text != null && text.trim().isNotEmpty) {
                return text.trim();
              }
            }
          } else {
            final classified = classifyHttpError(
              statusCode: response.statusCode,
              body: response.body,
              model: model,
            );
            if (classified.category == AiFailureCategory.authentication) {
              throw classified;
            }
          }
        } on AiSummaryException catch (e) {
          if (e.category == AiFailureCategory.authentication) {
            rethrow;
          }
        } catch (_) {}
      }
      throw const AiSummaryException(
        category: AiFailureCategory.network,
        message: 'Groq assistant service failed to generate response.',
      );
    }

    final requestBody = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.3,
        'maxOutputTokens': 700,
      }
    });

    for (final model in AppConfig.geminiModels) {
      final url = Uri.parse(AppConfig.geminiEndpointWithKey(apiKey, model: model));
      try {
        final response = await _client
            .post(
              url,
              headers: {
                'Content-Type': 'application/json',
                'x-goog-api-key': apiKey,
              },
              body: requestBody,
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 200) {
          final decoded = jsonDecode(response.body);
          final text = extractGeneratedText(decoded);
          if (text != null && text.trim().isNotEmpty) {
            return text.trim();
          }
        }
      } catch (_) {}
    }

    throw const AiSummaryException(
      category: AiFailureCategory.unknown,
      message: 'The AI assistant could not complete the request.',
    );
  }
}
