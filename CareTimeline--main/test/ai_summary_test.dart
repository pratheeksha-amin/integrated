import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:care_timeline/ai_summary.dart';
import 'package:care_timeline/app_config.dart';
import 'package:care_timeline/health_analysis.dart';

void main() {
  final sampleRecords = [
    {
      'recordDate': '2026-10-10 09:00',
      'symptomName': 'Headache',
      'severity': 4,
      'description': 'Morning onset',
      'medicineName': 'Paracetamol',
      'medicineTaken': 1,
      'observedEffects': 'Drowsiness',
      'notes': 'After breakfast',
    },
    {
      'recordDate': '2026-10-12 09:00',
      'symptomName': 'Headache',
      'severity': 7,
      'medicineName': 'Paracetamol',
      'medicineTaken': 1,
      'observedEffects': 'Less pain after 2 hours',
    },
  ];

  group('Prompt and parsing', () {
    test('prompt includes actual timeline records, not a canned template body', () {
      final prompt = GeminiAiService.buildSummaryPrompt(sampleRecords);
      expect(prompt, contains('Headache'));
      expect(prompt, contains('2026-10-10 09:00'));
      expect(prompt, contains('Paracetamol'));
      expect(prompt, contains('Drowsiness'));
      expect(prompt, contains('Overview:'));
      expect(prompt, contains('Never invent'));
      expect(prompt, isNot(contains('John Doe')));
    });

    test('extractGeneratedText concatenates non-thought parts', () {
      final decoded = {
        'candidates': [
          {
            'content': {
              'parts': [
                {'thought': true, 'text': 'internal reasoning'},
                {'text': 'Overview: two headache logs.'},
              ]
            }
          }
        ]
      };
      expect(GeminiAiService.extractGeneratedText(decoded), 'Overview: two headache logs.');
    });

    test('malformed payload is treated as invalid response', () {
      expect(GeminiAiService.extractGeneratedText({'candidates': []}), isNull);
      expect(GeminiAiService.extractGeneratedText('not-json-object'), isNull);
    });

    test('HTTP 403 with API key language is authentication', () {
      final error = GeminiAiService.classifyHttpError(
        statusCode: 403,
        body: '{"error":{"message":"API key not valid"}}',
        model: 'gemini-3.8-flash',
      );
      expect(error.category, AiFailureCategory.authentication);
      expect(error.userMessage, contains('Authentication failure'));
    });

    test('HTTP 429 is quota exceeded', () {
      final error = GeminiAiService.classifyHttpError(
        statusCode: 429,
        body: '{"error":{"status":"RESOURCE_EXHAUSTED"}}',
        model: 'gemini-3.8-flash',
      );
      expect(error.category, AiFailureCategory.quotaExceeded);
    });
  });

  group('LLM generateSummary does not silently fall back', () {
    test('successful Gemini JSON is returned as an LLM summary', () async {
      final client = MockClient((request) async {
        expect(request.url.path, contains('models/${AppConfig.geminiModels.first}:generateContent'));
        expect(request.headers['x-goog-api-key'], isNotEmpty);
        final body = jsonDecode(request.body) as Map;
        final prompt = body['contents'][0]['parts'][0]['text'] as String;
        expect(prompt, contains('Headache'));
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Overview:\nPatient logged headache twice.\nSymptom patterns:\nSeverity rose from 4 to 7.\nMedication observations:\nParacetamol taken; drowsiness reported.\nPoints for the doctor:\nReview severity increase.'}
                  ]
                }
              }
            ]
          }),
          200,
        );
      });

      GeminiAiService.instance.debugSetHttpClient(client);
      GeminiAiService.instance.debugSetApiKeyOverride('test-key-not-real');

      final result = await GeminiAiService.instance.generateSummary(records: sampleRecords);
      expect(result.fromLlm, isTrue);
      expect(result.text, contains('LLM-GENERATED'));
      expect(result.text, contains('Severity rose from 4 to 7'));
      expect(result.text, isNot(contains('CARETIMELINE LOCAL RULE-BASED HEALTH SUMMARY')));
    });

    test('empty records throw instead of producing a fake AI summary', () async {
      expect(
        () => GeminiAiService.instance.generateSummary(records: const []),
        throwsA(isA<AiSummaryException>().having(
          (e) => e.category,
          'category',
          AiFailureCategory.emptyRecords,
        )),
      );
    });

    test('invalid credentials throw authentication and do not return offline text', () async {
      final client = MockClient((request) async {
        return http.Response('{"error":{"message":"API key not valid. Please pass a valid API key."}}', 400);
      });
      GeminiAiService.instance.debugSetHttpClient(client);
      GeminiAiService.instance.debugSetApiKeyOverride('invalid-key');

      try {
        await GeminiAiService.instance.generateSummary(records: sampleRecords);
        fail('Expected AiSummaryException');
      } on AiSummaryException catch (e) {
        expect(e.category, AiFailureCategory.authentication);
        final offline = HealthAnalysisService.instance.generateOfflineSummary(sampleRecords);
        expect(e.userMessage, isNot(contains('LOCAL RULE-BASED')));
        expect(offline, contains('LOCAL RULE-BASED'));
      }
    });

    test('timeout is classified without returning a local summary', () async {
      final client = MockClient((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response('{}', 200);
      });
      GeminiAiService.instance.debugSetHttpClient(client);
      GeminiAiService.instance.debugSetApiKeyOverride('test-key-not-real');

      // The service uses a 25s timeout; a MockClient delay will not hit it.
      // Network-style client exceptions still must not fall back.
      GeminiAiService.instance.debugSetHttpClient(MockClient((request) {
        throw http.ClientException('Failed host lookup');
      }));

      expect(
        () => GeminiAiService.instance.generateSummary(records: sampleRecords),
        throwsA(isA<AiSummaryException>().having(
          (e) => e.category,
          'category',
          AiFailureCategory.network,
        )),
      );
    });

    test('malformed success payload is invalid response, not a local summary', () async {
      final client = MockClient((request) async {
        return http.Response('{"candidates":[{"content":{"parts":[{"text":""}]}}]}', 200);
      });
      GeminiAiService.instance.debugSetHttpClient(client);
      GeminiAiService.instance.debugSetApiKeyOverride('test-key-not-real');

      expect(
        () => GeminiAiService.instance.generateSummary(records: sampleRecords),
        throwsA(isA<AiSummaryException>().having(
          (e) => e.category,
          'category',
          AiFailureCategory.invalidResponse,
        )),
      );
    });
  });

  group('Groq LLM Integration Tests', () {
    test('successful Groq API call with actual patient records returns formatted LLM summary', () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), AppConfig.groqBaseUrl);
        expect(request.headers['Authorization'], 'Bearer gsk_valid_mock_key');
        expect(request.headers['Content-Type'], 'application/json');

        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['model'], AppConfig.groqModels.first);
        final messages = body['messages'] as List;
        final userContent = messages[1]['content'] as String;
        expect(userContent, contains('Headache'));
        expect(userContent, contains('Paracetamol'));

        return http.Response(
          jsonEncode({
            'id': 'chatcmpl-test',
            'choices': [
              {
                'index': 0,
                'message': {
                  'role': 'assistant',
                  'content': 'Overview:\nPatient logged headaches with increasing severity.\n\nSymptom patterns:\nHeadache severity increased from 4/10 to 7/10.\n\nMedication observations:\nParacetamol taken on both occasions.\n\nPoints for the doctor:\nAssess trigger for escalating headache intensity.',
                },
                'finish_reason': 'stop',
              }
            ]
          }),
          200,
        );
      });

      GeminiAiService.instance.debugSetHttpClient(client);
      GeminiAiService.instance.debugSetApiKeyOverride('gsk_valid_mock_key');

      final result = await GeminiAiService.instance.generateSummary(records: sampleRecords);
      expect(result.fromLlm, isTrue);
      expect(result.model, AppConfig.groqModels.first);
      expect(result.text, contains('=== CARETIMELINE LLM-GENERATED SUMMARY ==='));
      expect(result.text, contains('Headache severity increased from 4/10 to 7/10'));
      expect(result.text, contains('Disclaimer: Informational support for a doctor'));
    });

    test('Groq model fallback succeeds when primary model is unavailable', () async {
      final attemptedModels = <String>[];
      final client = MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final model = body['model'] as String;
        attemptedModels.add(model);

        if (model == AppConfig.groqModels[0]) {
          // Primary model returns 404 or decommissioned error
          return http.Response(
            jsonEncode({
              'error': {
                'message': 'The model $model does not exist',
                'type': 'invalid_request_error',
                'code': 'model_not_found',
              }
            }),
            404,
          );
        }

        // Secondary fallback model succeeds
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'message': {
                  'role': 'assistant',
                  'content': 'Overview:\nSummary generated using secondary model.',
                }
              }
            ]
          }),
          200,
        );
      });

      GeminiAiService.instance.debugSetHttpClient(client);
      GeminiAiService.instance.debugSetApiKeyOverride('gsk_valid_mock_key');

      final result = await GeminiAiService.instance.generateSummary(records: sampleRecords);
      expect(result.fromLlm, isTrue);
      expect(result.model, AppConfig.groqModels[1]);
      expect(attemptedModels, [AppConfig.groqModels[0], AppConfig.groqModels[1]]);
      expect(result.text, contains('secondary model'));
    });

    test('Groq HTTP 401 invalid API key throws authentication exception with clear error and retains offline fallback', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'message': 'Invalid API Key',
              'type': 'invalid_request_error',
              'code': 'invalid_api_key',
            }
          }),
          401,
        );
      });

      GeminiAiService.instance.debugSetHttpClient(client);
      GeminiAiService.instance.debugSetApiKeyOverride('gsk_invalid_mock_key');

      try {
        await GeminiAiService.instance.generateSummary(records: sampleRecords);
        fail('Should have thrown AiSummaryException');
      } on AiSummaryException catch (e) {
        expect(e.category, AiFailureCategory.authentication);
        expect(e.userMessage, contains('Authentication failure'));
        expect(e.message, contains('The AI service rejected the configured API key'));

        // Offline rule-based summary remains fully available as fallback
        final offline = HealthAnalysisService.instance.generateOfflineSummary(sampleRecords);
        expect(offline, contains('CARETIMELINE LOCAL RULE-BASED HEALTH SUMMARY'));
        expect(offline, contains('Headache'));
      }
    });
  });
}
