import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/feature_data_providers.dart';
import '../repositories/settings_repository.dart';
import '../theme/app_theme.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
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
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) =>
                        _save(settings.copyWith(readingLanguage: value)),
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'English', child: Text('English')),
                      PopupMenuItem(value: 'French', child: Text('French')),
                      PopupMenuItem(value: 'German', child: Text('German')),
                      PopupMenuItem(value: 'Swedish', child: Text('Swedish')),
                    ],
                  ),
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
                  onChanged: _saving
                      ? null
                      : (value) {
                          _save(settings.copyWith(notificationsEnabled: value));
                        },
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
                  onChanged: _saving
                      ? null
                      : (value) {
                          _save(settings.copyWith(offlineModeEnabled: value));
                        },
                  title: const Text('Offline mode'),
                ),
              ),
              if (_saving) ...[
                const SizedBox(height: 12),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _save(AppSettings next) async {
    setState(() => _saving = true);
    try {
      await ref.read(settingsProvider.notifier).save(next);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }
}
