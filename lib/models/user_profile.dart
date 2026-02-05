import 'subscription_tier.dart';

class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.username,
    required this.city,
    required this.countryCode,
    required this.bio,
    required this.nationalityCodes,
    required this.followers,
    required this.following,
    required this.joinedLabel,
    required this.showAgePublic,
    required this.age,
    required this.avatarAsset,
    required this.wallpaperAsset,
    required this.subscriptionTier,
    required this.streakDays,
    required this.points,
    required this.isCreator,
  });

  final String id;
  final String displayName;
  final String username;
  final String city;
  final String countryCode;
  final String bio;
  final List<String> nationalityCodes;
  final int followers;
  final int following;
  final String joinedLabel;
  final bool showAgePublic;
  final int age;
  final String avatarAsset;
  final String wallpaperAsset;
  final SubscriptionTier subscriptionTier;
  final int streakDays;
  final int points;
  final bool isCreator;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: json['displayName'] as String,
      username: json['username'] as String? ?? 'user',
      city: json['city'] as String,
      countryCode: json['countryCode'] as String,
      bio: json['bio'] as String? ?? '',
      nationalityCodes: (json['nationalityCodes'] as List<dynamic>? ?? const [])
          .cast<String>(),
      followers: json['followers'] as int? ?? 0,
      following: json['following'] as int? ?? 0,
      joinedLabel: json['joinedLabel'] as String? ?? 'Joined recently',
      showAgePublic: json['showAgePublic'] as bool? ?? false,
      age: json['age'] as int? ?? 0,
      avatarAsset:
          json['avatarAsset'] as String? ??
          'assets/images/placeholder-user.jpg',
      wallpaperAsset:
          json['wallpaperAsset'] as String? ?? 'assets/images/placeholder.jpg',
      subscriptionTier: SubscriptionTier.values.byName(
        json['subscriptionTier'] as String,
      ),
      streakDays: json['streakDays'] as int,
      points: json['points'] as int,
      isCreator: json['isCreator'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayName': displayName,
      'username': username,
      'city': city,
      'countryCode': countryCode,
      'bio': bio,
      'nationalityCodes': nationalityCodes,
      'followers': followers,
      'following': following,
      'joinedLabel': joinedLabel,
      'showAgePublic': showAgePublic,
      'age': age,
      'avatarAsset': avatarAsset,
      'wallpaperAsset': wallpaperAsset,
      'subscriptionTier': subscriptionTier.name,
      'streakDays': streakDays,
      'points': points,
      'isCreator': isCreator,
    };
  }
}
