import 'package:hive/hive.dart';

/// Stores small app-level flags (currently just first-launch detection) in
/// an untyped Hive box, separate from the [UserProfile] record itself.
class AppSettingsRepository {
  AppSettingsRepository._();

  static final AppSettingsRepository instance = AppSettingsRepository._();

  static const String _boxName = 'app_settings';
  static const String _isFirstLaunchKey = 'isFirstLaunch';

  Box get _box => Hive.box(_boxName);

  /// True until [completeFirstLaunch] has been called at least once.
  Future<bool> isFirstLaunch() async {
    return (_box.get(_isFirstLaunchKey) as bool?) ?? true;
  }

  Future<void> completeFirstLaunch() async {
    await _box.put(_isFirstLaunchKey, false);
  }
}
