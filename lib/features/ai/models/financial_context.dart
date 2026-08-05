class FinancialContext {
  final String fullName;
  final double monthlyIncome;
  final double monthlyEmi;
  final double savingsGoal;
  final double totalWalletBalance;
  final double monthlyIncomeTotal;
  final double monthlyExpenseTotal;
  final String recentTransactionsSummary;

  const FinancialContext({
    required this.fullName,
    required this.monthlyIncome,
    required this.monthlyEmi,
    required this.savingsGoal,
    required this.totalWalletBalance,
    required this.monthlyIncomeTotal,
    required this.monthlyExpenseTotal,
    required this.recentTransactionsSummary,
  });

  FinancialContext copyWith({
    String? fullName,
    double? monthlyIncome,
    double? monthlyEmi,
    double? savingsGoal,
    double? totalWalletBalance,
    double? monthlyIncomeTotal,
    double? monthlyExpenseTotal,
    String? recentTransactionsSummary,
  }) {
    return FinancialContext(
      fullName: fullName ?? this.fullName,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      monthlyEmi: monthlyEmi ?? this.monthlyEmi,
      savingsGoal: savingsGoal ?? this.savingsGoal,
      totalWalletBalance: totalWalletBalance ?? this.totalWalletBalance,
      monthlyIncomeTotal: monthlyIncomeTotal ?? this.monthlyIncomeTotal,
      monthlyExpenseTotal: monthlyExpenseTotal ?? this.monthlyExpenseTotal,
      recentTransactionsSummary:
          recentTransactionsSummary ?? this.recentTransactionsSummary,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'fullName': fullName,
      'monthlyIncome': monthlyIncome,
      'monthlyEmi': monthlyEmi,
      'savingsGoal': savingsGoal,
      'totalWalletBalance': totalWalletBalance,
      'monthlyIncomeTotal': monthlyIncomeTotal,
      'monthlyExpenseTotal': monthlyExpenseTotal,
      'recentTransactionsSummary': recentTransactionsSummary,
    };
  }

  factory FinancialContext.fromMap(Map<String, dynamic> map) {
    if (map.isEmpty) {
      throw ArgumentError.value(map, 'map', 'Map must not be empty');
    }

    dynamic rawFullName = map['fullName'];
    dynamic rawMonthlyIncome = map['monthlyIncome'];
    dynamic rawMonthlyEmi = map['monthlyEmi'];
    dynamic rawSavingsGoal = map['savingsGoal'];
    dynamic rawTotalWalletBalance = map['totalWalletBalance'];
    dynamic rawMonthlyIncomeTotal = map['monthlyIncomeTotal'];
    dynamic rawMonthlyExpenseTotal = map['monthlyExpenseTotal'];
    dynamic rawRecentTransactionsSummary = map['recentTransactionsSummary'];

    if (rawFullName == null) {
      throw ArgumentError.notNull('fullName');
    }
    if (rawMonthlyIncome == null) {
      throw ArgumentError.notNull('monthlyIncome');
    }
    if (rawMonthlyEmi == null) {
      throw ArgumentError.notNull('monthlyEmi');
    }
    if (rawSavingsGoal == null) {
      throw ArgumentError.notNull('savingsGoal');
    }
    if (rawTotalWalletBalance == null) {
      throw ArgumentError.notNull('totalWalletBalance');
    }
    if (rawMonthlyIncomeTotal == null) {
      throw ArgumentError.notNull('monthlyIncomeTotal');
    }
    if (rawMonthlyExpenseTotal == null) {
      throw ArgumentError.notNull('monthlyExpenseTotal');
    }
    if (rawRecentTransactionsSummary == null) {
      throw ArgumentError.notNull('recentTransactionsSummary');
    }

    String fullName = rawFullName.toString();

    double parseDouble(dynamic v, String fieldName) {
      if (v is double) return v;
      if (v is int) return v.toDouble();
      if (v is String) {
        final parsed = double.tryParse(v);
        if (parsed != null) return parsed;
        throw ArgumentError.value(v, fieldName, 'Cannot parse to double');
      }
      throw ArgumentError.value(v, fieldName, 'Invalid type for double');
    }

    final monthlyIncome = parseDouble(rawMonthlyIncome, 'monthlyIncome');
    final monthlyEmi = parseDouble(rawMonthlyEmi, 'monthlyEmi');
    final savingsGoal = parseDouble(rawSavingsGoal, 'savingsGoal');
    final totalWalletBalance = parseDouble(
      rawTotalWalletBalance,
      'totalWalletBalance',
    );
    final monthlyIncomeTotal = parseDouble(
      rawMonthlyIncomeTotal,
      'monthlyIncomeTotal',
    );
    final monthlyExpenseTotal = parseDouble(
      rawMonthlyExpenseTotal,
      'monthlyExpenseTotal',
    );

    final recentTransactionsSummary = rawRecentTransactionsSummary.toString();

    return FinancialContext(
      fullName: fullName,
      monthlyIncome: monthlyIncome,
      monthlyEmi: monthlyEmi,
      savingsGoal: savingsGoal,
      totalWalletBalance: totalWalletBalance,
      monthlyIncomeTotal: monthlyIncomeTotal,
      monthlyExpenseTotal: monthlyExpenseTotal,
      recentTransactionsSummary: recentTransactionsSummary,
    );
  }
}
