import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/models/cash_flow_event.dart';
import 'package:paysense/shared/providers/cash_flow_provider.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';
import 'package:paysense/shared/utils/cash_flow_calculator.dart';
import 'package:paysense/shared/utils/currency_formatter.dart';
import 'package:paysense/shared/widgets/app_card.dart';

const _weekdayLabels = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];

class CashFlowScreen extends ConsumerWidget {
  const CashFlowScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(selectedCashFlowMonthProvider);
    final selectedDate = ref.watch(selectedCashFlowDateProvider);
    final events = ref.watch(cashFlowEventsProvider);
    final monthSummary = ref.watch(cashFlowMonthSummaryProvider);
    final upcoming = ref.watch(cashFlowUpcomingEventsProvider);

    final currencyCode = ref.watch(userProfileProvider).value?.currency.isNotEmpty == true
        ? ref.watch(userProfileProvider).value!.currency
        : 'INR';
    final currencyFormatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: CurrencyFormatter.symbolFor(currencyCode),
      decimalDigits: 0,
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final grouped = CashFlowCalculator.groupByDate(events);
    final dayEvents = grouped[DateTime(selectedDate.year, selectedDate.month, selectedDate.day)] ??
        const <CashFlowEvent>[];
    final daySummary = CashFlowCalculator.summarizeDay(dayEvents);

    final earliestMonth = DateTime(now.year, now.month - cashFlowMonthRangeInMonths, 1);
    final latestMonth = DateTime(now.year, now.month + cashFlowMonthRangeInMonths, 1);
    final canGoPrev = DateTime(month.year, month.month - 1, 1).isAfter(earliestMonth.subtract(const Duration(days: 1)));
    final canGoNext = DateTime(month.year, month.month + 1, 1).isBefore(latestMonth.add(const Duration(days: 1)));

    void goToMonth(DateTime target) {
      ref.read(selectedCashFlowMonthProvider.notifier).state = DateTime(target.year, target.month, 1);
    }

    void goToday() {
      goToMonth(today);
      ref.read(selectedCashFlowDateProvider.notifier).state = today;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Cash Flow'),
        actions: [
          TextButton(
            onPressed: today == selectedDate && month.year == today.year && month.month == today.month
                ? null
                : goToday,
            child: const Text('Today'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            _MonthNavigator(
              month: month,
              canGoPrev: canGoPrev,
              canGoNext: canGoNext,
              onPrev: () => goToMonth(DateTime(month.year, month.month - 1, 1)),
              onNext: () => goToMonth(DateTime(month.year, month.month + 1, 1)),
            ),
            const SizedBox(height: 16),
            _MonthSummaryCard(summary: monthSummary, currencyFormatter: currencyFormatter),
            const SizedBox(height: 16),
            _CalendarGrid(
              month: month,
              today: today,
              selectedDate: selectedDate,
              eventsByDate: grouped,
              onSelect: (date) => ref.read(selectedCashFlowDateProvider.notifier).state = date,
            ),
            const SizedBox(height: 20),
            _SelectedDaySection(
              date: selectedDate,
              summary: daySummary,
              currencyFormatter: currencyFormatter,
            ),
            const SizedBox(height: 20),
            _UpcomingSection(events: upcoming, currencyFormatter: currencyFormatter),
          ],
        ),
      ),
    );
  }
}

class _MonthNavigator extends StatelessWidget {
  const _MonthNavigator({
    required this.month,
    required this.canGoPrev,
    required this.canGoNext,
    required this.onPrev,
    required this.onNext,
  });

  final DateTime month;
  final bool canGoPrev;
  final bool canGoNext;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: canGoPrev ? onPrev : null,
          icon: const Icon(Icons.chevron_left_rounded),
          color: AppColors.textPrimary,
        ),
        Text(
          DateFormat('MMMM yyyy').format(month).toUpperCase(),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        IconButton(
          onPressed: canGoNext ? onNext : null,
          icon: const Icon(Icons.chevron_right_rounded),
          color: AppColors.textPrimary,
        ),
      ],
    );
  }
}

class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({required this.summary, required this.currencyFormatter});

  final CashFlowMonthSummary summary;
  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context) {
    if (!summary.hasActivity) {
      return AppCard(
        padding: const EdgeInsets.all(20),
        child: Text(
          'No cash-flow activity for this month yet.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: 'Recorded income',
                  value: currencyFormatter.format(summary.recordedIncome),
                  color: AppColors.primary,
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  label: 'Upcoming income',
                  value: currencyFormatter.format(summary.upcomingIncome),
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: 'Recorded expenses',
                  value: currencyFormatter.format(summary.recordedExpense),
                  color: AppColors.accent,
                ),
              ),
              Expanded(
                child: _SummaryStat(
                  label: 'Upcoming expenses',
                  value: currencyFormatter.format(summary.upcomingExpense),
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          Divider(height: 28, color: AppColors.divider),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Expected net',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${summary.expectedNet >= 0 ? '+' : ''}${currencyFormatter.format(summary.expectedNet)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: summary.expectedNet >= 0 ? AppColors.success : AppColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  const _CalendarGrid({
    required this.month,
    required this.today,
    required this.selectedDate,
    required this.eventsByDate,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime today;
  final DateTime selectedDate;
  final Map<DateTime, List<CashFlowEvent>> eventsByDate;
  final ValueChanged<DateTime> onSelect;

  List<DateTime?> _gridDays() {
    final first = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingEmpty = (first.weekday - DateTime.monday) % 7;

    final cells = <DateTime?>[
      for (var i = 0; i < leadingEmpty; i++) null,
      for (var d = 1; d <= daysInMonth; d++) DateTime(month.year, month.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }

  @override
  Widget build(BuildContext context) {
    final cells = _gridDays();

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: _weekdayLabels
                .map(
                  (label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          for (var row = 0; row < cells.length / 7; row++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(
                      child: _DayCell(
                        date: cells[row * 7 + col],
                        today: today,
                        selectedDate: selectedDate,
                        dayEvents: cells[row * 7 + col] == null
                            ? const []
                            : eventsByDate[cells[row * 7 + col]] ?? const [],
                        onSelect: onSelect,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.today,
    required this.selectedDate,
    required this.dayEvents,
    required this.onSelect,
  });

  final DateTime? date;
  final DateTime today;
  final DateTime selectedDate;
  final List<CashFlowEvent> dayEvents;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final current = date;
    if (current == null) {
      return const SizedBox(height: 44);
    }

    final isToday = current == today;
    final isSelected = current == selectedDate;
    final hasInflow = dayEvents.any((e) => e.isInflow);
    final hasOutflow = dayEvents.any((e) => !e.isInflow);
    final hasOverdue = dayEvents.any((e) => e.isOverdue);

    return GestureDetector(
      onTap: () => onSelect(current),
      child: Container(
        height: 44,
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 1),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lightTeal : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: isToday && !isSelected
              ? Border.all(color: AppColors.primary, width: 1.4)
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${current.day}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 3),
            if (hasInflow || hasOutflow)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasInflow) _Dot(color: AppColors.primary),
                  if (hasInflow && hasOutflow) const SizedBox(width: 3),
                  if (hasOutflow) _Dot(color: hasOverdue ? AppColors.danger : AppColors.accent),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _SelectedDaySection extends StatelessWidget {
  const _SelectedDaySection({
    required this.date,
    required this.summary,
    required this.currencyFormatter,
  });

  final DateTime date;
  final CashFlowDaySummary summary;
  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('d MMMM').format(date),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 14),
          if (!summary.hasEvents)
            Text(
              'No financial activity scheduled for this day.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else ...[
            if (summary.recordedIncome.isNotEmpty)
              _EventTypeGroup(
                title: 'Income',
                items: summary.recordedIncome,
                currencyFormatter: currencyFormatter,
                amountColor: AppColors.primary,
                sign: '+',
              ),
            if (summary.recordedExpenses.isNotEmpty) ...[
              const SizedBox(height: 12),
              _EventTypeGroup(
                title: 'Expenses',
                items: summary.recordedExpenses,
                currencyFormatter: currencyFormatter,
                amountColor: AppColors.accent,
                sign: '-',
              ),
            ],
            if (summary.upcoming.isNotEmpty) ...[
              const SizedBox(height: 12),
              _EventTypeGroup(
                title: 'Upcoming',
                items: summary.upcoming,
                currencyFormatter: currencyFormatter,
                amountColor: AppColors.textSecondary,
                sign: '',
              ),
            ],
            Divider(height: 28, color: AppColors.divider),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total outgoing',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  currencyFormatter.format(summary.totalOutgoing),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Net expected movement',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${summary.netExpectedMovement >= 0 ? '+' : ''}${currencyFormatter.format(summary.netExpectedMovement)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: summary.netExpectedMovement >= 0 ? AppColors.success : AppColors.danger,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EventTypeGroup extends StatelessWidget {
  const _EventTypeGroup({
    required this.title,
    required this.items,
    required this.currencyFormatter,
    required this.amountColor,
    required this.sign,
  });

  final String title;
  final List<CashFlowEvent> items;
  final NumberFormat currencyFormatter;
  final Color amountColor;
  final String sign;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 6),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (item.isOverdue) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: AppColors.softCoral,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Overdue',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                        fontSize: 10,
                      ),
                    ),
                  ),
                ],
                Text(
                  '${item.isInflow ? '+' : sign.isEmpty ? '-' : sign}${currencyFormatter.format(item.amount)}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: item.isOverdue ? AppColors.danger : amountColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _UpcomingSection extends StatelessWidget {
  const _UpcomingSection({required this.events, required this.currencyFormatter});

  final List<CashFlowEvent> events;
  final NumberFormat currencyFormatter;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Upcoming',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        if (events.isEmpty)
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Text(
              "You're all caught up 🎉",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          )
        else
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: events.map((event) {
                return InkWell(
                  onTap: () => _navigateToSource(context, event),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (event.isOverdue ? AppColors.danger : AppColors.accent)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _iconFor(event.type),
                            color: event.isOverdue ? AppColors.danger : AppColors.accent,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.title,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                event.isOverdue
                                    ? 'Overdue since ${DateFormat('d MMM').format(event.date)}'
                                    : 'Due ${DateFormat('d MMM').format(event.date)}',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: event.isOverdue ? AppColors.danger : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          currencyFormatter.format(event.amount),
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  IconData _iconFor(CashFlowEventType type) {
    switch (type) {
      case CashFlowEventType.bill:
        return Icons.receipt_long_rounded;
      case CashFlowEventType.loanPayment:
        return Icons.account_balance_rounded;
      case CashFlowEventType.recurringPayment:
        return Icons.autorenew_rounded;
      case CashFlowEventType.recurringIncome:
        return Icons.arrow_downward_rounded;
      case CashFlowEventType.income:
      case CashFlowEventType.expense:
        return Icons.receipt_rounded;
    }
  }

  void _navigateToSource(BuildContext context, CashFlowEvent event) {
    final route = switch (event.type) {
      CashFlowEventType.bill => AppRoutes.bills,
      CashFlowEventType.loanPayment => AppRoutes.loans,
      CashFlowEventType.recurringPayment ||
      CashFlowEventType.recurringIncome => AppRoutes.recurring,
      CashFlowEventType.income || CashFlowEventType.expense => AppRoutes.transactions,
    };
    Navigator.of(context).pushNamed(route);
  }
}
