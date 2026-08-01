import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/wallet.dart';
import '../repositories/wallet_repository.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository.instance;
});

final walletsProvider = AsyncNotifierProvider<WalletsNotifier, List<Wallet>>(
  () {
    return WalletsNotifier();
  },
);

class WalletsNotifier extends AsyncNotifier<List<Wallet>> {
  @override
  Future<List<Wallet>> build() async {
    final repository = ref.read(walletRepositoryProvider);
    return repository.getAll();
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    final repository = ref.read(walletRepositoryProvider);
    state = await AsyncValue.guard(() => repository.getAll());
  }
}
