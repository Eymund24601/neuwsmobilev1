import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../theme/app_theme.dart';

class ArticlePage extends StatefulWidget {
  const ArticlePage({super.key, required this.article});

  final ArticleContent article;

  @override
  State<ArticlePage> createState() => _ArticlePageState();
}

class _ArticlePageState extends State<ArticlePage> {
  final ScrollController _controller = ScrollController();
  bool _splitActive = false;
  bool _polyglotEnabled = true;
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
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  String _cleanLanguage(String value) {
    return value
        .replaceAll('Learning:', '')
        .replaceAll('Native:', '')
        .trim();
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

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final article = widget.article;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          controller: _controller,
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.bookmark_border),
                      tooltip: 'Save',
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.share_outlined),
                      tooltip: 'Share',
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset(
                        article.imageAsset,
                        height: 210,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      article.title,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontSize: 28,
                            height: 1.15,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: palette.surfaceCard,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: palette.border),
                          ),
                          child: Text(
                            article.topic,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: palette.muted,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () {},
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  article.authorName,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  article.authorLocation,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: palette.muted,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 10),
                            const CircleAvatar(
                              radius: 18,
                              backgroundImage: AssetImage('assets/images/placeholder-user.jpg'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Row(
                          children: [
                            _IconAction(icon: Icons.chat_bubble_outline, onTap: () {}),
                            _IconAction(icon: Icons.send_outlined, onTap: () {}),
                            _IconAction(icon: Icons.bookmark_border, onTap: () {}),
                          ],
                        ),
                        const Spacer(),
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
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                child: _PolyglotReader(
                  splitActive: _splitActive,
                  polyglotEnabled: _polyglotEnabled,
                  labelTop: article.date,
                  labelBottom: _polyglotEnabled ? '' : article.date,
                  bodyTop: article.bodyTop,
                  bodyBottom: article.bodyBottom,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Up next', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: palette.surfaceAlt,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Play today\'s quick crossword based on this story',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.2),
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Icon(icon, size: 20),
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
          value: topLanguage,
          options: languages,
          onSelected: onTopSelected,
          palette: palette,
        ),
        if (enabled) ...[
          const SizedBox(width: 6),
          _LanguageFlag(
            label: _codeFor(bottomLanguage),
            value: bottomLanguage,
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
    required this.value,
    required this.options,
    required this.onSelected,
    required this.palette,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onSelected;
  final NeuwsPalette palette;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (context) => options
          .map(
            (option) => PopupMenuItem(
              value: option,
              child: Text(option),
            ),
          )
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
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ),
    );
  }
}

class _PolyglotReader extends StatelessWidget {
  const _PolyglotReader({
    required this.splitActive,
    required this.polyglotEnabled,
    required this.labelTop,
    required this.labelBottom,
    required this.bodyTop,
    required this.bodyBottom,
  });

  final bool splitActive;
  final bool polyglotEnabled;
  final String labelTop;
  final String labelBottom;
  final String bodyTop;
  final String bodyBottom;

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.65;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      height: polyglotEnabled ? height : null,
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
                    labelTop: labelTop,
                    labelBottom: labelBottom,
                    bodyTop: bodyTop,
                    bodyBottom: bodyBottom,
                  )
                : _SingleReader(
                    key: const ValueKey('single'),
                    label: labelTop,
                    body: bodyTop,
                  ))
            : _SingleReader(
                key: const ValueKey('single-off'),
                label: labelTop,
                body: bodyBottom,
              ),
      ),
    );
  }
}

class _SingleReader extends StatelessWidget {
  const _SingleReader({super.key, required this.label, required this.body});

  final String label;
  final String body;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          body,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
        ),
      ],
    );
  }
}

class _SplitReader extends StatefulWidget {
  const _SplitReader({
    super.key,
    required this.labelTop,
    required this.labelBottom,
    required this.bodyTop,
    required this.bodyBottom,
  });

  final String labelTop;
  final String labelBottom;
  final String bodyTop;
  final String bodyBottom;

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
    _topController.addListener(() => _syncScroll(_topController, _bottomController));
    _bottomController.addListener(() => _syncScroll(_bottomController, _topController));
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
    final percent = maxFrom <= 0 ? 0.0 : (from.offset / maxFrom).clamp(0.0, 1.0);
    final target = maxTo * percent;

    _syncing = true;
    to.jumpTo(target);
    _syncing = false;
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    // TODO: Map word pairs across languages and highlight both on tap.
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            controller: _topController,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.labelTop.isNotEmpty) ...[
                  Text(
                    widget.labelTop,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.muted),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  widget.bodyTop,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
                ),
              ],
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.labelBottom.isNotEmpty) ...[
                  Text(
                    widget.labelBottom,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.muted),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  widget.bodyBottom,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.55),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
