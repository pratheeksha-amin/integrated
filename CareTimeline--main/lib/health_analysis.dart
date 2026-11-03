class DetectedPattern {
  final String title;
  final String type; // 'recurring', 'increasing_severity', 'medication_observation', 'info'
  final String description;
  final String supportingData;
  final String ruleExplanation;

  const DetectedPattern({
    required this.title,
    required this.type,
    required this.description,
    required this.supportingData,
    required this.ruleExplanation,
  });
}

class HealthAnalysisService {
  static final HealthAnalysisService instance = HealthAnalysisService._internal();

  HealthAnalysisService._internal();

  // Pattern detection logic executed 100% locally in Dart
  List<DetectedPattern> detectPatterns(List<Map<String, dynamic>> records) {
    final patterns = <DetectedPattern>[];

    if (records.isEmpty) {
      patterns.add(const DetectedPattern(
        title: 'No Data Logged Yet',
        type: 'info',
        description: 'Log your daily symptoms to enable automatic pattern detection.',
        supportingData: '0 health records recorded.',
        ruleExplanation: 'Pattern detection requires health records over multiple dates.',
      ));
      return patterns;
    }

    if (records.length < 3) {
      patterns.add(DetectedPattern(
        title: 'Insufficient Data for Trend Analysis',
        type: 'info',
        description: 'You have logged ${records.length} record(s). At least 3 records are needed to reliably identify trends and recurring patterns.',
        supportingData: '${records.length} record(s) logged.',
        ruleExplanation: 'Rule: Minimum threshold of 3 distinct entries required to avoid false pattern alerts.',
      ));
      return patterns;
    }

    // 1. Recurring Symptoms Detection (Normalized case & whitespace)
    final symptomCounts = <String, int>{};
    final symptomRecords = <String, List<Map<String, dynamic>>>{};

    for (final r in records) {
      final name = (r['symptomName'] as String? ?? '').trim().toLowerCase();
      if (name.isEmpty) continue;
      symptomCounts[name] = (symptomCounts[name] ?? 0) + 1;
      symptomRecords.putIfAbsent(name, () => []).add(r);
    }

    symptomCounts.forEach((symptom, count) {
      if (count >= 2) {
        final displayName = symptomRecords[symptom]!.first['symptomName'] as String;
        final dates = symptomRecords[symptom]!
            .map((r) => '${r['recordDate']} (Sev: ${r['severity']}/10)')
            .take(4)
            .join(', ');

        patterns.add(DetectedPattern(
          title: 'Recurring Symptom: $displayName',
          type: 'recurring',
          description: '$displayName has been recorded $count times in your history.',
          supportingData: 'Entries: $dates',
          ruleExplanation: 'Rule: Identified when a normalized symptom name appears across 2 or more distinct entries.',
        ));
      }
    });

    // 2. Increasing Symptom Severity Trend
    symptomRecords.forEach((symptom, recs) {
      if (recs.length >= 3) {
        // Sort chronologically ascending for trend detection
        final chronological = List<Map<String, dynamic>>.from(recs)
          ..sort((a, b) => (a['recordDate'] as String).compareTo(b['recordDate'] as String));

        final severities = chronological.map((r) => (r['severity'] as num).toInt()).toList();
        final len = severities.length;
        final recent3 = severities.sublist(len - 3);

        // Check strictly increasing recent trend
        if (recent3[0] < recent3[1] && recent3[1] <= recent3[2]) {
          final displayName = chronological.first['symptomName'] as String;
          final recentDates = chronological
              .sublist(len - 3)
              .map((r) => '${r['recordDate']}: Sev ${r['severity']}')
              .join(' -> ');

          patterns.add(DetectedPattern(
            title: 'Increasing Severity Trend: $displayName',
            type: 'increasing_severity',
            description: 'Severity for $displayName has shown an upward trend over the last 3 logged entries ($recentDates).',
            supportingData: 'Recent progression: $recentDates',
            ruleExplanation: 'Rule: Triggered when 3 consecutive chronological entries for the same symptom have increasing severity values.',
          ));
        }
      }
    });

    // 3. Repeated Medication-Related Observations
    final medObservations = <String, Map<String, int>>{};

    for (final r in records) {
      final med = (r['medicineName'] as String? ?? '').trim();
      final taken = (r['medicineTaken'] as int? ?? 0) == 1;
      final effect = (r['observedEffects'] as String? ?? '').trim().toLowerCase();

      if (med.isNotEmpty && taken && effect.isNotEmpty) {
        final medLower = med.toLowerCase();
        medObservations.putIfAbsent(medLower, () => {});
        medObservations[medLower]![effect] = (medObservations[medLower]![effect] ?? 0) + 1;
      }
    }

    medObservations.forEach((medKey, effects) {
      effects.forEach((effect, count) {
        if (count >= 2) {
          patterns.add(DetectedPattern(
            title: 'Repeated Observation with $medKey',
            type: 'medication_observation',
            description: 'Reported observation "$effect" recorded $count times after taking $medKey.',
            supportingData: 'Frequency: $count occurrences logged by user.',
            ruleExplanation: 'Rule: User-reported observation repeated >= 2 times when medicine was taken. (Note: Correlative observation only, not clinical causation).',
          ));
        }
      });
    });

    if (patterns.isEmpty) {
      patterns.add(const DetectedPattern(
        title: 'Stable / No Critical Patterns',
        type: 'info',
        description: 'No recurring high-severity patterns or medication correlations were identified in the current records.',
        supportingData: 'All recorded symptoms currently within normal logged thresholds.',
        ruleExplanation: 'Rule: All severity changes remain within non-escalating bounds.',
      ));
    }

    return patterns;
  }

  // Generates offline, rule-based summary (Section 15)
  String generateOfflineSummary(List<Map<String, dynamic>> records) {
    if (records.isEmpty) {
      return 'No health records available for the selected period.';
    }

    final chronological = List<Map<String, dynamic>>.from(records)
      ..sort((a, b) => (a['recordDate'] as String).compareTo(b['recordDate'] as String));

    final startDate = chronological.first['recordDate'];
    final endDate = chronological.last['recordDate'];
    final totalRecords = chronological.length;

    // Severity calculations
    final severities = chronological.map((r) => (r['severity'] as num).toDouble()).toList();
    final avgSeverity = severities.reduce((a, b) => a + b) / severities.length;
    final maxSeverity = severities.reduce((a, b) => a > b ? a : b).toInt();
    final minSeverity = severities.reduce((a, b) => a < b ? a : b).toInt();

    // Symptoms frequency
    final symptomFrequencies = <String, int>{};
    for (final r in chronological) {
      final name = (r['symptomName'] as String? ?? 'Unknown').trim();
      symptomFrequencies[name] = (symptomFrequencies[name] ?? 0) + 1;
    }

    // Medicines tracked
    final medicinesTracked = <String>{};
    final medicationEffects = <String>[];
    int medsTakenCount = 0;

    for (final r in chronological) {
      final med = (r['medicineName'] as String? ?? '').trim();
      final taken = (r['medicineTaken'] as int? ?? 0) == 1;
      final effect = (r['observedEffects'] as String? ?? '').trim();

      if (med.isNotEmpty) {
        medicinesTracked.add(med);
        if (taken) medsTakenCount++;
      }
      if (effect.isNotEmpty) {
        medicationEffects.add('$med: "$effect" on ${r['recordDate']}');
      }
    }

    final buffer = StringBuffer();
    buffer.writeln('=== CARETIMELINE LOCAL RULE-BASED HEALTH SUMMARY ===');
    buffer.writeln('Note: Locally generated without AI or external servers.');
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('• Reporting Period: $startDate to $endDate');
    buffer.writeln('• Total Recorded Entries: $totalRecords');
    buffer.writeln('• Severity Metrics: Avg ${avgSeverity.toStringAsFixed(1)}/10, Min $minSeverity/10, Peak $maxSeverity/10');
    buffer.writeln('');
    buffer.writeln('Recorded Symptoms & Frequencies:');
    symptomFrequencies.forEach((sym, cnt) {
      buffer.writeln('  - $sym: $cnt time(s)');
    });
    buffer.writeln('');
    if (medicinesTracked.isNotEmpty) {
      buffer.writeln('Medication Adherence & Observations:');
      buffer.writeln('  - Medications logged: ${medicinesTracked.join(', ')}');
      buffer.writeln('  - Doses marked as taken: $medsTakenCount');
      if (medicationEffects.isNotEmpty) {
        buffer.writeln('  - User-reported observations:');
        for (final obs in medicationEffects.take(5)) {
          buffer.writeln('     * $obs');
        }
      }
    } else {
      buffer.writeln('No medication intake recorded during this timeframe.');
    }
    buffer.writeln('----------------------------------------------------');
    buffer.writeln('Disclaimer: This summary reflects user-logged entries only. It is not a clinical diagnosis or medical recommendation.');

    return buffer.toString();
  }
}
