import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PerksPage extends StatelessWidget {
  const PerksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return Scaffold(
      appBar: AppBar(title: const Text('Perks')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _PerkCard(
            title: 'Nordic Rail 20% Off',
            subtitle: 'Travel',
            code: 'NEUWS20',
            palette: palette,
          ),
          const SizedBox(height: 12),
          _PerkCard(
            title: 'Berlin Coffee Pass',
            subtitle: 'Food',
            code: 'EUROPEBREW',
            palette: palette,
          ),
          const SizedBox(height: 12),
          _PerkCard(
            title: 'Premium Creator Tools',
            subtitle: 'SaaS',
            code: 'CREATOR30',
            palette: palette,
          ),
        ],
      ),
    );
  }
}

class _PerkCard extends StatelessWidget {
  const _PerkCard({
    required this.title,
    required this.subtitle,
    required this.code,
    required this.palette,
  });

  final String title;
  final String subtitle;
  final String code;
  final NeuwsPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            subtitle,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 6),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Code: $code', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
