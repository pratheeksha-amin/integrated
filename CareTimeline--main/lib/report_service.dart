import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'health_analysis.dart';

class ReportService {
  static final ReportService instance = ReportService._internal();

  ReportService._internal();

  // ================= 1. JSON EXPORT & SHARING =================

  Future<void> exportAndShareJson({
    required BuildContext context,
    required String patientName,
    required List<Map<String, dynamic>> records,
    String? aiSummary,
  }) async {
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot export an empty health history.')),
      );
      return;
    }

    final chronological = List<Map<String, dynamic>>.from(records)
      ..sort((a, b) => (a['recordDate'] as String).compareTo(b['recordDate'] as String));

    final detectedPatterns = HealthAnalysisService.instance.detectPatterns(chronological);

    // Format export payload with versioned schema
    final exportData = {
      'schemaVersion': '1.0.0',
      'app': 'CareTimeline',
      'exportDate': DateTime.now().toIso8601String(),
      'patientReference': 'PT-${patientName.hashCode.abs().toString().padLeft(6, '0')}',
      'patientDisplayName': patientName,
      'reportingPeriod': {
        'start': chronological.first['recordDate'],
        'end': chronological.last['recordDate'],
      },
      'recordCount': chronological.length,
      'aiSummary': aiSummary,
      'detectedPatterns': detectedPatterns.map((p) => {
        'title': p.title,
        'type': p.type,
        'description': p.description,
        'supportingData': p.supportingData,
        'ruleExplanation': p.ruleExplanation,
      }).toList(),
      'records': chronological.map((r) => {
        'recordDate': r['recordDate'],
        'symptomName': r['symptomName'],
        'severity': r['severity'],
        'description': r['description'] ?? '',
        'medicineName': r['medicineName'] ?? '',
        'medicineTaken': r['medicineTaken'] ?? 0,
        'observedEffects': r['observedEffects'] ?? '',
        'notes': r['notes'] ?? '',
      }).toList(),
    };

    final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);

    // Save to cache file for sharing
    final tempDir = await getTemporaryDirectory();
    final fileName = 'caretimeline_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(jsonString);

    await SharePlus.instance.share(
      ShareParams(
        subject: 'CareTimeline Patient Health Report',
        files: [XFile(file.path, mimeType: 'application/json', name: fileName)],
      ),
    );
  }

  // ================= 2. JSON IMPORT & VALIDATION =================

  Map<String, dynamic> validateAndParseJsonReport(String jsonContent) {
    dynamic parsed;
    try {
      parsed = jsonDecode(jsonContent);
    } catch (e) {
      throw const FormatException('Invalid JSON format: Could not parse file.');
    }

    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('Invalid report: Expected a JSON object at root.');
    }

    // Schema checks
    if (!parsed.containsKey('schemaVersion') || !parsed.containsKey('records')) {
      throw const FormatException('Missing required fields: schemaVersion or records.');
    }

    if (parsed['schemaVersion'] != '1.0.0') {
      throw FormatException('Unsupported report schema version: ${parsed['schemaVersion']}');
    }

    final records = parsed['records'];
    if (records is! List) {
      throw const FormatException('Corrupted report: records must be a list.');
    }

    if (records.isEmpty) {
      throw const FormatException('The selected report contains 0 health records.');
    }

    // Validate individual record entries
    for (int i = 0; i < records.length; i++) {
      final rec = records[i];
      if (rec is! Map) {
        throw FormatException('Record #$i is not a valid object.');
      }
      if (rec['recordDate'] == null || rec['symptomName'] == null || rec['severity'] == null) {
        throw FormatException('Record #$i is missing required date, symptom, or severity.');
      }
      final sev = rec['severity'];
      if (sev is! num || sev < 1 || sev > 10) {
        throw FormatException('Record #$i has invalid severity ($sev). Must be between 1 and 10.');
      }
    }

    return parsed;
  }

  // ================= 3. PDF REPORT GENERATION =================

  Future<void> generateAndSharePdf({
    required BuildContext context,
    required String patientName,
    required List<Map<String, dynamic>> records,
    String? aiSummary,
  }) async {
    if (records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No health records to include in PDF.')),
      );
      return;
    }

    final chronological = List<Map<String, dynamic>>.from(records)
      ..sort((a, b) => (a['recordDate'] as String).compareTo(b['recordDate'] as String));

    final patterns = HealthAnalysisService.instance.detectPatterns(chronological);
    final fallbackSummary = HealthAnalysisService.instance.generateOfflineSummary(chronological);

    final pdf = pw.Document();

    // Theme colors
    final primaryColor = PdfColor.fromHex('#00796B');
    final secondaryColor = PdfColor.fromHex('#0288D1');
    final greyColor = PdfColor.fromHex('#555555');
    final lightGrey = PdfColor.fromHex('#F5F5F5');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context pdfContext) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'CareTimeline Health Report',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    pw.Text(
                      'Offline-First Personal Health Consultation Summary',
                      style: pw.TextStyle(fontSize: 10, color: greyColor),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
                        style: const pw.TextStyle(fontSize: 9)),
                    pw.Text('Patient: $patientName',
                        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
            pw.Divider(color: primaryColor, thickness: 1.5),
            pw.SizedBox(height: 10),

            // Clinical Disclaimer Notice
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: lightGrey,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: pw.Text(
                'CLINICAL NOTICE: This report is generated locally from user-recorded health updates. '
                'It does not constitute a medical diagnosis or treatment plan. It is intended for review during clinical consultation.',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.black),
              ),
            ),
            pw.SizedBox(height: 14),

            // Consultation Summary Section
            pw.Text(
              aiSummary != null ? 'Consultation Summary (AI Assisted)' : 'Consultation Summary (Local Rule-Based)',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor),
            ),
            pw.SizedBox(height: 6),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Text(
                aiSummary ?? fallbackSummary,
                style: const pw.TextStyle(fontSize: 9, lineSpacing: 2),
              ),
            ),
            pw.SizedBox(height: 14),

            // Detected Patterns
            pw.Text(
              'Identified Health Patterns',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor),
            ),
            pw.SizedBox(height: 6),
            ...patterns.map((p) => pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: lightGrey,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(p.title,
                          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: secondaryColor)),
                      pw.Text(p.description, style: const pw.TextStyle(fontSize: 8)),
                      pw.Text(p.supportingData,
                          style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: greyColor)),
                    ],
                  ),
                )),
            pw.SizedBox(height: 14),

            // Health Records Table
            pw.Text(
              'Chronological Health Timeline (${chronological.length} entries)',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor),
            ),
            pw.SizedBox(height: 6),
            pw.TableHelper.fromTextArray(
              context: pdfContext,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 8, color: PdfColors.white),
              headerDecoration: pw.BoxDecoration(color: primaryColor),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              cellAlignment: pw.Alignment.centerLeft,
              data: <List<String>>[
                <String>['Date/Time', 'Symptom', 'Sev', 'Medicine', 'Taken', 'Observed Effects / Notes'],
                ...chronological.map((r) => [
                      r['recordDate'] ?? '',
                      r['symptomName'] ?? '',
                      '${r['severity']}/10',
                      r['medicineName']?.toString().isNotEmpty == true ? r['medicineName'] : '-',
                      r['medicineTaken'] == 1 ? 'Yes' : 'No',
                      '${r['observedEffects'] ?? ''} ${r['notes'] ?? ''}'.trim(),
                    ]),
              ],
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'caretimeline_report_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }
}
