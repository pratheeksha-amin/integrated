import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/medicine_storage_service.dart';
import '../../services/medicine_search_service.dart';

class MedicineResultScreen extends StatefulWidget {
  final String medicineName;
  final Map<String, dynamic>? data;

  const MedicineResultScreen({
    super.key,
    required this.medicineName,
    this.data,
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

      setState(() {
        translatedData = data ?? widget.data;
        isLoading = false;
      });
    } catch (e) {
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
      return value;
    }

    if (value is List) {
      if (value.isEmpty) return fallback;

      return value.map((item) {
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

  @override
  Widget build(BuildContext context) {
    final medicine = translatedData ?? widget.data;

    return Scaffold(
      appBar: AppBar(
        title: Text('medicineResult.title'.tr()),
        actions: [
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
        child: Text(
          'medicineResult.notFound'.tr(),
        ),
      )
          : Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.medicineName,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (medicine['manufacturer'] != null)
                Text(
                  medicine['manufacturer'].toString(),
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blueGrey[700],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              if (medicine['strength'] != null || medicine['medicine_type'] != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Text(
                    "${medicine['strength'] ?? ''} ${medicine['medicine_type'] ?? ''}".trim(),
                    style: const TextStyle(
                      fontSize: 16,
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
              ),

              infoCard(
                'medicineResult.dosage'.tr(),
                getField(
                  'dosage_and_administration',
                  'medicineResult.generalDosageInfo'.tr(),
                ),
              ),

              infoCard(
                'medicineResult.sideEffects'.tr(),
                getField(
                  'adverse_reactions',
                  'medicineResult.commonSideEffects'.tr(),
                ),
              ),

              infoCard(
                'medicineResult.warnings'.tr(),
                getField(
                  'warnings',
                  'medicineResult.precautions'.tr(),
                ),
              ),

              infoCard(
                'medicineResult.storage'.tr(),
                getField(
                  'storage_and_handling',
                  'medicineResult.storageInstructions'.tr(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget infoCard(String title, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(value),
          ],
        ),
      ),
    );
  }
}
