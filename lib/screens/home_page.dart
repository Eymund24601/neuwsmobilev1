import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/mock_data.dart';
import '../theme/app_theme.dart';
import 'article_page.dart';
import 'events_page.dart';
import 'saved_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _activeTab = 0;

  final List<String> _tabs = const ['Today', 'Lifestyle', 'Opinion', 'Sections'];

  void _openArticle() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ArticlePage(article: HomeMockData.article)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final hero = HomeMockData.hero;
    final listStories = HomeMockData.listStories;
    final creators = HomeMockData.creators;
    final miniGames = HomeMockData.miniGames;
    final learning = HomeMockData.learning;

    return SafeArea(
      child: Column(
        children: [
          _HomeTopBar(
            onBookmark: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SavedPage()),
              );
            },
            onEvents: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EventsPage()),
              );
            },
          ),
          _TopTabs(
            tabs: _tabs,
            activeIndex: _activeTab,
            onTap: (index) => setState(() => _activeTab = index),
            onEvents: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const EventsPage()),
              );
            },
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Text('The Latest', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                _HeroStoryCard(
                  title: hero.title,
                  date: hero.date,
                  byline: hero.byline,
                  imageAsset: hero.imageAsset,
                  onTap: _openArticle,
                ),
                const SizedBox(height: 20),
                _StoryRow(
                  title: listStories[0].title,
                  date: listStories[0].date,
                  onTap: _openArticle,
                ),
                const SizedBox(height: 16),
                _StoryRow(
                  title: listStories[1].title,
                  date: listStories[1].date,
                  onTap: _openArticle,
                ),
                const SizedBox(height: 24),
                const _SectionHeader(
                  title: 'From real people like you',
                  subtitle: 'Local voices across Europe',
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 190,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: creators.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 12),
                    itemBuilder: (context, index) => _CreatorCard(
                      title: creators[index].title,
                      author: creators[index].author,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const _SectionHeader(
                  title: 'Today\'s games',
                  subtitle: '2 free plays - 1 remaining',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MiniGameCard(
                        title: miniGames[0].title,
                        tag: miniGames[0].tag,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MiniGameCard(
                        title: miniGames[1].title,
                        tag: miniGames[1].tag,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _SectionHeader(
                  title: 'Continue learning',
                  subtitle: 'EU Institutions - 52% complete',
                ),
                const SizedBox(height: 12),
                _LearningCard(
                  title: learning.title,
                  subtitle: learning.subtitle,
                  progress: learning.progress,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: palette.surfaceCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Perks & events', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 6),
                            Text(
                              '1 event and 2 perks near you',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: palette.muted,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios, size: 16),
                    ],
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

class _HomeTopBar extends StatelessWidget {
  const _HomeTopBar({required this.onBookmark, required this.onEvents});

  final VoidCallback onBookmark;
  final VoidCallback onEvents;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
      child: Row(
        children: [
          const Spacer(),
          Text(
            'nEUws',
            style: GoogleFonts.libreBaskerville(
              fontSize: 26,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              IconButton(
                onPressed: onBookmark,
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
    required this.onEvents,
  });

  final List<String> tabs;
  final int activeIndex;
  final ValueChanged<int> onTap;
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: isActive ? Theme.of(context).colorScheme.onSurface : palette.muted,
                            ),
                      ),
                      const SizedBox(height: 8),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 2,
                        width: 40,
                        color: isActive ? Theme.of(context).colorScheme.onSurface : Colors.transparent,
                      ),
                    ],
                  ),
                );
              },
              separatorBuilder: (context, index) => const SizedBox(width: 18),
              itemCount: tabs.length,
            ),
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
                  Container(
                    height: 2,
                    width: 44,
                    color: palette.eventsChip,
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

class _HeroStoryCard extends StatelessWidget {
  const _HeroStoryCard({
    required this.title,
    required this.date,
    required this.byline,
    required this.imageAsset,
    required this.onTap,
  });

  final String title;
  final String date;
  final String byline;
  final String imageAsset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surfaceAlt,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    byline.toUpperCase(),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: palette.muted,
                          letterSpacing: 1.1,
                          fontSize: 11,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          height: 1.2,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    date,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.muted,
                          letterSpacing: 1.2,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.asset(
                imageAsset,
                height: 120,
                width: 90,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryRow extends StatelessWidget {
  const _StoryRow({required this.title, required this.date, required this.onTap});

  final String title;
  final String date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surfaceCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          height: 1.2,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    date,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.muted,
                          letterSpacing: 1.1,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 70,
              width: 70,
              decoration: BoxDecoration(
                color: palette.imagePlaceholder,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.image, color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: palette.muted,
                    ),
              ),
            ],
          ),
        ),
        Icon(Icons.arrow_forward_ios, size: 16, color: palette.muted),
      ],
    );
  }
}

class _CreatorCard extends StatelessWidget {
  const _CreatorCard({required this.title, required this.author});

  final String title;
  final String author;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceElevated,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: const AssetImage('assets/images/placeholder-user.jpg'),
            backgroundColor: palette.imagePlaceholder,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.2),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            author,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.muted,
                ),
          ),
        ],
      ),
    );
  }
}

class _MiniGameCard extends StatelessWidget {
  const _MiniGameCard({required this.title, required this.tag});

  final String title;
  final String tag;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tag.toUpperCase(),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.muted,
                  letterSpacing: 1.2,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.1),
          ),
        ],
      ),
    );
  }
}

class _LearningCard extends StatelessWidget {
  const _LearningCard({
    required this.title,
    required this.subtitle,
    required this.progress,
  });

  final String title;
  final String subtitle;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(height: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: palette.muted,
                ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: palette.progressBg,
              valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}
