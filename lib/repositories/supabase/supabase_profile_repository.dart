import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/subscription_tier.dart';
import '../../models/user_profile.dart';
import '../profile_repository.dart';
import 'supabase_mapping_utils.dart';

class SupabaseProfileRepository implements ProfileRepository {
  const SupabaseProfileRepository();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  Future<UserProfile> getCurrentProfile() async {
    final authUser = _client.auth.currentUser;
    if (authUser == null) {
      throw StateError('No signed-in user. Supabase auth session is required.');
    }

    final row = await _client
        .from('profiles')
        .select('''
          id,
          display_name,
          username,
          city,
          country_code,
          bio,
          nationality_codes,
          followers_count,
          following_count,
          joined_label,
          created_at,
          joined_at,
          birthdate,
          show_age_public,
          avatar_url,
          wallpaper_url,
          subscription_tier,
          streak_days,
          points,
          is_creator
          ''')
        .eq('id', authUser.id)
        .maybeSingle();

    if (row == null) {
      return _fallbackProfile(authUser.id);
    }

    return _mapProfile(row);
  }

  UserProfile _mapProfile(Map<String, dynamic> row) {
    final birthDate = SupabaseMappingUtils.dateTimeValue(row, const [
      'birthdate',
    ]);
    final now = DateTime.now();
    int age = 0;
    if (birthDate != null) {
      age = now.year - birthDate.year;
      if (now.month < birthDate.month ||
          (now.month == birthDate.month && now.day < birthDate.day)) {
        age--;
      }
    }

    final tierRaw = SupabaseMappingUtils.stringValue(row, const [
      'subscription_tier',
    ], fallback: 'free').toLowerCase();
    var tier = SubscriptionTier.free;
    for (final option in SubscriptionTier.values) {
      if (option.name == tierRaw) {
        tier = option;
        break;
      }
    }

    final nationalityCodes = row['nationality_codes'] is List
        ? (row['nationality_codes'] as List)
              .whereType<String>()
              .map((code) => code.trim().toUpperCase())
              .where((code) => code.isNotEmpty)
              .toList()
        : <String>[];

    final joinedAt = SupabaseMappingUtils.dateTimeValue(row, const [
      'created_at',
      'joined_at',
    ]);
    final joinedLabel = SupabaseMappingUtils.stringValue(
      row,
      const ['joined_label'],
      fallback: joinedAt == null
          ? 'Joined recently'
          : 'Joined ${_monthName(joinedAt.month)} ${joinedAt.year}',
    );

    return UserProfile(
      id: SupabaseMappingUtils.stringValue(row, const ['id'], fallback: ''),
      displayName: SupabaseMappingUtils.stringValue(row, const [
        'display_name',
      ], fallback: 'nEUws User'),
      username: SupabaseMappingUtils.stringValue(row, const [
        'username',
      ], fallback: 'user'),
      city: SupabaseMappingUtils.stringValue(row, const ['city'], fallback: ''),
      countryCode: SupabaseMappingUtils.stringValue(row, const [
        'country_code',
      ], fallback: 'EU'),
      bio: SupabaseMappingUtils.stringValue(row, const ['bio'], fallback: ''),
      nationalityCodes: nationalityCodes,
      followers: SupabaseMappingUtils.intValue(row, const [
        'followers_count',
      ], fallback: 0),
      following: SupabaseMappingUtils.intValue(row, const [
        'following_count',
      ], fallback: 0),
      joinedLabel: joinedLabel,
      showAgePublic: SupabaseMappingUtils.boolValue(row, const [
        'show_age_public',
      ], fallback: false),
      age: age < 0 ? 0 : age,
      avatarAsset: SupabaseMappingUtils.stringValue(row, const [
        'avatar_url',
      ], fallback: 'assets/images/placeholder-user.jpg'),
      wallpaperAsset: SupabaseMappingUtils.stringValue(row, const [
        'wallpaper_url',
      ], fallback: 'assets/images/placeholder.jpg'),
      subscriptionTier: tier,
      streakDays: SupabaseMappingUtils.intValue(row, const [
        'streak_days',
      ], fallback: 0),
      points: SupabaseMappingUtils.intValue(row, const ['points'], fallback: 0),
      isCreator: SupabaseMappingUtils.boolValue(row, const [
        'is_creator',
      ], fallback: false),
    );
  }

  UserProfile _fallbackProfile(String userId) {
    return UserProfile(
      id: userId,
      displayName: 'nEUws User',
      username: 'user',
      city: '',
      countryCode: 'EU',
      bio: '',
      nationalityCodes: const [],
      followers: 0,
      following: 0,
      joinedLabel: 'Joined recently',
      showAgePublic: false,
      age: 0,
      avatarAsset: 'assets/images/placeholder-user.jpg',
      wallpaperAsset: 'assets/images/placeholder.jpg',
      subscriptionTier: SubscriptionTier.free,
      streakDays: 0,
      points: 0,
      isCreator: false,
    );
  }

  String _monthName(int month) {
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return names[month - 1];
  }
}
