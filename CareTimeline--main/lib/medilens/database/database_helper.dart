import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await initDatabase();
    return _database!;
  }

  static Future<Database> initDatabase() async {
    String path = join(
      await getDatabasesPath(),
      "medilens.db",
    );

    return await openDatabase(
      path,
      version: 4,
      onCreate: (db, version) async {
        await _createTables(db);
        await _migrateJsonToSqlite(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Initial tables handled by _createTables if starting from scratch
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE history ADD COLUMN preferredLanguage TEXT');
          await _createMedicineInfoTable(db);
          await _migrateJsonToSqlite(db);
        }
        if (oldVersion < 4) {
          await db.execute('''
            DELETE FROM history 
            WHERE id NOT IN (
              SELECT MAX(id) FROM history GROUP BY medicineName
            )
          ''');
          await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_history_medicineName ON history(medicineName)');
          
          await db.execute('DROP TABLE IF EXISTS medicine_info');
          await _createMedicineInfoTable(db);
          await _migrateJsonToSqlite(db);
        }
      },
    );
  }

  static Future<void> _createMedicineInfoTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS medicine_info(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        brandName TEXT,
        genericName TEXT,
        strength TEXT,
        medicineType TEXT,
        manufacturer TEXT,
        usage TEXT,
        dosage TEXT,
        sideEffects TEXT,
        warnings TEXT,
        storage TEXT,
        prescriptionRequired INTEGER
      )
    ''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_medicine_info_brandName ON medicine_info(brandName)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_medicine_info_genericName ON medicine_info(genericName)');
  }

  static Future<void> _createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS medicines(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        uses TEXT,
        dosage TEXT,
        sideEffects TEXT,
        warnings TEXT,
        storage TEXT,
        language TEXT,
        favorite INTEGER,
        scannedDate TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicineName TEXT,
        medicineData TEXT,
        searchedAt TEXT,
        preferredLanguage TEXT
      )
    ''');
    await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_history_medicineName ON history(medicineName)');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorites(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        medicineName TEXT UNIQUE,
        medicineData TEXT
      )
    ''');

    await _createMedicineInfoTable(db);
  }

  static Future<void> _migrateJsonToSqlite(Database db) async {
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM medicine_info'));
    if (count != null && count > 0) return;

    final parts = [
      'assets/data/medicines_part1.json',
      'assets/data/medicines_part2.json',
      'assets/data/medicines_part3.json',
      'assets/data/medicines_part4.json',
      'assets/data/medicines_part5.json',
      'assets/data/medicines_part6.json',
      'assets/data/medicines_part7.json',
    ];

    await db.transaction((txn) async {
      for (String path in parts) {
        try {
          final String content = await rootBundle.loadString(path);
          final List<dynamic> data = jsonDecode(content);
          
          for (var item in data) {
            await txn.insert('medicine_info', {
              'brandName': item['brandName'],
              'genericName': item['genericName'],
              'strength': item['strength'],
              'medicineType': item['medicineType'],
              'manufacturer': item['manufacturer'],
              'usage': item['usage'],
              'dosage': item['dosage'],
              'sideEffects': jsonEncode(item['sideEffects']),
              'warnings': jsonEncode(item['warnings']),
              'storage': item['storage'],
              'prescriptionRequired': item['prescriptionRequired'] == true ? 1 : 0,
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          }
        } catch (e) {
          // Ignore loading errors
        }
      }
    });
  }
}
