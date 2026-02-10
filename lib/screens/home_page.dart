import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_routes.dart';
import '../data/mock_data.dart';
import '../models/article_summary.dart';
import '../models/event_summary.dart';
import '../providers/cache_providers.dart';
import '../providers/feature_data_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive_image.dart';
import '../widgets/primary_top_bar.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  static const _tabsPreferenceKey = 'home.tabs.v1';
  static const _defaultArticleSlug = 'europe-social-club';

  final List<String> _defaultTabs = const [
    'Today',
    'Lifestyle',
    'Opinion',
    'Sections',
  ];
  final ScrollController _creatorsController = ScrollController();
  final ScrollController _eventsController = ScrollController();

  List<String> _tabs = const ['Today', 'Lifestyle', 'Opinion', 'Sections'];
  int _activeTab = 0;
  int _visibleCreatorCount = 3;
  int _visibleEventCount = 3;
  int _eventTotalForPagination = 0;

  @override
  void initState() {
    super.initState();
    _creatorsController.addListener(_loadMoreCreatorsIfNeeded);
    _eventsController.addListener(_loadMoreEventsIfNeeded);
    _loadSavedTabs();
  }

  @override
  void dispose() {
    _creatorsController
      ..removeListener(_loadMoreCreatorsIfNeeded)
      ..dispose();
    _eventsController
      ..removeListener(_loadMoreEventsIfNeeded)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadSavedTabs() async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    final saved = preferences.getStringList(_tabsPreferenceKey);
    if (!mounted || saved == null || saved.isEmpty) {
      return;
    }
    setState(() {
      _tabs = saved;
      _activeTab = min(_activeTab, _tabs.length - 1);
    });
  }

  Future<void> _saveTabs(List<String> tabs) async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.setStringList(_tabsPreferenceKey, tabs);
  }

  void _loadMoreCreatorsIfNeeded() {
    if (!_creatorsController.hasClients) {
      return;
    }
    final nearEnd = _creatorsController.position.extentAfter < 220;
    if (!nearEnd || _visibleCreatorCount >= HomeMockData.creators.length) {
      return;
    }
    setState(() {
      _visibleCreatorCount = min(
        _visibleCreatorCount + 3,
        HomeMockData.creators.length,
      );
    });
  }

  void _loadMoreEventsIfNeeded() {
    if (!_eventsController.hasClients) {
      return;
    }
    final nearEnd = _eventsController.position.extentAfter < 240;
    if (!nearEnd || _visibleEventCount >= _eventTotalForPagination) {
      return;
    }
    setState(() {
      _visibleEventCount = min(
        _visibleEventCount + 3,
        _eventTotalForPagination,
      );
    });
  }

  void _openArticle(String slug) {
    context.pushNamed(AppRouteName.article, pathParameters: {'slug': slug});
  }

  Future<void> _openTabEditor() async {
    final nextTabs = await showModalBottomSheet<List<String>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final controller = TextEditingController();
        var working = List<String>.from(_tabs);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit tabs',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tab in working)
                        InputChip(
                          label: Text(tab),
                          onDeleted: working.length <= 1
                              ? null
                              : () {
                                  setModalState(() {
                                    working.remove(tab);
                                  });
                                },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            hintText: 'Add tab (e.g. Tech, Sweden)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: () {
                          final value = controller.text.trim();
                          if (value.isEmpty) {
                            return;
                          }
                          final exists = working.any(
                            (item) => item.toLowerCase() == value.toLowerCase(),
                          );
                          if (exists) {
                            return;
                          }
                          setModalState(() {
                            working = [...working, value];
                            controller.clear();
                          });
                        },
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () =>
                            Navigator.of(context).pop(_defaultTabs),
                        child: const Text('Reset'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(working),
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (nextTabs == null || nextTabs.isEmpty) {
      return;
    }

    setState(() {
      _tabs = nextTabs;
      _activeTab = min(_activeTab, _tabs.length - 1);
    });
    await _saveTabs(nextTabs);
  }

  List<ArticleSummary> _articleRows(List<ArticleSummary> stories) {
    if (stories.isNotEmpty) {
      return stories.take(4).toList();
    }
    return const [
      ArticleSummary(
        id: 'fallback-1',
        slug: _defaultArticleSlug,
        title:
            'Is Your Social Life Missing Something? This Conversation Is for You.',
        topic: 'Lifestyle',
        countryCode: 'SE',
        readTimeMinutes: 6,
        publishedAtLabel: 'FEBRUARY 3, 2026',
        isPremium: false,
      ),
      ArticleSummary(
        id: 'fallback-2',
        slug: _defaultArticleSlug,
        title:
            'How Communities Defend Elections Without Waiting for Institutions',
        topic: 'Opinion',
        countryCode: 'DE',
        readTimeMinutes: 7,
        publishedAtLabel: 'FEBRUARY 2, 2026',
        isPremium: true,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final topStories =
        ref.watch(topStoriesProvider).valueOrNull ?? const <ArticleSummary>[];
    final profile = ref.watch(profileProvider).valueOrNull;
    final progression = ref.watch(userProgressionProvider).valueOrNull;
    final perks = ref.watch(userPerksProvider).valueOrNull ?? const [];
    final events =
        ref.watch(eventsProvider).valueOrNull ?? const <EventSummary>[];

    _eventTotalForPagination = events.length;

    final articleRows = _articleRows(topStories);
    final creators = HomeMockData.creators.take(_visibleCreatorCount).toList();
    final visibleEvents = events
        .take(min(_visibleEventCount, events.length))
        .toList();
    final eventsCity = profile?.city ?? 'your city';

    return SafeArea(
      child: Column(
        children: [
          PrimaryTopBar(
            title: 'neuws',
            trailing: [
              IconButton(
                onPressed: () => context.pushNamed(AppRouteName.saved),
                icon: const Icon(Icons.bookmark_border),
                tooltip: 'Saved',
              ),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.search),
                tooltip: 'Search',
              ),
            ],
          ),
          _TopTabs(
            tabs: _tabs,
            activeIndex: _activeTab,
            onTap: (index) => setState(() => _activeTab = index),
            onEditTabs: _openTabEditor,
            onEvents: () => context.pushNamed(AppRouteName.events),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                for (var i = 0; i < articleRows.length; i++)
                  _ArticleListItem(
                    story: articleRows[i],
                    showImage: i % 2 == 0,
                    onTap: () => _openArticle(articleRows[i].slug),
                  ),
                const SizedBox(height: 14),
                const _SectionHeader(
                  title: 'Local voices across the continent',
                  subtitle: 'European people like you',
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 194,
                  child: ScrollConfiguration(
                    behavior: const _HorizontalDragScrollBehavior(),
                    child: ListView.separated(
                      controller: _creatorsController,
                      scrollDirection: Axis.horizontal,
                      itemCount: creators.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) => _CreatorCard(
                        title: creators[index].title,
                        name: creators[index].name,
                        location: creators[index].location,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionHeader(
                  title: 'Collect your daily words',
                  subtitle: 'Build your streak from stories',
                ),
                const SizedBox(height: 12),
                _ProgressSnapshotCard(
                  streakDays:
                      progression?.currentStreakDays ??
                      profile?.streakDays ??
                      0,
                  xp: progression?.totalXp ?? profile?.points ?? 0,
                  level: progression?.level ?? 1,
                  unlockedPerks: perks.length,
                ),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Events in $eventsCity',
                  subtitle: 'Local and Europe-wide meetups',
                ),
                const SizedBox(height: 12),
                if (visibleEvents.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.surfaceCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: palette.border),
                    ),
                    child: Text(
                      'No upcoming events available right now.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: palette.muted),
                    ),
                  )
                else
                  SizedBox(
                    height: 236,
                    child: ScrollConfiguration(
                      behavior: const _HorizontalDragScrollBehavior(),
                      child: ListView.separated(
                        controller: _eventsController,
                        scrollDirection: Axis.horizontal,
                        itemCount: visibleEvents.length,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 12),
                        itemBuilder: (context, index) =>
                            _EventBubbleCard(event: visibleEvents[index]),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopTabs extends StatelessWidget {
  const _TopTabs({
    required this.tabs,
    required this.activeIndex,
    required this.onTap,
    required this.onEditTabs,
    required this.onEvents,
  });

  final List<String> tabs;
  final int activeIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onEditTabs;
  final VoidCallback onEvents;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final isActive = index == activeIndex;
                return GestureDetector(
                  onTap: () => onTap(index),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        tabs[index],
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: isActive
                                  ? Theme.of(context).colorScheme.onSurface
                                  : palette.muted,
                            ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 2,
                        width: 40,
                        color: isActive
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.transparent,
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(width: 18),
              itemCount: tabs.length,
            ),
          ),
          IconButton(
            onPressed: onEditTabs,
            icon: const Icon(Icons.add),
            tooltip: 'Edit tabs',
          ),
          GestureDetector(
            onTap: onEvents,
            child: Padding(
              padding: const EdgeInsets.only(right: 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Events',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: palette.eventsChip,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(height: 2, width: 44, color: palette.eventsChip),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArticleListItem extends StatelessWidget {
  const _ArticleListItem({
    required this.story,
    required this.showImage,
    required this.onTap,
  });

  final ArticleSummary story;
  final bool showImage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final titleColor = Theme.of(context).colorScheme.onSurface;
    final flags = _flagsFromCountryCode(story.countryCode);

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showImage) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.asset(
                      'assets/images/placeholder.jpg',
                      width: 110,
                      height: 86,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            story.topic,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: titleColor,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          for (final flag in flags)
                            Text(
                              flag,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: titleColor),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        story.title,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(height: 1.12),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        story.publishedAtLabel,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: palette.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: palette.border, height: 1),
          ],
        ),
      ),
    );
  }

  List<String> _flagsFromCountryCode(String countryCode) {
    final codeList = countryCode
        .split(',')
        .map((code) => code.trim().toUpperCase())
        .where((code) => code.isNotEmpty)
        .take(3);
    return codeList.map(_flagForCode).where((flag) => flag.isNotEmpty).toList();
  }

  String _flagForCode(String code) {
    switch (code) {
      case 'AT':
        return '🇦🇹';
      case 'DE':
        return '🇩🇪';
      case 'FR':
        return '🇫🇷';
      case 'PT':
        return '🇵🇹';
      case 'SE':
        return '🇸🇪';
      case 'DK':
        return '🇩🇰';
      case 'NO':
        return '🇳🇴';
      case 'LV':
        return '🇱🇻';
      case 'LT':
        return '🇱🇹';
      case 'EE':
        return '🇪🇪';
      case 'PL':
        return '🇵🇱';
      case 'GR':
        return '🇬🇷';
      case 'RO':
        return '🇷🇴';
      case 'BE':
        return '🇧🇪';
      case 'FI':
        return '🇫🇮';
      default:
        return '';
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.muted),
        ),
      ],
    );
  }
}

class _CreatorCard extends StatelessWidget {
  const _CreatorCard({
    required this.title,
    required this.name,
    required this.location,
  });

  final String title;
  final String name;
  final String location;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return Container(
      width: 274,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(height: 1.2, fontSize: 23),
            maxLines: 3,
            overflow: TextOverflow.visible,
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage: const AssetImage(
                  'assets/images/placeholder-user.jpg',
                ),
                backgroundColor: palette.imagePlaceholder,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      location,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: palette.muted),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressSnapshotCard extends StatelessWidget {
  const _ProgressSnapshotCard({
    required this.streakDays,
    required this.xp,
    required this.level,
    required this.unlockedPerks,
  });

  final int streakDays;
  final int xp;
  final int level;
  final int unlockedPerks;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ProgressStat(label: 'Streak', value: '${streakDays}d'),
          ),
          Expanded(
            child: _ProgressStat(label: 'XP', value: '$xp'),
          ),
          Expanded(
            child: _ProgressStat(label: 'Level', value: '$level'),
          ),
          Expanded(
            child: _ProgressStat(label: 'Perks', value: '$unlockedPerks'),
          ),
        ],
      ),
    );
  }
}

class _ProgressStat extends StatelessWidget {
  const _ProgressStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.muted),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _EventBubbleCard extends StatelessWidget {
  const _EventBubbleCard({required this.event});

  final EventSummary event;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return InkWell(
      onTap: () {
        context.pushNamed(
          AppRouteName.eventDetail,
          pathParameters: {'eventId': event.id},
        );
      },
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          color: palette.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: AdaptiveImage(
                source: event.imageAsset,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.tag,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: palette.muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      event.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    Text(
                      event.dateLabel,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: palette.muted),
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

class _HorizontalDragScrollBehavior extends MaterialScrollBehavior {
  const _HorizontalDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.stylus,
  };
}
