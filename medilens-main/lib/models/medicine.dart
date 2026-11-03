class Medicine {
  final String name;
  final String? genericName;
  final String? description;
  final List<String>? uses;
  final String? dosage;
  final List<String>? sideEffects;
  final List<String>? warnings;
  final List<String>? interactions;
  final String? storage;
  final String? manufacturer;
  final String? prescription;

  Medicine({
    required this.name,
    this.genericName,
    this.description,
    this.uses,
    this.dosage,
    this.sideEffects,
    this.warnings,
    this.interactions,
    this.storage,
    this.manufacturer,
    this.prescription,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    // FDA API often nests common info inside 'openfda'
    final openfda = json['openfda'] is Map ? json['openfda'] : {};

    // Helper to safely extract String from potential List/Map
    String? getString(dynamic value) {
      if (value == null) return null;
      if (value is String) return value;
      if (value is List && value.isNotEmpty) return value.first.toString();
      if (value is Map) return value.values.firstOrNull?.toString();
      return value.toString();
    }

    // Helper to safely extract List of Strings
    List<String> getList(dynamic value) {
      if (value == null) return [];
      if (value is List) return value.map((e) => e.toString()).toList();
      if (value is String) return [value];
      return [];
    }

    return Medicine(
      name: getString(json['name']) ?? getString(openfda['brand_name']) ?? 'Unknown',
      genericName: getString(json['generic_name']) ?? getString(openfda['generic_name']),
      description: getString(json['description']) ?? getString(json['indications_and_usage']),
      uses: getList(json['uses'] ?? json['indications_and_usage']),
      dosage: getString(json['dosage'] ?? json['dosage_and_administration']),
      sideEffects: getList(json['side_effects'] ?? json['adverse_reactions']),
      warnings: getList(json['warnings']),
      interactions: getList(json['interactions'] ?? json['drug_interactions']),
      storage: getString(json['storage'] ?? json['storage_and_handling']),
      manufacturer: getString(json['manufacturer'] ?? openfda['manufacturer_name']),
      prescription: getString(json['prescription']),
    );
  }
}
