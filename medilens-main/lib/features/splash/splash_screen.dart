import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:medilens/features/home/home_screen.dart';
import 'package:medilens/features/language/language_screen.dart';
import 'package:medilens/services/language_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  // Static flag to skip splash delay if the app has already been 
  // through the splash screen once (e.g. during a language change).
  static bool _isFirstTime = true;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _startApp();
  }

  Future<void> _startApp() async {
    final bool complete = await LanguageService.isOnboardingComplete();
    
    if (SplashScreen._isFirstTime) {
      // Show splash for 1.5 seconds only on the very first launch
      await Future.delayed(const Duration(milliseconds: 1500));
      SplashScreen._isFirstTime = false;
    } else {
      // During a language change (MaterialApp rebuild), we transition instantly
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (!mounted) return;
    
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => complete 
            ? const HomeScreen() 
            : const LanguageScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.medical_services,
              size: 90,
              color: Colors.white,
            ),
            const SizedBox(height: 20),
            Text(
              'app.name'.tr(),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'app.tagline'.tr(),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
