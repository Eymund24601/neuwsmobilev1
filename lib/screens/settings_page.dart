import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/feature_data_providers.dart';
import '../theme/app_theme.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text('Could not load settings: $error'),
          ),
        ),
        data: (settings) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            children: [
              Container(
                decoration: BoxDecoration(
                  color: palette.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Reading language'),
                  subtitle: Text(settings.readingLanguage),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: palette.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: SwitchListTile(
                  value: settings.notificationsEnabled,
                  onChanged: (_) {},
                  title: const Text('Notifications'),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: palette.surfaceCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: palette.border),
                ),
                child: SwitchListTile(
                  value: settings.offlineModeEnabled,
                  onChanged: (_) {},
                  title: const Text('Offline mode'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
