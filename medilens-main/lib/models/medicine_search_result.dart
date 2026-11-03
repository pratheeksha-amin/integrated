class MedicineSearchResult {
  final String genericName;
  final String brandName;
  final String manufacturer;

  MedicineSearchResult({
    required this.genericName,
    required this.brandName,
    required this.manufacturer,
  });

  factory MedicineSearchResult.fromJson(Map<String, dynamic> json) {
    final openfda = json["openfda"] ?? {};

    String getString(dynamic value) {
      if (value == null) return "";
      if (value is String) return value;
      if (value is List && value.isNotEmpty) return value.first.toString();
      return "";
    }

    return MedicineSearchResult(
      genericName: getString(openfda["generic_name"]),
      brandName: getString(openfda["brand_name"]),
      manufacturer: getString(openfda["manufacturer_name"]),
    );
  }
}
