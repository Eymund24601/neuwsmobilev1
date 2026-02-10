import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/cache/cache_service.dart';

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  return SharedPreferences.getInstance();
});

final cacheServiceProvider = FutureProvider<CacheService>((ref) async {
  final preferences = await ref.watch(sharedPreferencesProvider.future);
  return CacheService.create(preferences);
});
