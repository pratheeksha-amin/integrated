import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:care_timeline/medilens/models/language.dart';
import 'package:care_timeline/medilens/models/medicine_search_result.dart';
import 'package:care_timeline/medilens/services/medicine_parser.dart';
import 'package:care_timeline/medilens/features/language_screen.dart';

void main() {
  group('MediLens Integration Tests', () {
    test('Supported Languages list includes all 6 required languages', () {
      expect(languages.length, 6);
      final codes = languages.map((l) => l.code).toList();
      expect(codes, containsAll(['en', 'hi', 'kn', 'ta', 'te', 'ml']));
    });

    test('MedicineParser cleans lines and extracts candidates from OCR text', () {
      const ocrText = '''
BATCH NO: B12345
PARACETAMOL 500mg TABLET
EXP DATE: 12/2028
MFG: Sun Pharma
''';
      final candidates = MedicineParser.getSearchCandidates(ocrText);
      expect(candidates, contains('PARACETAMOL TABLET'));
      expect(candidates, contains('PARACETAMOL'));
      expect(candidates, isNot(contains('BATCH NO')));
      expect(candidates, isNot(contains('EXP DATE')));
    });

    test('MedicineSearchResult parses fields correctly from map', () {
      final map = {
        'brand_name': 'Paracetamol 500',
        'generic_name': 'Acetaminophen',
        'strength': '500 mg',
        'medicine_type': 'Tablet',
        'manufacturer': 'PharmaCorp',
        'indications_and_usage': ['Relief of mild to moderate pain', 'Fever reduction'],
        'dosage_and_administration': ['1 tablet every 4 to 6 hours'],
        'adverse_reactions': ['Nausea', 'Rash'],
        'warnings': ['Do not exceed 4000mg in 24 hours'],
        'storage_and_handling': ['Store below 25C'],
        'prescription_required': false,
      };

      final result = MedicineSearchResult.fromMap(map);
      expect(result.brandName, 'Paracetamol 500');
      expect(result.genericName, 'Acetaminophen');
      expect(result.prescriptionRequired, false);
      expect(result.sideEffects, contains('Nausea'));
    });
  });
}
