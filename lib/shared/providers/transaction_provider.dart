import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository.instance;
});

final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<Transaction>>(
      TransactionsNotifier.new,
    );

class TransactionsNotifier extends AsyncNotifier<List<Transaction>> {
  @override
  Future<List<Transaction>> build() async {
    final repository = ref.watch(transactionRepositoryProvider);
    return repository.getAll();
  }

  Future<void> reload() async {
    state = const AsyncLoading<List<Transaction>>();
    final repository = ref.read(transactionRepositoryProvider);
    state = await AsyncValue.guard<List<Transaction>>(
      () => repository.getAll(),
    );
  }
}
