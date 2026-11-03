import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class MedicineScreen extends StatelessWidget {
  const MedicineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('medicine.detailsTitle'.tr()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Icon(
                Icons.medication,
                size: 100,
                color: Colors.blue,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'medicine.sampleName'.tr(),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 20),

            buildSection(
              'medicine.uses'.tr(),
              'medicine.usesContent'.tr(),
            ),

            buildSection(
              'medicine.generalDosage'.tr(),
              'medicine.generalDosageContent'.tr(),
            ),

            buildSection(
              'medicine.commonSideEffects'.tr(),
              'medicine.commonSideEffectsContent'.tr(),
            ),

            buildSection(
              'medicine.warnings'.tr(),
              'medicine.warningsContent'.tr(),
            ),

            buildSection(
              'medicine.storage'.tr(),
              'medicine.storageContent'.tr(),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.favorite_border),
                label: Text('medicine.addToFavorites'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                content,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
