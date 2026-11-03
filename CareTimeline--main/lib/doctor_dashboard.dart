import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import 'auth_service.dart';
import 'database.dart';
import 'health_analysis.dart';
import 'report_service.dart';

class DoctorDashboardScreen extends StatefulWidget {
  final AppUser user;
  final VoidCallback onLogout;

  const DoctorDashboardScreen({super.key, required this.user, required this.onLogout});

  @override
  State<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends State<DoctorDashboardScreen> {
  Map<String, dynamic>? _doctorProfile;
  List<Map<String, dynamic>> _importedReports = [];
  List<Map<String, dynamic>> _sharedReports = [];   // in-app patient→doctor reports
  int _unreadCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final profile = await AppDatabase.instance.getDoctorProfile(widget.user.id);
    final reports = await AppDatabase.instance.getImportedReports(widget.user.id);
    final doctorEmail = widget.user.email.isNotEmpty
        ? widget.user.email
        : (profile?['email'] as String? ?? '');
    final shared = await AppDatabase.instance.getSharedReportsForDoctor(
      widget.user.id,
      doctorEmail,
    );
    final unread = shared.where((r) => (r['isRead'] as int? ?? 0) == 0).length;

    if (mounted) {
      setState(() {
        _doctorProfile = profile;
        _importedReports = reports;
        _sharedReports = shared;
        _unreadCount = unread;
        _isLoading = false;
      });
    }
  }

  Future<void> _importPatientReport() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (files.isEmpty || files.first.path == null) {
        return; // User canceled picker
      }

      final file = File(files.first.path!);
      final content = await file.readAsString();

      // Validate JSON schema
      final parsed = ReportService.instance.validateAndParseJsonReport(content);

      if (!mounted) return;

      // Show preview dialog before confirming import
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.file_download_done, color: Colors.teal),
              SizedBox(width: 8),
              Text('Confirm Import'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Patient Reference: ${parsed['patientReference']}'),
              Text('Display Name: ${parsed['patientDisplayName'] ?? 'Anonymous'}'),
              Text('Total Records: ${parsed['recordCount']}'),
              Text('Reporting Period: ${parsed['reportingPeriod']['start']} to ${parsed['reportingPeriod']['end']}'),
              const SizedBox(height: 12),
              const Text('Do you want to import this patient report into your doctor account for review?'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Import Report')),
          ],
        ),
      );

      if (confirmed == true) {
        await AppDatabase.instance.insertImportedReport(
          doctorId: widget.user.id,
          patientReference: parsed['patientReference'],
          reportDate: parsed['exportDate'],
          sourceFileName: files.first.name,
          structuredData: jsonEncode(parsed),
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Patient report imported successfully.'),
              backgroundColor: Colors.green,
            ),
          );
          _loadDashboardData();
        }
      }
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 8),
                Text('Import Failed'),
              ],
            ),
            content: Text(e.toString().replaceAll('FormatException: ', '')),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          ),
        );
      }
    }
  }

  void _openReportViewer(Map<String, dynamic> reportRecord) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorReportViewerScreen(
          reportRecord: reportRecord,
          doctorId: widget.user.id,
          onDeleted: _loadDashboardData,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Doctor Portal', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colorScheme.secondary)),
            Text(widget.user.fullName, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _loadDashboardData,
              ),
              if (_unreadCount > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('$_unreadCount', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            tooltip: 'Log Out',
            onPressed: () async {
              await AuthService.instance.logout();
              widget.onLogout();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  // Doctor Info Card
                  Card(
                    elevation: 0,
                    color: colorScheme.secondaryContainer.withAlpha(90),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 24,
                                backgroundColor: colorScheme.secondary,
                                child: const Icon(Icons.medical_services, color: Colors.white, size: 24),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.user.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                    ),
                                    Text(
                                      _doctorProfile?['specialization'] ?? 'General Medicine',
                                      style: TextStyle(color: colorScheme.secondary, fontWeight: FontWeight.w600),
                                    ),
                                    if ((_doctorProfile?['clinicName'] as String? ?? '').isNotEmpty)
                                      Text(
                                        _doctorProfile!['clinicName'],
                                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.shield_outlined, size: 14, color: Colors.amber.shade900),
                                const SizedBox(width: 6),
                                Text(
                                  _doctorProfile?['verificationStatus'] ?? 'Unverified (Self-Reported)',
                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Doctor email - shown so patients know what email address to use when sharing reports
                  if (widget.user.email.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 0),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.teal.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.teal.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.email_outlined, size: 16, color: Colors.teal.shade700),
                              const SizedBox(width: 6),
                              Text(
                                'Your CareTimeline Email (Share with Patients)',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.teal.shade700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            widget.user.email,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Patients must enter this email when sending you their health report.',
                            style: TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Import Action Banner
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.secondary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.file_upload_outlined),
                    label: const Text('Import JSON Report (File)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    onPressed: _importPatientReport,
                  ),
                  const SizedBox(height: 24),

                  // ===== NEW: In-App Shared Reports from Patients =====
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.inbox_rounded, size: 20),
                          const SizedBox(width: 6),
                          Text(
                            'Patient Reports Sent to You (${_sharedReports.length})',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          if (_unreadCount > 0) ...[  
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.error,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$_unreadCount new',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_unreadCount > 0)
                        TextButton(
                          onPressed: () async {
                            final email = widget.user.email.isNotEmpty
                                ? widget.user.email
                                : (_doctorProfile?['email'] as String? ?? '');
                            await AppDatabase.instance.markAllReportsReadForDoctor(widget.user.id, email);
                            _loadDashboardData();
                          },
                          child: const Text('Mark all read'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_sharedReports.isEmpty)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Icon(Icons.mark_email_unread_outlined, size: 48, color: Colors.grey),
                            SizedBox(height: 10),
                            Text(
                              'No reports received yet.',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Your patients can tap "Send Summary to Doctor" in the Reports tab and enter your registered email to send their health data here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black54, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._sharedReports.map((report) {
                      final isUnread = (report['isRead'] as int? ?? 0) == 0;
                      final sentAt = (report['reportSentAt'] as String?) ?? '';
                      final formattedDate = sentAt.length >= 10 ? sentAt.substring(0, 10) : sentAt;
                      return Card(
                        elevation: isUnread ? 2 : 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        color: isUnread ? colorScheme.primaryContainer.withAlpha(120) : null,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            color: isUnread ? colorScheme.primary : colorScheme.outlineVariant,
                            width: isUnread ? 1.5 : 1,
                          ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: isUnread ? colorScheme.primary : colorScheme.secondaryContainer,
                            child: Icon(Icons.person, color: isUnread ? Colors.white : colorScheme.secondary),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  report['fromPatientName'] as String? ?? 'Patient',
                                  style: TextStyle(fontWeight: isUnread ? FontWeight.bold : FontWeight.normal),
                                ),
                              ),
                              if (isUnread)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.error,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('NEW', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if ((report['fromPatientEmail'] as String? ?? '').isNotEmpty)
                                Text(
                                  report['fromPatientEmail'] as String,
                                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600),
                                ),
                              Text('Sent: $formattedDate', style: const TextStyle(fontSize: 12)),
                              Text(
                                report['aiSummary'] != null ? 'AI + Offline summary included' : 'Offline summary included',
                                style: TextStyle(fontSize: 11, color: colorScheme.primary),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () async {
                            final nav = Navigator.of(context);
                            await AppDatabase.instance.markSharedReportRead(report['id'] as int);
                            if (!mounted) return;
                            await nav.push(
                              MaterialPageRoute(
                                builder: (_) => SharedReportDetailScreen(
                                  report: report,
                                  onDeleted: _loadDashboardData,
                                ),
                              ),
                            );
                            if (mounted) _loadDashboardData();
                          },
                        ),
                      );
                    }),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Imported Patient Reports (${_importedReports.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Isolated by Account',
                        style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  if (_importedReports.isEmpty)
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Icon(Icons.folder_shared_outlined, size: 54, color: Colors.grey),
                            SizedBox(height: 12),
                            Text(
                              'No patient reports imported yet.',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Ask your patient to share their structured CareTimeline report (.json) with you, then tap the import button above.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.black54, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._importedReports.map((report) {
                      final rawData = jsonDecode(report['structuredData'] as String);
                      final recordCount = rawData['recordCount'] ?? 0;
                      final period = rawData['reportingPeriod'];
                      final dateRange = period != null ? '${period['start']} to ${period['end']}' : 'Unknown';

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: colorScheme.outlineVariant),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: colorScheme.secondaryContainer,
                            child: Icon(Icons.person, color: colorScheme.secondary),
                          ),
                          title: Text(
                            '${report['patientReference']} (${rawData['patientDisplayName'] ?? 'Patient'})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Period: $dateRange', style: const TextStyle(fontSize: 12)),
                              Text('Entries: $recordCount | File: ${report['sourceFileName']}', style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _openReportViewer(report),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

// ================= DOCTOR REPORT VIEWER SCREEN =================

class DoctorReportViewerScreen extends StatefulWidget {
  final Map<String, dynamic> reportRecord;
  final int doctorId;
  final VoidCallback onDeleted;

  const DoctorReportViewerScreen({
    super.key,
    required this.reportRecord,
    required this.doctorId,
    required this.onDeleted,
  });

  @override
  State<DoctorReportViewerScreen> createState() => _DoctorReportViewerScreenState();
}

class _DoctorReportViewerScreenState extends State<DoctorReportViewerScreen> {
  late Map<String, dynamic> _parsedData;
  late List<Map<String, dynamic>> _records;
  String? _selectedSymptom;
  List<String> _distinctSymptoms = [];

  @override
  void initState() {
    super.initState();
    _parsedData = jsonDecode(widget.reportRecord['structuredData'] as String);
    final rawList = (_parsedData['records'] as List? ?? []);
    _records = rawList.map((e) => Map<String, dynamic>.from(e as Map)).toList();

    final set = <String>{};
    for (final r in _records) {
      final name = (r['symptomName'] as String? ?? '').trim();
      if (name.isNotEmpty) set.add(name);
    }
    _distinctSymptoms = set.toList()..sort();
    if (_distinctSymptoms.isNotEmpty) {
      _selectedSymptom = _distinctSymptoms.first;
    }
  }

  void _confirmDeleteReport() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Imported Report'),
        content: const Text('Are you sure you want to remove this imported report from your doctor dashboard?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await AppDatabase.instance.deleteImportedReport(widget.reportRecord['id'], widget.doctorId);
              widget.onDeleted();
              if (mounted) Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final patientRef = _parsedData['patientReference'] ?? 'Patient';
    final patientName = _parsedData['patientDisplayName'] ?? patientRef;
    final aiSummary = _parsedData['aiSummary'] as String?;
    final patterns = HealthAnalysisService.instance.detectPatterns(_records);
    final offlineSummary = HealthAnalysisService.instance.generateOfflineSummary(_records);

    final filteredRecords = _records
        .where((r) => (r['symptomName'] as String? ?? '').trim().toLowerCase() == _selectedSymptom?.toLowerCase())
        .toList()
      ..sort((a, b) => (a['recordDate'] as String).compareTo(b['recordDate'] as String));

    return Scaffold(
      appBar: AppBar(
        title: Text('Review: $patientRef'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            tooltip: 'Export Review PDF',
            onPressed: () => ReportService.instance.generateAndSharePdf(
              context: context,
              patientName: patientName,
              records: _records,
              aiSummary: aiSummary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete Report',
            onPressed: _confirmDeleteReport,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Clinical Consultation Notice
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: const Text(
                'Clinical Review Notice: This report represents self-reported patient updates. '
                'Review the timeline and medication observations to guide your clinical consultation.',
                style: TextStyle(fontSize: 12, height: 1.3),
              ),
            ),
            const SizedBox(height: 16),

            // Summary Section
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          aiSummary != null ? Icons.auto_awesome : Icons.summarize_outlined,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          aiSummary != null ? 'Patient AI Consultation Summary' : 'Local Rule-Based Summary',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      aiSummary ?? offlineSummary,
                      style: const TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Detected Patterns
            Text(
              'Identified Health Patterns',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...patterns.map((p) => Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  color: colorScheme.surfaceContainerHighest.withAlpha(120),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.title, style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.secondary)),
                        const SizedBox(height: 4),
                        Text(p.description, style: const TextStyle(fontSize: 12)),
                        const SizedBox(height: 2),
                        Text(p.supportingData, style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 16),

            // Symptom Chart
            if (_distinctSymptoms.isNotEmpty) ...[
              Text(
                'Symptom Progression Chart',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Symptom: '),
                  DropdownButton<String>(
                    value: _selectedSymptom,
                    items: _distinctSymptoms.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedSymptom = val);
                    },
                  ),
                ],
              ),
              if (filteredRecords.length >= 2) ...[
                SizedBox(
                  height: 180,
                  child: LineChart(
                    LineChartData(
                      minY: 1,
                      maxY: 10,
                      gridData: const FlGridData(show: true, drawVerticalLine: false),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 2,
                            reservedSize: 26,
                            getTitlesWidget: (val, _) => Text(val.toInt().toString(), style: const TextStyle(fontSize: 9)),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            interval: 1,
                            getTitlesWidget: (val, _) {
                              final idx = val.toInt();
                              if (idx >= 0 && idx < filteredRecords.length) {
                                final d = filteredRecords[idx]['recordDate'] as String;
                                return Text(d.substring(5, 10), style: const TextStyle(fontSize: 8));
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            filteredRecords.length,
                            (i) => FlSpot(i.toDouble(), (filteredRecords[i]['severity'] as num).toDouble()),
                          ),
                          isCurved: true,
                          color: colorScheme.secondary,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Text('Insufficient data to display progression curve for this symptom.'),
                ),
            ],
            const SizedBox(height: 20),

            // Health History Timeline
            Text(
              'Chronological Health Timeline (${_records.length} records)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ..._records.map((r) {
              final sev = r['severity'] as int;
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(r['symptomName'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Severity: $sev/10', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      Text(r['recordDate'] ?? '', style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
                      if ((r['medicineName'] as String? ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Medicine: ${r['medicineName']} (${r['medicineTaken'] == 1 ? 'Taken' : 'Not taken'})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                      if ((r['observedEffects'] as String? ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Observed: ${r['observedEffects']}', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SharedReportDetailScreen � Shows full in-app shared patient report to doctor
// ============================================================================
class SharedReportDetailScreen extends StatelessWidget {
  final Map<String, dynamic> report;
  final VoidCallback onDeleted;

  const SharedReportDetailScreen({
    super.key,
    required this.report,
    required this.onDeleted,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final patientName = report['fromPatientName'] as String? ?? 'Patient';
    final patientEmail = report['fromPatientEmail'] as String? ?? '';
    final sentAt = report['reportSentAt'] as String? ?? '';
    final aiSummary = report['aiSummary'] as String?;
    final offlineSummary = report['offlineSummary'] as String? ?? '';
    final reportId = report['id'] as int;

    // Parse health records from structuredData
    List<Map<String, dynamic>> records = [];
    try {
      final parsed = jsonDecode(report['structuredData'] as String);
      final raw = parsed['records'] as List?;
      if (raw != null) {
        records = raw.map((r) => Map<String, dynamic>.from(r as Map)).toList()
          ..sort((a, b) => (a['recordDate'] as String).compareTo(b['recordDate'] as String));
      }
    } catch (_) {}

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient Report', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.secondary)),
            Text(patientName, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            tooltip: 'Delete Report',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Delete Report'),
                  content: const Text('Permanently remove this shared patient report from your account?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await AppDatabase.instance.deleteSharedReport(reportId);
                onDeleted();
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Identity Card
            Card(
              elevation: 0,
              color: colorScheme.secondaryContainer.withAlpha(80),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: colorScheme.secondary,
                      child: Text(
                        patientName.isNotEmpty ? patientName[0].toUpperCase() : 'P',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(patientName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                          if (patientEmail.isNotEmpty)
                            Row(
                              children: [
                                const Icon(Icons.email_outlined, size: 14, color: Colors.black54),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: SelectableText(
                                    patientEmail,
                                    style: TextStyle(fontSize: 13, color: colorScheme.secondary, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 4),
                          Text(
                            'Sent: ${sentAt.length >= 10 ? sentAt.substring(0, 10) : sentAt}',
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                          Text(
                            '${records.length} health record(s)',
                            style: TextStyle(fontSize: 12, color: colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Summary
            Text(
              aiSummary != null ? 'AI Clinical Summary' : 'Rule-Based Summary',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          aiSummary != null ? Icons.auto_awesome : Icons.summarize_outlined,
                          color: colorScheme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          aiSummary != null ? 'AI-Assisted Consultation Summary' : 'Offline Rule-Based Summary',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SelectableText(
                      aiSummary ?? offlineSummary,
                      style: const TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Health Records Timeline
            Text(
              'Health Records (${records.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (records.isEmpty)
              const Center(child: Text('No individual records available.', style: TextStyle(color: Colors.grey)))
            else
              ...records.map((r) {
                final sev = r['severity'];
                final sevInt = sev is int ? sev : (sev is num ? sev.toInt() : 5);
                final Color sevColor = sevInt <= 3
                    ? Colors.green.shade600
                    : sevInt <= 6
                        ? Colors.orange.shade700
                        : Colors.red.shade700;
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(
                    side: BorderSide(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                r['symptomName']?.toString() ?? '',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: sevColor.withAlpha(30),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: sevColor.withAlpha(100)),
                              ),
                              child: Text(
                                'Sev: $sevInt/10',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: sevColor),
                              ),
                            ),
                          ],
                        ),
                        Text(
                          r['recordDate']?.toString() ?? '',
                          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                        ),
                        if ((r['medicineName']?.toString() ?? '').isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Medicine: ${r['medicineName']} (${r['medicineTaken'] == 1 ? 'Taken' : 'Not taken'})',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                        if ((r['observedEffects']?.toString() ?? '').isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Observed: ${r['observedEffects']}',
                            style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
