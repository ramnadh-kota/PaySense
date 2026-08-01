import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/shared/models/transaction.dart';
import 'package:paysense/shared/repositories/transaction_repository.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository.instance;
});

final transactionsProvider = FutureProvider<List<Transaction>>((ref) async {
  final repository = ref.watch(transactionRepositoryProvider);
  return repository.getAll();
});
