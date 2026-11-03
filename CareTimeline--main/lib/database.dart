import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static final AppDatabase instance = AppDatabase._internal();
  static Database? _database;

  AppDatabase._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'care_timeline.db');

    return await openDatabase(
      path,
      version: 4, // v4 stores locally generated patient summaries
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Users table (with email for patient-doctor linking)
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fullName TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        email TEXT,
        passwordHash TEXT NOT NULL,
        passwordSalt TEXT NOT NULL,
        role TEXT NOT NULL CHECK(role IN ('patient', 'doctor')),
        createdAt TEXT NOT NULL
      )
    ''');

    // 2. Patient Profiles table
    await db.execute('''
      CREATE TABLE patient_profiles (
        userId INTEGER PRIMARY KEY,
        age INTEGER,
        bloodGroup TEXT,
        emergencyContact TEXT,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // 3. Doctor Profiles table
    await db.execute('''
      CREATE TABLE doctor_profiles (
        userId INTEGER PRIMARY KEY,
        specialization TEXT NOT NULL,
        registrationNumber TEXT,
        clinicName TEXT,
        verificationStatus TEXT NOT NULL DEFAULT 'Unverified (Self-Reported)',
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // 4. Health Records table
    await db.execute('''
      CREATE TABLE health_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patientId INTEGER NOT NULL,
        recordDate TEXT NOT NULL,
        symptomName TEXT NOT NULL,
        severity INTEGER NOT NULL CHECK(severity >= 1 AND severity <= 10),
        description TEXT,
        medicineName TEXT,
        medicineTaken INTEGER NOT NULL DEFAULT 0,
        observedEffects TEXT,
        notes TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (patientId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // 5. Imported Patient Reports table (for Doctors - file import)
    await db.execute('''
      CREATE TABLE imported_patient_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        importedByDoctorId INTEGER NOT NULL,
        patientReference TEXT NOT NULL,
        reportDate TEXT NOT NULL,
        sourceFileName TEXT NOT NULL,
        importedAt TEXT NOT NULL,
        structuredData TEXT NOT NULL,
        FOREIGN KEY (importedByDoctorId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // 6. NEW: Shared Reports table (in-app patient→doctor sharing by email)
    await db.execute('''
      CREATE TABLE shared_reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fromPatientId INTEGER NOT NULL,
        fromPatientName TEXT NOT NULL,
        toDoctorEmail TEXT NOT NULL,
        toDoctorId INTEGER,
        reportSentAt TEXT NOT NULL,
        aiSummary TEXT,
        offlineSummary TEXT NOT NULL,
        structuredData TEXT NOT NULL,
        isRead INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (fromPatientId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');

    // Performance Indexes
    await db.execute('CREATE INDEX idx_users_username ON users(username)');
    await db.execute('CREATE INDEX idx_users_email ON users(email)');
    await db.execute('CREATE INDEX idx_health_records_patient ON health_records(patientId, recordDate)');
    await db.execute('CREATE INDEX idx_health_records_symptom ON health_records(patientId, symptomName)');
    await db.execute('CREATE INDEX idx_doctor_reports ON imported_patient_reports(importedByDoctorId)');
    await db.execute('CREATE INDEX idx_shared_reports_doctor ON shared_reports(toDoctorEmail)');
    await db.execute('CREATE INDEX idx_shared_reports_read ON shared_reports(toDoctorId, isRead)');

    await db.execute('''
      CREATE TABLE generated_summaries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        patientId INTEGER NOT NULL,
        createdAt TEXT NOT NULL,
        source TEXT NOT NULL,
        model TEXT,
        summaryText TEXT NOT NULL,
        FOREIGN KEY (patientId) REFERENCES users(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_generated_summaries_patient ON generated_summaries(patientId, createdAt)');
  }

  // Migration: Adds email + shared_reports table if upgrading from v1
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add email column to existing users table
      try {
        await db.execute('ALTER TABLE users ADD COLUMN email TEXT');
      } catch (_) {}

      // Create shared_reports table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS shared_reports (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          fromPatientId INTEGER NOT NULL,
          fromPatientName TEXT NOT NULL,
          toDoctorEmail TEXT NOT NULL,
          toDoctorId INTEGER,
          reportSentAt TEXT NOT NULL,
          aiSummary TEXT,
          offlineSummary TEXT NOT NULL,
          structuredData TEXT NOT NULL,
          isRead INTEGER NOT NULL DEFAULT 0,
          FOREIGN KEY (fromPatientId) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');

      try {
        await db.execute('CREATE INDEX idx_users_email ON users(email)');
        await db.execute('CREATE INDEX idx_shared_reports_doctor ON shared_reports(toDoctorEmail)');
        await db.execute('CREATE INDEX idx_shared_reports_read ON shared_reports(toDoctorId, isRead)');
      } catch (_) {}
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS generated_summaries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          patientId INTEGER NOT NULL,
          createdAt TEXT NOT NULL,
          source TEXT NOT NULL,
          model TEXT,
          summaryText TEXT NOT NULL,
          FOREIGN KEY (patientId) REFERENCES users(id) ON DELETE CASCADE
        )
      ''');
      try {
        await db.execute('CREATE INDEX idx_generated_summaries_patient ON generated_summaries(patientId, createdAt)');
      } catch (_) {}
    }
  }

  // ================= USER OPERATIONS =================

  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    final db = await database;
    final normalized = username.trim().toLowerCase();
    final results = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first;
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final normalized = email.trim().toLowerCase();
    final results = await db.query(
      'users',
      where: 'LOWER(email) = ?',
      whereArgs: [normalized],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first;
  }

  Future<Map<String, dynamic>?> getUserById(int id) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first;
  }

  Future<Map<String, dynamic>?> getPatientProfile(int userId) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT u.id, u.fullName, u.username, u.email, u.role, u.createdAt,
             p.age, p.bloodGroup, p.emergencyContact
      FROM users u
      LEFT JOIN patient_profiles p ON u.id = p.userId
      WHERE u.id = ? AND u.role = 'patient'
    ''', [userId]);
    if (results.isEmpty) return null;
    return results.first;
  }

  Future<Map<String, dynamic>?> getDoctorProfile(int userId) async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT u.id, u.fullName, u.username, u.email, u.role, u.createdAt,
             d.specialization, d.registrationNumber, d.clinicName, d.verificationStatus
      FROM users u
      LEFT JOIN doctor_profiles d ON u.id = d.userId
      WHERE u.id = ? AND u.role = 'doctor'
    ''', [userId]);
    if (results.isEmpty) return null;
    return results.first;
  }

  Future<void> updatePatientProfile(int userId, {int? age, String? bloodGroup, String? emergencyContact, String? fullName, String? email}) async {
    final db = await database;
    await db.transaction((txn) async {
      final userUpdates = <String, dynamic>{};
      if (fullName != null && fullName.trim().isNotEmpty) {
        userUpdates['fullName'] = fullName.trim();
      }
      if (email != null && email.trim().isNotEmpty) {
        userUpdates['email'] = email.trim().toLowerCase();
      }
      if (userUpdates.isNotEmpty) {
        await txn.update('users', userUpdates, where: 'id = ?', whereArgs: [userId]);
      }
      await txn.insert(
        'patient_profiles',
        {
          'userId': userId,
          'age': age,
          'bloodGroup': bloodGroup?.trim(),
          'emergencyContact': emergencyContact?.trim(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> updateDoctorProfile(int userId, {String? fullName, String? specialization, String? registrationNumber, String? clinicName, String? email}) async {
    final db = await database;
    await db.transaction((txn) async {
      final userUpdates = <String, dynamic>{};
      if (fullName != null && fullName.trim().isNotEmpty) {
        userUpdates['fullName'] = fullName.trim();
      }
      if (email != null && email.trim().isNotEmpty) {
        userUpdates['email'] = email.trim().toLowerCase();
      }
      if (userUpdates.isNotEmpty) {
        await txn.update('users', userUpdates, where: 'id = ?', whereArgs: [userId]);
      }
      final doctorUpdates = <String, dynamic>{};
      if (specialization != null) doctorUpdates['specialization'] = specialization.trim();
      if (registrationNumber != null) doctorUpdates['registrationNumber'] = registrationNumber.trim();
      if (clinicName != null) doctorUpdates['clinicName'] = clinicName.trim();
      if (doctorUpdates.isNotEmpty) {
        await txn.update('doctor_profiles', doctorUpdates, where: 'userId = ?', whereArgs: [userId]);
      }
    });
  }

  // ================= HEALTH RECORD OPERATIONS =================

  Future<int> insertHealthRecord(Map<String, dynamic> record) async {
    final db = await database;
    return await db.insert('health_records', record);
  }

  Future<int> updateHealthRecord(int id, int patientId, Map<String, dynamic> record) async {
    final db = await database;
    return await db.update(
      'health_records',
      record,
      where: 'id = ? AND patientId = ?',
      whereArgs: [id, patientId],
    );
  }

  Future<int> deleteHealthRecord(int id, int patientId) async {
    final db = await database;
    return await db.delete(
      'health_records',
      where: 'id = ? AND patientId = ?',
      whereArgs: [id, patientId],
    );
  }

  Future<List<Map<String, dynamic>>> getHealthRecords(int patientId, {String? symptomName, String? startDate, String? endDate}) async {
    final db = await database;
    final whereClauses = ['patientId = ?'];
    final whereArgs = <dynamic>[patientId];

    if (symptomName != null && symptomName.trim().isNotEmpty) {
      whereClauses.add('LOWER(symptomName) = LOWER(?)');
      whereArgs.add(symptomName.trim());
    }
    if (startDate != null && startDate.trim().isNotEmpty) {
      whereClauses.add('recordDate >= ?');
      whereArgs.add(startDate.trim());
    }
    if (endDate != null && endDate.trim().isNotEmpty) {
      whereClauses.add('recordDate <= ?');
      whereArgs.add(endDate.trim());
    }

    return await db.query(
      'health_records',
      where: whereClauses.join(' AND '),
      whereArgs: whereArgs,
      orderBy: 'recordDate DESC, id DESC',
    );
  }

  Future<int> getHealthRecordCount(int patientId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM health_records WHERE patientId = ?',
      [patientId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> saveGeneratedSummary({
    required int patientId,
    required String source,
    String? model,
    required String summaryText,
  }) async {
    final db = await database;
    return await db.insert('generated_summaries', {
      'patientId': patientId,
      'createdAt': DateTime.now().toIso8601String(),
      'source': source,
      'model': model,
      'summaryText': summaryText,
    });
  }

  Future<Map<String, dynamic>?> getLatestGeneratedSummary(int patientId) async {
    final db = await database;
    final rows = await db.query(
      'generated_summaries',
      where: 'patientId = ?',
      whereArgs: [patientId],
      orderBy: 'createdAt DESC, id DESC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first;
  }

  // ================= SHARED REPORTS (Patient → Doctor in-app) =================

  /// Patient sends a report to a doctor identified by their registered email
  Future<int> sendSharedReport({
    required int fromPatientId,
    required String fromPatientName,
    required String toDoctorEmail,
    String? aiSummary,
    required String offlineSummary,
    required String structuredData,
  }) async {
    final db = await database;

    // Try to find doctor's id on this device (same phone scenario)
    final doctorUser = await getUserByEmail(toDoctorEmail);

    return await db.insert('shared_reports', {
      'fromPatientId': fromPatientId,
      'fromPatientName': fromPatientName,
      'toDoctorEmail': toDoctorEmail.trim().toLowerCase(),
      'toDoctorId': doctorUser?['id'],
      'reportSentAt': DateTime.now().toIso8601String(),
      'aiSummary': aiSummary,
      'offlineSummary': offlineSummary,
      'structuredData': structuredData,
      'isRead': 0,
    });
  }

  /// Doctor fetches all shared reports directed to their registered email
  Future<List<Map<String, dynamic>>> getSharedReportsForDoctor(int doctorId, String doctorEmail) async {
    final db = await database;
    final normalizedEmail = doctorEmail.trim().toLowerCase();
    return await db.query(
      'shared_reports',
      where: "LOWER(toDoctorEmail) = ? OR toDoctorId = ?",
      whereArgs: [normalizedEmail, doctorId],
      orderBy: 'reportSentAt DESC',
    );
  }

  Future<int> getUnreadSharedReportCount(int doctorId, String doctorEmail) async {
    final db = await database;
    final normalizedEmail = doctorEmail.trim().toLowerCase();
    final result = await db.rawQuery(
      "SELECT COUNT(*) as count FROM shared_reports WHERE (LOWER(toDoctorEmail) = ? OR toDoctorId = ?) AND isRead = 0",
      [normalizedEmail, doctorId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markSharedReportRead(int reportId) async {
    final db = await database;
    await db.update('shared_reports', {'isRead': 1, 'toDoctorId': -1}, where: 'id = ?', whereArgs: [reportId]);
  }

  Future<void> markAllReportsReadForDoctor(int doctorId, String doctorEmail) async {
    final db = await database;
    final normalizedEmail = doctorEmail.trim().toLowerCase();
    await db.rawUpdate(
      "UPDATE shared_reports SET isRead = 1 WHERE LOWER(toDoctorEmail) = ? OR toDoctorId = ?",
      [normalizedEmail, doctorId],
    );
  }

  Future<int> deleteSharedReport(int reportId) async {
    final db = await database;
    return await db.delete('shared_reports', where: 'id = ?', whereArgs: [reportId]);
  }

  // ================= IMPORTED DOCTOR REPORTS (File-based) =================

  Future<int> insertImportedReport({
    required int doctorId,
    required String patientReference,
    required String reportDate,
    required String sourceFileName,
    required String structuredData,
  }) async {
    final db = await database;
    return await db.insert('imported_patient_reports', {
      'importedByDoctorId': doctorId,
      'patientReference': patientReference,
      'reportDate': reportDate,
      'sourceFileName': sourceFileName,
      'importedAt': DateTime.now().toIso8601String(),
      'structuredData': structuredData,
    });
  }

  Future<List<Map<String, dynamic>>> getImportedReports(int doctorId) async {
    final db = await database;
    return await db.query(
      'imported_patient_reports',
      where: 'importedByDoctorId = ?',
      whereArgs: [doctorId],
      orderBy: 'importedAt DESC',
    );
  }

  Future<Map<String, dynamic>?> getImportedReportById(int reportId, int doctorId) async {
    final db = await database;
    final results = await db.query(
      'imported_patient_reports',
      where: 'id = ? AND importedByDoctorId = ?',
      whereArgs: [reportId, doctorId],
      limit: 1,
    );
    if (results.isEmpty) return null;
    return results.first;
  }

  Future<int> deleteImportedReport(int reportId, int doctorId) async {
    final db = await database;
    return await db.delete(
      'imported_patient_reports',
      where: 'id = ? AND importedByDoctorId = ?',
      whereArgs: [reportId, doctorId],
    );
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}


