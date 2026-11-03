class MedicineSearchResult {
  final String brandName;
  final String genericName;
  final String strength;
  final String medicineType;
  final String manufacturer;
  final String usage;
  final String dosage;
  final List<String> sideEffects;
  final List<String> warnings;
  final String storage;
  final bool prescriptionRequired;

  MedicineSearchResult({
    required this.brandName,
    required this.genericName,
    required this.strength,
    required this.medicineType,
    required this.manufacturer,
    required this.usage,
    required this.dosage,
    required this.sideEffects,
    required this.warnings,
    required this.storage,
    required this.prescriptionRequired,
  });

  factory MedicineSearchResult.fromMap(Map<String, dynamic> map) {
    return MedicineSearchResult(
      brandName: map['brand_name'] ?? map['brandName'] ?? '',
      genericName: map['generic_name'] ?? map['genericName'] ?? '',
      strength: map['strength'] ?? '',
      medicineType: map['medicine_type'] ?? map['medicineType'] ?? '',
      manufacturer: map['manufacturer'] ?? '',
      usage: (map['indications_and_usage'] is List)
          ? (map['indications_and_usage'] as List).join(', ')
          : (map['usage'] ?? ''),
      dosage: (map['dosage_and_administration'] is List)
          ? (map['dosage_and_administration'] as List).join(', ')
          : (map['dosage'] ?? ''),
      sideEffects: (map['adverse_reactions'] is List)
          ? List<String>.from(map['adverse_reactions'])
          : (map['sideEffects'] != null ? [map['sideEffects'].toString()] : []),
      warnings: (map['warnings'] is List)
          ? List<String>.from(map['warnings'])
          : (map['warnings'] != null ? [map['warnings'].toString()] : []),
      storage: (map['storage_and_handling'] is List)
          ? (map['storage_and_handling'] as List).join(', ')
          : (map['storage'] ?? ''),
      prescriptionRequired: map['prescription_required'] == true || map['prescriptionRequired'] == 1,
    );
  }
}
