class SupabaseMappingUtils {
  SupabaseMappingUtils._();

  static String stringValue(
    Map<String, dynamic> row,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final value = row[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return fallback;
  }

  static int intValue(
    Map<String, dynamic> row,
    List<String> keys, {
    int fallback = 0,
  }) {
    for (final key in keys) {
      final value = row[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return fallback;
  }

  static bool boolValue(
    Map<String, dynamic> row,
    List<String> keys, {
    bool fallback = false,
  }) {
    for (final key in keys) {
      final value = row[key];
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String) {
        if (value.toLowerCase() == 'true') {
          return true;
        }
        if (value.toLowerCase() == 'false') {
          return false;
        }
      }
    }
    return fallback;
  }

  static DateTime? dateTimeValue(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  static String upperDateLabel(DateTime? value, {String fallback = ''}) {
    if (value == null) {
      return fallback;
    }
    const months = [
      'JANUARY',
      'FEBRUARY',
      'MARCH',
      'APRIL',
      'MAY',
      'JUNE',
      'JULY',
      'AUGUST',
      'SEPTEMBER',
      'OCTOBER',
      'NOVEMBER',
      'DECEMBER',
    ];
    final month = months[value.month - 1];
    return '$month ${value.day}, ${value.year}';
  }
}
