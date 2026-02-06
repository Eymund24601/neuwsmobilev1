import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/app_routes.dart';
import '../models/community_models.dart';
import '../models/user_profile.dart';
import '../providers/cache_providers.dart';
import '../providers/feature_data_providers.dart';
import '../theme/app_theme.dart';

class YouPage extends ConsumerStatefulWidget {
  const YouPage({super.key});

  @override
  ConsumerState<YouPage> createState() => _YouPageState();
}

class _YouPageState extends ConsumerState<YouPage> {
  int _activeTab = 0;
  String? _selectedAvatar;
  String? _selectedWallpaper;
  static const _avatarKey = 'you.avatar.v1';
  static const _wallpaperKey = 'you.wallpaper.v1';

  static const _tabLabels = [
    'Articles',
    'Reposted',
    'Official Collections',
    'Favourite Authors',
  ];

  static const _avatarChoices = [
    'assets/images/placeholder-user.jpg',
    'assets/images/placeholder-logo.png',
    'assets/images/placeholder.jpg',
  ];

  static const _wallpaperChoices = [
    'assets/images/placeholder.jpg',
    'assets/images/placeholder-logo.png',
    'assets/images/placeholder-user.jpg',
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedVisuals();
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return SafeArea(
      child: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Could not load profile: $error'),
          ),
        ),
        data: (profile) {
          final progression = ref.watch(userProgressionProvider).valueOrNull;
          final avatar = _selectedAvatar ?? profile.avatarAsset;
          final wallpaper = _selectedWallpaper ?? profile.wallpaperAsset;

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _ProfileHeader(
                profile: profile,
                progression: progression,
                avatarAsset: avatar,
                wallpaperAsset: wallpaper,
                onPickAvatar: () => _openPicker(
                  context,
                  title: 'Choose profile picture',
                  options: _avatarChoices,
                  onSelected: _setAvatar,
                ),
                onPickWallpaper: () => _openPicker(
                  context,
                  title: 'Choose wallpaper',
                  options: _wallpaperChoices,
                  onSelected: _setWallpaper,
                ),
              ),
              const SizedBox(height: 14),
              _TabBarRow(
                tabs: _tabLabels,
                activeIndex: _activeTab,
                onTap: (index) => setState(() => _activeTab = index),
              ),
              _TabContent(activeTab: _activeTab),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openPicker(
    BuildContext context, {
    required String title,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) async {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: options.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    return InkWell(
                      onTap: () => Navigator.of(context).pop(option),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 130,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: palette.border),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(option, fit: BoxFit.cover),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (picked != null) {
      onSelected(picked);
    }
  }

  Future<void> _loadSavedVisuals() async {
    final preferences = await ref.read(sharedPreferencesProvider.future);
    final avatar = preferences.getString(_avatarKey);
    final wallpaper = preferences.getString(_wallpaperKey);
    if (!mounted) {
      return;
    }
    setState(() {
      _selectedAvatar = avatar;
      _selectedWallpaper = wallpaper;
    });
  }

  Future<void> _setAvatar(String value) async {
    setState(() => _selectedAvatar = value);
    final preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.setString(_avatarKey, value);
  }

  Future<void> _setWallpaper(String value) async {
    setState(() => _selectedWallpaper = value);
    final preferences = await ref.read(sharedPreferencesProvider.future);
    await preferences.setString(_wallpaperKey, value);
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.profile,
    required this.progression,
    required this.avatarAsset,
    required this.wallpaperAsset,
    required this.onPickAvatar,
    required this.onPickWallpaper,
  });

  final UserProfile profile;
  final UserProgressionSummary? progression;
  final String avatarAsset;
  final String wallpaperAsset;
  final VoidCallback onPickAvatar;
  final VoidCallback onPickWallpaper;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: 200,
              width: double.infinity,
              child: Image.asset(wallpaperAsset, fit: BoxFit.cover),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: FilledButton.tonalIcon(
                onPressed: onPickWallpaper,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit'),
              ),
            ),
            Positioned(
              left: 16,
              bottom: -48,
              child: Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).scaffoldBackgroundColor,
                    ),
                    child: CircleAvatar(
                      radius: 54,
                      backgroundImage: AssetImage(avatarAsset),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 62, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName,
                style: Theme.of(
                  context,
                ).textTheme.displayMedium?.copyWith(fontSize: 34),
              ),
              const SizedBox(height: 2),
              Text(
                '@${profile.username}',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: palette.muted),
              ),
              const SizedBox(height: 12),
              Text(
                profile.bio,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.4, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  _MetaItem(
                    icon: Icons.location_on_outlined,
                    label: '${profile.city}, ${profile.countryCode}',
                  ),
                  if (profile.showAgePublic)
                    _MetaItem(
                      icon: Icons.cake_outlined,
                      label: '${profile.age} years old',
                    ),
                  _MetaItem(
                    icon: Icons.event_outlined,
                    label: profile.joinedLabel,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    _flagsFromCodes(profile.nationalityCodes),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${profile.following} Following',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '${profile.followers} Followers',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatChip(
                    label: 'XP',
                    value: '${progression?.totalXp ?? profile.points}',
                  ),
                  _StatChip(
                    label: 'Level',
                    value: '${progression?.level ?? 1}',
                  ),
                  _StatChip(
                    label: 'Streak',
                    value:
                        '${progression?.currentStreakDays ?? profile.streakDays}d',
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _flagsFromCodes(List<String> codes) {
    return codes.map(_flagForCode).where((flag) => flag.isNotEmpty).join(' ');
  }

  String _flagForCode(String code) {
    switch (code.toUpperCase()) {
      case 'AT':
        return '\uD83C\uDDE6\uD83C\uDDF9';
      case 'DE':
        return '\uD83C\uDDE9\uD83C\uDDEA';
      case 'SE':
        return '\uD83C\uDDF8\uD83C\uDDEA';
      case 'DK':
        return '\uD83C\uDDE9\uD83C\uDDF0';
      case 'NO':
        return '\uD83C\uDDF3\uD83C\uDDF4';
      case 'FR':
        return '\uD83C\uDDEB\uD83C\uDDF7';
      case 'PT':
        return '\uD83C\uDDF5\uD83C\uDDF9';
      case 'ES':
        return '\uD83C\uDDEA\uD83C\uDDF8';
      case 'IT':
        return '\uD83C\uDDEE\uD83C\uDDF9';
      default:
        return '';
    }
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: palette.muted),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: palette.muted, fontSize: 15),
        ),
      ],
    );
  }
}

class _TabBarRow extends StatelessWidget {
  const _TabBarRow({
    required this.tabs,
    required this.activeIndex,
    required this.onTap,
  });

  final List<String> tabs;
  final int activeIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return Column(
      children: [
        SizedBox(
          height: 48,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            scrollDirection: Axis.horizontal,
            itemCount: tabs.length,
            separatorBuilder: (context, index) => const SizedBox(width: 18),
            itemBuilder: (context, index) {
              final active = index == activeIndex;
              return InkWell(
                onTap: () => onTap(index),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      tabs[index],
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: active
                            ? Theme.of(context).colorScheme.onSurface
                            : palette.muted,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      height: 3,
                      width: 74,
                      color: active
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        Divider(color: palette.border, height: 1),
      ],
    );
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({required this.activeTab});

  final int activeTab;

  @override
  Widget build(BuildContext context) {
    switch (activeTab) {
      case 0:
        return const _ArticlesTab();
      case 1:
        return const _RepostedTab();
      case 2:
        return const _CollectionsTab();
      default:
        return const _FavouriteAuthorsTab();
    }
  }
}

class _ArticlesTab extends ConsumerWidget {
  const _ArticlesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articles = ref.watch(topStoriesProvider).valueOrNull ?? const [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      child: Column(
        children: [
          for (final article in articles.take(6))
            _FeedRowItem(
              title: article.title,
              topic: article.topic,
              date: article.publishedAtLabel,
              slug: article.slug,
              showImage: articles.indexOf(article).isEven,
            ),
        ],
      ),
    );
  }
}

class _RepostedTab extends ConsumerWidget {
  const _RepostedTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reposted =
        ref.watch(repostedArticlesProvider).valueOrNull ?? const [];
    if (reposted.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 24, 16, 28),
        child: Text('No reposted stories yet.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      child: Column(
        children: [
          for (final item in reposted)
            _FeedRowItem(
              title: item.title,
              topic: item.sourceLabel,
              date: 'Reposted',
              slug: item.slug,
              showImage: reposted.indexOf(item).isEven,
            ),
        ],
      ),
    );
  }
}

class _CollectionsTab extends ConsumerWidget {
  const _CollectionsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final collections =
        ref.watch(userCollectionsProvider).valueOrNull ?? const [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Shared folders from saved articles',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 10),
          if (collections.isEmpty)
            Text(
              'No collections yet.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.muted),
            ),
          for (final collection in collections)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.surfaceCard,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_open_outlined),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          collection.name,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${collection.itemCount} saved articles',
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: palette.muted),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () {},
                    child: Text(collection.isPublic ? 'Public' : 'Private'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FavouriteAuthorsTab extends ConsumerWidget {
  const _FavouriteAuthorsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final authors = ref.watch(messageContactsProvider).valueOrNull ?? const [];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Up to 6 profiles recommended to your followers',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 10),
          if (authors.isEmpty)
            Text(
              'No connected authors yet.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.muted),
            ),
          GridView.builder(
            itemCount: authors.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.35,
            ),
            itemBuilder: (context, index) {
              final author = authors[index];
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: palette.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundImage: AssetImage(
                        'assets/images/placeholder-user.jpg',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      author.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      author.relation,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: palette.muted),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _FeedRowItem extends StatelessWidget {
  const _FeedRowItem({
    required this.title,
    required this.topic,
    required this.date,
    required this.showImage,
    this.slug = '',
  });

  final String title;
  final String topic;
  final String date;
  final bool showImage;
  final String slug;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final titleColor = Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: slug.isEmpty
          ? null
          : () {
              context.pushNamed(
                AppRouteName.article,
                pathParameters: {'slug': slug},
              );
            },
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
                      Text(
                        topic,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: titleColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(height: 1.12),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        date,
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
}
