class FinancialContext {
  final String fullName;
  final double monthlyIncome;
  final double monthlyEmi;
  final double savingsGoal;
  final double totalWalletBalance;
  final double monthlyIncomeTotal;
  final double monthlyExpenseTotal;
  final double totalBudget;
  final double totalBudgetSpent;
  final double totalBudgetRemaining;
  final double budgetUsagePercentage;
  final String highestSpendingBudgetCategory;
  final String recentTransactionsSummary;
  final int totalGoals;
  final int completedGoals;
  final double totalTargetSavings;
  final double totalCurrentSavings;
  final String nearestGoal;
  final double goalCompletionPercentage;

  const FinancialContext({
    required this.fullName,
    required this.monthlyIncome,
    required this.monthlyEmi,
    required this.savingsGoal,
    required this.totalWalletBalance,
    required this.monthlyIncomeTotal,
    required this.monthlyExpenseTotal,
    required this.totalBudget,
    required this.totalBudgetSpent,
    required this.totalBudgetRemaining,
    required this.budgetUsagePercentage,
    required this.highestSpendingBudgetCategory,
    required this.recentTransactionsSummary,
    required this.totalGoals,
    required this.completedGoals,
    required this.totalTargetSavings,
    required this.totalCurrentSavings,
    required this.nearestGoal,
    required this.goalCompletionPercentage,
  });

  FinancialContext copyWith({
    String? fullName,
    double? monthlyIncome,
    double? monthlyEmi,
    double? savingsGoal,
    double? totalWalletBalance,
    double? monthlyIncomeTotal,
    double? monthlyExpenseTotal,
    double? totalBudget,
    double? totalBudgetSpent,
    double? totalBudgetRemaining,
    double? budgetUsagePercentage,
    String? highestSpendingBudgetCategory,
    String? recentTransactionsSummary,
    int? totalGoals,
    int? completedGoals,
    double? totalTargetSavings,
    double? totalCurrentSavings,
    String? nearestGoal,
    double? goalCompletionPercentage,
  }) {
    return FinancialContext(
      fullName: fullName ?? this.fullName,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      monthlyEmi: monthlyEmi ?? this.monthlyEmi,
      savingsGoal: savingsGoal ?? this.savingsGoal,
      totalWalletBalance: totalWalletBalance ?? this.totalWalletBalance,
      monthlyIncomeTotal: monthlyIncomeTotal ?? this.monthlyIncomeTotal,
      monthlyExpenseTotal: monthlyExpenseTotal ?? this.monthlyExpenseTotal,
      totalBudget: totalBudget ?? this.totalBudget,
      totalBudgetSpent: totalBudgetSpent ?? this.totalBudgetSpent,
      totalBudgetRemaining: totalBudgetRemaining ?? this.totalBudgetRemaining,
      budgetUsagePercentage:
          budgetUsagePercentage ?? this.budgetUsagePercentage,
      highestSpendingBudgetCategory:
          highestSpendingBudgetCategory ?? this.highestSpendingBudgetCategory,
      recentTransactionsSummary:
          recentTransactionsSummary ?? this.recentTransactionsSummary,
      totalGoals: totalGoals ?? this.totalGoals,
      completedGoals: completedGoals ?? this.completedGoals,
      totalTargetSavings: totalTargetSavings ?? this.totalTargetSavings,
      totalCurrentSavings: totalCurrentSavings ?? this.totalCurrentSavings,
      nearestGoal: nearestGoal ?? this.nearestGoal,
      goalCompletionPercentage:
          goalCompletionPercentage ?? this.goalCompletionPercentage,
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
      'totalBudget': totalBudget,
      'totalBudgetSpent': totalBudgetSpent,
      'totalBudgetRemaining': totalBudgetRemaining,
      'budgetUsagePercentage': budgetUsagePercentage,
      'highestSpendingBudgetCategory': highestSpendingBudgetCategory,
      'recentTransactionsSummary': recentTransactionsSummary,
      'totalGoals': totalGoals,
      'completedGoals': completedGoals,
      'totalTargetSavings': totalTargetSavings,
      'totalCurrentSavings': totalCurrentSavings,
      'nearestGoal': nearestGoal,
      'goalCompletionPercentage': goalCompletionPercentage,
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
    dynamic rawTotalBudget = map['totalBudget'];
    dynamic rawTotalBudgetSpent = map['totalBudgetSpent'];
    dynamic rawTotalBudgetRemaining = map['totalBudgetRemaining'];
    dynamic rawBudgetUsagePercentage = map['budgetUsagePercentage'];
    dynamic rawHighestSpendingBudgetCategory =
        map['highestSpendingBudgetCategory'];
    dynamic rawRecentTransactionsSummary = map['recentTransactionsSummary'];
    dynamic rawTotalGoals = map['totalGoals'];
    dynamic rawCompletedGoals = map['completedGoals'];
    dynamic rawTotalTargetSavings = map['totalTargetSavings'];
    dynamic rawTotalCurrentSavings = map['totalCurrentSavings'];
    dynamic rawNearestGoal = map['nearestGoal'];
    dynamic rawGoalCompletionPercentage = map['goalCompletionPercentage'];

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
    if (rawTotalBudget == null) {
      throw ArgumentError.notNull('totalBudget');
    }
    if (rawTotalBudgetSpent == null) {
      throw ArgumentError.notNull('totalBudgetSpent');
    }
    if (rawTotalBudgetRemaining == null) {
      throw ArgumentError.notNull('totalBudgetRemaining');
    }
    if (rawBudgetUsagePercentage == null) {
      throw ArgumentError.notNull('budgetUsagePercentage');
    }
    if (rawHighestSpendingBudgetCategory == null) {
      throw ArgumentError.notNull('highestSpendingBudgetCategory');
    }
    if (rawRecentTransactionsSummary == null) {
      throw ArgumentError.notNull('recentTransactionsSummary');
    }
    if (rawTotalGoals == null) {
      throw ArgumentError.notNull('totalGoals');
    }
    if (rawCompletedGoals == null) {
      throw ArgumentError.notNull('completedGoals');
    }
    if (rawTotalTargetSavings == null) {
      throw ArgumentError.notNull('totalTargetSavings');
    }
    if (rawTotalCurrentSavings == null) {
      throw ArgumentError.notNull('totalCurrentSavings');
    }
    if (rawNearestGoal == null) {
      throw ArgumentError.notNull('nearestGoal');
    }
    if (rawGoalCompletionPercentage == null) {
      throw ArgumentError.notNull('goalCompletionPercentage');
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

    int parseInt(dynamic v, String fieldName) {
      if (v is int) return v;
      if (v is double) return v.toInt();
      if (v is String) {
        final parsed = int.tryParse(v);
        if (parsed != null) return parsed;
        throw ArgumentError.value(v, fieldName, 'Cannot parse to int');
      }
      throw ArgumentError.value(v, fieldName, 'Invalid type for int');
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
    final totalBudget = parseDouble(rawTotalBudget, 'totalBudget');
    final totalBudgetSpent = parseDouble(
      rawTotalBudgetSpent,
      'totalBudgetSpent',
    );
    final totalBudgetRemaining = parseDouble(
      rawTotalBudgetRemaining,
      'totalBudgetRemaining',
    );
    final budgetUsagePercentage = parseDouble(
      rawBudgetUsagePercentage,
      'budgetUsagePercentage',
    );
    final highestSpendingBudgetCategory = rawHighestSpendingBudgetCategory
        .toString();
    final recentTransactionsSummary = rawRecentTransactionsSummary.toString();
    final totalGoals = parseInt(rawTotalGoals, 'totalGoals');
    final completedGoals = parseInt(rawCompletedGoals, 'completedGoals');
    final totalTargetSavings = parseDouble(
      rawTotalTargetSavings,
      'totalTargetSavings',
    );
    final totalCurrentSavings = parseDouble(
      rawTotalCurrentSavings,
      'totalCurrentSavings',
    );
    final nearestGoal = rawNearestGoal.toString();
    final goalCompletionPercentage = parseDouble(
      rawGoalCompletionPercentage,
      'goalCompletionPercentage',
    );

    return FinancialContext(
      fullName: fullName,
      monthlyIncome: monthlyIncome,
      monthlyEmi: monthlyEmi,
      savingsGoal: savingsGoal,
      totalWalletBalance: totalWalletBalance,
      monthlyIncomeTotal: monthlyIncomeTotal,
      monthlyExpenseTotal: monthlyExpenseTotal,
      totalBudget: totalBudget,
      totalBudgetSpent: totalBudgetSpent,
      totalBudgetRemaining: totalBudgetRemaining,
      budgetUsagePercentage: budgetUsagePercentage,
      highestSpendingBudgetCategory: highestSpendingBudgetCategory,
      recentTransactionsSummary: recentTransactionsSummary,
      totalGoals: totalGoals,
      completedGoals: completedGoals,
      totalTargetSavings: totalTargetSavings,
      totalCurrentSavings: totalCurrentSavings,
      nearestGoal: nearestGoal,
      goalCompletionPercentage: goalCompletionPercentage,
    );
  }
}
