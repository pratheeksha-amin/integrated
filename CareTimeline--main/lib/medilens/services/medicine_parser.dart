class MedicineParser {
  static List<String> getSearchCandidates(String text) {
    if (text.isEmpty) return [];

    List<String> lines = text.split('\n');
    List<String> candidates = [];
    
    for (String line in lines) {
      String cleaned = _cleanLine(line);
      
      if (cleaned.isEmpty || cleaned.length < 3) continue;

      if (cleaned.toLowerCase().contains("batch") ||
          cleaned.toLowerCase().contains("expiry") ||
          cleaned.toLowerCase().contains("mfg") ||
          cleaned.toLowerCase().contains("exp date") ||
          cleaned.toLowerCase().contains("price") ||
          cleaned.toLowerCase().contains("tax")) {
        continue;
      }

      candidates.add(cleaned);
      
      List<String> words = cleaned.split(' ');
      if (words.length > 1) {
        for (String word in words) {
          if (word.length > 3) {
            candidates.add(word);
          }
        }
      }
    }

    return candidates.toSet().toList();
  }

  static String extractMedicineName(String text) {
    final candidates = getSearchCandidates(text);
    return candidates.isNotEmpty ? candidates.first : "Unknown Medicine";
  }

  static String _cleanLine(String line) {
    String cleaned = line.replaceAll(RegExp(r'\d+\s*(mg|ml|g|mcg|tablet|capsule|tab|cap)s?\b', caseSensitive: false), '');
    cleaned = cleaned.replaceAll(RegExp(r'[^a-zA-Z0-9\s\-]'), '');
    cleaned = cleaned.trim().replaceAll(RegExp(r'\s+'), ' ');
    return cleaned;
  }
}
