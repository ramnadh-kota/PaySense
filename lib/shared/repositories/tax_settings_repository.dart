import 'package:hive/hive.dart';

import '../models/tax_settings.dart';

/// Single-instance persisted tax profile — mirrors [UserProfileRepository]'s
/// pattern. Never touched by SMS, wallet, transaction, goal, loan, or
/// budget code; only the Tax Planner screen and the tax what-if pipeline
/// read/write it.
class TaxSettingsRepository {
  TaxSettingsRepository._();

  static final TaxSettingsRepository instance = TaxSettingsRepository._();

  static const String _boxName = 'tax_settings';
  static const String _key = 'profile';

  Box<TaxSettings> get _box => Hive.box<TaxSettings>(_boxName);

  Future<TaxSettings?> get() async {
    return _box.get(_key);
  }

  Future<TaxSettings> save(TaxSettings settings) async {
    await _box.put(_key, settings);
    return settings;
  }

  Future<void> clear() async {
    await _box.delete(_key);
  }
}
