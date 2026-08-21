/// Deterministic, keyword-based routing for AI Financial Assistant
/// questions — deliberately NOT an NLP/intent-classification model. Maps a
/// user's free-text question to the [FinancialQuestionCategory] set it most
/// likely concerns, so [FinancialContextBuilder] can send a trimmed,
/// relevant slice of financial context instead of always sending
/// everything. When nothing matches confidently, [classifyQuestion] returns
/// [FinancialQuestionCategory.general] alone, which
/// [FinancialContextBuilder] treats as "include everything" — the safe
/// fallback the spec calls for.
library;

enum FinancialQuestionCategory {
  spending,
  budget,
  savings,
  goals,
  emergencyFund,
  debt,
  bills,
  subscriptions,
  cashFlow,
  safeToSpend,
  financialHealth,
  financialPlanning,
  reports,

  /// Placeholder category for a future Tax Planning conversation flow (see
  /// PHASE 11 in the milestone spec) — the AI may discuss general tax
  /// concepts today, but there is no deterministic tax calculator behind
  /// this category yet. Intentionally inert: nothing currently routes
  /// context differently for it beyond the general fallback.
  taxPlanning,

  general,
}

/// Keyword sets are intentionally small and literal — this is pattern
/// matching, not NLP. A question can match multiple categories (e.g. "can I
/// afford ₹5,000 today" matches both safeToSpend and cashFlow); all matches
/// are returned so the caller can union their contexts.
const Map<FinancialQuestionCategory, List<String>> _categoryKeywords = {
  FinancialQuestionCategory.spending: [
    'spend', 'spent', 'spending', 'expense', 'expenses', 'wasting', 'waste',
    'where is my money', 'where did my money',
  ],
  FinancialQuestionCategory.budget: ['budget', 'budgets', 'overspend', 'overspent'],
  FinancialQuestionCategory.savings: [
    'save', 'saving', 'savings', 'savings rate', 'save more', 'increase my savings',
  ],
  FinancialQuestionCategory.goals: ['goal', 'goals', 'on track', 'vacation', 'target amount'],
  FinancialQuestionCategory.emergencyFund: ['emergency fund', 'emergency savings', 'rainy day'],
  FinancialQuestionCategory.debt: [
    'loan', 'loans', 'debt', 'emi', 'emis', 'interest rate', 'pay off', 'payoff',
  ],
  FinancialQuestionCategory.bills: ['bill', 'bills', 'due date', 'overdue'],
  FinancialQuestionCategory.subscriptions: ['subscription', 'subscriptions', 'netflix', 'recurring payment'],
  FinancialQuestionCategory.cashFlow: [
    'cash flow', 'cashflow', 'upcoming', 'after my bills', 'left after',
  ],
  FinancialQuestionCategory.safeToSpend: [
    'can i afford', 'can i spend', 'safe to spend', 'afford to spend', 'afford this',
    'safely spend', 'how much can i spend',
  ],
  FinancialQuestionCategory.financialHealth: ['financial health', 'how am i doing', 'wellness score'],
  FinancialQuestionCategory.financialPlanning: [
    'financial planning', 'financially prepared', 'net worth', 'readiness',
    'what should i do with', 'next salary',
  ],
  FinancialQuestionCategory.reports: ['report', 'reports', 'this month vs', 'compare', 'trend'],
  FinancialQuestionCategory.taxPlanning: ['tax', 'taxes', 'income tax', 'deduction', 'itr', 'tax filing'],
};

/// Classifies [question] into one or more categories by simple, literal
/// (case-insensitive) substring matching. Returns `{general}` alone when
/// nothing matches — the caller should treat that as "use the full,
/// unfiltered financial context" rather than guessing at a narrower one.
Set<FinancialQuestionCategory> classifyQuestion(String question) {
  final normalized = question.toLowerCase();
  final matches = <FinancialQuestionCategory>{};

  for (final entry in _categoryKeywords.entries) {
    if (entry.value.any(normalized.contains)) {
      matches.add(entry.key);
    }
  }

  return matches.isEmpty ? {FinancialQuestionCategory.general} : matches;
}
