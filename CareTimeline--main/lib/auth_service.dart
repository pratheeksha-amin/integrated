import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'database.dart';

class AppUser {
  final int id;
  final String fullName;
  final String username;
  final String email;
  final String role; // 'patient' or 'doctor'

  const AppUser({
    required this.id,
    required this.fullName,
    required this.username,
    required this.email,
    required this.role,
  });

  bool get isDoctor => role == 'doctor';
  bool get isPatient => role == 'patient';
}

class AuthService {
  static final AuthService instance = AuthService._internal();
  final _secureStorage = const FlutterSecureStorage();

  AuthService._internal();

  String _generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt:$password');
    return sha256.convert(bytes).toString();
  }

  Future<AppUser> registerPatient({
    required String fullName,
    required String username,
    required String email,
    required String password,
    int? age,
    String? bloodGroup,
    String? emergencyContact,
  }) async {
    final cleanFullName = fullName.trim();
    final cleanUsername = username.trim().toLowerCase();
    final cleanEmail = email.trim().toLowerCase();

    if (cleanFullName.isEmpty) throw Exception('Full name is required.');
    if (cleanUsername.isEmpty || cleanUsername.length < 3) {
      throw Exception('Username must be at least 3 characters.');
    }
    if (!cleanEmail.contains('@')) throw Exception('Please enter a valid email address.');
    if (password.length < 6) throw Exception('Password must be at least 6 characters.');

    final db = await AppDatabase.instance.database;

    final existing = await AppDatabase.instance.getUserByUsername(cleanUsername);
    if (existing != null) throw Exception('Username is already registered.');

    final existingEmail = await AppDatabase.instance.getUserByEmail(cleanEmail);
    if (existingEmail != null) throw Exception('This email address is already registered.');

    final salt = _generateSalt();
    final passwordHash = _hashPassword(password, salt);
    final now = DateTime.now().toIso8601String();

    int userId = 0;
    await db.transaction((txn) async {
      userId = await txn.insert('users', {
        'fullName': cleanFullName,
        'username': cleanUsername,
        'email': cleanEmail,
        'passwordHash': passwordHash,
        'passwordSalt': salt,
        'role': 'patient',
        'createdAt': now,
      });

      await txn.insert('patient_profiles', {
        'userId': userId,
        'age': age,
        'bloodGroup': bloodGroup?.trim(),
        'emergencyContact': emergencyContact?.trim(),
      });
    });

    final user = AppUser(
      id: userId,
      fullName: cleanFullName,
      username: cleanUsername,
      email: cleanEmail,
      role: 'patient',
    );
    await _saveSession(user);
    return user;
  }

  Future<AppUser> registerDoctor({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required String specialization,
    String? registrationNumber,
    String? clinicName,
  }) async {
    final cleanFullName = fullName.trim();
    final cleanUsername = username.trim().toLowerCase();
    final cleanEmail = email.trim().toLowerCase();
    final cleanSpec = specialization.trim();

    if (cleanFullName.isEmpty) throw Exception('Full name is required.');
    if (cleanUsername.isEmpty || cleanUsername.length < 3) {
      throw Exception('Username must be at least 3 characters.');
    }
    if (!cleanEmail.contains('@')) throw Exception('Please enter a valid email address.');
    if (cleanSpec.isEmpty) throw Exception('Medical specialization is required.');
    if (password.length < 6) throw Exception('Password must be at least 6 characters.');

    final db = await AppDatabase.instance.database;

    final existing = await AppDatabase.instance.getUserByUsername(cleanUsername);
    if (existing != null) throw Exception('Username is already registered.');

    final existingEmail = await AppDatabase.instance.getUserByEmail(cleanEmail);
    if (existingEmail != null) throw Exception('This email address is already registered.');

    final salt = _generateSalt();
    final passwordHash = _hashPassword(password, salt);
    final now = DateTime.now().toIso8601String();

    int userId = 0;
    await db.transaction((txn) async {
      userId = await txn.insert('users', {
        'fullName': cleanFullName,
        'username': cleanUsername,
        'email': cleanEmail,
        'passwordHash': passwordHash,
        'passwordSalt': salt,
        'role': 'doctor',
        'createdAt': now,
      });

      await txn.insert('doctor_profiles', {
        'userId': userId,
        'specialization': cleanSpec,
        'registrationNumber': registrationNumber?.trim(),
        'clinicName': clinicName?.trim(),
        'verificationStatus': 'Unverified (Self-Reported)',
      });
    });

    final user = AppUser(
      id: userId,
      fullName: cleanFullName,
      username: cleanUsername,
      email: cleanEmail,
      role: 'doctor',
    );
    await _saveSession(user);
    return user;
  }

  Future<AppUser> login({
    required String username,
    required String password,
  }) async {
    final cleanUsername = username.trim().toLowerCase();
    if (cleanUsername.isEmpty || password.isEmpty) {
      throw Exception('Please enter both username/email and password.');
    }

    // Allow login by username or email
    Map<String, dynamic>? userRow =
        await AppDatabase.instance.getUserByUsername(cleanUsername);
    userRow ??= await AppDatabase.instance.getUserByEmail(cleanUsername);

    if (userRow == null) throw Exception('Invalid username or password.');

    final computedHash = _hashPassword(password, userRow['passwordSalt'] as String);
    if (computedHash != userRow['passwordHash'] as String) {
      throw Exception('Invalid username or password.');
    }

    final user = AppUser(
      id: userRow['id'] as int,
      fullName: userRow['fullName'] as String,
      username: userRow['username'] as String,
      email: (userRow['email'] as String?) ?? '',
      role: userRow['role'] as String,
    );
    await _saveSession(user);
    return user;
  }

  Future<void> _saveSession(AppUser user) async {
    await _secureStorage.write(key: 'session_user_id', value: user.id.toString());
    await _secureStorage.write(key: 'session_full_name', value: user.fullName);
    await _secureStorage.write(key: 'session_username', value: user.username);
    await _secureStorage.write(key: 'session_email', value: user.email);
    await _secureStorage.write(key: 'session_role', value: user.role);
  }

  Future<AppUser?> getCurrentSession() async {
    try {
      final idStr = await _secureStorage.read(key: 'session_user_id');
      final fullName = await _secureStorage.read(key: 'session_full_name');
      final username = await _secureStorage.read(key: 'session_username');
      final email = await _secureStorage.read(key: 'session_email');
      final role = await _secureStorage.read(key: 'session_role');

      if (idStr == null || fullName == null || username == null || role == null) {
        return null;
      }
      final id = int.tryParse(idStr);
      if (id == null) return null;

      final userRow = await AppDatabase.instance.getUserById(id);
      if (userRow == null) {
        await logout();
        return null;
      }

      return AppUser(
        id: id,
        fullName: fullName,
        username: username,
        email: email ?? '',
        role: role,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    await _secureStorage.deleteAll();
  }
}
