import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return SafeArea(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title, style: Theme.of(context).textTheme.displayMedium),
            const SizedBox(height: 12),
            Text(
              'Coming soon',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: palette.muted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
