class MedicineParser {
  static List<String> getSearchCandidates(String text) {
    if (text.isEmpty) return [];

    List<String> lines = text.split('\n');
    List<String> candidates = [];
    
    for (String line in lines) {
      String cleaned = _cleanLine(line);
      
      if (cleaned.isEmpty || cleaned.length < 3) continue;

      // Ignore lines that are definitely not medicine names
      if (cleaned.toLowerCase().contains("batch") ||
          cleaned.toLowerCase().contains("expiry") ||
          cleaned.toLowerCase().contains("mfg") ||
          cleaned.toLowerCase().contains("exp date") ||
          cleaned.toLowerCase().contains("price") ||
          cleaned.toLowerCase().contains("tax")) {
        continue;
      }

      candidates.add(cleaned);
      
      // Also split the line by spaces to get individual words as candidates
      List<String> words = cleaned.split(' ');
      if (words.length > 1) {
        for (String word in words) {
          if (word.length > 3) {
            candidates.add(word);
          }
        }
      }
    }

    // Remove duplicates while preserving order
    return candidates.toSet().toList();
  }

  /// Legacy support for single string extraction
  static String extractMedicineName(String text) {
    final candidates = getSearchCandidates(text);
    return candidates.isNotEmpty ? candidates.first : "Unknown Medicine";
  }

  static String _cleanLine(String line) {
    // Remove common dosage and quantity patterns
    String cleaned = line.replaceAll(RegExp(r'\d+\s*(mg|ml|g|mcg|tablet|capsule|tab|cap)s?\b', caseSensitive: false), '');
    
    // Remove special characters except spaces and hyphens
    cleaned = cleaned.replaceAll(RegExp(r'[^a-zA-Z0-9\s\-]'), '');
    
    // Remove extra whitespace
    cleaned = cleaned.trim().replaceAll(RegExp(r'\s+'), ' ');
    
    return cleaned;
  }
}
