import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class MedicineStorageService {
  static Future<void> addToHistory(Map<String, dynamic> medicine, String language) async {
    final db = await DatabaseHelper.database;
    final String name = medicine["name"] ?? medicine["brand_name"] ?? "Unknown";
    final String dataJson = jsonEncode(medicine);
    final String now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.delete(
        'history',
        where: 'medicineName = ?',
        whereArgs: [name],
      );

      await txn.insert('history', {
        'medicineName': name,
        'medicineData': dataJson,
        'searchedAt': now,
        'preferredLanguage': language,
      });
    });
  }

  static Future<List<Map<String, dynamic>>> getHistory() async {
    final db = await DatabaseHelper.database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'history',
      orderBy: 'searchedAt DESC',
    );

    return maps.map((item) {
      return {
        "name": item["medicineName"],
        "language": item["preferredLanguage"],
        "data": item["medicineData"] != null ? jsonDecode(item["medicineData"]) : null,
      };
    }).toList();
  }

  static Future<void> toggleFavourite(Map<String, dynamic> medicine) async {
    final db = await DatabaseHelper.database;
    final String name = medicine["name"] ?? medicine["brand_name"] ?? "Unknown";
    
    final List<Map<String, dynamic>> existing = await db.query(
      'favorites',
      where: 'medicineName = ?',
      whereArgs: [name],
    );

    if (existing.isNotEmpty) {
      await db.delete(
        'favorites',
        where: 'medicineName = ?',
        whereArgs: [name],
      );
    } else {
      await db.insert(
        'favorites',
        {
          'medicineName': name,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  static Future<bool> isFavourite(String name) async {
    final db = await DatabaseHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'favorites',
      where: 'medicineName = ?',
      whereArgs: [name],
    );
    return maps.isNotEmpty;
  }

  static Future<List<Map<String, dynamic>>> getFavourite() async {
    final db = await DatabaseHelper.database;
    
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT f.medicineName as name, m.* 
      FROM favorites f
      JOIN medicine_info m ON f.medicineName = m.brandName
      ORDER BY f.id DESC
    ''');

    return maps.map((item) {
      return {
        "name": item["name"],
        "data": {
          "brand_name": item["brandName"],
          "generic_name": item["genericName"],
          "strength": item["strength"],
          "medicine_type": item["medicineType"],
          "manufacturer": item["manufacturer"],
          "indications_and_usage": [item["usage"]],
          "dosage_and_administration": [item["dosage"]],
          "adverse_reactions": jsonDecode(item["sideEffects"] ?? "[]"),
          "warnings": jsonDecode(item["warnings"] ?? "[]"),
          "storage_and_handling": [item["storage"]],
          "prescription_required": item["prescriptionRequired"] == 1,
        }
      };
    }).toList();
  }

  static Future<void> removeFavourite(String name) async {
    final db = await DatabaseHelper.database;
    await db.delete(
      'favorites',
      where: 'medicineName = ?',
      whereArgs: [name],
    );
  }
}
