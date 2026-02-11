import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../repositories/article_repository.dart';
import '../repositories/community_repository.dart';
import '../repositories/creator_repository.dart';
import '../repositories/events_repository.dart';
import '../repositories/games_repository.dart';
import '../repositories/learn_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/supabase/supabase_article_repository.dart';
import '../repositories/supabase/supabase_community_repository.dart';
import '../repositories/supabase/supabase_creator_repository.dart';
import '../repositories/supabase/supabase_events_repository.dart';
import '../repositories/supabase/supabase_games_repository.dart';
import '../repositories/supabase/supabase_learn_repository.dart';
import '../repositories/supabase/supabase_profile_repository.dart';
import '../repositories/supabase/supabase_settings_repository.dart';
import '../services/supabase/supabase_bootstrap.dart';

final supabaseAuthStateProvider = StreamProvider<AuthState?>((ref) {
  if (!SupabaseBootstrap.isConfigured || !SupabaseBootstrap.isInitialized) {
    return Stream<AuthState?>.value(null);
  }
  return Supabase.instance.client.auth.onAuthStateChange;
});

final hasSupabaseSessionProvider = Provider<bool>((ref) {
  if (!SupabaseBootstrap.isConfigured || !SupabaseBootstrap.isInitialized) {
    return false;
  }
  final authState = ref.watch(supabaseAuthStateProvider).valueOrNull;
  if (authState != null) {
    return authState.session != null;
  }
  return Supabase.instance.client.auth.currentSession != null;
});

final currentSupabaseUserEmailProvider = Provider<String>((ref) {
  if (!SupabaseBootstrap.isConfigured || !SupabaseBootstrap.isInitialized) {
    return '';
  }
  ref.watch(supabaseAuthStateProvider);
  return Supabase.instance.client.auth.currentUser?.email ?? '';
});

final currentSupabaseUserIdProvider = Provider<String>((ref) {
  if (!SupabaseBootstrap.isConfigured || !SupabaseBootstrap.isInitialized) {
    return '';
  }
  ref.watch(supabaseAuthStateProvider);
  return Supabase.instance.client.auth.currentUser?.id ?? '';
});

final articleRepositoryProvider = Provider<ArticleRepository>((ref) {
  return const SupabaseArticleRepository();
});

final learnRepositoryProvider = Provider<LearnRepository>((ref) {
  return const SupabaseLearnRepository();
});

final gamesRepositoryProvider = Provider<GamesRepository>((ref) {
  return const SupabaseGamesRepository();
});

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  return const SupabaseEventsRepository();
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return const SupabaseProfileRepository();
});

final creatorRepositoryProvider = Provider<CreatorRepository>((ref) {
  return const SupabaseCreatorRepository();
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return const SupabaseSettingsRepository();
});

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return const SupabaseCommunityRepository();
});
