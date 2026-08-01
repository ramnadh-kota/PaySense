import '../models/user_profile.dart';

class UserProfileRepository {
  UserProfileRepository._();

  static final UserProfileRepository instance = UserProfileRepository._();

  UserProfile? _profile;

  Future<UserProfile?> getProfile() async {
    return _profile;
  }

  Future<UserProfile> saveProfile(UserProfile profile) async {
    _profile = profile;
    return profile;
  }

  Future<void> clearProfile() async {
    _profile = null;
  }

  Future<bool> hasCompletedOnboarding() async {
    return _profile?.onboardingCompleted ?? false;
  }
}
