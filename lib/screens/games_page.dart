import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_routes.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_top_bar.dart';

class GamesPage extends StatelessWidget {
  const GamesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(0, 0, 0, 28),
        children: [
          const PrimaryTopBar(title: 'Puzzles & Quizzes'),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Today's puzzles",
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 22),
                ),
                const SizedBox(height: 16),
                const _PuzzleCard(
                  title: 'Quick crossword',
                  accent: Color(0xFFF29D38),
                  icon: Icons.grid_4x4,
                ),
                const SizedBox(height: 12),
                const _PuzzleCard(
                  title: 'Sudoku (easy)',
                  accent: Color(0xFF6CC4E8),
                  icon: Icons.grid_view,
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  physics: const NeverScrollableScrollPhysics(),
                  children: const [
                    _PuzzleTile(
                      title: 'Word wheel',
                      accent: Color(0xFFEFA1A1),
                      icon: Icons.blur_circular,
                    ),
                    _PuzzleTile(
                      title: 'Wordiply',
                      accent: Color(0xFFD6A3FF),
                      icon: Icons.grid_3x3,
                    ),
                    _PuzzleTile(
                      title: 'On the ball',
                      accent: Color(0xFF9FE0D1),
                      icon: Icons.sports_soccer,
                    ),
                    _PuzzleTile(
                      title: 'Film reveal',
                      accent: Color(0xFFF5C36B),
                      icon: Icons.movie_filter,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: () =>
                      context.pushNamed(AppRouteName.quizCategories),
                  icon: const Icon(Icons.quiz_outlined),
                  label: const Text('Open Quiz Categories'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () {
                    context.pushNamed(
                      AppRouteName.topicFeed,
                      pathParameters: {'topicOrCountryCode': 'Lifestyle'},
                    );
                  },
                  icon: const Icon(Icons.public),
                  label: const Text('Country/Topic Feed Example'),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: palette.surfaceCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: palette.border),
                  ),
                  child: Text(
                    'Daily streaks and premium challenges coming soon.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: palette.muted),
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

class _PuzzleCard extends StatelessWidget {
  const _PuzzleCard({
    required this.title,
    required this.accent,
    required this.icon,
  });

  final String title;
  final Color accent;
  final IconData icon;

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
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(color: accent),
            ),
          ),
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: palette.imagePlaceholder,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 30),
          ),
        ],
      ),
    );
  }
}

class _PuzzleTile extends StatelessWidget {
  const _PuzzleTile({
    required this.title,
    required this.accent,
    required this.icon,
  });

  final String title;
  final Color accent;
  final IconData icon;

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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: accent),
          ),
          const Spacer(),
          Align(
            alignment: Alignment.bottomRight,
            child: Icon(icon, color: accent, size: 34),
          ),
        ],
      ),
    );
  }
}
