class ParseHelpers {
  ParseHelpers._();

  static double parseDouble(dynamic value, {double fallback = 0}) {
    if (value == null) return fallback;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is num) return value.toDouble();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return fallback;
      return double.tryParse(trimmed) ?? fallback;
    }
    return fallback;
  }

  static int parseInt(dynamic value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is num) return value.toInt();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return fallback;
      return int.tryParse(trimmed) ?? double.tryParse(trimmed)?.round() ?? fallback;
    }
    return fallback;
  }

  static List<double> parseDoubleList(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => parseDouble(item)).toList();
  }
}
