import '../../core/routes/app_routes.dart';
import '../models/bill.dart';
import '../models/financial_search_result.dart';
import '../models/goal.dart';
import '../models/loan.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../models/wallet.dart';
import 'safe_to_spend_calculator.dart';

/// PAYSENSE SEARCH — PART E/F. A deterministic, rule-based financial data
/// search + a small deterministic natural-language answer engine. This
/// is the "Can deterministic engine answer?" box in the Search+AI hybrid
/// architecture (PART L) — AI is never consulted for anything this class
/// can already answer from real, existing data.
///
/// Two kinds of result:
/// - [FinancialSearchEngine.search] — a browsing-style query ("Swiggy",
///   "transactions above 5000") returns a ranked list of
///   [FinancialSearchResult]s to display and let the user open.
/// - [FinancialSearchEngine.answer] — a question with one clear numeric/
///   factual answer ("how much did I spend this month?") returns a single
///   [FinancialSearchAnswer] computed directly from real records — never
///   AI-generated, never a duplicated calculator formula (these are plain
///   sums/comparisons over already-existing data, not a
///   `FinancialHealthCalculator`-style derived metric).
class FinancialSearchEngine {
  FinancialSearchEngine._();

  static final RegExp _amountAbovePattern = RegExp(r'(?:above|over|more than)\s*₹?\s*([\d,]+)', caseSensitive: false);
  static final RegExp _amountBelowPattern = RegExp(r'(?:below|under|less than)\s*₹?\s*([\d,]+)', caseSensitive: false);
  static final RegExp _betweenDatesPattern = RegExp(
    r'between\s+([a-z]+ \d{1,2})\s+and\s+([a-z]+ \d{1,2})',
    caseSensitive: false,
  );

  /// Attempts a direct, computed answer first. Returns `null` when the
  /// query isn't one of the recognized question forms — callers should
  /// then fall back to [search], and only to AI if neither yields
  /// anything (PART L).
  static FinancialSearchAnswer? answer({
    required String query,
    required List<Transaction> transactions,
    required List<Wallet> wallets,
    required List<Loan> loans,
    required DateTime now,
    List<Bill> bills = const [],
    List<RecurringTransaction> recurringTransactions = const [],
    SafeToSpendResult? safeToSpend,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;

    final thisMonthStart = DateTime(now.year, now.month, 1);
    final thisMonthEnd = DateTime(now.year, now.month + 1, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final weekStart = now.subtract(const Duration(days: 7));

    bool inRange(DateTime date, DateTime start, DateTime end) => !date.isBefore(start) && date.isBefore(end);

    double sumExpense(DateTime start, DateTime end, {String? category}) {
      return transactions
          .where((t) =>
              t.transactionType == 'expense' &&
              inRange(t.createdAt, start, end) &&
              (category == null || t.categoryId.toLowerCase().contains(category) || t.title.toLowerCase().contains(category)))
          .fold(0.0, (sum, t) => sum + t.amount);
    }

    // "how much did I spend this week"
    if (q.contains('how much') && q.contains('spend') && q.contains('this week') && !q.contains(' on ')) {
      final total = sumExpense(weekStart, now.add(const Duration(days: 1)));
      return FinancialSearchAnswer(question: query, answer: 'You\'ve spent ₹${total.toStringAsFixed(0)} this week.', amount: total);
    }

    // "how much did I spend this month"
    if (q.contains('how much') && q.contains('spend') && q.contains('this month') && !q.contains(' on ')) {
      final total = sumExpense(thisMonthStart, thisMonthEnd);
      return FinancialSearchAnswer(question: query, answer: 'You\'ve spent ₹${total.toStringAsFixed(0)} this month.', amount: total);
    }

    // "where am I spending the most" / "biggest spending category"
    if ((q.contains('where') && q.contains('spending')) || q.contains('spending the most') || q.contains('biggest spending category')) {
      final totalsByCategory = <String, double>{};
      for (final t in transactions) {
        if (t.transactionType.toLowerCase() != 'expense') continue;
        if (!inRange(t.createdAt, thisMonthStart, thisMonthEnd)) continue;
        totalsByCategory[t.categoryId] = (totalsByCategory[t.categoryId] ?? 0) + t.amount;
      }
      if (totalsByCategory.isEmpty) {
        return const FinancialSearchAnswer(question: '', answer: 'No spending recorded this month yet.');
      }
      final top = totalsByCategory.entries.reduce((a, b) => a.value >= b.value ? a : b);
      return FinancialSearchAnswer(
        question: query,
        answer: 'You\'re spending the most on ${top.key}: ₹${top.value.toStringAsFixed(0)} this month.',
        amount: top.value,
      );
    }

    // "how much do I owe"
    if (q.contains('how much') && q.contains('owe')) {
      final activeLoans = loans.where((l) => l.isActive).toList();
      if (activeLoans.isEmpty) {
        return const FinancialSearchAnswer(question: '', answer: 'You don\'t owe anything on any active loans.');
      }
      final total = activeLoans.fold<double>(0, (sum, l) => sum + l.outstandingAmount);
      return FinancialSearchAnswer(
        question: query,
        answer: 'You owe ₹${total.toStringAsFixed(0)} across ${activeLoans.length} active loan${activeLoans.length == 1 ? '' : 's'}.',
        amount: total,
      );
    }

    // "how much can I safely spend" — reuses an already-computed SafeToSpendResult; omitted if none supplied.
    if (safeToSpend != null && q.contains('how much') && q.contains('safe') && q.contains('spend')) {
      return FinancialSearchAnswer(
        question: query,
        answer: 'PaySense estimates you can safely spend ₹${safeToSpend.safeToSpend.toStringAsFixed(0)} '
            'after your upcoming bills and EMIs.',
        amount: safeToSpend.safeToSpend,
      );
    }

    // "how much did I spend on food" / "how much did I spend on X"
    final spendOnMatch = RegExp(r'how much.*spend.*on\s+([a-z ]+?)(?:\s+this month|\s+last month)?$').firstMatch(q);
    if (spendOnMatch != null) {
      final category = spendOnMatch.group(1)!.trim();
      final useLastMonth = q.contains('last month');
      final start = useLastMonth ? lastMonthStart : thisMonthStart;
      final end = useLastMonth ? thisMonthStart : thisMonthEnd;
      final total = sumExpense(start, end, category: category);
      return FinancialSearchAnswer(
        question: query,
        answer: 'You\'ve spent ₹${total.toStringAsFixed(0)} on $category ${useLastMonth ? 'last month' : 'this month'}.',
        amount: total,
      );
    }

    // "which wallet has the most money"
    if (q.contains('which wallet') && (q.contains('most money') || q.contains('most balance') || q.contains('highest balance'))) {
      if (wallets.isEmpty) {
        return const FinancialSearchAnswer(question: '', answer: 'You don\'t have any wallets yet.');
      }
      final richest = wallets.reduce((a, b) => a.currentBalance > b.currentBalance ? a : b);
      return FinancialSearchAnswer(
        question: query,
        answer: '${richest.name} has the most money: ₹${richest.currentBalance.toStringAsFixed(0)}.',
        amount: richest.currentBalance,
      );
    }

    // "how much money came in this month" / "money in this month"
    if ((q.contains('money came in') || q.contains('money in') || (q.contains('how much') && q.contains('income'))) && q.contains('this month')) {
      final total = transactions
          .where((t) => t.transactionType == 'income' && inRange(t.createdAt, thisMonthStart, thisMonthEnd))
          .fold(0.0, (sum, t) => sum + t.amount);
      return FinancialSearchAnswer(question: query, answer: '₹${total.toStringAsFixed(0)} came in this month.', amount: total);
    }

    // "how much money went out this month" / "money out this month"
    if ((q.contains('money went out') || q.contains('money out')) && q.contains('this month')) {
      final total = sumExpense(thisMonthStart, thisMonthEnd);
      return FinancialSearchAnswer(question: query, answer: '₹${total.toStringAsFixed(0)} went out this month.', amount: total);
    }

    // "what bills are due" / "bills due"
    if (q.contains('bills due') || (q.contains('what bills') && q.contains('due'))) {
      final unpaid = bills.where((b) => !b.isPaid).toList()..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      if (unpaid.isEmpty) {
        return const FinancialSearchAnswer(question: '', answer: 'No bills are due right now.');
      }
      final total = unpaid.fold(0.0, (sum, b) => sum + b.amount);
      final next = unpaid.first;
      return FinancialSearchAnswer(
        question: query,
        answer: '${unpaid.length} bill${unpaid.length == 1 ? '' : 's'} due, totalling ₹${total.toStringAsFixed(0)}. '
            'Next: ${next.title} (₹${next.amount.toStringAsFixed(0)}) on ${next.dueDate.day}/${next.dueDate.month}/${next.dueDate.year}.',
        amount: total,
      );
    }

    // "how much recurring money do I have" / "total recurring"
    if ((q.contains('recurring') || q.contains('subscriptions')) &&
        (q.contains('how much') || q.contains('total'))) {
      final active = recurringTransactions.where((r) => r.isActive && r.transactionType == 'expense').toList();
      if (active.isEmpty) {
        return const FinancialSearchAnswer(question: '', answer: 'You don\'t have any active recurring payments.');
      }
      final monthlyTotal = active.fold(0.0, (sum, r) => sum + r.monthlyEquivalentAmount);
      return FinancialSearchAnswer(
        question: query,
        answer: 'You have ${active.length} active recurring payment${active.length == 1 ? '' : 's'} totalling about '
            '₹${monthlyTotal.toStringAsFixed(0)} per month.',
        amount: monthlyTotal,
      );
    }

    // "when is my next EMI"
    if (q.contains('next emi') || (q.contains('when') && q.contains('emi'))) {
      final activeLoans = loans.where((l) => l.isActive).toList()..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
      if (activeLoans.isEmpty) {
        return const FinancialSearchAnswer(question: '', answer: 'You don\'t have any active loans.');
      }
      final next = activeLoans.first;
      return FinancialSearchAnswer(
        question: query,
        answer: 'Your next EMI is ₹${next.emiAmount.toStringAsFixed(0)} for ${next.loanName} on '
            '${next.nextDueDate.day}/${next.nextDueDate.month}/${next.nextDueDate.year}.',
        amount: next.emiAmount,
      );
    }

    return null;
  }

  /// Browsing-style search across transactions, wallets, and recurring
  /// payments — ranked, deterministic, never AI. Amount/date filters are
  /// parsed from the query text itself (e.g. "transactions above 5000").
  static List<FinancialSearchResult> search({
    required String query,
    required List<Transaction> transactions,
    required List<Wallet> wallets,
    required List<RecurringTransaction> recurringTransactions,
    required List<Loan> loans,
    required List<Goal> goals,
    required DateTime now,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];

    final walletNameById = {for (final w in wallets) w.id: w.name};
    final walletBankById = {for (final w in wallets) w.id: w.bankName.toLowerCase()};

    // "show my Swiggy spending" / "Swiggy spending" — extracts the
    // merchant/category term rather than requiring it to be the WHOLE
    // query, so a phrase like this actually matches (a bare "Swiggy"
    // query already worked via the fallback below; this covers the
    // fuller phrasing too).
    final spendingPhraseMatch = RegExp(r'^(?:show\s+(?:my\s+)?)?([a-z0-9 ]+?)\s+spending$').firstMatch(q);
    if (spendingPhraseMatch != null) {
      final term = spendingPhraseMatch.group(1)!.trim();
      if (term.isNotEmpty) {
        final results = transactions
            .where((t) => t.title.toLowerCase().contains(term) || t.categoryId.toLowerCase().contains(term))
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        if (results.isNotEmpty) {
          return results.map((t) => _transactionResult(t, walletNameById)).toList();
        }
      }
    }

    // "my biggest expenses"
    if (q.contains('biggest expense')) {
      final expenses = transactions.where((t) => t.transactionType == 'expense').toList()
        ..sort((a, b) => b.amount.compareTo(a.amount));
      return expenses.take(10).map((t) => _transactionResult(t, walletNameById)).toList();
    }

    // amount filters: "transactions above 5000" / "below 1000"
    final aboveMatch = _amountAbovePattern.firstMatch(q);
    final belowMatch = _amountBelowPattern.firstMatch(q);
    if (aboveMatch != null || belowMatch != null) {
      var results = transactions.toList();
      if (aboveMatch != null) {
        final threshold = double.parse(aboveMatch.group(1)!.replaceAll(',', ''));
        results = results.where((t) => t.amount > threshold).toList();
      }
      if (belowMatch != null) {
        final threshold = double.parse(belowMatch.group(1)!.replaceAll(',', ''));
        results = results.where((t) => t.amount < threshold).toList();
      }
      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return results.map((t) => _transactionResult(t, walletNameById)).toList();
    }

    // "show income this month" / "show expenses last month"
    if (q.contains('income') || q.contains('expense')) {
      final wantsIncome = q.contains('income');
      final thisMonthStart = DateTime(now.year, now.month, 1);
      final thisMonthEnd = DateTime(now.year, now.month + 1, 1);
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);
      DateTime? start;
      DateTime? end;
      if (q.contains('this month')) {
        start = thisMonthStart;
        end = thisMonthEnd;
      } else if (q.contains('last month')) {
        start = lastMonthStart;
        end = thisMonthStart;
      }
      var results = transactions.where((t) => t.transactionType == (wantsIncome ? 'income' : 'expense')).toList();
      if (start != null && end != null) {
        results = results.where((t) => !t.createdAt.isBefore(start!) && t.createdAt.isBefore(end!)).toList();
      }
      results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return results.map((t) => _transactionResult(t, walletNameById)).toList();
    }

    // "show transactions from HDFC" — by wallet/bank name.
    final fromMatch = RegExp(r'from\s+([a-z ]+)$').firstMatch(q);
    if (fromMatch != null) {
      final bank = fromMatch.group(1)!.trim();
      final results = transactions.where((t) {
        final walletName = (walletNameById[t.accountId] ?? '').toLowerCase();
        final bankName = walletBankById[t.accountId] ?? '';
        return walletName.contains(bank) || bankName.contains(bank);
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return results.map((t) => _transactionResult(t, walletNameById)).toList();
    }

    // "transactions between June 1 and June 30"
    final betweenMatch = _betweenDatesPattern.firstMatch(q);
    if (betweenMatch != null) {
      final start = _parseLooseDate(betweenMatch.group(1)!, now.year);
      final end = _parseLooseDate(betweenMatch.group(2)!, now.year);
      if (start != null && end != null) {
        final inclusiveEnd = end.add(const Duration(days: 1));
        final results = transactions.where((t) => !t.createdAt.isBefore(start) && t.createdAt.isBefore(inclusiveEnd)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return results.map((t) => _transactionResult(t, walletNameById)).toList();
      }
    }

    // "show my loans"
    if (q.contains('loan')) {
      final results = loans.toList()..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
      return results
          .map((l) => FinancialSearchResult(
                type: FinancialSearchResultType.loan,
                title: l.loanName,
                subtitle: 'EMI ₹${l.emiAmount.toStringAsFixed(0)} · next ${l.nextDueDate.day}/${l.nextDueDate.month}',
                amount: l.emiAmount,
                date: l.nextDueDate,
                route: AppRoutes.loans,
                entityId: l.id,
              ))
          .toList();
    }

    // "which subscriptions are costing me the most" — ranked by real
    // monthly-equivalent cost (RecurringTransaction.monthlyEquivalentAmount
    // — the SAME normalization used elsewhere, never re-derived here).
    if (q.contains('subscription') && (q.contains('most') || q.contains('costing') || q.contains('expensive'))) {
      final active = recurringTransactions.where((r) => r.isActive && r.transactionType == 'expense').toList()
        ..sort((a, b) => b.monthlyEquivalentAmount.compareTo(a.monthlyEquivalentAmount));
      return active
          .map((r) => FinancialSearchResult(
                type: FinancialSearchResultType.recurring,
                title: r.title,
                subtitle: '${r.frequency} · ₹${r.monthlyEquivalentAmount.toStringAsFixed(0)}/month',
                amount: r.monthlyEquivalentAmount,
                date: r.nextDueDate,
                route: AppRoutes.recurring,
                entityId: r.id,
              ))
          .toList();
    }

    // "show my subscriptions" / "what are my recurring payments" / "what payments are coming up"
    if (q.contains('recurring') || q.contains('subscription') || (q.contains('payment') && (q.contains('coming up') || q.contains('due')))) {
      final active = recurringTransactions.where((r) => r.isActive).toList()
        ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));
      return active
          .map((r) => FinancialSearchResult(
                type: FinancialSearchResultType.recurring,
                title: r.title,
                subtitle: '${r.frequency} · ₹${r.amount.toStringAsFixed(0)}',
                amount: r.amount,
                date: r.nextDueDate,
                route: AppRoutes.recurring,
                entityId: r.id,
              ))
          .toList();
    }

    // Fallback: plain keyword match across transaction title/category,
    // wallet name, recurring title, loan name, goal title.
    final results = <FinancialSearchResult>[];
    results.addAll(
      transactions
          .where((t) => t.title.toLowerCase().contains(q) || t.categoryId.toLowerCase().contains(q))
          .map((t) => _transactionResult(t, walletNameById)),
    );
    results.addAll(
      wallets.where((w) => w.name.toLowerCase().contains(q) || w.bankName.toLowerCase().contains(q)).map(
            (w) => FinancialSearchResult(
              type: FinancialSearchResultType.wallet,
              title: w.name,
              subtitle: '₹${w.currentBalance.toStringAsFixed(0)}',
              amount: w.currentBalance,
              route: AppRoutes.wallet,
              entityId: w.id,
            ),
          ),
    );
    results.addAll(
      recurringTransactions.where((r) => r.title.toLowerCase().contains(q)).map(
            (r) => FinancialSearchResult(
              type: FinancialSearchResultType.recurring,
              title: r.title,
              subtitle: '${r.frequency} · ₹${r.amount.toStringAsFixed(0)}',
              amount: r.amount,
              date: r.nextDueDate,
              route: AppRoutes.recurring,
              entityId: r.id,
            ),
          ),
    );
    results.addAll(
      loans.where((l) => l.loanName.toLowerCase().contains(q) || l.lenderName.toLowerCase().contains(q)).map(
            (l) => FinancialSearchResult(
              type: FinancialSearchResultType.loan,
              title: l.loanName,
              subtitle: 'EMI ₹${l.emiAmount.toStringAsFixed(0)} · next ${l.nextDueDate.day}/${l.nextDueDate.month}',
              amount: l.emiAmount,
              date: l.nextDueDate,
              route: AppRoutes.loans,
              entityId: l.id,
            ),
          ),
    );
    results.addAll(
      goals.where((g) => g.title.toLowerCase().contains(q)).map(
            (g) => FinancialSearchResult(
              type: FinancialSearchResultType.goal,
              title: g.title,
              subtitle: '₹${g.currentAmount.toStringAsFixed(0)} of ₹${g.targetAmount.toStringAsFixed(0)}',
              amount: g.targetAmount,
              date: g.targetDate,
              route: AppRoutes.goals,
              entityId: g.id,
            ),
          ),
    );
    return results;
  }

  static FinancialSearchResult _transactionResult(Transaction t, Map<String, String> walletNameById) {
    return FinancialSearchResult(
      type: FinancialSearchResultType.transaction,
      title: t.title,
      subtitle: '${walletNameById[t.accountId] ?? 'Unknown wallet'} · ${t.createdAt.day}/${t.createdAt.month}/${t.createdAt.year}',
      amount: t.amount,
      date: t.createdAt,
      route: AppRoutes.transactions,
      entityId: t.id,
    );
  }

  static const _monthNames = [
    'jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec',
  ];

  /// Parses "June 1" / "jun 30" style fragments — deliberately narrow
  /// (no year, no ambiguous numeric formats) since this only supports the
  /// "between X and Y" query form, always relative to [assumedYear].
  static DateTime? _parseLooseDate(String fragment, int assumedYear) {
    final match = RegExp(r'([a-z]+)\s+(\d{1,2})').firstMatch(fragment.trim());
    if (match == null) return null;
    final monthText = match.group(1)!.substring(0, 3);
    final monthIndex = _monthNames.indexOf(monthText);
    if (monthIndex == -1) return null;
    final day = int.tryParse(match.group(2)!);
    if (day == null) return null;
    return DateTime(assumedYear, monthIndex + 1, day);
  }
}
