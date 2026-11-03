class AppLanguage {
  final String name;
  final String code;

  const AppLanguage({
    required this.name,
    required this.code,
  });
}

const List<AppLanguage> languages = [
  AppLanguage(name: "English", code: "en"),
  AppLanguage(name: "ಕನ್ನಡ", code: "kn"),
  AppLanguage(name: "हिन्दी", code: "hi"),
  AppLanguage(name: "தமிழ்", code: "ta"),
  AppLanguage(name: "తెలుగు", code: "te"),
  AppLanguage(name: "മലയാളം", code: "ml"),
];