import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class WritePage extends StatelessWidget {
  const WritePage({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return Scaffold(
      appBar: AppBar(title: const Text('Write')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'Headline',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Country / topic',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            minLines: 8,
            maxLines: 12,
            decoration: const InputDecoration(
              labelText: 'Story body',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.surfaceCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.border),
            ),
            child: Text(
              'Writing helpers and publish API are planned for Supabase phase.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: palette.muted),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {},
            child: const Text('Save Draft (UI only)'),
          ),
        ],
      ),
    );
  }
}
