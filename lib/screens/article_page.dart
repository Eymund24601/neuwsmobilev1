import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/app_routes.dart';
import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive_image.dart';

class ArticleVocabPair {
  const ArticleVocabPair({
    required this.label,
    required this.topText,
    required this.bottomText,
  });

  final String label;
  final String topText;
  final String bottomText;
}

class ArticlePage extends StatefulWidget {
  const ArticlePage({
    super.key,
    required this.article,
    this.vocabPairs = const [],
    this.onCollectWords,
  });

  final ArticleContent article;
  final List<ArticleVocabPair> vocabPairs;
  final Future<void> Function()? onCollectWords;

  @override
  State<ArticlePage> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  final ScrollController _controller = ScrollController();
  bool _splitActive = false;
  bool _polyglotEnabled = true;
  bool _collecting = false;
  int? _selectedPairIndex;
  late String _languageTop;
  late String _languageBottom;

  final List<String> _languages = const [
    'English',
    'Swedish',
    'French',
    'German',
    'Spanish',
    'Italian',
    'Portuguese',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleScroll);
    _languageTop = _cleanLanguage(widget.article.languageTop);
    _languageBottom = _cleanLanguage(widget.article.languageBottom);
    _selectedPairIndex = widget.vocabPairs.isEmpty ? null : 0;
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  String _cleanLanguage(String value) {
    return value.replaceAll('Learning:', '').replaceAll('Native:', '').trim();
  }

  ArticleVocabPair? get _selectedPair {
    final index = _selectedPairIndex;
    if (index == null || index < 0 || index >= widget.vocabPairs.length) {
      return null;
    }
    return widget.vocabPairs[index];
  }

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

  void _setTopLanguage(String value) {
    setState(() => _languageTop = value);
  }

  void _setBottomLanguage(String value) {
    setState(() => _languageBottom = value);
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
                        topLanguage: _languageTop,
                        bottomLanguage: _languageBottom,
                        languages: _languages,
                        onTopSelected: _setTopLanguage,
                        onBottomSelected: _setBottomLanguage,
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
          if (widget.vocabPairs.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < widget.vocabPairs.length; i++)
                      FilterChip(
                        selected: _selectedPairIndex == i,
                        onSelected: (selected) {
                          setState(() {
                            _selectedPairIndex = selected ? i : null;
                          });
                        },
                        label: Text(widget.vocabPairs[i].label),
                      ),
                  ],
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
  final ValueChanged<String> onTopSelected;
  final ValueChanged<String> onBottomSelected;

  String _codeFor(String language) {
    switch (language.toLowerCase()) {
      case 'swedish':
        return 'SE';
      case 'english':
        return 'EN';
      case 'french':
        return 'FR';
      case 'german':
        return 'DE';
      case 'spanish':
        return 'ES';
      case 'italian':
        return 'IT';
      case 'portuguese':
        return 'PT';
      default:
        return language.substring(0, 2).toUpperCase();
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
  final ValueChanged<String> onSelected;
  final NeuwsPalette palette;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
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
  });

  final bool splitActive;
  final bool polyglotEnabled;
  final String bodyTop;
  final String bodyBottom;
  final String highlightTopTerm;
  final String highlightBottomTerm;

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
                    )
                  : _SingleReader(
                      key: const ValueKey('single'),
                      body: bodyTop,
                      highlightTerm: highlightTopTerm,
                    ))
            : _SingleReader(
                key: const ValueKey('single-off'),
                body: bodyBottom,
                highlightTerm: highlightBottomTerm,
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
  });

  final String body;
  final String highlightTerm;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(
      context,
    ).textTheme.bodyLarge?.copyWith(fontSize: 20, height: 1.62);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _buildHighlightedParagraph(
        context,
        text: body,
        highlightTerm: highlightTerm,
        style: style,
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
  });

  final String bodyTop;
  final String bodyBottom;
  final String topHighlightTerm;
  final String bottomHighlightTerm;

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
            child: _buildHighlightedParagraph(
              context,
              text: widget.bodyTop,
              highlightTerm: widget.topHighlightTerm,
              style: style,
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
            child: _buildHighlightedParagraph(
              context,
              text: widget.bodyBottom,
              highlightTerm: widget.bottomHighlightTerm,
              style: style,
            ),
          ),
        ),
      ],
    );
  }
}

Widget _buildHighlightedParagraph(
  BuildContext context, {
  required String text,
  required String highlightTerm,
  required TextStyle? style,
}) {
  if (highlightTerm.trim().isEmpty || style == null) {
    return Text(text, style: style);
  }

  final expression = RegExp(RegExp.escape(highlightTerm), caseSensitive: false);
  final matches = expression.allMatches(text).toList();
  if (matches.isEmpty) {
    return Text(text, style: style);
  }

  final highlightColor = Theme.of(
    context,
  ).colorScheme.primary.withValues(alpha: 0.2);
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

  return RichText(text: TextSpan(children: spans));
}
