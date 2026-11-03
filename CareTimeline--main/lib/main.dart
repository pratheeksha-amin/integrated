import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'database_factory.dart';
import 'auth_service.dart';
import 'auth_screens.dart';
import 'health_screens.dart';
import 'doctor_dashboard.dart';
import 'database.dart';
import 'medilens/database/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initDatabaseFactory();
  await EasyLocalization.ensureInitialized();
  // Initialize CareTimeline SQLite database instance
  await AppDatabase.instance.database;
  // Initialize MediLens SQLite medicine database instance
  await DatabaseHelper.database;

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
        Locale('kn'),
        Locale('ta'),
        Locale('te'),
        Locale('ml'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      saveLocale: true,
      child: const CareTimelineApp(),
    ),
  );
}

class CareTimelineApp extends StatefulWidget {
  const CareTimelineApp({super.key});

  @override
  State<CareTimelineApp> createState() => _CareTimelineAppState();
}

class _CareTimelineAppState extends State<CareTimelineApp> {
  AppUser? _currentUser;
  bool _isCheckingSession = true;

  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final sessionUser = await AuthService.instance.getCurrentSession();
    if (mounted) {
      setState(() {
        _currentUser = sessionUser;
        _isCheckingSession = false;
      });
    }
  }

  void _onAuthenticated(AppUser user) {
    setState(() {
      _currentUser = user;
    });
  }

  void _onLogout() {
    setState(() {
      _currentUser = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: ValueKey(context.locale.languageCode),
      title: 'CareTimeline AI',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00796B), // Healthcare Teal
          brightness: Brightness.light,
          primary: const Color(0xFF00796B),
          secondary: const Color(0xFF0288D1), // Medical Blue
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
        ),
      ),
      home: _isCheckingSession
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            )
          : _currentUser == null
              ? WelcomeScreen(onAuthenticated: _onAuthenticated)
              : _currentUser!.isDoctor
                  ? DoctorDashboardScreen(user: _currentUser!, onLogout: _onLogout)
                  : PatientDashboardScreen(user: _currentUser!, onLogout: _onLogout),
    );
  }
}
