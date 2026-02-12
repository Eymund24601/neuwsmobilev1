import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/app_routes.dart';
import '../data/mock_data.dart';
import '../services/polyglot/word_token_utils.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive_image.dart';

class ArticleVocabPair {
  const ArticleVocabPair({
    required this.label,
    required this.topText,
    required this.bottomText,
    this.topStartUtf16,
    this.topEndUtf16,
    this.bottomStartUtf16,
    this.bottomEndUtf16,
    this.statusMessage,
  });

  final String label;
  final String topText;
  final String bottomText;
  final int? topStartUtf16;
  final int? topEndUtf16;
  final int? bottomStartUtf16;
  final int? bottomEndUtf16;
  final String? statusMessage;
}

typedef ArticleTapPairResolver =
    ArticleVocabPair? Function({
      required bool fromTop,
      required String word,
      required int start,
      required int end,
    });

class ArticlePage extends StatefulWidget {
  const ArticlePage({
    super.key,
    required this.article,
    required this.topLanguage,
    required this.bottomLanguage,
    this.languageOptions = const [
      'English',
      'Swedish',
      'French',
      'German',
      'Spanish',
      'Italian',
      'Portuguese',
    ],
    this.onTopLanguageSelected,
    this.onBottomLanguageSelected,
    this.vocabPairs = const [],
    this.onResolveTapPair,
    this.onCollectWords,
  });

  final ArticleContent article;
  final String topLanguage;
  final String bottomLanguage;
  final List<String> languageOptions;
  final ValueChanged<String>? onTopLanguageSelected;
  final ValueChanged<String>? onBottomLanguageSelected;
  final List<ArticleVocabPair> vocabPairs;
  final ArticleTapPairResolver? onResolveTapPair;
  final Future<void> Function()? onCollectWords;

  @override
  State<ArticlePage> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  final ScrollController _controller = ScrollController();
  bool _splitActive = false;
  bool _polyglotEnabled = true;
  bool _collecting = false;
  ArticleVocabPair? _selectedPair;
  String? _tapStatusMessage;
  bool _tapStatusIsError = false;

  void _handleScroll() {
    if (!_polyglotEnabled) {
      if (_splitActive) {
        setState(() => _splitActive = false);
      }
      return;
    }

    final shouldSplit = _controller.offset > 220;
    if (shouldSplit != _splitActive) {
      setState(() => _splitActive = shouldSplit);
    }
  }

  void _togglePolyglot(bool enabled) {
    setState(() {
      _polyglotEnabled = enabled;
      if (!enabled) {
        _splitActive = false;
      }
    });
  }

  void _selectKeyWord(ArticleVocabPair pair) {
    final shouldClear = _samePair(_selectedPair, pair);
    setState(() {
      _selectedPair = shouldClear ? null : pair;
      _tapStatusIsError = false;
      _tapStatusMessage = shouldClear
          ? null
          : 'Selected ${pair.topText} / ${pair.bottomText}.';
    });
  }

  bool _samePair(ArticleVocabPair? a, ArticleVocabPair b) {
    if (a == null) {
      return false;
    }
    return a.topText == b.topText && a.bottomText == b.bottomText;
  }

  _HighlightRange? _rangeFor(int? start, int? end) {
    if (start == null || end == null || end <= start) {
      return null;
    }
    return _HighlightRange(start: start, end: end);
  }

  void _handleWordTap({
    required bool fromTop,
    required String word,
    required int start,
    required int end,
  }) {
    final resolver = widget.onResolveTapPair;
    if (resolver == null) {
      return;
    }
    final resolved = resolver.call(
      fromTop: fromTop,
      word: word,
      start: start,
      end: end,
    );
    if (resolved == null) {
      final cleanWord = PolyglotWordTokenUtils.trimEdgePunctuation(word).trim();
      final displayWord = cleanWord.isEmpty ? word.trim() : cleanWord;
      setState(() {
        _selectedPair = null;
        _tapStatusIsError = true;
        _tapStatusMessage = displayWord.isEmpty
            ? 'No reliable match for this tap.'
            : 'No reliable match for "$displayWord".';
      });
      return;
    }
    setState(() {
      _selectedPair = resolved;
      _tapStatusIsError = false;
      _tapStatusMessage =
          resolved.statusMessage ??
          'Mapped ${resolved.topText} -> ${resolved.bottomText}.';
    });
  }

  Future<void> _collectWords() async {
    if (_collecting || widget.onCollectWords == null) {
      return;
    }

    setState(() => _collecting = true);
    try {
      await widget.onCollectWords!.call();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Words collected and saved to your profile.'),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = '$error';
      if (message.toLowerCase().contains('sign in required')) {
        context.pushNamed(AppRouteName.signIn);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not collect words: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _collecting = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final article = widget.article;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'nEUws',
          style: GoogleFonts.libreBaskerville(fontWeight: FontWeight.w700),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.bookmark_border),
            tooltip: 'Save',
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.send_outlined),
            tooltip: 'Send',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: CustomScrollView(
        controller: _controller,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Text(
                article.title,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: 34,
                  height: 1.1,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: AdaptiveImage(
              source: article.imageAsset,
              height: 250,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Text(
                article.excerpt,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  height: 1.35,
                  color: palette.muted,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GestureDetector(
                          onTap: () {},
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const CircleAvatar(
                                radius: 18,
                                backgroundImage: AssetImage(
                                  'assets/images/placeholder-user.jpg',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    article.authorName,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  Text(
                                    article.authorLocation,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: palette.muted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: palette.surfaceCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: palette.border),
                          ),
                          child: Text(
                            article.topic,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: palette.muted),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      _LanguageSelector(
                        enabled: _polyglotEnabled,
                        topLanguage: widget.topLanguage,
                        bottomLanguage: widget.bottomLanguage,
                        languages: widget.languageOptions,
                        onTopSelected: widget.onTopLanguageSelected,
                        onBottomSelected: widget.onBottomLanguageSelected,
                      ),
                      Switch(
                        value: _polyglotEnabled,
                        onChanged: _togglePolyglot,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
              child: Text(
                article.date,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.muted,
                  letterSpacing: 1.1,
                ),
              ),
            ),
          ),
          if (_tapStatusMessage != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: _tapStatusIsError
                        ? Theme.of(
                            context,
                          ).colorScheme.errorContainer.withValues(alpha: 0.55)
                        : palette.surfaceCard,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _tapStatusIsError
                          ? Theme.of(context).colorScheme.error
                          : palette.border,
                    ),
                  ),
                  child: Text(
                    _tapStatusMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _tapStatusIsError
                          ? Theme.of(context).colorScheme.error
                          : palette.muted,
                    ),
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
              child: _PolyglotReader(
                splitActive: _splitActive,
                polyglotEnabled: _polyglotEnabled,
                bodyTop: article.bodyTop,
                bodyBottom: article.bodyBottom,
                highlightTopTerm: _selectedPair?.topText ?? '',
                highlightBottomTerm: _selectedPair?.bottomText ?? '',
                highlightTopRange: _rangeFor(
                  _selectedPair?.topStartUtf16,
                  _selectedPair?.topEndUtf16,
                ),
                highlightBottomRange: _rangeFor(
                  _selectedPair?.bottomStartUtf16,
                  _selectedPair?.bottomEndUtf16,
                ),
                onTopWordTap: (word, start, end) => _handleWordTap(
                  fromTop: true,
                  word: word,
                  start: start,
                  end: end,
                ),
                onBottomWordTap: (word, start, end) => _handleWordTap(
                  fromTop: false,
                  word: word,
                  start: start,
                  end: end,
                ),
              ),
            ),
          ),
          if (widget.vocabPairs.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Key words',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final pair in widget.vocabPairs)
                          FilterChip(
                            selected: _samePair(_selectedPair, pair),
                            onSelected: (_) => _selectKeyWord(pair),
                            label: Text('${pair.topText} / ${pair.bottomText}'),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: palette.surfaceAlt,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: palette.border),
                      ),
                      child: Row(
                        children: [
                          const CircleAvatar(
                            radius: 16,
                            backgroundImage: AssetImage(
                              'assets/images/placeholder-user.jpg',
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              article.authorName,
                              style: Theme.of(context).textTheme.titleSmall,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () {},
                            child: const Text('Follow'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: widget.onCollectWords == null || _collecting
                        ? null
                        : _collectWords,
                    child: Text(
                      _collecting ? 'Collecting...' : 'Collect Words',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({
    required this.enabled,
    required this.topLanguage,
    required this.bottomLanguage,
    required this.languages,
    required this.onTopSelected,
    required this.onBottomSelected,
  });

  final bool enabled;
  final String topLanguage;
  final String bottomLanguage;
  final List<String> languages;
  final ValueChanged<String>? onTopSelected;
  final ValueChanged<String>? onBottomSelected;

  String _codeFor(String language) {
    final normalized = language.trim().toLowerCase();
    if (normalized.isEmpty) {
      return '--';
    }
    switch (normalized) {
      case 'swedish':
      case 'sv':
        return 'SV';
      case 'english':
      case 'en':
        return 'EN';
      case 'french':
      case 'fr':
        return 'FR';
      case 'german':
      case 'de':
        return 'DE';
      case 'spanish':
      case 'es':
        return 'ES';
      case 'italian':
      case 'it':
        return 'IT';
      case 'portuguese':
      case 'pt':
        return 'PT';
      default:
        return normalized.length < 2
            ? normalized.toUpperCase()
            : normalized.substring(0, 2).toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return Row(
      children: [
        _LanguageFlag(
          label: _codeFor(topLanguage),
          options: languages,
          onSelected: onTopSelected,
          palette: palette,
        ),
        if (enabled) ...[
          const SizedBox(width: 6),
          _LanguageFlag(
            label: _codeFor(bottomLanguage),
            options: languages,
            onSelected: onBottomSelected,
            palette: palette,
          ),
        ],
      ],
    );
  }
}

class _LanguageFlag extends StatelessWidget {
  const _LanguageFlag({
    required this.label,
    required this.options,
    required this.onSelected,
    required this.palette,
  });

  final String label;
  final List<String> options;
  final ValueChanged<String>? onSelected;
  final NeuwsPalette palette;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      enabled: onSelected != null,
      onSelected: onSelected,
      itemBuilder: (context) => options
          .map((option) => PopupMenuItem(value: option, child: Text(option)))
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: palette.border),
          borderRadius: BorderRadius.circular(10),
          color: palette.surfaceCard,
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _PolyglotReader extends StatelessWidget {
  const _PolyglotReader({
    required this.splitActive,
    required this.polyglotEnabled,
    required this.bodyTop,
    required this.bodyBottom,
    required this.highlightTopTerm,
    required this.highlightBottomTerm,
    required this.highlightTopRange,
    required this.highlightBottomRange,
    required this.onTopWordTap,
    required this.onBottomWordTap,
  });

  final bool splitActive;
  final bool polyglotEnabled;
  final String bodyTop;
  final String bodyBottom;
  final String highlightTopTerm;
  final String highlightBottomTerm;
  final _HighlightRange? highlightTopRange;
  final _HighlightRange? highlightBottomRange;
  final void Function(String word, int start, int end)? onTopWordTap;
  final void Function(String word, int start, int end)? onBottomWordTap;

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context);
    final immersiveHeight =
        screen.size.height - kToolbarHeight - screen.padding.top - 8;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      height: polyglotEnabled && splitActive ? immersiveHeight : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SizeTransition(sizeFactor: animation, child: child),
          );
        },
        child: polyglotEnabled
            ? (splitActive
                  ? _SplitReader(
                      key: const ValueKey('split'),
                      bodyTop: bodyTop,
                      bodyBottom: bodyBottom,
                      topHighlightTerm: highlightTopTerm,
                      bottomHighlightTerm: highlightBottomTerm,
                      topHighlightRange: highlightTopRange,
                      bottomHighlightRange: highlightBottomRange,
                      onTopWordTap: onTopWordTap,
                      onBottomWordTap: onBottomWordTap,
                    )
                  : _SingleReader(
                      key: const ValueKey('single'),
                      body: bodyTop,
                      highlightTerm: highlightTopTerm,
                      highlightRange: highlightTopRange,
                      onWordTap: onTopWordTap,
                    ))
            : _SingleReader(
                key: const ValueKey('single-off'),
                body: bodyBottom,
                highlightTerm: highlightBottomTerm,
                highlightRange: highlightBottomRange,
                onWordTap: onBottomWordTap,
              ),
      ),
    );
  }
}

class _SingleReader extends StatelessWidget {
  const _SingleReader({
    super.key,
    required this.body,
    required this.highlightTerm,
    required this.highlightRange,
    required this.onWordTap,
  });

  final String body;
  final String highlightTerm;
  final _HighlightRange? highlightRange;
  final void Function(String word, int start, int end)? onWordTap;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(fontSize: 20, height: 1.62);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _TappableParagraph(
        text: body,
        highlightTerm: highlightTerm,
        highlightRange: highlightRange,
        style: style,
        onWordTap: onWordTap,
      ),
    );
  }
}

class _SplitReader extends StatefulWidget {
  const _SplitReader({
    super.key,
    required this.bodyTop,
    required this.bodyBottom,
    required this.topHighlightTerm,
    required this.bottomHighlightTerm,
    required this.topHighlightRange,
    required this.bottomHighlightRange,
    required this.onTopWordTap,
    required this.onBottomWordTap,
  });

  final String bodyTop;
  final String bodyBottom;
  final String topHighlightTerm;
  final String bottomHighlightTerm;
  final _HighlightRange? topHighlightRange;
  final _HighlightRange? bottomHighlightRange;
  final void Function(String word, int start, int end)? onTopWordTap;
  final void Function(String word, int start, int end)? onBottomWordTap;

  @override
  State<_SplitReader> createState() => _SplitReaderState();
}

class _SplitReaderState extends State<_SplitReader> {
  final ScrollController _topController = ScrollController();
  final ScrollController _bottomController = ScrollController();
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _topController.addListener(
      () => _syncScroll(_topController, _bottomController),
    );
    _bottomController.addListener(
      () => _syncScroll(_bottomController, _topController),
    );
  }

  @override
  void dispose() {
    _topController.dispose();
    _bottomController.dispose();
    super.dispose();
  }

  void _syncScroll(ScrollController from, ScrollController to) {
    if (_syncing || !from.hasClients || !to.hasClients) {
      return;
    }
    final maxFrom = from.position.maxScrollExtent;
    final maxTo = to.position.maxScrollExtent;
    final percent = maxFrom <= 0
        ? 0.0
        : (from.offset / maxFrom).clamp(0.0, 1.0);
    final target = maxTo * percent;

    _syncing = true;
    to.jumpTo(target);
    _syncing = false;
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final style = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(fontSize: 20, height: 1.62);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _topController,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _TappableParagraph(
              text: widget.bodyTop,
              highlightTerm: widget.topHighlightTerm,
              highlightRange: widget.topHighlightRange,
              style: style,
              onWordTap: widget.onTopWordTap,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Divider(color: palette.border, height: 1),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: _bottomController,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: _TappableParagraph(
              text: widget.bodyBottom,
              highlightTerm: widget.bottomHighlightTerm,
              highlightRange: widget.bottomHighlightRange,
              style: style,
              onWordTap: widget.onBottomWordTap,
            ),
          ),
        ),
      ],
    );
  }
}

class _TappableParagraph extends StatefulWidget {
  const _TappableParagraph({
    required this.text,
    required this.highlightTerm,
    required this.highlightRange,
    required this.style,
    required this.onWordTap,
  });

  final String text;
  final String highlightTerm;
  final _HighlightRange? highlightRange;
  final TextStyle? style;
  final void Function(String word, int start, int end)? onWordTap;

  @override
  State<_TappableParagraph> createState() => _TappableParagraphState();
}

class _TappableParagraphState extends State<_TappableParagraph> {
  final GlobalKey _paragraphKey = GlobalKey();

  void _handleTap(TapUpDetails details) {
    final callback = widget.onWordTap;
    if (callback == null || widget.text.isEmpty) {
      return;
    }

    final renderObject = _paragraphKey.currentContext?.findRenderObject();
    if (renderObject is! RenderParagraph) {
      return;
    }

    final localOffset = renderObject.globalToLocal(details.globalPosition);
    final textPosition = renderObject.getPositionForOffset(localOffset);
    final bounds = _wordBoundsAt(widget.text, textPosition.offset);
    if (bounds == null) {
      return;
    }

    final word = widget.text.substring(bounds.start, bounds.end);
    callback(word, bounds.start, bounds.end);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.style == null) {
      return Text(widget.text);
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: widget.onWordTap == null ? null : _handleTap,
      child: RichText(
        key: _paragraphKey,
        text: _buildHighlightedText(
          context,
          text: widget.text,
          highlightTerm: widget.highlightTerm,
          highlightRange: widget.highlightRange,
          style: widget.style!,
        ),
      ),
    );
  }
}

TextSpan _buildHighlightedText(
  BuildContext context, {
  required String text,
  required String highlightTerm,
  required _HighlightRange? highlightRange,
  required TextStyle style,
}) {
  final highlightColor = Theme.of(
    context,
  ).colorScheme.primary.withValues(alpha: 0.2);
  if (highlightRange != null) {
    final start = highlightRange.start.clamp(0, text.length).toInt();
    final end = highlightRange.end.clamp(start, text.length).toInt();
    if (end > start) {
      final spans = <TextSpan>[
        if (start > 0) TextSpan(text: text.substring(0, start), style: style),
        TextSpan(
          text: text.substring(start, end),
          style: style.copyWith(backgroundColor: highlightColor),
        ),
        if (end < text.length)
          TextSpan(text: text.substring(end), style: style),
      ];
      return TextSpan(children: spans);
    }
  }

  if (highlightTerm.trim().isEmpty) {
    return TextSpan(text: text, style: style);
  }

  final expression = RegExp(RegExp.escape(highlightTerm), caseSensitive: false);
  final matches = expression.allMatches(text).toList();
  if (matches.isEmpty) {
    return TextSpan(text: text, style: style);
  }

  final spans = <TextSpan>[];
  var cursor = 0;
  for (final match in matches) {
    if (match.start > cursor) {
      spans.add(
        TextSpan(text: text.substring(cursor, match.start), style: style),
      );
    }
    spans.add(
      TextSpan(
        text: text.substring(match.start, match.end),
        style: style.copyWith(backgroundColor: highlightColor),
      ),
    );
    cursor = match.end;
  }
  if (cursor < text.length) {
    spans.add(TextSpan(text: text.substring(cursor), style: style));
  }

  return TextSpan(children: spans);
}

bool _isWordCharacter(String char) {
  return PolyglotWordTokenUtils.isWordCharacter(char);
}

_WordBounds? _wordBoundsAt(String text, int offset) {
  if (text.isEmpty) {
    return null;
  }
  final safeOffset = offset.clamp(0, text.length - 1);
  var index = safeOffset;

  if (!_isWordCharacter(text[index])) {
    if (index > 0 && _isWordCharacter(text[index - 1])) {
      index--;
    } else if (index + 1 < text.length && _isWordCharacter(text[index + 1])) {
      index++;
    } else {
      return null;
    }
  }

  var start = index;
  while (start > 0 && _isWordCharacter(text[start - 1])) {
    start--;
  }

  var end = index + 1;
  while (end < text.length && _isWordCharacter(text[end])) {
    end++;
  }

  if (start >= end) {
    return null;
  }
  return _WordBounds(start: start, end: end);
}

class _HighlightRange {
  const _HighlightRange({required this.start, required this.end});

  final int start;
  final int end;
}

class _WordBounds {
  const _WordBounds({required this.start, required this.end});

  final int start;
  final int end;
}
