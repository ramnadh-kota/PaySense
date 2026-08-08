import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';

final appSettingsRepositoryProvider = Provider<AppSettingsRepository>((ref) {
  return AppSettingsRepository.instance;
});

final isFirstLaunchProvider =
    AsyncNotifierProvider<IsFirstLaunchNotifier, bool>(
      IsFirstLaunchNotifier.new,
    );

class IsFirstLaunchNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final repository = ref.watch(appSettingsRepositoryProvider);
    return repository.isFirstLaunch();
  }

  Future<void> completeFirstLaunch() async {
    final repository = ref.read(appSettingsRepositoryProvider);
    await repository.completeFirstLaunch();
    state = const AsyncValue.data(false);
  }
}
