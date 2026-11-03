import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:medilens/services/language_service.dart';
import '../../models/language.dart';

class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentCode = context.locale.languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text('language.chooseLanguage'.tr()),
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: languages.length,
        itemBuilder: (context, index) {
          final lang = languages[index];
          final isSelected = lang.code == currentCode;

          return ListTile(
            leading: const Icon(Icons.language),
            title: Text(lang.name),
            trailing: isSelected
                ? const Icon(Icons.check_circle, color: Colors.blue)
                : null,
            onTap: () async {
              // 1. Mark onboarding as complete first
              await LanguageService.setOnboardingComplete();

              // 2. Set the new locale. 
              // Because MaterialApp has a Key based on locale in main.dart, 
              // this will trigger a full rebuild of the app starting from 
              // the SplashScreen, ensuring all translations update instantly.
              if (context.mounted) {
                await context.setLocale(Locale(lang.code));
              }
            },
          );
        },
      ),
    );
  }
}
