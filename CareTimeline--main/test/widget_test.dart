import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:care_timeline/health_analysis.dart';
import 'package:care_timeline/report_service.dart';
import 'package:care_timeline/auth_screens.dart';

void main() {
  group('Rule-Based Health Pattern Analysis Tests', () {
    test('Empty records list returns no data pattern', () {
      final patterns = HealthAnalysisService.instance.detectPatterns([]);
      expect(patterns.length, 1);
      expect(patterns.first.type, 'info');
      expect(patterns.first.title, contains('No Data'));
    });

    test('Fewer than 3 records flags insufficient data rule', () {
      final records = [
        {'recordDate': '2026-10-15 09:00', 'symptomName': 'Headache', 'severity': 4, 'medicineTaken': 0},
        {'recordDate': '2026-10-16 09:00', 'symptomName': 'Headache', 'severity': 5, 'medicineTaken': 0},
      ];
      final patterns = HealthAnalysisService.instance.detectPatterns(records);
      expect(patterns.any((p) => p.title.contains('Insufficient Data')), isTrue);
    });

    test('Recurring symptoms detected with case normalization', () {
      final records = [
        {'recordDate': '2026-10-14 09:00', 'symptomName': 'Migraine', 'severity': 5, 'medicineTaken': 0},
        {'recordDate': '2026-10-15 09:00', 'symptomName': 'migraine ', 'severity': 6, 'medicineTaken': 0},
        {'recordDate': '2026-10-16 09:00', 'symptomName': 'MIGRAINE', 'severity': 7, 'medicineTaken': 0},
      ];
      final patterns = HealthAnalysisService.instance.detectPatterns(records);
      final recurring = patterns.where((p) => p.type == 'recurring').toList();
      expect(recurring.isNotEmpty, isTrue);
      expect(recurring.first.title, contains('Recurring Symptom: Migraine'));
    });

    test('Increasing severity trend rule flags upward progression', () {
      final records = [
        {'recordDate': '2026-10-14 09:00', 'symptomName': 'Cough', 'severity': 3, 'medicineTaken': 0},
        {'recordDate': '2026-10-15 09:00', 'symptomName': 'Cough', 'severity': 5, 'medicineTaken': 0},
        {'recordDate': '2026-10-16 09:00', 'symptomName': 'Cough', 'severity': 8, 'medicineTaken': 0},
      ];
      final patterns = HealthAnalysisService.instance.detectPatterns(records);
      final upward = patterns.where((p) => p.type == 'increasing_severity').toList();
      expect(upward.isNotEmpty, isTrue);
      expect(upward.first.title, contains('Increasing Severity Trend'));
    });

    test('Repeated medication observation identified without claiming causation', () {
      final records = [
        {'recordDate': '2026-10-14', 'symptomName': 'Fever', 'severity': 6, 'medicineName': 'Paracetamol', 'medicineTaken': 1, 'observedEffects': 'sweating and nausea'},
        {'recordDate': '2026-10-15', 'symptomName': 'Fever', 'severity': 5, 'medicineName': 'Paracetamol', 'medicineTaken': 1, 'observedEffects': 'sweating and nausea'},
        {'recordDate': '2026-10-16', 'symptomName': 'Fever', 'severity': 4, 'medicineName': 'Paracetamol', 'medicineTaken': 0, 'observedEffects': ''},
      ];
      final patterns = HealthAnalysisService.instance.detectPatterns(records);
      final medObs = patterns.where((p) => p.type == 'medication_observation').toList();
      expect(medObs.isNotEmpty, isTrue);
      expect(medObs.first.ruleExplanation, contains('Correlative observation only'));
    });

    test('Offline rule-based summary generates proper period and metrics', () {
      final records = [
        {'recordDate': '2026-10-10 10:00', 'symptomName': 'Asthma', 'severity': 4, 'medicineName': 'Inhaler', 'medicineTaken': 1},
        {'recordDate': '2026-10-12 10:00', 'symptomName': 'Asthma', 'severity': 6, 'medicineName': 'Inhaler', 'medicineTaken': 1},
      ];
      final summary = HealthAnalysisService.instance.generateOfflineSummary(records);
      expect(summary, contains('CARETIMELINE LOCAL RULE-BASED HEALTH SUMMARY'));
      expect(summary, contains('2026-10-10 10:00 to 2026-10-12 10:00'));
      expect(summary, contains('Total Recorded Entries: 2'));
    });
  });

  group('Report JSON Validation Tests', () {
    test('Valid report JSON parsed cleanly', () {
      const validJson = '''
      {
        "schemaVersion": "1.0.0",
        "app": "CareTimeline",
        "patientReference": "PT-123456",
        "exportDate": "2026-10-18T10:00:00Z",
        "records": [
          {
            "recordDate": "2026-10-18 09:00",
            "symptomName": "Fatigue",
            "severity": 4
          }
        ]
      }
      ''';
      final parsed = ReportService.instance.validateAndParseJsonReport(validJson);
      expect(parsed['patientReference'], 'PT-123456');
      expect((parsed['records'] as List).length, 1);
    });

    test('Malformed JSON throws FormatException', () {
      expect(
        () => ReportService.instance.validateAndParseJsonReport('{invalid json}'),
        throwsA(isA<FormatException>()),
      );
    });

    test('Unsupported schema version rejected', () {
      const wrongVersionJson = '''
      {
        "schemaVersion": "2.0.0",
        "records": [{"recordDate": "2026-10-18", "symptomName": "Pain", "severity": 5}]
      }
      ''';
      expect(
        () => ReportService.instance.validateAndParseJsonReport(wrongVersionJson),
        throwsA(isA<FormatException>()),
      );
    });

    test('Invalid severity out of range rejected', () {
      const invalidSeverityJson = '''
      {
        "schemaVersion": "1.0.0",
        "records": [{"recordDate": "2026-10-18", "symptomName": "Pain", "severity": 15}]
      }
      ''';
      expect(
        () => ReportService.instance.validateAndParseJsonReport(invalidSeverityJson),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('Welcome Screen UI Test', () {
    testWidgets('Renders CareTimeline Welcome Screen with action buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: WelcomeScreen(onAuthenticated: (_) {}),
        ),
      );

      expect(find.text('CareTimeline'), findsOneWidget);
      expect(find.text('Create New Account'), findsOneWidget);
      expect(find.text('Sign In to Existing Account'), findsOneWidget);
      expect(find.text('100% Offline-Ready Storage'), findsOneWidget);
    });
  });
}
