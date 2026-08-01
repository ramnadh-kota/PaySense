import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_profile.dart';
import '../repositories/user_profile_repository.dart';

final userProfileRepositoryProvider = Provider<UserProfileRepository>((ref) {
  return UserProfileRepository.instance;
});

final userProfileProvider =
    AsyncNotifierProvider<UserProfileNotifier, UserProfile?>(() {
      return UserProfileNotifier();
    });

class UserProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() async {
    final repository = ref.read(userProfileRepositoryProvider);
    return repository.getProfile();
  }

  Future<void> saveProfile(UserProfile profile) async {
    state = const AsyncValue.loading();
    final repository = ref.read(userProfileRepositoryProvider);
    final savedProfile = await repository.saveProfile(profile);
    state = AsyncValue.data(savedProfile);
  }

  Future<void> clearProfile() async {
    state = const AsyncValue.loading();
    final repository = ref.read(userProfileRepositoryProvider);
    await repository.clearProfile();
    state = const AsyncValue.data(null);
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    final repository = ref.read(userProfileRepositoryProvider);
    state = await AsyncValue.guard(() => repository.getProfile());
  }
}
