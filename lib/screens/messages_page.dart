import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/app_routes.dart';
import '../models/community_models.dart';
import '../providers/feature_data_providers.dart';
import '../providers/repository_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_top_bar.dart';
import '../widgets/sign_in_required_view.dart';
import '../widgets/adaptive_image.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  String _query = '';
  final _client = Supabase.instance.client;
  RealtimeChannel? _inboxChannel;
  Timer? _realtimeDebounce;
  StreamSubscription<AuthState>? _authStateSubscription;

  @override
  void initState() {
    super.initState();
    _authStateSubscription = _client.auth.onAuthStateChange.listen((event) {
      if (!mounted) {
        return;
      }
      _unbindRealtime();
      _bindRealtime();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      ref.read(messageThreadsProvider.notifier).refresh();
      ref.read(messageContactsProvider.notifier).refresh();
      _bindRealtime();
    });
  }

  @override
  void dispose() {
    _authStateSubscription?.cancel();
    _realtimeDebounce?.cancel();
    _unbindRealtime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final useMockData = ref.watch(useMockDataProvider);
    final hasSession = ref.watch(hasSupabaseSessionProvider);
    if (!useMockData && !hasSession) {
      return const SafeArea(
        child: SignInRequiredView(
          message: 'Sign in is required to view messages.',
        ),
      );
    }
    final threadsAsync = ref.watch(messageThreadsProvider);
    final contactsAsync = ref.watch(messageContactsProvider);

    return SafeArea(
      child: Column(
        children: [
          PrimaryTopBar(
            title: 'Messages',
            trailing: [
              IconButton(
                onPressed: () => _openNewMessage(contactsAsync),
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'New message',
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _SearchInput(
              hintText: 'Search users and messages',
              onChanged: (value) => setState(() => _query = value),
            ),
          ),
          Expanded(
            child: threadsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('Could not load messages: $error'),
                ),
              ),
              data: (threads) {
                final filtered = threads.where((item) {
                  final query = _query.trim().toLowerCase();
                  if (query.isEmpty) {
                    return true;
                  }
                  return item.displayName.toLowerCase().contains(query) ||
                      item.preview.toLowerCase().contains(query);
                }).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No conversations yet.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: palette.muted),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Divider(color: palette.border, height: 1),
                  ),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return Align(
                      alignment: Alignment.center,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: _ConversationRow(
                          item: item,
                          onTap: () => context.pushNamed(
                            AppRouteName.messageThread,
                            pathParameters: {'threadId': item.threadId},
                            extra: item.displayName,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _bindRealtime() {
    if (_inboxChannel != null || _client.auth.currentSession == null) {
      return;
    }
    _inboxChannel = _client
        .channel('public:dm_inbox:${_client.auth.currentUser?.id ?? 'anon'}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'dm_messages',
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'dm_thread_participants',
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        .subscribe();
  }

  void _unbindRealtime() {
    final channel = _inboxChannel;
    if (channel != null) {
      _client.removeChannel(channel);
      _inboxChannel = null;
    }
  }

  void _scheduleRealtimeRefresh() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 220), () async {
      if (!mounted) {
        return;
      }
      await ref.read(messageThreadsProvider.notifier).refresh();
      await ref.read(messageContactsProvider.notifier).refresh();
    });
  }

  void _openNewMessage(AsyncValue<List<MessageContactSummary>> contactsAsync) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        var search = '';
        final palette = Theme.of(context).extension<NeuwsPalette>()!;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return contactsAsync.when(
              loading: () => const SizedBox(
                height: 260,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stackTrace) => SizedBox(
                height: 260,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text('Could not load contacts: $error'),
                  ),
                ),
              ),
              data: (contacts) {
                final filteredContacts = contacts.where((item) {
                  final query = search.trim().toLowerCase();
                  if (query.isEmpty) {
                    return true;
                  }
                  return item.displayName.toLowerCase().contains(query) ||
                      item.relation.toLowerCase().contains(query);
                }).toList();

                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    12,
                    16,
                    MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.66,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Message',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        _SearchInput(
                          hintText: 'Search followers and following',
                          onChanged: (value) =>
                              setModalState(() => search = value),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: filteredContacts.isEmpty
                              ? Center(
                                  child: Text(
                                    'No contacts found.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: palette.muted),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: filteredContacts.length,
                                  separatorBuilder: (context, index) =>
                                      Divider(color: palette.border, height: 1),
                                  itemBuilder: (context, index) {
                                    final contact = filteredContacts[index];
                                    return ListTile(
                                      contentPadding: EdgeInsets.zero,
                                      leading: const CircleAvatar(
                                        radius: 22,
                                        backgroundImage: AssetImage(
                                          'assets/images/placeholder-user.jpg',
                                        ),
                                      ),
                                      title: Text(contact.displayName),
                                      subtitle: Text(contact.relation),
                                      onTap: () {
                                        Navigator.of(context).pop();
                                        _openThreadByContact(contact);
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openThreadByContact(MessageContactSummary contact) async {
    final threads = ref.read(messageThreadsProvider).valueOrNull ?? const [];
    MessageThreadSummary? target;
    for (final thread in threads) {
      if (thread.otherUserId == contact.userId) {
        target = thread;
        break;
      }
    }

    if (target == null) {
      try {
        final threadId = await ref
            .read(communityRepositoryProvider)
            .createOrGetDmThread(contact.userId);
        if (threadId == null || threadId.isEmpty) {
          if (!mounted) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not create conversation right now.'),
            ),
          );
          return;
        }

        await ref.read(messageThreadsProvider.notifier).refresh();
        final refreshed =
            ref.read(messageThreadsProvider).valueOrNull ?? const [];
        for (final thread in refreshed) {
          if (thread.threadId == threadId) {
            target = thread;
            break;
          }
        }
        target ??= MessageThreadSummary(
          threadId: threadId,
          displayName: contact.displayName,
          preview: '',
          timeLabel: '',
          unreadCount: 0,
          otherUserId: contact.userId,
          otherUserAvatarUrl: 'assets/images/placeholder-user.jpg',
        );
      } catch (error) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open conversation: $error')),
        );
        return;
      }
    }

    if (!mounted) {
      return;
    }
    context.pushNamed(
      AppRouteName.messageThread,
      pathParameters: {'threadId': target.threadId},
      extra: target.displayName,
    );
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.item, required this.onTap});

  final MessageThreadSummary item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final unread = item.unreadCount > 0;
    final avatarSource = item.otherUserAvatarUrl?.trim().isEmpty ?? true
        ? 'assets/images/placeholder-user.jpg'
        : item.otherUserAvatarUrl!;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipOval(
              child: AdaptiveImage(
                source: avatarSource,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: unread
                          ? Theme.of(context).colorScheme.onSurface
                          : palette.muted,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.timeLabel.isNotEmpty)
                    Text(
                      item.timeLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (unread) ...[
                    const SizedBox(width: 10),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({required this.hintText, required this.onChanged});

  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: palette.surfaceCard,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: palette.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: palette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}
