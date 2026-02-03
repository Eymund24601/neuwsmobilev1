import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/theme_controller.dart';

class YouPage extends StatelessWidget {
  const YouPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundImage: AssetImage('assets/images/placeholder-user.jpg'),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Marta Keller', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Vienna, Austria - Premium',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: palette.muted,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _ProfileStatCard(
            title: 'Reading streak',
            value: '12 days',
            subtitle: 'Keep it going for a bonus badge.',
          ),
          const SizedBox(height: 12),
          const _ProfileStatCard(
            title: 'Learning points',
            value: '1,240 XP',
            subtitle: 'You are in the top 18% this week.',
          ),
          const SizedBox(height: 12),
          const _ProfileStatCard(
            title: 'Saved stories',
            value: '28',
            subtitle: 'Across 5 custom folders.',
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: palette.surfaceCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.border),
            ),
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: ThemeController.mode,
              builder: (context, mode, child) {
                return SwitchListTile(
                  value: mode == ThemeMode.dark,
                  onChanged: ThemeController.setDarkMode,
                  title: const Text('Dark mode'),
                  subtitle: Text(
                    'Switch between light and dark themes',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.muted),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final String title;
  final String value;
  final String subtitle;

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
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
        ],
      ),
    );
  }
}
