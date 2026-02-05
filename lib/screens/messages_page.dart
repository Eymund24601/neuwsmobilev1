import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/primary_top_bar.dart';

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  final List<_Conversation> _conversations = const [
    _Conversation(
      name: 'Marta Keller',
      preview: 'New message',
      timeLabel: '2h',
      unread: true,
    ),
    _Conversation(
      name: 'Lukas Brenner',
      preview: 'Sent Monday',
      timeLabel: 'Mon',
    ),
    _Conversation(
      name: 'Lea Novak',
      preview: 'Can we publish this thread tonight?',
      timeLabel: '1d',
      unread: true,
    ),
    _Conversation(
      name: 'Miguel Sousa',
      preview: 'Sent 5h ago',
      timeLabel: '5h',
    ),
    _Conversation(
      name: 'Aino Jarvinen',
      preview: 'Loved your latest piece on Helsinki',
      timeLabel: '2d',
    ),
    _Conversation(
      name: 'Andrei Popescu',
      preview: 'New message',
      timeLabel: '3d',
    ),
  ];

  final List<_Contact> _contacts = const [
    _Contact(name: 'Marta Keller', relation: 'Follows you'),
    _Contact(name: 'Lukas Brenner', relation: 'You follow each other'),
    _Contact(name: 'Lea Novak', relation: 'Follows you'),
    _Contact(name: 'Miguel Sousa', relation: 'You follow each other'),
    _Contact(name: 'Aino Jarvinen', relation: 'You follow each other'),
    _Contact(name: 'Andrei Popescu', relation: 'Follows you'),
    _Contact(name: 'Nikos Petrou', relation: 'You follow each other'),
  ];

  String _query = '';

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final filtered = _conversations.where((item) {
      final query = _query.trim().toLowerCase();
      if (query.isEmpty) {
        return true;
      }
      return item.name.toLowerCase().contains(query) ||
          item.preview.toLowerCase().contains(query);
    }).toList();

    return SafeArea(
      child: Column(
        children: [
          PrimaryTopBar(
            title: 'Messages',
            trailing: [
              IconButton(
                onPressed: _openNewMessage,
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
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              itemCount: filtered.length,
              separatorBuilder: (context, index) =>
                  Divider(color: palette.border, height: 1),
              itemBuilder: (context, index) {
                final item = filtered[index];
                return _ConversationRow(item: item);
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openNewMessage() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        var search = '';
        final palette = Theme.of(context).extension<NeuwsPalette>()!;

        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredContacts = _contacts.where((item) {
              final query = search.trim().toLowerCase();
              if (query.isEmpty) {
                return true;
              }
              return item.name.toLowerCase().contains(query) ||
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
                      onChanged: (value) => setModalState(() => search = value),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView.separated(
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
                            title: Text(contact.name),
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
  }
}

class _ConversationRow extends StatelessWidget {
  const _ConversationRow({required this.item});

  final _Conversation item;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6),
      leading: const CircleAvatar(
        radius: 30,
        backgroundImage: AssetImage('assets/images/placeholder-user.jpg'),
      ),
      title: Text(
        item.name,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: item.unread ? FontWeight.w800 : FontWeight.w600,
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
                  color: item.unread
                      ? Theme.of(context).colorScheme.onSurface
                      : palette.muted,
                  fontWeight: item.unread ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (item.unread) ...[
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

class _Conversation {
  const _Conversation({
    required this.name,
    required this.preview,
    required this.timeLabel,
    this.unread = false,
  });

  final String name;
  final String preview;
  final String timeLabel;
  final bool unread;
}

class _Contact {
  const _Contact({required this.name, required this.relation});

  final String name;
  final String relation;
}
