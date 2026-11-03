import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../models/language.dart';
import '../services/language_service.dart';

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
              await LanguageService.setOnboardingComplete();

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
