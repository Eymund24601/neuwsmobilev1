import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PricingPage extends StatelessWidget {
  const PricingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return Scaffold(
      appBar: AppBar(title: const Text('Premium')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          _TierCard(
            title: 'Free',
            price: 'EUR 0',
            bullets: const [
              '2 deep dives/day',
              '2 games/day',
              'Basic learning tracks',
            ],
            palette: palette,
            isHighlighted: false,
          ),
          const SizedBox(height: 12),
          _TierCard(
            title: 'Premium',
            price: 'EUR 7.99 / month',
            bullets: const [
              'Unlimited deep dives',
              'Unlimited games',
              'Full learning tracks',
              'Priority perks/events',
            ],
            palette: palette,
            isHighlighted: true,
          ),
          const SizedBox(height: 12),
          _TierCard(
            title: 'Creator',
            price: 'Invite / criteria based',
            bullets: const [
              'Publishing tools',
              'Boosted visibility',
              'Better earning tier',
            ],
            palette: palette,
            isHighlighted: false,
          ),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({
    required this.title,
    required this.price,
    required this.bullets,
    required this.palette,
    required this.isHighlighted,
  });

  final String title;
  final String price;
  final List<String> bullets;
  final NeuwsPalette palette;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighlighted ? palette.surfaceAlt : palette.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted
              ? Theme.of(context).colorScheme.primary
              : palette.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            price,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontSize: 28),
          ),
          const SizedBox(height: 12),
          for (final bullet in bullets) ...[
            Row(
              children: [
                const Icon(Icons.check, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(bullet)),
              ],
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () {},
            child: Text(isHighlighted ? 'Upgrade' : 'Select'),
          ),
        ],
      ),
    );
  }
}
