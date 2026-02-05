class ArticleConversionUtils {
  ArticleConversionUtils._();

  static String slugifyTitle(String title, {DateTime? now}) {
    final normalized = title
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
    final clean = normalized.replaceAll(RegExp(r'^-|-$'), '');
    final stamp = (now ?? DateTime.now()).millisecondsSinceEpoch;
    if (clean.isEmpty) {
      return 'article-$stamp';
    }
    return '$clean-$stamp';
  }

  static String buildExcerpt(String content, {int maxChars = 200}) {
    final compact = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= maxChars) {
      return compact;
    }
    return '${compact.substring(0, maxChars).trimRight()}...';
  }

  static int estimateReadTimeMinutes(
    String content, {
    int wordsPerMinute = 200,
  }) {
    final text = content.trim();
    if (text.isEmpty) {
      return 1;
    }
    final words = text.split(RegExp(r'\s+')).length;
    final minutes = (words / wordsPerMinute).ceil();
    return minutes < 1 ? 1 : minutes;
  }
}
