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
  final int totalRecurringTransactions;
  final int activeRecurringTransactions;
  final double monthlyRecurringIncome;
  final double monthlyRecurringExpense;
  final String nextUpcomingPayment;
  final String nextUpcomingPaymentDate;
  final int totalBills;
  final int unpaidBills;
  final int overdueBills;
  final double totalUnpaidBillsAmount;
  final String nextBillTitle;
  final String nextBillDueDate;
  final double totalLoanAmount;
  final double outstandingLoanAmount;

  /// Sum of active loans' monthly EMI (distinct from [monthlyEmi], which is
  /// the user's self-reported figure from profile setup).
  final double monthlyLoanEmi;
  final double totalInterestRemaining;
  final int activeLoanCount;
  final String nextLoanPayment;

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
    required this.totalRecurringTransactions,
    required this.activeRecurringTransactions,
    required this.monthlyRecurringIncome,
    required this.monthlyRecurringExpense,
    required this.nextUpcomingPayment,
    required this.nextUpcomingPaymentDate,
    required this.totalBills,
    required this.unpaidBills,
    required this.overdueBills,
    required this.totalUnpaidBillsAmount,
    required this.nextBillTitle,
    required this.nextBillDueDate,
    required this.totalLoanAmount,
    required this.outstandingLoanAmount,
    required this.monthlyLoanEmi,
    required this.totalInterestRemaining,
    required this.activeLoanCount,
    required this.nextLoanPayment,
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
    int? totalRecurringTransactions,
    int? activeRecurringTransactions,
    double? monthlyRecurringIncome,
    double? monthlyRecurringExpense,
    String? nextUpcomingPayment,
    String? nextUpcomingPaymentDate,
    int? totalBills,
    int? unpaidBills,
    int? overdueBills,
    double? totalUnpaidBillsAmount,
    String? nextBillTitle,
    String? nextBillDueDate,
    double? totalLoanAmount,
    double? outstandingLoanAmount,
    double? monthlyLoanEmi,
    double? totalInterestRemaining,
    int? activeLoanCount,
    String? nextLoanPayment,
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
      totalRecurringTransactions:
          totalRecurringTransactions ?? this.totalRecurringTransactions,
      activeRecurringTransactions:
          activeRecurringTransactions ?? this.activeRecurringTransactions,
      monthlyRecurringIncome:
          monthlyRecurringIncome ?? this.monthlyRecurringIncome,
      monthlyRecurringExpense:
          monthlyRecurringExpense ?? this.monthlyRecurringExpense,
      nextUpcomingPayment: nextUpcomingPayment ?? this.nextUpcomingPayment,
      nextUpcomingPaymentDate:
          nextUpcomingPaymentDate ?? this.nextUpcomingPaymentDate,
      totalBills: totalBills ?? this.totalBills,
      unpaidBills: unpaidBills ?? this.unpaidBills,
      overdueBills: overdueBills ?? this.overdueBills,
      totalUnpaidBillsAmount:
          totalUnpaidBillsAmount ?? this.totalUnpaidBillsAmount,
      nextBillTitle: nextBillTitle ?? this.nextBillTitle,
      nextBillDueDate: nextBillDueDate ?? this.nextBillDueDate,
      totalLoanAmount: totalLoanAmount ?? this.totalLoanAmount,
      outstandingLoanAmount: outstandingLoanAmount ?? this.outstandingLoanAmount,
      monthlyLoanEmi: monthlyLoanEmi ?? this.monthlyLoanEmi,
      totalInterestRemaining:
          totalInterestRemaining ?? this.totalInterestRemaining,
      activeLoanCount: activeLoanCount ?? this.activeLoanCount,
      nextLoanPayment: nextLoanPayment ?? this.nextLoanPayment,
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
      'totalRecurringTransactions': totalRecurringTransactions,
      'activeRecurringTransactions': activeRecurringTransactions,
      'monthlyRecurringIncome': monthlyRecurringIncome,
      'monthlyRecurringExpense': monthlyRecurringExpense,
      'nextUpcomingPayment': nextUpcomingPayment,
      'nextUpcomingPaymentDate': nextUpcomingPaymentDate,
      'totalBills': totalBills,
      'unpaidBills': unpaidBills,
      'overdueBills': overdueBills,
      'totalUnpaidBillsAmount': totalUnpaidBillsAmount,
      'nextBillTitle': nextBillTitle,
      'nextBillDueDate': nextBillDueDate,
      'totalLoanAmount': totalLoanAmount,
      'outstandingLoanAmount': outstandingLoanAmount,
      'monthlyLoanEmi': monthlyLoanEmi,
      'totalInterestRemaining': totalInterestRemaining,
      'activeLoanCount': activeLoanCount,
      'nextLoanPayment': nextLoanPayment,
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
    dynamic rawTotalRecurringTransactions = map['totalRecurringTransactions'];
    dynamic rawActiveRecurringTransactions =
        map['activeRecurringTransactions'];
    dynamic rawMonthlyRecurringIncome = map['monthlyRecurringIncome'];
    dynamic rawMonthlyRecurringExpense = map['monthlyRecurringExpense'];
    dynamic rawNextUpcomingPayment = map['nextUpcomingPayment'];
    dynamic rawNextUpcomingPaymentDate = map['nextUpcomingPaymentDate'];
    dynamic rawTotalBills = map['totalBills'];
    dynamic rawUnpaidBills = map['unpaidBills'];
    dynamic rawOverdueBills = map['overdueBills'];
    dynamic rawTotalUnpaidBillsAmount = map['totalUnpaidBillsAmount'];
    dynamic rawNextBillTitle = map['nextBillTitle'];
    dynamic rawNextBillDueDate = map['nextBillDueDate'];
    dynamic rawTotalLoanAmount = map['totalLoanAmount'];
    dynamic rawOutstandingLoanAmount = map['outstandingLoanAmount'];
    dynamic rawMonthlyLoanEmi = map['monthlyLoanEmi'];
    dynamic rawTotalInterestRemaining = map['totalInterestRemaining'];
    dynamic rawActiveLoanCount = map['activeLoanCount'];
    dynamic rawNextLoanPayment = map['nextLoanPayment'];

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
    if (rawTotalRecurringTransactions == null) {
      throw ArgumentError.notNull('totalRecurringTransactions');
    }
    if (rawActiveRecurringTransactions == null) {
      throw ArgumentError.notNull('activeRecurringTransactions');
    }
    if (rawMonthlyRecurringIncome == null) {
      throw ArgumentError.notNull('monthlyRecurringIncome');
    }
    if (rawMonthlyRecurringExpense == null) {
      throw ArgumentError.notNull('monthlyRecurringExpense');
    }
    if (rawNextUpcomingPayment == null) {
      throw ArgumentError.notNull('nextUpcomingPayment');
    }
    if (rawNextUpcomingPaymentDate == null) {
      throw ArgumentError.notNull('nextUpcomingPaymentDate');
    }
    if (rawTotalBills == null) {
      throw ArgumentError.notNull('totalBills');
    }
    if (rawUnpaidBills == null) {
      throw ArgumentError.notNull('unpaidBills');
    }
    if (rawOverdueBills == null) {
      throw ArgumentError.notNull('overdueBills');
    }
    if (rawTotalUnpaidBillsAmount == null) {
      throw ArgumentError.notNull('totalUnpaidBillsAmount');
    }
    if (rawNextBillTitle == null) {
      throw ArgumentError.notNull('nextBillTitle');
    }
    if (rawNextBillDueDate == null) {
      throw ArgumentError.notNull('nextBillDueDate');
    }
    if (rawTotalLoanAmount == null) {
      throw ArgumentError.notNull('totalLoanAmount');
    }
    if (rawOutstandingLoanAmount == null) {
      throw ArgumentError.notNull('outstandingLoanAmount');
    }
    if (rawMonthlyLoanEmi == null) {
      throw ArgumentError.notNull('monthlyLoanEmi');
    }
    if (rawTotalInterestRemaining == null) {
      throw ArgumentError.notNull('totalInterestRemaining');
    }
    if (rawActiveLoanCount == null) {
      throw ArgumentError.notNull('activeLoanCount');
    }
    if (rawNextLoanPayment == null) {
      throw ArgumentError.notNull('nextLoanPayment');
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
    final totalRecurringTransactions = parseInt(
      rawTotalRecurringTransactions,
      'totalRecurringTransactions',
    );
    final activeRecurringTransactions = parseInt(
      rawActiveRecurringTransactions,
      'activeRecurringTransactions',
    );
    final monthlyRecurringIncome = parseDouble(
      rawMonthlyRecurringIncome,
      'monthlyRecurringIncome',
    );
    final monthlyRecurringExpense = parseDouble(
      rawMonthlyRecurringExpense,
      'monthlyRecurringExpense',
    );
    final nextUpcomingPayment = rawNextUpcomingPayment.toString();
    final nextUpcomingPaymentDate = rawNextUpcomingPaymentDate.toString();
    final totalBills = parseInt(rawTotalBills, 'totalBills');
    final unpaidBills = parseInt(rawUnpaidBills, 'unpaidBills');
    final overdueBills = parseInt(rawOverdueBills, 'overdueBills');
    final totalUnpaidBillsAmount = parseDouble(
      rawTotalUnpaidBillsAmount,
      'totalUnpaidBillsAmount',
    );
    final nextBillTitle = rawNextBillTitle.toString();
    final nextBillDueDate = rawNextBillDueDate.toString();
    final totalLoanAmount = parseDouble(rawTotalLoanAmount, 'totalLoanAmount');
    final outstandingLoanAmount = parseDouble(
      rawOutstandingLoanAmount,
      'outstandingLoanAmount',
    );
    final monthlyLoanEmi = parseDouble(rawMonthlyLoanEmi, 'monthlyLoanEmi');
    final totalInterestRemaining = parseDouble(
      rawTotalInterestRemaining,
      'totalInterestRemaining',
    );
    final activeLoanCount = parseInt(rawActiveLoanCount, 'activeLoanCount');
    final nextLoanPayment = rawNextLoanPayment.toString();

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
      totalRecurringTransactions: totalRecurringTransactions,
      activeRecurringTransactions: activeRecurringTransactions,
      monthlyRecurringIncome: monthlyRecurringIncome,
      monthlyRecurringExpense: monthlyRecurringExpense,
      nextUpcomingPayment: nextUpcomingPayment,
      nextUpcomingPaymentDate: nextUpcomingPaymentDate,
      totalBills: totalBills,
      unpaidBills: unpaidBills,
      overdueBills: overdueBills,
      totalUnpaidBillsAmount: totalUnpaidBillsAmount,
      nextBillTitle: nextBillTitle,
      nextBillDueDate: nextBillDueDate,
      totalLoanAmount: totalLoanAmount,
      outstandingLoanAmount: outstandingLoanAmount,
      monthlyLoanEmi: monthlyLoanEmi,
      totalInterestRemaining: totalInterestRemaining,
      activeLoanCount: activeLoanCount,
      nextLoanPayment: nextLoanPayment,
    );
  }
}
