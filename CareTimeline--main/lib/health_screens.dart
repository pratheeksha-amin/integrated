import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';
import 'database.dart';
import 'health_analysis.dart';
import 'ai_summary.dart';
import 'report_service.dart';
import 'medilens/features/medicine_assistant_screen.dart';
import 'accessibility/accessibility_widgets.dart';
import 'accessibility/font_size_service.dart';
import 'accessibility/tts_service.dart';
import 'package:easy_localization/easy_localization.dart';

class PatientDashboardScreen extends StatefulWidget {
  final AppUser user;
  final VoidCallback onLogout;

  const PatientDashboardScreen({super.key, required this.user, required this.onLogout});

  @override
  State<PatientDashboardScreen> createState() => _PatientDashboardScreenState();
}

class _PatientDashboardScreenState extends State<PatientDashboardScreen> {
  int _currentIndex = 0;
  bool _isOnline = false;
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;
  bool _isGeneratingAiSummary = false;
  Map<String, dynamic>? _latestSavedSummary;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _loadRecords();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isOnline = !connectivityResult.contains(ConnectivityResult.none);
      });
    }
  }

  Future<void> _loadRecords() async {
    setState(() => _isLoading = true);
    final data = await AppDatabase.instance.getHealthRecords(widget.user.id);
    final latestSummary =
        await AppDatabase.instance.getLatestGeneratedSummary(widget.user.id);
    if (mounted) {
      setState(() {
        _records = data;
        _latestSavedSummary = latestSummary;
        _isLoading = false;
      });
    }
  }

  void _openAddEditScreen({Map<String, dynamic>? existingRecord, String? prefilledMedicineName}) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditRecordScreen(
          patientId: widget.user.id,
          existingRecord: existingRecord,
          prefilledMedicineName: prefilledMedicineName,
        ),
      ),
    );
    if (updated == true) {
      _loadRecords();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final pages = [
      _buildOverviewTab(colorScheme),
      _buildTimelineTab(colorScheme),
      MedicineAssistantScreen(
        onAddToPatientHistory: (medName) => _openAddEditScreen(prefilledMedicineName: medName),
      ),
      _buildTrendsTab(colorScheme),
      _buildReportsTab(colorScheme),
      _buildProfileTab(colorScheme),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CareTimeline', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: colorScheme.primary)),
            Text('Patient: ${widget.user.fullName}', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Chip(
              avatar: Icon(
                _isOnline ? Icons.wifi : Icons.wifi_off,
                size: 14,
                color: _isOnline ? Colors.green.shade800 : Colors.grey.shade700,
              ),
              label: Text(
                _isOnline ? 'Online' : 'Offline',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _isOnline ? Colors.green.shade800 : Colors.grey.shade700,
                ),
              ),
              backgroundColor: _isOnline ? Colors.green.shade50 : Colors.grey.shade200,
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (idx) => setState(() => _currentIndex = idx),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.timeline_outlined), selectedIcon: Icon(Icons.timeline), label: 'Timeline'),
          NavigationDestination(icon: Icon(Icons.medication_outlined), selectedIcon: Icon(Icons.medication), label: 'Medicine Assistant'),
          NavigationDestination(icon: Icon(Icons.show_chart_outlined), selectedIcon: Icon(Icons.show_chart), label: 'Trends'),
          NavigationDestination(icon: Icon(Icons.summarize_outlined), selectedIcon: Icon(Icons.summarize), label: 'Reports'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
      floatingActionButton: _currentIndex <= 2
          ? FloatingActionButton.extended(
              onPressed: () => _openAddEditScreen(),
              icon: const Icon(Icons.add),
              label: const Text('Log Health'),
            )
          : null,
    );
  }

  // ================= TAB 1: OVERVIEW =================
  Widget _buildOverviewTab(ColorScheme colorScheme) {
    final patterns = HealthAnalysisService.instance.detectPatterns(_records);

    return RefreshIndicator(
      onRefresh: _loadRecords,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Card(
              elevation: 0,
              color: colorScheme.primaryContainer.withAlpha(90),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: colorScheme.primary,
                      child: const Icon(Icons.favorite, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('EEEE, MMM d, yyyy').format(DateTime.now()),
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Hello, ${widget.user.fullName}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_records.length} total entries saved locally',
                            style: TextStyle(fontSize: 13, color: colorScheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // AI Health Assistant Interactive Card
            Card(
              elevation: 0,
              color: Colors.teal.shade50,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.teal.shade200),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.teal.shade800),
                        const SizedBox(width: 8),
                        Text(
                          'Ask CareTimeline AI Assistant',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.teal.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Ask questions about your health timeline, medication trends, or get clinical summaries.',
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Ask AI Assistant ✨'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.teal.shade700,
                      ),
                      onPressed: () => _showAiAssistantBottomSheet(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Medicine Assistant Card (MediLens Integration)
            Card(
              elevation: 0,
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: Colors.blue.shade200),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: colorScheme.secondary,
                      child: const Icon(Icons.medication_liquid_outlined, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Medicine Assistant',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Offline brand & generic info, ML Kit OCR packaging scan',
                            style: TextStyle(fontSize: 12, color: Colors.black87),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: () => setState(() => _currentIndex = 2),
                      child: const Text('Open'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Detected Patterns Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detected Health Patterns',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Offline Rule-Based',
                  style: TextStyle(fontSize: 11, color: colorScheme.primary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...patterns.map((pattern) {
              Color badgeColor = colorScheme.primary;
              IconData badgeIcon = Icons.info_outline;

              if (pattern.type == 'increasing_severity') {
                badgeColor = Colors.orange.shade800;
                badgeIcon = Icons.trending_up;
              } else if (pattern.type == 'recurring') {
                badgeColor = Colors.teal.shade700;
                badgeIcon = Icons.repeat;
              } else if (pattern.type == 'medication_observation') {
                badgeColor = Colors.indigo.shade700;
                badgeIcon = Icons.medication_outlined;
              }

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(badgeIcon, size: 18, color: badgeColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pattern.title,
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: badgeColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(pattern.description, style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          pattern.supportingData,
                          style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),

            // Recent 3 Updates
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Updates',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () => setState(() => _currentIndex = 1),
                  child: const Text('View All'),
                ),
              ],
            ),
            if (_records.isEmpty)
              _buildEmptyState('No health entries recorded yet. Tap "+ Log Health" below to start.')
            else
              ..._records.take(3).map((r) => _buildRecordCard(r, colorScheme)),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // ================= TAB 2: TIMELINE =================
  Widget _buildTimelineTab(ColorScheme colorScheme) {
    if (_records.isEmpty) {
      return _buildEmptyState('Your health timeline is empty.\nTap "+ Log Health" to add your first symptom or medication update.');
    }

    return RefreshIndicator(
      onRefresh: _loadRecords,
      child: ListView.builder(
        padding: const EdgeInsets.all(16.0),
        itemCount: _records.length,
        itemBuilder: (ctx, i) {
          final record = _records[i];
          return _buildRecordCard(record, colorScheme, showFullDetails: true);
        },
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> r, ColorScheme colorScheme, {bool showFullDetails = false}) {
    final severity = r['severity'] as int;
    final Color severityColor = severity <= 3
        ? Colors.green.shade600
        : severity <= 6
            ? Colors.orange.shade700
            : Colors.red.shade700;

    final medName = (r['medicineName'] as String? ?? '').trim();
    final medTaken = (r['medicineTaken'] as int? ?? 0) == 1;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    r['symptomName'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: severityColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: severityColor.withAlpha(120)),
                  ),
                  child: Text(
                    'Severity: $severity/10',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: severityColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  r['recordDate'] ?? '',
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
            if ((r['description'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(r['description'], style: const TextStyle(fontSize: 13)),
            ],
            if (medName.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      medTaken ? Icons.check_circle : Icons.cancel_outlined,
                      size: 16,
                      color: medTaken ? Colors.green.shade700 : Colors.red.shade700,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Med: $medName (${medTaken ? 'Dose Taken' : 'Missed'})',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if ((r['observedEffects'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Observed: ${r['observedEffects']}',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: colorScheme.onSurfaceVariant),
              ),
            ],
            if (showFullDetails) ...[
              const Divider(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit'),
                    onPressed: () => _openAddEditScreen(existingRecord: r),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    label: const Text('Delete', style: TextStyle(color: Colors.red)),
                    onPressed: () => _confirmDelete(r['id']),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelete(int recordId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Health Record'),
        content: const Text('Are you sure you want to permanently delete this health record from SQLite storage?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await AppDatabase.instance.deleteHealthRecord(recordId, widget.user.id);
              _loadRecords();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Record deleted successfully.')),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ================= TAB 3: TRENDS & CHARTS =================
  Widget _buildTrendsTab(ColorScheme colorScheme) {
    if (_records.isEmpty) {
      return _buildEmptyState('No health records to plot.\nAdd entries to see your symptom severity trends over time.');
    }

    return SymptomTrendsView(patientId: widget.user.id, records: _records);
  }

  // ================= TAB 4: REPORTS & AI =================
  Widget _buildReportsTab(ColorScheme colorScheme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text('Clinical Consultation Summary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Generate a structured summary for your doctor consultation. Generate Summary sends your logged timeline to Google Gemini. Generate Offline Summary uses the local rule-based engine and does not call an LLM.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Timeline data sent to Gemini is limited to dates, symptoms, severity, medicines and patient-reported observations. It is processed by Google\'s Gemini API.',
                    style: TextStyle(fontSize: 12, height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: _isGeneratingAiSummary
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.psychology_outlined),
                    label: Text(_isGeneratingAiSummary
                        ? 'Generating LLM summary...'
                        : 'Generate Summary'),
                    onPressed: _isGeneratingAiSummary
                        ? null
                        : () {
                            if (_records.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No health records to summarize.')),
                              );
                              return;
                            }
                            _generateAiSummary();
                          },
                  ),
                  const SizedBox(height: 10),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.offline_bolt_outlined),
                    label: const Text('Generate Offline Summary'),
                    onPressed: _isGeneratingAiSummary
                        ? null
                        : () async {
                            final summary = HealthAnalysisService.instance.generateOfflineSummary(_records);
                            await AppDatabase.instance.saveGeneratedSummary(
                              patientId: widget.user.id,
                              source: 'offline',
                              summaryText: summary,
                            );
                            await _loadRecords();
                            if (!mounted) return;
                            _showSummaryModal(
                              'Rule-based offline summary',
                              summary,
                              isLlmGenerated: false,
                            );
                          },
                  ),
                  if (_latestSavedSummary != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Last saved summary (${_latestSavedSummary!['source'] == 'llm' ? 'LLM-generated' : 'rule-based'})',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_latestSavedSummary!['createdAt'] ?? ''}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Send report to Doctor (in-app)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.send_rounded, color: colorScheme.secondary),
                      const SizedBox(width: 8),
                      const Text('Send to Your Doctor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Send your health summary directly to your doctor\'s CareTimeline account by entering their email address. The doctor will see it immediately on their dashboard.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('Send Summary to Doctor'),
                    onPressed: () {
                      if (_records.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Add health records first before sending a summary.')),
                        );
                        return;
                      }
                      _showSendToDoctorDialog();
                    },
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export PDF Report'),
                    onPressed: () => ReportService.instance.generateAndSharePdf(
                      context: context,
                      patientName: widget.user.fullName,
                      records: _records,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= GEMINI AI SUMMARY =================
  Future<void> _generateAiSummary() async {
    if (_isGeneratingAiSummary) return;
    setState(() => _isGeneratingAiSummary = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating LLM summary...'),
                SizedBox(height: 8),
                Text(
                  'Sending timeline records to Google Gemini',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final result = await GeminiAiService.instance.generateSummary(
        records: _records,
      );
      await AppDatabase.instance.saveGeneratedSummary(
        patientId: widget.user.id,
        source: 'llm',
        model: result.model,
        summaryText: result.text,
      );
      await _loadRecords();
      if (!mounted) return;
      Navigator.pop(context);
      final providerLabel = result.model.contains('llama') ||
              result.model.contains('mixtral') ||
              result.model.contains('gemma')
          ? 'Groq LLM'
          : 'Google Gemini';
      _showSummaryModal(
        'LLM-generated summary ($providerLabel)',
        result.text,
        isLlmGenerated: true,
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      final cleanMsg = e is AiSummaryException
          ? e.userMessage
          : e.toString().replaceAll('Exception: ', '');
      final isKeyError = e is AiSummaryException &&
          (e.category == AiFailureCategory.missingConfiguration ||
           e.category == AiFailureCategory.authentication);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.amber),
              SizedBox(width: 8),
              Text('LLM summary failed'),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(
              'A real Gemini response was not received, so no AI summary is shown.\n\n$cleanMsg\n\nUse Generate Offline Summary if you want a local rule-based summary instead.',
            ),
          ),
          actions: [
            if (isKeyError)
              FilledButton.icon(
                icon: const Icon(Icons.key_rounded, size: 16),
                label: const Text('Update API Key'),
                onPressed: () {
                  Navigator.pop(ctx);
                  _showApiKeyManagerDialog();
                },
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isKeyError ? 'Cancel' : 'OK'),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isGeneratingAiSummary = false);
      }
    }
  }

  // ================= AI HEALTH ASSISTANT =================
  void _showAiAssistantBottomSheet() {
    final queryController = TextEditingController();
    String? aiResponse;
    bool isLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          Future<void> submitQuery(String question) async {
            if (question.trim().isEmpty) return;
            setS(() {
              isLoading = true;
              aiResponse = null;
            });

            try {
              final answer = await GeminiAiService.instance.askAiAssistant(
                records: _records,
                question: question,
              );
              if (ctx.mounted) {
                setS(() {
                  isLoading = false;
                  aiResponse = answer;
                });
              }
            } catch (e) {
              final message = e is AiSummaryException
                  ? e.userMessage
                  : e.toString().replaceAll('Exception: ', '');
              if (ctx.mounted) {
                setS(() {
                  isLoading = false;
                  aiResponse = 'LLM request failed.\n\n$message';
                });
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.auto_awesome, color: Colors.teal),
                        SizedBox(width: 8),
                        Text('CareTimeline AI Assistant', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.summarize_outlined, size: 14),
                      label: const Text('Summarize timeline'),
                      onPressed: () {
                        queryController.text = 'Summarize my health timeline';
                        submitQuery(queryController.text);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.medication_outlined, size: 14),
                      label: const Text('Medication intake'),
                      onPressed: () {
                        queryController.text = 'Analyze my medication intake';
                        submitQuery(queryController.text);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.warning_amber_outlined, size: 14),
                      label: const Text('Severity highlights'),
                      onPressed: () {
                        queryController.text = 'Highlight my severe symptoms';
                        submitQuery(queryController.text);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: queryController,
                        decoration: const InputDecoration(
                          hintText: 'Ask about your health logs...',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.send_rounded),
                      onPressed: () => submitQuery(queryController.text),
                    ),
                  ],
                ),
                if (isLoading) ...[
                  const SizedBox(height: 20),
                  const Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('AI is analyzing your timeline...'),
                      ],
                    ),
                  ),
                ],
                if (aiResponse != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.smart_toy_outlined, size: 16, color: Colors.teal),
                            SizedBox(width: 6),
                            Text('CareTimeline AI Response:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TtsControlBar(
                          textToRead: aiResponse!,
                          languageCode: context.locale.languageCode,
                          label: 'Read Aloud',
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder<double>(
                          valueListenable: FontSizeService.instance.fontSizeNotifier,
                          builder: (context, baseFontSize, _) {
                            return SelectableText(
                              aiResponse!,
                              style: TextStyle(fontSize: baseFontSize, height: 1.4),
                            );
                          },
                        ),
                        if (aiResponse!.contains('Missing configuration') ||
                            aiResponse!.contains('Authentication failure')) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.key_rounded, size: 16),
                            label: const Text('Update API Key'),
                            onPressed: () {
                              Navigator.pop(ctx);
                              _showApiKeyManagerDialog();
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  // ================= SEND TO DOCTOR DIALOG =================
  void _showSendToDoctorDialog() {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.send_rounded),
              SizedBox(width: 8),
              Text('Send to Doctor'),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter your doctor\'s registered email address. Your health summary and records will be sent to their CareTimeline account.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: "Doctor's Email Address",
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                      hintText: 'doctor@example.com',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter the doctor\'s email';
                      if (!v.contains('@')) return 'Enter a valid email address';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Note: The doctor must also have a CareTimeline account with this email.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSending ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: isSending
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSending = true);

                      final doctorEmail = emailController.text.trim().toLowerCase();

                      // Check if doctor exists
                      final doctorUser = await AppDatabase.instance.getUserByEmail(doctorEmail);
                      if (doctorUser == null || doctorUser['role'] != 'doctor') {
                        if (ctx.mounted) {
                          setDialogState(() => isSending = false);
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(
                              content: Text('No doctor account found with email "$doctorEmail". Ask your doctor to register first.'),
                              backgroundColor: Colors.red.shade700,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                        return;
                      }

                      // Generate summaries: always store the rule-based copy.
                      // Attach an LLM summary only when Gemini actually responds.
                      String offlineSummary = HealthAnalysisService.instance.generateOfflineSummary(_records);
                      String? aiSummary;

                      try {
                        final result = await GeminiAiService.instance.generateSummary(records: _records);
                        aiSummary = result.text;
                        await AppDatabase.instance.saveGeneratedSummary(
                          patientId: widget.user.id,
                          source: 'llm',
                          model: result.model,
                          summaryText: result.text,
                        );
                      } catch (_) {
                        await AppDatabase.instance.saveGeneratedSummary(
                          patientId: widget.user.id,
                          source: 'offline',
                          summaryText: offlineSummary,
                        );
                      }

                      // Build structured data
                      final structuredData = jsonEncode({
                        'schemaVersion': '2.0',
                        'exportedAt': DateTime.now().toIso8601String(),
                        'patientName': widget.user.fullName,
                        'totalRecords': _records.length,
                        'records': _records,
                      });

                      await AppDatabase.instance.sendSharedReport(
                        fromPatientId: widget.user.id,
                        fromPatientName: widget.user.fullName,
                        toDoctorEmail: doctorEmail,
                        aiSummary: aiSummary,
                        offlineSummary: offlineSummary,
                        structuredData: structuredData,
                      );

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Report sent to Dr. ${doctorUser['fullName']} successfully! 🎉\nThey can see it on their Doctor Dashboard.',
                              ),
                              backgroundColor: Colors.green.shade700,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                        }
                      }
                    },
              child: isSending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send Report'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSummaryModal(String title, String summary, {bool isLlmGenerated = false}) {
    final currentLang = context.locale.languageCode;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.all(20.0),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  const FontSizeControls(compact: true),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const Divider(),
              Row(
                children: [
                  Chip(
                    avatar: Icon(
                      isLlmGenerated ? Icons.auto_awesome : Icons.offline_bolt_outlined,
                      size: 16,
                    ),
                    label: Text(
                      isLlmGenerated ? 'LLM Summary' : 'Rule-based offline summary',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Read Aloud Text-To-Speech Controls
              TtsControlBar(
                textToRead: summary,
                languageCode: currentLang,
                label: 'Read Summary Aloud',
              ),
              const SizedBox(height: 12),

              ValueListenableBuilder<double>(
                valueListenable: FontSizeService.instance.fontSizeNotifier,
                builder: (context, baseFontSize, _) {
                  return SelectableText(
                    summary,
                    style: TextStyle(fontSize: baseFontSize, height: 1.5, fontFamily: 'monospace'),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================= TAB 5: PROFILE & SETTINGS =================
  Widget _buildProfileTab(ColorScheme colorScheme) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: AppDatabase.instance.getPatientProfile(widget.user.id),
      builder: (ctx, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final profile = snapshot.data!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    widget.user.fullName.isNotEmpty ? widget.user.fullName[0].toUpperCase() : 'P',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.user.fullName,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                '@${widget.user.username}',
                textAlign: TextAlign.center,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildProfileRow('Account Role', 'Patient (Offline)'),
                      const Divider(),
                      _buildProfileRow('Age', profile['age'] != null ? '${profile['age']} years' : 'Not specified'),
                      const Divider(),
                      _buildProfileRow('Blood Group', profile['bloodGroup'] ?? 'Not specified'),
                      const Divider(),
                      _buildProfileRow('Emergency Contact', profile['emergencyContact'] ?? 'Not specified'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: colorScheme.outlineVariant),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: ListTile(
                  leading: const Icon(Icons.key_outlined),
                  title: const Text('Developer Gemini key (optional)'),
                  subtitle: const Text('Optional local override. Prefer env.json + dart-define for builds.'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => _showApiKeyManagerDialog(),
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('Log Out', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  await AuthService.instance.logout();
                  widget.onLogout();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(color: Colors.black87)),
        ],
      ),
    );
  }

  void _showApiKeyManagerDialog() async {
    final currentKey = await GeminiAiService.instance.getStoredOverrideKey() ?? '';
    final controller = TextEditingController(text: currentKey);
    bool obscure = true;

    if (!mounted) return;
    // ignore: use_build_context_synchronously
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.key_rounded, color: Colors.teal),
              SizedBox(width: 8),
              Text('AI Provider Key (Groq / Gemini)'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Get a FREE API key from Groq or Google Gemini:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final uri = Uri.parse('https://console.groq.com/keys');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: const Text(
                          '1. Groq Console (gsk_...) → console.groq.com',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () async {
                          final uri = Uri.parse('https://aistudio.google.com/app/apikey');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        child: const Text(
                          '2. Google AI Studio → aistudio.google.com',
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: controller,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    labelText: 'Paste Groq (gsk_...) or Gemini key here',
                    prefixIcon: const Icon(Icons.vpn_key_outlined),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setS(() => obscure = !obscure),
                    ),
                  ),
                ),
                if (currentKey.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Key already saved (${currentKey.length} chars)',
                        style: const TextStyle(fontSize: 11, color: Colors.green),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
          actions: [
            if (currentKey.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await GeminiAiService.instance.clearApiKey();
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('API key cleared.')),
                      );
                    }
                  }
                },
                child: const Text('Clear', style: TextStyle(color: Colors.red)),
              ),
            FilledButton.icon(
              icon: const Icon(Icons.save_outlined, size: 16),
              label: const Text('Save Key'),
              onPressed: () async {
                final key = controller.text.trim();
                if (key.isEmpty) {
                  Navigator.pop(ctx);
                  return;
                }
                await GeminiAiService.instance.saveApiKey(key);
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Gemini API key saved! AI summaries are now available.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notes_rounded, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= ADD / EDIT HEALTH RECORD SCREEN =================

class AddEditRecordScreen extends StatefulWidget {
  final int patientId;
  final Map<String, dynamic>? existingRecord;
  final String? prefilledMedicineName;

  const AddEditRecordScreen({
    super.key,
    required this.patientId,
    this.existingRecord,
    this.prefilledMedicineName,
  });

  @override
  State<AddEditRecordScreen> createState() => _AddEditRecordScreenState();
}

class _AddEditRecordScreenState extends State<AddEditRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _selectedDateTime;
  final _symptomController = TextEditingController();
  double _severity = 5.0;
  final _descriptionController = TextEditingController();
  final _medicineController = TextEditingController();
  bool _medicineTaken = false;
  final _effectsController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isSaving = false;

  final List<String> _commonSymptoms = [
    'Headache',
    'Fever',
    'Cough',
    'Fatigue',
    'Chest Tightness',
    'Nausea',
    'Back Pain',
    'Joint Pain',
    'Stomach Ache',
    'Dizziness',
    'Sore Throat',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.existingRecord != null) {
      final r = widget.existingRecord!;
      _selectedDateTime = DateTime.tryParse(r['recordDate']) ?? DateTime.now();
      _symptomController.text = r['symptomName'] ?? '';
      _severity = (r['severity'] as num?)?.toDouble() ?? 5.0;
      _descriptionController.text = r['description'] ?? '';
      _medicineController.text = r['medicineName'] ?? '';
      _medicineTaken = (r['medicineTaken'] as int? ?? 0) == 1;
      _effectsController.text = r['observedEffects'] ?? '';
      _notesController.text = r['notes'] ?? '';
    } else {
      _selectedDateTime = DateTime.now();
      if (widget.prefilledMedicineName != null && widget.prefilledMedicineName!.isNotEmpty) {
        _medicineController.text = widget.prefilledMedicineName!;
        _medicineTaken = true;
      }
    }
  }

  @override
  void dispose() {
    _symptomController.dispose();
    _descriptionController.dispose();
    _medicineController.dispose();
    _effectsController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final now = DateTime.now().toIso8601String();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(_selectedDateTime);

    final recordMap = {
      'patientId': widget.patientId,
      'recordDate': dateStr,
      'symptomName': _symptomController.text.trim(),
      'severity': _severity.round(),
      'description': _descriptionController.text.trim(),
      'medicineName': _medicineController.text.trim(),
      'medicineTaken': _medicineTaken ? 1 : 0,
      'observedEffects': _effectsController.text.trim(),
      'notes': _notesController.text.trim(),
      'updatedAt': now,
    };

    try {
      if (widget.existingRecord != null) {
        await AppDatabase.instance.updateHealthRecord(
          widget.existingRecord!['id'],
          widget.patientId,
          recordMap,
        );
      } else {
        recordMap['createdAt'] = now;
        await AppDatabase.instance.insertHealthRecord(recordMap);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingRecord != null ? 'Record updated.' : 'Health update saved locally.'),
            backgroundColor: Colors.green.shade800,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingRecord != null;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Health Entry' : 'Log Health Entry'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Date & Time Picker Tile
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Record Date & Time'),
                  subtitle: Text(DateFormat('yyyy-MM-dd HH:mm').format(_selectedDateTime)),
                  trailing: const Icon(Icons.edit_calendar),
                  onTap: _pickDateTime,
                ),
                const SizedBox(height: 16),

                // Symptom Field with Quick Suggestion Chips
                TextFormField(
                  controller: _symptomController,
                  decoration: const InputDecoration(
                    labelText: 'Symptom Name *',
                    hintText: 'e.g. Migraine, Fever, Joint Pain',
                    prefixIcon: Icon(Icons.healing),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter symptom name' : null,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: _commonSymptoms.take(6).map((s) {
                    return ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 11)),
                      onPressed: () => setState(() => _symptomController.text = s),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // Severity Slider (1 to 10)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Symptom Severity (1 to 10)', style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                              '${_severity.round()}/10',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: _severity <= 3
                                    ? Colors.green.shade700
                                    : _severity <= 6
                                        ? Colors.orange.shade700
                                        : Colors.red.shade700,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: _severity,
                          min: 1,
                          max: 10,
                          divisions: 9,
                          label: '${_severity.round()}',
                          onChanged: (val) => setState(() => _severity = val),
                        ),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('1 (Mild)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text('5 (Moderate)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text('10 (Severe)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _descriptionController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Symptom Description (Optional)',
                    hintText: 'Describe how it feels, triggers, or duration',
                    prefixIcon: Icon(Icons.notes),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),

                // Medication Section
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Medication Tracking (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _medicineController,
                          decoration: const InputDecoration(
                            labelText: 'Medicine Name & Dosage',
                            hintText: 'e.g. Paracetamol 500mg',
                            prefixIcon: Icon(Icons.medication),
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Was this medicine taken?'),
                          value: _medicineTaken,
                          onChanged: (val) => setState(() => _medicineTaken = val),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _effectsController,
                          decoration: const InputDecoration(
                            labelText: 'User-Reported Observations (Optional)',
                            hintText: 'e.g. Relieved headache in 45m, slight drowsiness',
                            prefixIcon: Icon(Icons.visibility_outlined),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Additional Notes (Optional)',
                    prefixIcon: Icon(Icons.bookmark_border),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),

                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.save),
                  label: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEditing ? 'Update Health Entry' : 'Save Health Entry', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: _isSaving ? null : _saveRecord,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ================= SYMPTOM TRENDS VIEW (fl_chart) =================

class SymptomTrendsView extends StatefulWidget {
  final int patientId;
  final List<Map<String, dynamic>> records;

  const SymptomTrendsView({super.key, required this.patientId, required this.records});

  @override
  State<SymptomTrendsView> createState() => _SymptomTrendsViewState();
}

class _SymptomTrendsViewState extends State<SymptomTrendsView> {
  String? _selectedSymptom;
  List<String> _distinctSymptoms = [];

  @override
  void initState() {
    super.initState();
    _extractSymptoms();
  }

  @override
  void didUpdateWidget(covariant SymptomTrendsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _extractSymptoms();
  }

  void _extractSymptoms() {
    final set = <String>{};
    for (final r in widget.records) {
      final name = (r['symptomName'] as String? ?? '').trim();
      if (name.isNotEmpty) set.add(name);
    }
    _distinctSymptoms = set.toList()..sort();
    if (_distinctSymptoms.isNotEmpty && (_selectedSymptom == null || !_distinctSymptoms.contains(_selectedSymptom))) {
      _selectedSymptom = _distinctSymptoms.first;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_distinctSymptoms.isEmpty) {
      return const Center(child: Text('No recorded symptoms available for trends.'));
    }

    final filtered = widget.records
        .where((r) => (r['symptomName'] as String? ?? '').trim().toLowerCase() == _selectedSymptom?.toLowerCase())
        .toList()
      ..sort((a, b) => (a['recordDate'] as String).compareTo(b['recordDate'] as String));

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text('Select Symptom: ', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedSymptom,
                  items: _distinctSymptoms.map((sym) {
                    return DropdownMenuItem(value: sym, child: Text(sym));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedSymptom = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (filtered.length < 2)
            Expanded(
              child: Center(
                child: Text(
                  'Only ${filtered.length} entry found for "$_selectedSymptom".\nLog at least 2 entries for this symptom to plot a progression curve.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, height: 1.4),
                ),
              ),
            )
          else ...[
            Text(
              'Severity Progression (1 - 10) Over Time',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Expanded(
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
                        reservedSize: 28,
                        getTitlesWidget: (val, meta) => Text(
                          val.toInt().toString(),
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 1,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx >= 0 && idx < filtered.length) {
                            final rawDate = filtered[idx]['recordDate'] as String;
                            final parts = rawDate.split(' ');
                            final dateShort = parts.first.substring(5); // MM-dd
                            return Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Text(dateShort, style: const TextStyle(fontSize: 9)),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(filtered.length, (idx) {
                        final sev = (filtered[idx]['severity'] as num).toDouble();
                        return FlSpot(idx.toDouble(), sev);
                      }),
                      isCurved: true,
                      color: colorScheme.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 5,
                            color: colorScheme.primary,
                            strokeColor: Colors.white,
                            strokeWidth: 2,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: colorScheme.primary.withAlpha(40),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

