import 'dart:io';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/ocr_service.dart';
import '../../services/medicine_parser.dart';
import '../../services/medicine_search_service.dart';
import '../medicine/medicine_result_screen.dart';
import '../../services/medicine_storage_service.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker picker = ImagePicker();

  File? selectedImage;
  String extractedText = "";
  bool isLoading = false;

  Future<void> pickImage(ImageSource source) async {
    final XFile? image = await picker.pickImage(
      source: source,
    );

    if (image != null) {
      if (!mounted) return;
      setState(() {
        selectedImage = File(image.path);
        extractedText = "";
      });

      extractMedicineText();
    }
  }

  Future<void> extractMedicineText() async {
    if (selectedImage == null) return;

    try {
      if (!mounted) return;
      setState(() {
        isLoading = true;
      });

      String text = await OCRService.extractText(selectedImage!);

      if (!mounted) return;
      setState(() {
        extractedText = text;
      });

      // Split the text and get all potential candidates for searching
      List<String> candidates = MedicineParser.getSearchCandidates(text);
      debugPrint("Search candidates: $candidates");

      final result = await MedicineSearchService()
          .searchWithCandidates(candidates, context.locale.languageCode);

      String medicineName = "Unknown Medicine";
      if (result != null) {
        medicineName = result["brand_name"] ?? result["generic_name"] ?? "Unknown";
        
        await MedicineStorageService.addToHistory({
          "name": medicineName,
          "data": result,
        }, context.locale.languageCode);
      } else {
        // Fallback to the first candidate if nothing found in DB
        if (candidates.isNotEmpty) {
          medicineName = candidates.first;
        }
      }

      if (!mounted) return;
      setState(() {
        isLoading = false;
      });

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MedicineResultScreen(
            medicineName: medicineName,
            data: result,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });

      debugPrint("Medicine scan error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('scan.title'.tr()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Expanded(
              child: selectedImage == null
                  ? Center(
                child: Text('scan.selectPrompt'.tr()),
              )
                  : Image.file(selectedImage!),
            ),

            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Camera"),
                ),
                ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () => pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text("Gallery"),
                ),
              ],
            ),

            const SizedBox(height: 20),

            if (isLoading)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),

            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  extractedText.isEmpty
                      ? 'scan.extractedPlaceholder'.tr()
                      : extractedText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
