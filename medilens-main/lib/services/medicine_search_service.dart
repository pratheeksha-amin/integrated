import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:translator/translator.dart';
import '../database/database_helper.dart';
import 'translation_cache_service.dart';

class GoogleTranslationService {
  final _translator = GoogleTranslator();

  /// Translates multiple strings into the target language using the translator package.
  Future<List<String>> translateBatch(List<String> texts, String targetLang) async {
    try {
      if (texts.isEmpty) return [];
      if (targetLang.toLowerCase() == 'en') return texts;

      List<String> results = [];
      for (String text in texts) {
        if (text.trim().isEmpty) {
          results.add("");
          continue;
        }
        
        final translation = await _translator.translate(text, to: targetLang);
        results.add(translation.text);
      }
      return results;
    } catch (e) {
      debugPrint("Translation via Package Failed: $e");
      return texts; // Fallback to original
    }
  }
}

class MedicineSearchService {
  Future<Map<String, dynamic>?> searchWithCandidates(
    List<String> candidates,
    String targetLang,
  ) async {
    for (String candidate in candidates) {
      final match = await _findInDatabase(candidate);
      if (match != null) {
        return await _getProcessedResult(match, targetLang);
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> searchMedicine(
    String medicineName,
    String targetLang,
  ) async {
    final match = await _findInDatabase(medicineName);
    if (match != null) {
      return await _getProcessedResult(match, targetLang);
    }
    return null;
  }

  Future<Map<String, dynamic>?> _findInDatabase(String searchKey) async {
    if (searchKey.isEmpty) return null;
    final db = await DatabaseHelper.database;
    final key = searchKey.toLowerCase().trim();

    // Requirement: Case-insensitive search directly in medicine_info.
    // Match against brand_name and generic_name.
    // Also support "contains" logic: return a medicine if the OCR text contains the brand/generic name.
    // This is achieved by searching for medicines whose names are present within the searchKey,
    // OR medicines whose names contain the searchKey.
    
    // 1. Exact or Partial match (medicine name contains search key)
    final List<Map<String, dynamic>> partialResults = await db.query(
      'medicine_info',
      where: 'LOWER(brandName)=? OR LOWER(genericName)=?',
      whereArgs: ['%$key%', '%$key%'],
      limit: 1,
    );

    if (partialResults.isNotEmpty) {
      return partialResults.first;
    }

    // 2. OCR "Contains" logic: Does the search key (OCR text) contain the medicine name?
    // We can use a rawQuery for this logic in SQL.
    final List<Map<String, dynamic>> reverseResults = await db.rawQuery(
      'SELECT * FROM medicine_info WHERE ? LIKE "%" || brandName || "%" OR ? LIKE "%" || genericName || "%" LIMIT 1',
      [key, key],
    );

    if (reverseResults.isNotEmpty) {
      return reverseResults.first;
    }

    return null;
  }

  Future<Map<String, dynamic>> _getProcessedResult(
    Map<String, dynamic> match,
    String targetLang,
  ) async {
    final String brandName = match["brandName"];

    // 1. If English, just format and return
    if (targetLang.toLowerCase() == 'en') {
      return _formatResult(match);
    }

    // 2. Check Local Cache
    final cachedData = await TranslationCacheService.get(brandName, targetLang);
    if (cachedData != null) return cachedData;

    // 3. Translate if not in cache
    final formatted = _formatResult(match);
    final translated = await _translateResult(formatted, targetLang);

    // 4. Save to Cache
    await TranslationCacheService.save(brandName, targetLang, translated);

    return translated;
  }

  Map<String, dynamic> _formatResult(Map<String, dynamic> match) {
    return {
      "brand_name": match["brandName"],
      "generic_name": match["genericName"],
      "strength": match["strength"],
      "medicine_type": match["medicineType"],
      "manufacturer": match["manufacturer"],
      "indications_and_usage": [match["usage"]],
      "dosage_and_administration": [match["dosage"]],
      "adverse_reactions": match["sideEffects"] is String ? jsonDecode(match["sideEffects"]) : (match["sideEffects"] ?? []),
      "warnings": match["warnings"] is String ? jsonDecode(match["warnings"]) : (match["warnings"] ?? []),
      "storage_and_handling": [match["storage"]],
      "prescription_required": match["prescriptionRequired"] == 1,
    };
  }

  Future<Map<String, dynamic>> _translateResult(
    Map<String, dynamic> data,
    String lang,
  ) async {
    final translator = GoogleTranslationService();
    
    List<String> toTranslate = [
      data["generic_name"] ?? "",
      data["medicine_type"] ?? "",
      ...(data["indications_and_usage"] as List).map((e) => e.toString()),
      ...(data["dosage_and_administration"] as List).map((e) => e.toString()),
      ...(data["adverse_reactions"] as List).map((e) => e.toString()),
      ...(data["warnings"] as List).map((e) => e.toString()),
      ...(data["storage_and_handling"] as List).map((e) => e.toString()),
    ];

    final results = await translator.translateBatch(toTranslate, lang);

    int idx = 0;
    return {
      ...data,
      "generic_name": results[idx++],
      "medicine_type": results[idx++],
      "indications_and_usage": [results[idx++]],
      "dosage_and_administration": [results[idx++]],
      "adverse_reactions": List.generate(
        (data["adverse_reactions"] as List).length, 
        (_) => results[idx++]
      ),
      "warnings": List.generate(
        (data["warnings"] as List).length, 
        (_) => results[idx++]
      ),
      "storage_and_handling": [results[idx++]],
    };
  }
}
