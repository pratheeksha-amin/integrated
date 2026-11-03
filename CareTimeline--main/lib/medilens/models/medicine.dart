class Medicine {
  final int? id;
  final String name;
  final String uses;
  final String dosage;
  final String sideEffects;
  final String warnings;
  final String storage;
  final String language;
  final bool favorite;
  final String scannedDate;

  Medicine({
    this.id,
    required this.name,
    required this.uses,
    required this.dosage,
    required this.sideEffects,
    required this.warnings,
    required this.storage,
    required this.language,
    this.favorite = false,
    required this.scannedDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'uses': uses,
      'dosage': dosage,
      'sideEffects': sideEffects,
      'warnings': warnings,
      'storage': storage,
      'language': language,
      'favorite': favorite ? 1 : 0,
      'scannedDate': scannedDate,
    };
  }

  factory Medicine.fromMap(Map<String, dynamic> map) {
    return Medicine(
      id: map['id'],
      name: map['name'] ?? '',
      uses: map['uses'] ?? '',
      dosage: map['dosage'] ?? '',
      sideEffects: map['sideEffects'] ?? '',
      warnings: map['warnings'] ?? '',
      storage: map['storage'] ?? '',
      language: map['language'] ?? 'en',
      favorite: map['favorite'] == 1,
      scannedDate: map['scannedDate'] ?? '',
    );
  }
}
