import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/community_models.dart';
import '../providers/feature_data_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/adaptive_image.dart';

class MessageThreadPage extends ConsumerStatefulWidget {
  const MessageThreadPage({
    super.key,
    required this.threadId,
    required this.threadTitle,
  });

  final String threadId;
  final String threadTitle;

  @override
  ConsumerState<MessageThreadPage> createState() => _MessageThreadPageState();
}

class _MessageThreadPageState extends ConsumerState<MessageThreadPage> {
  final _composerController = TextEditingController();
  final _scrollController = ScrollController();
  final _client = Supabase.instance.client;

  RealtimeChannel? _threadChannel;
  Timer? _realtimeDebounce;
  bool _sending = false;
  bool _didInitialScroll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }
      await ref
          .read(messageThreadMessagesProvider(widget.threadId).notifier)
          .refresh();
      await ref
          .read(messageThreadMessagesProvider(widget.threadId).notifier)
          .markRead();
      _bindRealtime();
    });
  }

  @override
  void dispose() {
    _composerController.dispose();
    _scrollController.dispose();
    _realtimeDebounce?.cancel();
    _unbindRealtime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final messagesAsync = ref.watch(
      messageThreadMessagesProvider(widget.threadId),
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.threadTitle)),
      body: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref
                  .read(messageThreadMessagesProvider(widget.threadId).notifier)
                  .refresh(),
              child: messagesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => ListView(
                  padding: const EdgeInsets.all(20),
                  children: [Text('Could not load conversation: $error')],
                ),
                data: (messages) {
                  if (!_didInitialScroll && messages.isNotEmpty) {
                    _didInitialScroll = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _scrollToBottom(jump: true);
                    });
                  }
                  if (messages.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text(
                          'No messages yet.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: palette.muted),
                        ),
                      ],
                    );
                  }
                  return ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final item = messages[index];
                      return _MessageBubble(item: item);
                    },
                  );
                },
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              decoration: BoxDecoration(
                color: palette.surfaceCard,
                border: Border(top: BorderSide(color: palette.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composerController,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Write a message...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 11,
                        ),
                        filled: true,
                        fillColor: palette.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(color: palette.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(color: palette.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : _sendMessage,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final text = _composerController.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }

    setState(() => _sending = true);
    try {
      await ref
          .read(messageThreadMessagesProvider(widget.threadId).notifier)
          .sendMessage(text);
      if (!mounted) {
        return;
      }
      _composerController.clear();
      _scrollToBottom();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send message: $error')));
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _bindRealtime() {
    if (_threadChannel != null || _client.auth.currentSession == null) {
      return;
    }

    _threadChannel = _client
        .channel('public:dm_messages:thread:${widget.threadId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'dm_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_id',
            value: widget.threadId,
          ),
          callback: (_) => _scheduleRealtimeSync(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'dm_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'thread_id',
            value: widget.threadId,
          ),
          callback: (_) => _scheduleRealtimeSync(),
        )
        .subscribe();
  }

  void _unbindRealtime() {
    final channel = _threadChannel;
    if (channel != null) {
      _client.removeChannel(channel);
      _threadChannel = null;
    }
  }

  void _scheduleRealtimeSync() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 180), () async {
      if (!mounted) {
        return;
      }
      await ref
          .read(messageThreadMessagesProvider(widget.threadId).notifier)
          .refresh();
      await ref
          .read(messageThreadMessagesProvider(widget.threadId).notifier)
          .markRead();
      await ref.read(messageThreadsProvider.notifier).refresh();
    });
  }

  void _scrollToBottom({bool jump = false}) {
    if (!_scrollController.hasClients) {
      return;
    }
    final target = _scrollController.position.maxScrollExtent;
    if (jump) {
      _scrollController.jumpTo(target);
      return;
    }
    _scrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.item});

  final DirectMessage item;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final alignEnd = item.isMine;
    final bubbleColor = alignEnd
        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
        : palette.surfaceCard;
    final textColor = Theme.of(context).colorScheme.onSurface;

    final avatarSource = item.senderAvatarUrl.trim().isEmpty
        ? 'assets/images/placeholder-user.jpg'
        : item.senderAvatarUrl;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: alignEnd
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!alignEnd)
            Padding(
              padding: const EdgeInsets.only(right: 8, bottom: 2),
              child: ClipOval(
                child: AdaptiveImage(
                  source: avatarSource,
                  width: 30,
                  height: 30,
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            const SizedBox(width: 38),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.border),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                child: Column(
                  crossAxisAlignment: alignEnd
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.body,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: textColor,
                        fontSize: 17,
                        height: 1.28,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatClock(item.createdAt),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: palette.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (alignEnd) const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _formatClock(DateTime? dateTime) {
    if (dateTime == null) {
      return '';
    }
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
