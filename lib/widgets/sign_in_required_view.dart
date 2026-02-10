import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app/app_routes.dart';
import '../theme/app_theme.dart';

class SignInRequiredView extends StatelessWidget {
  const SignInRequiredView({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.pushNamed(AppRouteName.signIn),
              icon: const Icon(Icons.login),
              label: const Text('Open Sign In'),
            ),
            const SizedBox(height: 8),
            Text(
              'Use your Supabase auth user credentials.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}
