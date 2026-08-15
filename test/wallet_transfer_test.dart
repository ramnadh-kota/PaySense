import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/models/wallet.dart';
import 'package:paysense/shared/providers/wallet_provider.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';
import 'package:paysense/shared/repositories/wallet_repository.dart';

Future<void> _initHive(Directory dir) async {
  Hive.init(dir.path);
  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(WalletAdapter());
  }
  if (!Hive.isAdapterRegistered(2)) {
    Hive.registerAdapter(TransactionAdapter());
  }

  await Hive.openBox<Wallet>('wallets');
  await Hive.openBox<Transaction>('transactions');
}

Future<Wallet> _addWallet(String id, double balance) async {
  final wallet = Wallet(
    id: id,
    name: id,
    bankName: '',
    type: 'Bank',
    openingBalance: balance,
    currentBalance: balance,
    createdAt: DateTime(2026, 1, 1),
  );
  await WalletRepository.instance.add(wallet);
  return wallet;
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('paysense_wallet_transfer_test');
    await _initHive(tempDir);
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('1. transfer moves money between two wallets', () async {
    await _addWallet('bank', 50000);
    await _addWallet('cash', 1000);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    await container.read(walletsProvider.notifier).transfer(
      fromWalletId: 'bank',
      toWalletId: 'cash',
      amount: 5000,
    );

    final bank = await WalletRepository.instance.getById('bank');
    final cash = await WalletRepository.instance.getById('cash');
    expect(bank!.currentBalance, 45000);
    expect(cash!.currentBalance, 6000);
  });

  test('2. source balance decreases by the transferred amount', () async {
    await _addWallet('bank', 50000);
    await _addWallet('cash', 1000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    await container.read(walletsProvider.notifier).transfer(
      fromWalletId: 'bank',
      toWalletId: 'cash',
      amount: 5000,
    );

    final bank = await WalletRepository.instance.getById('bank');
    expect(bank!.currentBalance, 45000);
  });

  test('3. destination balance increases by the transferred amount', () async {
    await _addWallet('bank', 50000);
    await _addWallet('cash', 1000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    await container.read(walletsProvider.notifier).transfer(
      fromWalletId: 'bank',
      toWalletId: 'cash',
      amount: 5000,
    );

    final cash = await WalletRepository.instance.getById('cash');
    expect(cash!.currentBalance, 6000);
  });

  test('4. transfer legs are never transactionType income', () async {
    await _addWallet('bank', 50000);
    await _addWallet('cash', 1000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    await container.read(walletsProvider.notifier).transfer(
      fromWalletId: 'bank',
      toWalletId: 'cash',
      amount: 5000,
    );

    final all = await TransactionRepository.instance.getAll();
    expect(all.where((t) => t.transactionType.toLowerCase() == 'income'), isEmpty);
    expect(all, hasLength(2));
    expect(all.every((t) => t.transactionType == 'transfer'), isTrue);
  });

  test('5. transfer legs are never transactionType expense', () async {
    await _addWallet('bank', 50000);
    await _addWallet('cash', 1000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    await container.read(walletsProvider.notifier).transfer(
      fromWalletId: 'bank',
      toWalletId: 'cash',
      amount: 5000,
    );

    final all = await TransactionRepository.instance.getAll();
    expect(all.where((t) => t.transactionType.toLowerCase() == 'expense'), isEmpty);
  });

  test('6. transfer to the same wallet is rejected', () async {
    await _addWallet('bank', 50000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    expect(
      () => container.read(walletsProvider.notifier).transfer(
        fromWalletId: 'bank',
        toWalletId: 'bank',
        amount: 100,
      ),
      throwsA(isA<WalletTransferException>()),
    );

    final bank = await WalletRepository.instance.getById('bank');
    expect(bank!.currentBalance, 50000);
  });

  test('7. a zero amount is rejected', () async {
    await _addWallet('bank', 50000);
    await _addWallet('cash', 1000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    expect(
      () => container.read(walletsProvider.notifier).transfer(
        fromWalletId: 'bank',
        toWalletId: 'cash',
        amount: 0,
      ),
      throwsA(isA<WalletTransferException>()),
    );
  });

  test('8. a negative amount is rejected', () async {
    await _addWallet('bank', 50000);
    await _addWallet('cash', 1000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    expect(
      () => container.read(walletsProvider.notifier).transfer(
        fromWalletId: 'bank',
        toWalletId: 'cash',
        amount: -500,
      ),
      throwsA(isA<WalletTransferException>()),
    );
  });

  test('9. insufficient balance is handled safely without mutating either wallet', () async {
    await _addWallet('bank', 100);
    await _addWallet('cash', 1000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    await expectLater(
      container.read(walletsProvider.notifier).transfer(
        fromWalletId: 'bank',
        toWalletId: 'cash',
        amount: 5000,
      ),
      throwsA(isA<WalletTransferException>()),
    );

    final bank = await WalletRepository.instance.getById('bank');
    final cash = await WalletRepository.instance.getById('cash');
    expect(bank!.currentBalance, 100);
    expect(cash!.currentBalance, 1000);
    expect(await TransactionRepository.instance.getAll(), isEmpty);
  });

  test('10. rapid double invocation creates only one transfer', () async {
    await _addWallet('bank', 50000);
    await _addWallet('cash', 1000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    final notifier = container.read(walletsProvider.notifier);
    final first = notifier.transfer(fromWalletId: 'bank', toWalletId: 'cash', amount: 5000);
    final second = notifier.transfer(fromWalletId: 'bank', toWalletId: 'cash', amount: 5000);
    await Future.wait([first, second]);

    final bank = await WalletRepository.instance.getById('bank');
    final cash = await WalletRepository.instance.getById('cash');
    expect(bank!.currentBalance, 45000);
    expect(cash!.currentBalance, 6000);
    expect(await TransactionRepository.instance.getAll(), hasLength(2));
  });

  test('11. the two transaction legs of a historical transfer remain linked', () async {
    await _addWallet('bank', 50000);
    await _addWallet('cash', 1000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    await container.read(walletsProvider.notifier).transfer(
      fromWalletId: 'bank',
      toWalletId: 'cash',
      amount: 5000,
    );

    final all = await TransactionRepository.instance.getAll();
    expect(all, hasLength(2));
    final sourceLeg = all.firstWhere((t) => t.accountId == 'bank');
    final destinationLeg = all.firstWhere((t) => t.accountId == 'cash');

    expect(sourceLeg.transferId, isNotNull);
    expect(sourceLeg.transferId, destinationLeg.transferId);
    expect(sourceLeg.transferCounterpartyWalletId, 'cash');
    expect(destinationLeg.transferCounterpartyWalletId, 'bank');
  });

  test('12. archiving a wallet after a transfer does not corrupt transfer history', () async {
    await _addWallet('bank', 50000);
    await _addWallet('cash', 1000);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(walletsProvider.future);

    await container.read(walletsProvider.notifier).transfer(
      fromWalletId: 'bank',
      toWalletId: 'cash',
      amount: 5000,
    );

    await container.read(walletsProvider.notifier).archiveWallet('cash');

    final archived = await WalletRepository.instance.getById('cash');
    expect(archived, isNotNull);
    expect(archived!.isArchived, isTrue);
    expect(archived.currentBalance, 6000);

    final all = await TransactionRepository.instance.getAll();
    expect(all, hasLength(2));
    expect(all.every((t) => t.transferId != null), isTrue);
  });
}
