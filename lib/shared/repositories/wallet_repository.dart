import 'dart:async';

import 'package:hive/hive.dart';

import '../models/wallet.dart';

class WalletRepository {
  WalletRepository._();

  static final WalletRepository instance = WalletRepository._();

  static const String _boxName = 'wallets';

  Box<Wallet> get _box => Hive.box<Wallet>(_boxName);

  Future<List<Wallet>> getAll() async {
    return List<Wallet>.unmodifiable(_box.values.toList());
  }

  Future<Wallet?> getById(String id) async {
    return _box.get(id);
  }

  Future<Wallet> add(Wallet wallet) async {
    await _box.put(wallet.id, wallet);
    return wallet;
  }

  Future<Wallet?> update(Wallet wallet) async {
    if (!_box.containsKey(wallet.id)) {
      return null;
    }

    await _box.put(wallet.id, wallet);
    return wallet;
  }

  Future<bool> delete(String id) async {
    if (!_box.containsKey(id)) {
      return false;
    }

    await _box.delete(id);
    return true;
  }

  Future<void> increaseBalance(String walletId, double amount) async {
    final wallet = _box.get(walletId);
    if (wallet == null) {
      return;
    }

    await _box.put(
      walletId,
      wallet.copyWith(currentBalance: wallet.currentBalance + amount),
    );
  }

  Future<void> decreaseBalance(String walletId, double amount) async {
    final wallet = _box.get(walletId);
    if (wallet == null) {
      return;
    }

    await _box.put(
      walletId,
      wallet.copyWith(currentBalance: wallet.currentBalance - amount),
    );
  }
}
