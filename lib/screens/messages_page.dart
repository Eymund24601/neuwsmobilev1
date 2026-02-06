import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_models.dart';
import '../providers/feature_data_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_top_bar.dart';

class MessagesPage extends ConsumerStatefulWidget {
  const MessagesPage({super.key});

  @override
  ConsumerState<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends ConsumerState<MessagesPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
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
                  separatorBuilder: (context, index) =>
                      Divider(color: palette.border, height: 1),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _ConversationRow(item: item);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
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
                                      onTap: () => Navigator.of(context).pop(),
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
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.item});

  final MessageThreadSummary item;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final unread = item.unreadCount > 0;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: const CircleAvatar(
        radius: 30,
        backgroundImage: AssetImage('assets/images/placeholder-user.jpg'),
      ),
      title: Text(
        item.displayName,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: Row(
          children: [
            Expanded(
              child: Text(
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
            ),
            if (unread) ...[
              const SizedBox(width: 8),
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
      trailing: Text(
        item.timeLabel,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: palette.muted),
      ),
      onTap: () {},
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
