import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/shared/models/notification_record.dart';
import 'package:paysense/shared/providers/notification_provider.dart';
import 'package:paysense/shared/widgets/app_card.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState
    extends ConsumerState<NotificationCenterScreen> {
  // PHASE 8 — "Recent insights" is a derived filter over the existing
  // notification history (type == insight), not a new persistent model.
  bool _insightsOnly = false;

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(notificationsProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationsProvider.notifier).markAllAsRead(),
              child: const Text('Mark all read'),
            ),
          IconButton(
            tooltip: 'Clear all',
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () => _handleClearAll(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: notificationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text(
              'Unable to load notifications right now.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          data: (notifications) {
            final visible = _insightsOnly
                ? notifications
                      .where((n) => n.notificationType == NotificationType.insight)
                      .toList()
                : notifications;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FilterChip(
                      label: const Text('Recent insights'),
                      avatar: const Icon(Icons.auto_awesome_rounded, size: 16),
                      selected: _insightsOnly,
                      onSelected: (selected) =>
                          setState(() => _insightsOnly = selected),
                    ),
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? _EmptyState(insightsOnly: _insightsOnly)
                      : ListView.separated(
                          padding: const EdgeInsets.all(24),
                          itemCount: visible.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return _NotificationTile(notification: visible[index]);
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _handleClearAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text(
          'This clears your notification history on this device. It does '
          'not affect your bills, goals, loans, or any other financial data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(notificationsProvider.notifier).clearAll();
    }
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});

  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = _styleFor(notification.notificationType);

    return AppCard(
      padding: const EdgeInsets.all(16),
      color: notification.isRead ? AppColors.surface : style.background,
      onTap: () async {
        await ref.read(notificationsProvider.notifier).markAsRead(notification.id);
        if (!context.mounted) {
          return;
        }
        final route = notification.relatedRoute;
        if (route != null && route.isNotEmpty) {
          Navigator.of(context).pushNamed(route);
        }
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(style.icon, color: style.color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: notification.isRead
                        ? FontWeight.w600
                        : FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notification.message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _relativeTime(notification.createdAt, DateTime.now()),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          if (!notification.isRead)
            Container(
              margin: const EdgeInsets.only(top: 4, left: 4),
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.accent,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}

class _NotificationStyle {
  const _NotificationStyle({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;
}

_NotificationStyle _styleFor(NotificationType type) {
  switch (type) {
    case NotificationType.bill:
      return _NotificationStyle(
        icon: Icons.receipt_long_rounded,
        color: AppColors.accent,
        background: AppColors.softCoral,
      );
    case NotificationType.recurringPayment:
      return _NotificationStyle(
        icon: Icons.autorenew_rounded,
        color: AppColors.primary,
        background: AppColors.lightTeal,
      );
    case NotificationType.loanPayment:
      return _NotificationStyle(
        icon: Icons.account_balance_rounded,
        color: AppColors.primary,
        background: AppColors.lightTeal,
      );
    case NotificationType.goal:
      return _NotificationStyle(
        icon: Icons.flag_rounded,
        color: AppColors.success,
        background: AppColors.lightTeal,
      );
    case NotificationType.financialHealth:
      return _NotificationStyle(
        icon: Icons.favorite_rounded,
        color: AppColors.accent,
        background: AppColors.softCoral,
      );
    case NotificationType.smsTransaction:
      return _NotificationStyle(
        icon: Icons.sms_rounded,
        color: AppColors.primary,
        background: AppColors.lightTeal,
      );
    case NotificationType.budget:
      return _NotificationStyle(
        icon: Icons.pie_chart_outline_rounded,
        color: AppColors.accent,
        background: AppColors.softCoral,
      );
    case NotificationType.insight:
      return _NotificationStyle(
        icon: Icons.auto_awesome_rounded,
        color: AppColors.primary,
        background: AppColors.lightTeal,
      );
    case NotificationType.general:
      return _NotificationStyle(
        icon: Icons.notifications_rounded,
        color: AppColors.primary,
        background: AppColors.lightTeal,
      );
  }
}

String _relativeTime(DateTime createdAt, DateTime now) {
  final difference = now.difference(createdAt);
  if (difference.inMinutes < 1) {
    return 'Just now';
  }
  if (difference.inMinutes < 60) {
    return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
  }
  if (difference.inHours < 24) {
    return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
  }
  if (difference.inDays == 1) {
    return 'Yesterday';
  }
  if (difference.inDays < 7) {
    return '${difference.inDays} days ago';
  }
  return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.insightsOnly = false});

  final bool insightsOnly;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              insightsOnly
                  ? Icons.auto_awesome_outlined
                  : Icons.notifications_none_rounded,
              size: 56,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              insightsOnly ? 'No insights yet' : "You're all caught up 🎉",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              insightsOnly
                  ? 'Meaningful insights about your spending and budgets will appear here.'
                  : 'Important reminders and financial updates will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
