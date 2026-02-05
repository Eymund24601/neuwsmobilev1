import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/article_repository.dart';
import '../repositories/creator_repository.dart';
import '../repositories/events_repository.dart';
import '../repositories/games_repository.dart';
import '../repositories/learn_repository.dart';
import '../repositories/mock/mock_article_repository.dart';
import '../repositories/mock/mock_creator_repository.dart';
import '../repositories/mock/mock_events_repository.dart';
import '../repositories/mock/mock_games_repository.dart';
import '../repositories/mock/mock_learn_repository.dart';
import '../repositories/mock/mock_profile_repository.dart';
import '../repositories/mock/mock_settings_repository.dart';
import '../repositories/profile_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/supabase/supabase_article_repository.dart';
import '../repositories/supabase/supabase_creator_repository.dart';
import '../repositories/supabase/supabase_events_repository.dart';
import '../repositories/supabase/supabase_games_repository.dart';
import '../repositories/supabase/supabase_learn_repository.dart';
import '../repositories/supabase/supabase_profile_repository.dart';
import '../repositories/supabase/supabase_settings_repository.dart';
import '../services/supabase/supabase_bootstrap.dart';

final useMockDataProvider = Provider<bool>(
  (ref) => !SupabaseBootstrap.isConfigured,
);

final articleRepositoryProvider = Provider<ArticleRepository>((ref) {
  if (ref.watch(useMockDataProvider)) {
    return MockArticleRepository();
  }
  return const SupabaseArticleRepository();
});

final learnRepositoryProvider = Provider<LearnRepository>((ref) {
  if (ref.watch(useMockDataProvider)) {
    return MockLearnRepository();
  }
  return const SupabaseLearnRepository();
});

final gamesRepositoryProvider = Provider<GamesRepository>((ref) {
  if (ref.watch(useMockDataProvider)) {
    return MockGamesRepository();
  }
  return const SupabaseGamesRepository();
});

final eventsRepositoryProvider = Provider<EventsRepository>((ref) {
  if (ref.watch(useMockDataProvider)) {
    return MockEventsRepository();
  }
  return const SupabaseEventsRepository();
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  if (ref.watch(useMockDataProvider)) {
    return MockProfileRepository();
  }
  return const SupabaseProfileRepository();
});

final creatorRepositoryProvider = Provider<CreatorRepository>((ref) {
  if (ref.watch(useMockDataProvider)) {
    return MockCreatorRepository();
  }
  return const SupabaseCreatorRepository();
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  if (ref.watch(useMockDataProvider)) {
    return MockSettingsRepository();
  }
  return const SupabaseSettingsRepository();
});
