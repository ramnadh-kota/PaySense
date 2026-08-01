import 'package:paysense/shared/models/transaction.dart';

/// In-memory repository for managing transactions.
class TransactionRepository {
  TransactionRepository._();

  static final TransactionRepository instance = TransactionRepository._();

  final List<Transaction> _transactions = <Transaction>[
    Transaction(
      id: 'tx-1',
      title: 'Salary',
      amount: 3200.0,
      categoryId: 'cat-income',
      accountId: 'acct-salary',
      transactionType: 'income',
      paymentMethod: 'bank',
      note: 'Monthly salary',
      createdAt: DateTime.utc(2024, 1, 10),
    ),
    Transaction(
      id: 'tx-2',
      title: 'Groceries',
      amount: 145.75,
      categoryId: 'cat-food',
      accountId: 'acct-checking',
      transactionType: 'expense',
      paymentMethod: 'card',
      note: 'Weekly groceries',
      createdAt: DateTime.utc(2024, 1, 12),
    ),
  ];

  Future<List<Transaction>> getAll() async {
    return List<Transaction>.unmodifiable(_transactions);
  }

  Future<Transaction?> getById(String id) async {
    for (final transaction in _transactions) {
      if (transaction.id == id) {
        return transaction;
      }
    }
    return null;
  }

  Future<void> add(Transaction transaction) async {
    if (!_transactions.any((item) => item.id == transaction.id)) {
      _transactions.add(transaction);
    }
  }

  Future<void> update(Transaction transaction) async {
    final index = _transactions.indexWhere((item) => item.id == transaction.id);
    if (index != -1) {
      _transactions[index] = transaction;
    }
  }

  Future<void> delete(String id) async {
    _transactions.removeWhere((transaction) => transaction.id == id);
  }
}
