import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'features/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

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
      path: 'assets/translations', // JSON translation files
      fallbackLocale: const Locale('en'), // Default language: English
      saveLocale: true, // Persist user's chosen language across restarts
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // We use a ValueKey based on the locale to force the entire 
    // MaterialApp tree to rebuild when the language changes. 
    // This ensures that all screens, including the Home screen, 
    // immediately reflect the new language without needing a restart.
    return MaterialApp(
      key: ValueKey(context.locale.languageCode),
      title: 'MediLens',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const SplashScreen(),
    );
  }
}
