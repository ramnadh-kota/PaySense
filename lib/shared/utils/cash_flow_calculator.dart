import 'package:flutter/foundation.dart';

import '../models/bill.dart';
import '../models/cash_flow_event.dart';
import '../models/loan.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';

/// How many months of navigation are allowed either side of the current
/// month — the calendar is a planning surface, not an unlimited archive.
const int cashFlowMonthRangeInMonths = 12;

/// How many items [CashFlowCalculator.upcomingEvents] returns by default.
const int cashFlowDefaultUpcomingLimit = 5;

@immutable
class CashFlowMonthSummary {
  const CashFlowMonthSummary({
    required this.recordedIncome,
    required this.recordedExpense,
    required this.upcomingIncome,
    required this.upcomingExpense,
    required this.hasActivity,
  });

  final double recordedIncome;
  final double recordedExpense;
  final double upcomingIncome;
  final double upcomingExpense;

  /// False when the month has no events at all — callers should show an
  /// empty-month message rather than a fabricated ₹0 summary.
  final bool hasActivity;

  double get expectedIncome => recordedIncome + upcomingIncome;
  double get expectedExpense => recordedExpense + upcomingExpense;
  double get expectedNet => expectedIncome - expectedExpense;
}

@immutable
class CashFlowDaySummary {
  const CashFlowDaySummary({
    required this.recordedIncome,
    required this.recordedExpenses,
    required this.upcoming,
    required this.totalOutgoing,
    required this.netExpectedMovement,
  });

  final List<CashFlowEvent> recordedIncome;
  final List<CashFlowEvent> recordedExpenses;

  /// Not-yet-recorded events due this day — bills, EMIs, recurring
  /// payments/income — regardless of inflow/outflow direction.
  final List<CashFlowEvent> upcoming;

  /// Sum of every outflow event this day, recorded or upcoming.
  final double totalOutgoing;

  /// Sum of every inflow event minus [totalOutgoing] — deliberately blends
  /// recorded and upcoming for a single day (labeled "expected", not
  /// "recorded"), since the sections above already distinguish the two.
  final double netExpectedMovement;

  bool get hasEvents =>
      recordedIncome.isNotEmpty || recordedExpenses.isNotEmpty || upcoming.isNotEmpty;
}

/// Pure, deterministic Cash Flow calculation. No Flutter/Riverpod
/// dependency — transforms existing Transaction/Bill/Loan/RecurringTransaction
/// data into [CashFlowEvent]s without inventing values or generating
/// synthetic future transactions.
class CashFlowCalculator {
  CashFlowCalculator._();

  /// All events whose date falls within [month] (any date in the target
  /// month; only year/month are used), recorded and upcoming combined.
  static List<CashFlowEvent> eventsForMonth({
    required List<Transaction> transactions,
    required List<Bill> bills,
    required List<Loan> loans,
    required List<RecurringTransaction> recurringTransactions,
    required DateTime month,
    required DateTime now,
  }) {
    final monthStart = DateTime(month.year, month.month, 1);
    final monthEnd = DateTime(month.year, month.month + 1, 1);

    bool inMonth(DateTime date) =>
        !date.isBefore(monthStart) && date.isBefore(monthEnd);

    final events = <CashFlowEvent>[];

    for (final transaction in transactions) {
      final event = _transactionEvent(transaction);
      if (inMonth(event.date)) {
        events.add(event);
      }
    }

    for (final bill in bills) {
      final event = _billEvent(bill, now);
      if (event != null && inMonth(event.date)) {
        events.add(event);
      }
    }

    for (final loan in loans) {
      final event = _loanEvent(loan, now);
      if (event != null && inMonth(event.date)) {
        events.add(event);
      }
    }

    for (final item in recurringTransactions) {
      final event = _recurringEvent(item, now);
      if (event != null && inMonth(event.date)) {
        events.add(event);
      }
    }

    events.sort((a, b) => a.date.compareTo(b.date));
    return events;
  }

  /// The next [limit] upcoming (or overdue) obligations, irrespective of
  /// which month is currently being viewed — powers the "Upcoming" section.
  /// Recorded transactions never appear here; they are never "upcoming".
  static List<CashFlowEvent> upcomingEvents({
    required List<Bill> bills,
    required List<Loan> loans,
    required List<RecurringTransaction> recurringTransactions,
    required DateTime now,
    int limit = cashFlowDefaultUpcomingLimit,
  }) {
    final events = <CashFlowEvent>[];

    for (final bill in bills) {
      final event = _billEvent(bill, now);
      if (event != null) events.add(event);
    }
    for (final loan in loans) {
      final event = _loanEvent(loan, now);
      if (event != null) events.add(event);
    }
    for (final item in recurringTransactions) {
      final event = _recurringEvent(item, now);
      if (event != null) events.add(event);
    }

    events.sort((a, b) => a.date.compareTo(b.date));
    return events.take(limit).toList();
  }

  /// Groups events by calendar day — powers the calendar grid's activity
  /// indicators.
  static Map<DateTime, List<CashFlowEvent>> groupByDate(
    List<CashFlowEvent> events,
  ) {
    final grouped = <DateTime, List<CashFlowEvent>>{};
    for (final event in events) {
      grouped.putIfAbsent(event.date, () => []).add(event);
    }
    return grouped;
  }

  static CashFlowDaySummary summarizeDay(List<CashFlowEvent> dayEvents) {
    final recordedIncome = dayEvents
        .where((e) => !e.isUpcoming && e.isInflow)
        .toList();
    final recordedExpenses = dayEvents
        .where((e) => !e.isUpcoming && !e.isInflow)
        .toList();
    final upcoming = dayEvents.where((e) => e.isUpcoming).toList();

    double totalOutgoing = 0;
    double totalIncoming = 0;
    for (final event in dayEvents) {
      if (event.isInflow) {
        totalIncoming += event.amount;
      } else {
        totalOutgoing += event.amount;
      }
    }

    return CashFlowDaySummary(
      recordedIncome: recordedIncome,
      recordedExpenses: recordedExpenses,
      upcoming: upcoming,
      totalOutgoing: totalOutgoing,
      netExpectedMovement: totalIncoming - totalOutgoing,
    );
  }

  /// Upcoming/overdue-only income vs. outgoing totals over a fixed rolling
  /// window from [now] (default 30 days) — powers the compact Dashboard
  /// card, which shows "next 30 days" regardless of which month the full
  /// calendar screen happens to be showing. Reuses [CashFlowMonthSummary]'s
  /// shape; `recordedIncome`/`recordedExpense` are always 0 here since this
  /// window is purely forward-looking.
  static CashFlowMonthSummary summarizeUpcomingWindow({
    required List<Bill> bills,
    required List<Loan> loans,
    required List<RecurringTransaction> recurringTransactions,
    required DateTime now,
    int windowDays = 30,
  }) {
    final horizon = DateTime(now.year, now.month, now.day).add(Duration(days: windowDays));

    double upcomingIncome = 0;
    double upcomingExpense = 0;
    var hasActivity = false;

    void apply(CashFlowEvent? event) {
      if (event == null || event.date.isAfter(horizon)) return;
      hasActivity = true;
      if (event.isInflow) {
        upcomingIncome += event.amount;
      } else {
        upcomingExpense += event.amount;
      }
    }

    for (final bill in bills) {
      apply(_billEvent(bill, now));
    }
    for (final loan in loans) {
      apply(_loanEvent(loan, now));
    }
    for (final item in recurringTransactions) {
      apply(_recurringEvent(item, now));
    }

    return CashFlowMonthSummary(
      recordedIncome: 0,
      recordedExpense: 0,
      upcomingIncome: upcomingIncome,
      upcomingExpense: upcomingExpense,
      hasActivity: hasActivity,
    );
  }

  static CashFlowMonthSummary summarizeMonth(List<CashFlowEvent> monthEvents) {
    double recordedIncome = 0;
    double recordedExpense = 0;
    double upcomingIncome = 0;
    double upcomingExpense = 0;

    for (final event in monthEvents) {
      if (event.isUpcoming) {
        if (event.isInflow) {
          upcomingIncome += event.amount;
        } else {
          upcomingExpense += event.amount;
        }
      } else {
        if (event.isInflow) {
          recordedIncome += event.amount;
        } else {
          recordedExpense += event.amount;
        }
      }
    }

    return CashFlowMonthSummary(
      recordedIncome: recordedIncome,
      recordedExpense: recordedExpense,
      upcomingIncome: upcomingIncome,
      upcomingExpense: upcomingExpense,
      hasActivity: monthEvents.isNotEmpty,
    );
  }

  static CashFlowEvent _transactionEvent(Transaction transaction) {
    final isIncome = transaction.transactionType.toLowerCase() == 'income';
    return CashFlowEvent(
      date: _dateOnly(transaction.createdAt),
      amount: transaction.amount,
      type: isIncome ? CashFlowEventType.income : CashFlowEventType.expense,
      title: transaction.title,
      source: 'Transaction',
      isUpcoming: false,
      isOverdue: false,
      sourceId: transaction.id,
    );
  }

  /// Null when the bill is already paid — a paid bill is represented by its
  /// recorded [Transaction] instead, never shown again as an unpaid
  /// obligation (avoids the exact duplication the feature spec warns about).
  static CashFlowEvent? _billEvent(Bill bill, DateTime now) {
    if (bill.isPaid) return null;
    final overdue = bill.isOverdue(now);
    return CashFlowEvent(
      date: _dateOnly(bill.dueDate),
      amount: bill.amount,
      type: CashFlowEventType.bill,
      title: bill.title,
      source: 'Bill',
      isUpcoming: true,
      isOverdue: overdue,
      sourceId: bill.id,
    );
  }

  /// Null for a closed loan. [Loan.nextDueDate] always points at the next
  /// unpaid installment (it only advances once an EMI is actually recorded
  /// as paid), so this can never coincide with a past recorded EMI payment.
  static CashFlowEvent? _loanEvent(Loan loan, DateTime now) {
    if (!loan.isActive) return null;
    final overdue = loan.isOverdue(now);
    return CashFlowEvent(
      date: _dateOnly(loan.nextDueDate),
      amount: loan.emiAmount,
      type: CashFlowEventType.loanPayment,
      title: loan.loanName,
      source: 'Loan EMI',
      isUpcoming: true,
      isOverdue: overdue,
      sourceId: loan.id,
    );
  }

  /// Null for an inactive/expired recurring definition. Only the single
  /// next occurrence is surfaced — [RecurringTransaction] already advances
  /// its own `nextDueDate` and generates a real [Transaction] once an
  /// occurrence is actually due, so there is no synthetic year of future
  /// entries to generate here, and no overlap with past recorded payments.
  static CashFlowEvent? _recurringEvent(
    RecurringTransaction item,
    DateTime now,
  ) {
    if (!item.isActive || item.isExpired) return null;
    final isIncome = item.transactionType.toLowerCase() == 'income';
    final dueDate = _dateOnly(item.nextDueDate);
    final overdue = dueDate.isBefore(_dateOnly(now));
    return CashFlowEvent(
      date: dueDate,
      amount: item.amount,
      type: isIncome
          ? CashFlowEventType.recurringIncome
          : CashFlowEventType.recurringPayment,
      title: item.title,
      source: isIncome ? 'Recurring Income' : 'Recurring Payment',
      isUpcoming: true,
      isOverdue: overdue,
      sourceId: item.id,
    );
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
