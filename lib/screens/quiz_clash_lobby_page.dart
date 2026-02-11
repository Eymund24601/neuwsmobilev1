import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/app_routes.dart';
import '../models/community_models.dart';
import '../models/quiz_clash_models.dart';
import '../providers/feature_data_providers.dart';
import '../providers/repository_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/sign_in_required_view.dart';

class QuizClashLobbyPage extends ConsumerStatefulWidget {
  const QuizClashLobbyPage({super.key});

  @override
  ConsumerState<QuizClashLobbyPage> createState() => _QuizClashLobbyPageState();
}

class _QuizClashLobbyPageState extends ConsumerState<QuizClashLobbyPage> {
  final _client = Supabase.instance.client;

  RealtimeChannel? _lobbyChannel;
  Timer? _realtimeDebounce;

  String _contactSearch = '';
  bool _sendingRandomInvite = false;
  final Set<String> _pendingInviteActions = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _bindRealtime();
    });
  }

  @override
  void dispose() {
    _realtimeDebounce?.cancel();
    _unbindRealtime();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final hasSession = ref.watch(hasSupabaseSessionProvider);
    if (!hasSession) {
      return const Scaffold(
        body: SafeArea(
          child: SignInRequiredView(
            message: 'Sign in is required to play Quiz Clash.',
          ),
        ),
      );
    }

    final contactsAsync = ref.watch(messageContactsProvider);
    final invitesAsync = ref.watch(quizClashInvitesProvider);
    final matchesAsync = ref.watch(quizClashMatchesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Quiz Clash')),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
          children: [
            Text(
              'Asynchronous 1v1 duel: 6 rounds, 3 questions per round, 48h turn timeout.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.muted),
            ),
            const SizedBox(height: 14),
            _SectionCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Challenge a random bot opponent',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _sendingRandomInvite
                        ? null
                        : () => _sendInvite(random: true),
                    icon: const Icon(Icons.casino_outlined),
                    label: Text(
                      _sendingRandomInvite ? 'Starting...' : 'Random',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invite a friend',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    onChanged: (value) =>
                        setState(() => _contactSearch = value.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search username',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: palette.surfaceAlt,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: palette.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: palette.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  contactsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (error, stackTrace) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text('Could not load contacts: $error'),
                    ),
                    data: (contacts) => _FriendInviteList(
                      contacts: _filterMutualContacts(contacts, _contactSearch),
                      onInvite: (contact) =>
                          _sendInvite(opponentUserId: contact.userId),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Pending invites',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            invitesAsync.when(
              loading: () => const _SectionCard(
                child: SizedBox(
                  height: 74,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, stackTrace) =>
                  _SectionCard(child: Text('Could not load invites: $error')),
              data: (invites) {
                if (invites.isEmpty) {
                  return const _SectionCard(child: Text('No pending invites.'));
                }
                return Column(
                  children: invites
                      .map(
                        (invite) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _InviteTile(
                            invite: invite,
                            busy: _pendingInviteActions.contains(invite.id),
                            onAccept: invite.isIncoming
                                ? () => _respondInvite(invite.id, true)
                                : null,
                            onDecline: invite.isIncoming
                                ? () => _respondInvite(invite.id, false)
                                : null,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 12),
            Text('Matches', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            matchesAsync.when(
              loading: () => const _SectionCard(
                child: SizedBox(
                  height: 74,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (error, stackTrace) =>
                  _SectionCard(child: Text('Could not load matches: $error')),
              data: (matches) {
                if (matches.isEmpty) {
                  return const _SectionCard(
                    child: Text('No matches yet. Send an invite to begin.'),
                  );
                }
                return Column(
                  children: matches
                      .map(
                        (match) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _MatchTile(
                            match: match,
                            onTap: () => context.pushNamed(
                              AppRouteName.quizClashMatch,
                              pathParameters: {'matchId': match.id},
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  List<MessageContactSummary> _filterMutualContacts(
    List<MessageContactSummary> contacts,
    String query,
  ) {
    final filtered = contacts.where((contact) {
      if (contact.relation != 'You follow each other') {
        return false;
      }
      final lowerQuery = query.toLowerCase();
      if (lowerQuery.isEmpty) {
        return true;
      }
      return contact.displayName.toLowerCase().contains(lowerQuery) ||
          contact.username.toLowerCase().contains(lowerQuery);
    }).toList();
    filtered.sort(
      (a, b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
    );
    return filtered;
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      ref.read(quizClashInvitesProvider.notifier).refresh(),
      ref.read(quizClashMatchesProvider.notifier).refresh(),
      ref.read(messageContactsProvider.notifier).refresh(),
    ]);
  }

  Future<void> _sendInvite({
    String? opponentUserId,
    bool random = false,
  }) async {
    if (_sendingRandomInvite) {
      return;
    }
    if (random) {
      setState(() => _sendingRandomInvite = true);
    }

    try {
      final id = await ref
          .read(gamesRepositoryProvider)
          .sendQuizClashInvite(opponentUserId: opponentUserId, random: random);
      if (!mounted) {
        return;
      }

      if (random && id != null && id.isNotEmpty) {
        final matchState = await ref
            .read(gamesRepositoryProvider)
            .getQuizClashTurnState(id);
        if (!mounted) {
          return;
        }
        if (matchState != null) {
          await _refreshAll();
          if (!mounted) {
            return;
          }
          context.pushNamed(
            AppRouteName.quizClashMatch,
            pathParameters: {'matchId': id},
          );
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            random ? 'Random bot match created.' : 'Quiz Clash invite sent.',
          ),
        ),
      );
      await _refreshAll();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send invite: $error')));
    } finally {
      if (random && mounted) {
        setState(() => _sendingRandomInvite = false);
      }
    }
  }

  Future<void> _respondInvite(String inviteId, bool accept) async {
    if (_pendingInviteActions.contains(inviteId)) {
      return;
    }

    setState(() => _pendingInviteActions.add(inviteId));
    try {
      final matchId = await ref
          .read(gamesRepositoryProvider)
          .respondToQuizClashInvite(inviteId: inviteId, accept: accept);
      if (!mounted) {
        return;
      }
      await _refreshAll();
      if (!mounted) {
        return;
      }
      if (accept && matchId != null && matchId.isNotEmpty) {
        context.pushNamed(
          AppRouteName.quizClashMatch,
          pathParameters: {'matchId': matchId},
        );
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not respond to invite: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _pendingInviteActions.remove(inviteId));
      }
    }
  }

  void _bindRealtime() {
    if (_lobbyChannel != null) {
      return;
    }
    final userId = ref.read(currentSupabaseUserIdProvider);
    if (userId.isEmpty) {
      return;
    }

    _lobbyChannel = _client
        .channel('public:quiz_clash_lobby:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'quiz_clash_invites',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'recipient_user_id',
            value: userId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'quiz_clash_invites',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_user_id',
            value: userId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'quiz_clash_matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'player_a_user_id',
            value: userId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'quiz_clash_matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'player_b_user_id',
            value: userId,
          ),
          callback: (_) => _scheduleRealtimeRefresh(),
        )
        .subscribe();
  }

  void _unbindRealtime() {
    final channel = _lobbyChannel;
    if (channel != null) {
      _client.removeChannel(channel);
      _lobbyChannel = null;
    }
  }

  void _scheduleRealtimeRefresh() {
    _realtimeDebounce?.cancel();
    _realtimeDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) {
        return;
      }
      _refreshAll();
    });
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: child,
    );
  }
}

class _FriendInviteList extends StatelessWidget {
  const _FriendInviteList({required this.contacts, required this.onInvite});

  final List<MessageContactSummary> contacts;
  final ValueChanged<MessageContactSummary> onInvite;

  @override
  Widget build(BuildContext context) {
    if (contacts.isEmpty) {
      return Text(
        'No mutual friends found.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Column(
      children: contacts
          .take(8)
          .map(
            (contact) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(contact.displayName),
                        if (contact.username.trim().isNotEmpty)
                          Text(
                            '@${contact.username}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () => onInvite(contact),
                    child: const Text('Invite'),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({
    required this.invite,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final QuizClashInviteSummary invite;
  final bool busy;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    return _SectionCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.opponentDisplayName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  invite.isIncoming ? 'Incoming invite' : 'Invite sent',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palette.muted),
                ),
              ],
            ),
          ),
          if (invite.isIncoming) ...[
            OutlinedButton(
              onPressed: busy ? null : onDecline,
              child: const Text('Decline'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: busy ? null : onAccept,
              child: Text(busy ? '...' : 'Accept'),
            ),
          ] else
            Text(
              'Pending',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: palette.muted),
            ),
        ],
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  const _MatchTile({required this.match, required this.onTap});

  final QuizClashMatchSummary match;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<NeuwsPalette>()!;
    final status = match.status == 'active'
        ? (match.isMyTurn ? 'Your turn' : 'Waiting')
        : match.status;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: _SectionCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    match.opponentDisplayName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Round ${match.currentRoundIndex}/${match.totalRounds} | ${match.scoreMe}/${match.totalRounds * 3} vs ${match.scoreOpponent}/${match.totalRounds * 3}',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: palette.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              status,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: match.isMyTurn
                    ? Theme.of(context).colorScheme.primary
                    : palette.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios, size: 14),
          ],
        ),
      ),
    );
  }
}
