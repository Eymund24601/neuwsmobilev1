import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/repository_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/sign_in_required_view.dart';

class WritePage extends ConsumerStatefulWidget {
  const WritePage({super.key});

  @override
  ConsumerState<WritePage> createState() => _WritePageState();
}

class _WritePageState extends ConsumerState<WritePage> {
  final _headlineController = TextEditingController();
  final _topicController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _headlineController.dispose();
    _topicController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    final headline = _headlineController.text.trim();
    final topic = _topicController.text.trim();
    final body = _bodyController.text.trim();
    if (headline.isEmpty || topic.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Headline, topic, and story body are required.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(creatorRepositoryProvider)
          .saveDraft(headline: headline, topic: topic, body: body);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Draft saved to backend.')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not save draft: $error')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final hasSession = ref.watch(hasSupabaseSessionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Write')),
      body: !hasSession
          ? const SignInRequiredView(
              message: 'Sign in is required to write and save drafts.',
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                TextField(
                  controller: _headlineController,
                  decoration: const InputDecoration(
                    labelText: 'Headline',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _topicController,
                  decoration: const InputDecoration(
                    labelText: 'Country / topic',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _bodyController,
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
                    'Draft saves now persist to Supabase when a session is available.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: palette.muted),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _saving ? null : _saveDraft,
                  child: Text(_saving ? 'Saving...' : 'Save Draft'),
                ),
              ],
            ),
    );
  }
}
