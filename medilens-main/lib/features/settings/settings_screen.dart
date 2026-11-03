import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../models/language.dart';
import '../language/language_screen.dart';

/// App Settings screen.
///
/// Currently exposes the "Language" option (requirement: tapping it opens
/// the language picker). More settings can be added here later following
/// the same ListTile pattern.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('settings.title'.tr()),
      ),
      body: ListView(
        children: [
          Builder(
            builder: (context) {
              // Rebuilds automatically when the locale changes because
              // this widget is inside the localized MaterialApp tree.
              final currentLanguage = languages.firstWhere(
                    (l) => l.code == context.locale.languageCode,
                orElse: () => languages.first,
              );

              return ListTile(
                leading: const Icon(Icons.language),
                title: Text('settings.languageTitle'.tr()),
                subtitle: Text(currentLanguage.name),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LanguageScreen(),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
