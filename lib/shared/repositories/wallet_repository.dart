import 'dart:async';

import '../models/wallet.dart';

class WalletRepository {
  WalletRepository._();

  static final WalletRepository instance = WalletRepository._();

  final List<Wallet> _wallets = <Wallet>[
    Wallet(
      id: 'wallet-hdfc-salary',
      name: 'HDFC Salary',
      bankName: 'HDFC Bank',
      type: 'Savings',
      openingBalance: 50000,
      currentBalance: 50000,
      createdAt: DateTime.utc(2024, 1, 1),
    ),
    Wallet(
      id: 'wallet-cash',
      name: 'Cash',
      bankName: 'Cash',
      type: 'Cash',
      openingBalance: 2000,
      currentBalance: 2000,
      createdAt: DateTime.utc(2024, 1, 1),
    ),
  ];

  Future<List<Wallet>> getAll() async {
    return List<Wallet>.unmodifiable(_wallets);
  }

  Future<Wallet?> getById(String id) async {
    return _wallets
        .where((wallet) => wallet.id == id)
        .cast<Wallet?>()
        .firstOrNull;
  }

  Future<Wallet> add(Wallet wallet) async {
    _wallets.add(wallet);
    return wallet;
  }

  Future<Wallet?> update(String id, Wallet wallet) async {
    final index = _wallets.indexWhere((item) => item.id == id);
    if (index < 0) {
      return null;
    }

    _wallets[index] = wallet;
    return wallet;
  }

  Future<bool> delete(String id) async {
    final index = _wallets.indexWhere((item) => item.id == id);
    if (index < 0) {
      return false;
    }

    _wallets.removeAt(index);
    return true;
  }

  Future<void> increaseBalance(String walletId, double amount) async {
    final index = _wallets.indexWhere((item) => item.id == walletId);
    if (index < 0) {
      return;
    }

    final wallet = _wallets[index];
    _wallets[index] = wallet.copyWith(
      currentBalance: wallet.currentBalance + amount,
    );
  }

  Future<void> decreaseBalance(String walletId, double amount) async {
    final index = _wallets.indexWhere((item) => item.id == walletId);
    if (index < 0) {
      return;
    }

    final wallet = _wallets[index];
    _wallets[index] = wallet.copyWith(
      currentBalance: wallet.currentBalance - amount,
    );
  }
}

extension on Iterable<Wallet?> {
  Wallet? get firstOrNull => isEmpty ? null : first;
}
