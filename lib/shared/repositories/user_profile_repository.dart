import 'package:hive/hive.dart';

import '../models/user_profile.dart';

class UserProfileRepository {
  UserProfileRepository._();

  static final UserProfileRepository instance = UserProfileRepository._();

  static const String _boxName = 'user_profile';
  static const String _profileKey = 'profile';

  Box<UserProfile> get _box => Hive.box<UserProfile>(_boxName);

  Future<UserProfile?> getProfile() async {
    return _box.get(_profileKey);
  }

  Future<UserProfile> saveProfile(UserProfile profile) async {
    await _box.put(_profileKey, profile);
    return profile;
  }

  Future<void> clearProfile() async {
    await _box.delete(_profileKey);
  }
}
