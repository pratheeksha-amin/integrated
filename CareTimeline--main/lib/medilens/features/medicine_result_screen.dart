import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/medicine_storage_service.dart';
import '../services/medicine_search_service.dart';
import '../../accessibility/accessibility_widgets.dart';
import '../../accessibility/font_size_service.dart';
import '../../accessibility/tts_service.dart';

class MedicineResultScreen extends StatefulWidget {
  final String medicineName;
  final Map<String, dynamic>? data;
  final Function(String medicineName)? onAddToPatientHistory;

  const MedicineResultScreen({
    super.key,
    required this.medicineName,
    this.data,
    this.onAddToPatientHistory,
  });

  @override
  State<MedicineResultScreen> createState() => _MedicineResultScreenState();
}

class _MedicineResultScreenState extends State<MedicineResultScreen> {
  Map<String, dynamic>? translatedData;
  bool isLoading = true;
  bool isFavorite = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _checkFavoriteStatus();
    await _fetchTranslatedData();
  }

  Future<void> _checkFavoriteStatus() async {
    final status = await MedicineStorageService.isFavourite(widget.medicineName);
    if (!mounted) return;
    setState(() {
      isFavorite = status;
    });
  }

  Future<void> _fetchTranslatedData() async {
    try {
      final langCode = context.locale.languageCode;

      final data = await MedicineSearchService()
          .searchMedicine(widget.medicineName, langCode);

      if (!mounted) return;
      setState(() {
        translatedData = data ?? widget.data;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        translatedData = widget.data;
        isLoading = false;
      });
    }
  }

  String getField(String key, String fallback) {
    final value = translatedData?[key] ?? widget.data?[key];

    if (value == null) return fallback;

    if (value is String) {
      return value.trim().isEmpty ? fallback : value;
    }

    if (value is List) {
      if (value.isEmpty) return fallback;

      final formatted = value.map((item) {
        if (item is String) {
          return item;
        }

        if (item is Map<String, dynamic>) {
          if (item.containsKey("text")) {
            return item["text"].toString();
          }

          return item.values.join(", ");
        }

        return item.toString();
      }).join("\n");
      return formatted.trim().isEmpty ? fallback : formatted;
    }

    if (value is Map<String, dynamic>) {
      if (value.containsKey("text")) {
        return value["text"].toString();
      }

      return value.values.join("\n");
    }

    return value.toString();
  }

  Future<void> toggleFavourite() async {
    final medicine = translatedData ?? widget.data;
    if (medicine == null) return;

    await MedicineStorageService.toggleFavourite({
      "name": widget.medicineName,
      ...medicine,
    });

    final newStatus = !isFavorite;
    if (!mounted) return;

    setState(() {
      isFavorite = newStatus;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newStatus ? "added to favorites".tr() : "removed from favorites".tr(),
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  String _buildFullTextToRead() {
    final buf = StringBuffer();
    buf.writeln(widget.medicineName);

    final medicine = translatedData ?? widget.data;
    if (medicine != null) {
      if (medicine['generic_name'] != null && medicine['generic_name'].toString().isNotEmpty) {
        buf.writeln('Generic name: ${medicine['generic_name']}');
      }
      final usage = getField('indications_and_usage', '');
      if (usage.isNotEmpty) buf.writeln('Indications and usage: $usage');

      final dosage = getField('dosage_and_administration', '');
      if (dosage.isNotEmpty) buf.writeln('Dosage and administration: $dosage');

      final sideEffects = getField('adverse_reactions', '');
      if (sideEffects.isNotEmpty) buf.writeln('Side effects: $sideEffects');

      final warnings = getField('warnings', '');
      if (warnings.isNotEmpty) buf.writeln('Warnings and precautions: $warnings');
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    final medicine = translatedData ?? widget.data;
    final colorScheme = Theme.of(context).colorScheme;
    final currentLang = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text('medicineResult.title'.tr()),
        actions: [
          const FontSizeControls(compact: true),
          IconButton(
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : null,
            ),
            onPressed: toggleFavourite,
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : medicine == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          'medicineResult.notFound'.tr(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : ValueListenableBuilder<double>(
                  valueListenable: FontSizeService.instance.fontSizeNotifier,
                  builder: (context, baseFontSize, _) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Disclaimer Notice Banner
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.amber.shade300),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Colors.amber.shade900, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'General medicine info only. Not personalized medical advice.',
                                      style: TextStyle(
                                        fontSize: baseFontSize - 2.0,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF451A03),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Read Aloud TTS Controls
                            TtsControlBar(
                              textToRead: _buildFullTextToRead(),
                              languageCode: currentLang,
                              label: 'Read Medicine Info',
                            ),
                            const SizedBox(height: 16),

                            Text(
                              widget.medicineName,
                              style: TextStyle(
                                fontSize: baseFontSize + 12.0,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (medicine['generic_name'] != null && medicine['generic_name'].toString().isNotEmpty)
                              Text(
                                "Generic: ${medicine['generic_name']}",
                                style: TextStyle(
                                  fontSize: baseFontSize + 1.0,
                                  color: colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            if (medicine['manufacturer'] != null && medicine['manufacturer'].toString().isNotEmpty)
                              Text(
                                medicine['manufacturer'].toString(),
                                style: TextStyle(
                                  fontSize: baseFontSize,
                                  color: Colors.blueGrey[700],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            if ((medicine['strength'] != null && medicine['strength'].toString().isNotEmpty) ||
                                (medicine['medicine_type'] != null && medicine['medicine_type'].toString().isNotEmpty))
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
                                child: Text(
                                  "${medicine['strength'] ?? ''} ${medicine['medicine_type'] ?? ''}".trim(),
                                  style: TextStyle(
                                    fontSize: baseFontSize + 1.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 16),

                            infoCard(
                              'medicineResult.usedFor'.tr(),
                              getField(
                                'indications_and_usage',
                                'medicineResult.infoPlaceholder'.tr(),
                              ),
                              baseFontSize,
                            ),

                            infoCard(
                              'medicineResult.dosage'.tr(),
                              getField(
                                'dosage_and_administration',
                                'medicineResult.generalDosageInfo'.tr(),
                              ),
                              baseFontSize,
                            ),

                            infoCard(
                              'medicineResult.sideEffects'.tr(),
                              getField(
                                'adverse_reactions',
                                'medicineResult.commonSideEffects'.tr(),
                              ),
                              baseFontSize,
                            ),

                            infoCard(
                              'medicineResult.warnings'.tr(),
                              getField(
                                'warnings',
                                'medicineResult.precautions'.tr(),
                              ),
                              baseFontSize,
                            ),

                            infoCard(
                              'medicineResult.storage'.tr(),
                              getField(
                                'storage_and_handling',
                                'medicineResult.storageInstructions'.tr(),
                              ),
                              baseFontSize,
                            ),

                            const SizedBox(height: 16),

                            // Action: Optionally add medicine to patient health history
                            if (widget.onAddToPatientHistory != null)
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  icon: const Icon(Icons.add_task),
                                  label: Text(
                                    'Add to Patient Health History',
                                    style: TextStyle(fontSize: baseFontSize),
                                  ),
                                  onPressed: () {
                                    final name = widget.medicineName;
                                    Navigator.pop(context);
                                    widget.onAddToPatientHistory!(name);
                                  },
                                ),
                              ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget infoCard(String title, String value, double baseFontSize) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: baseFontSize + 3.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(fontSize: baseFontSize, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
