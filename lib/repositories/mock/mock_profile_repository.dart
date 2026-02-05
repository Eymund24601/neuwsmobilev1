import '../../models/subscription_tier.dart';
import '../../models/user_profile.dart';
import '../profile_repository.dart';

class MockProfileRepository implements ProfileRepository {
  @override
  Future<UserProfile> getCurrentProfile() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return const UserProfile(
      id: 'user-1',
      displayName: 'Marta Keller',
      username: 'martakeller',
      city: 'Vienna',
      countryCode: 'AT',
      bio:
          'Real stories by real Europeans. Building bridges through culture, politics, and lived experience.',
      nationalityCodes: ['AT', 'DE', 'SE'],
      followers: 1284,
      following: 224,
      joinedLabel: 'Joined April 2024',
      showAgePublic: true,
      age: 25,
      avatarAsset: 'assets/images/placeholder-user.jpg',
      wallpaperAsset: 'assets/images/placeholder.jpg',
      subscriptionTier: SubscriptionTier.premium,
      streakDays: 12,
      points: 1240,
      isCreator: true,
    );
  }
}
