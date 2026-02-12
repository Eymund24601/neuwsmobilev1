class PolyglotWordTokenUtils {
  PolyglotWordTokenUtils._();

  static final RegExp _wordCharacterPattern = RegExp(
    "[\\p{L}\\p{N}'\u2019\\-]",
    unicode: true,
  );
  static final RegExp _nonTokenPattern = RegExp(
    r"[^\p{L}\p{N}]+",
    unicode: true,
  );
  static final RegExp _leadingPunctuationPattern = RegExp(
    r"^[^\p{L}\p{N}]+",
    unicode: true,
  );
  static final RegExp _trailingPunctuationPattern = RegExp(
    r"[^\p{L}\p{N}]+$",
    unicode: true,
  );

  static bool isWordCharacter(String value) {
    if (value.isEmpty) {
      return false;
    }
    return _wordCharacterPattern.hasMatch(value);
  }

  static String normalizeToken(String value) {
    return value.toLowerCase().replaceAll(_nonTokenPattern, '');
  }

  static String trimEdgePunctuation(String value) {
    return value
        .replaceAll(_leadingPunctuationPattern, '')
        .replaceAll(_trailingPunctuationPattern, '');
  }
}
