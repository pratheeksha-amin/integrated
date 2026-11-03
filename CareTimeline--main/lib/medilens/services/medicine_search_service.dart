import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:translator/translator.dart';
import '../database/database_helper.dart';
import 'translation_cache_service.dart';

class GoogleTranslationService {
  final _translator = GoogleTranslator();

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
      return texts;
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

    final List<Map<String, dynamic>> partialResults = await db.query(
      'medicine_info',
      where: 'LOWER(brandName) LIKE ? OR LOWER(genericName) LIKE ?',
      whereArgs: ['%$key%', '%$key%'],
      limit: 1,
    );

    if (partialResults.isNotEmpty) {
      return partialResults.first;
    }

    final List<Map<String, dynamic>> reverseResults = await db.rawQuery(
      'SELECT * FROM medicine_info WHERE ? LIKE "%" || LOWER(brandName) || "%" OR ? LIKE "%" || LOWER(genericName) || "%" LIMIT 1',
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
    final String brandName = match["brandName"] ?? match["brand_name"] ?? "";

    if (targetLang.toLowerCase() == 'en') {
      return _formatResult(match);
    }

    final cachedData = await TranslationCacheService.get(brandName, targetLang);
    if (cachedData != null) return cachedData;

    final formatted = _formatResult(match);
    final translated = await _translateResult(formatted, targetLang);

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
