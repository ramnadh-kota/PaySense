import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/core/services/notification_service.dart';
import 'package:paysense/shared/models/app_lock_settings.dart';
import 'package:paysense/shared/models/app_settings.dart';
import 'package:paysense/shared/providers/app_lock_provider.dart';
import 'package:paysense/shared/providers/auth_provider.dart';
import 'package:paysense/shared/providers/settings_provider.dart';
import 'package:paysense/shared/providers/account_aggregator_connections_provider.dart';
import 'package:paysense/shared/providers/sms_review_provider.dart';
import 'package:paysense/shared/services/account_aggregator/account_aggregator_models.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';
import 'package:paysense/shared/repositories/sms_fingerprint_repository.dart';
import 'package:paysense/shared/services/sms_channel.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/utils/currency_formatter.dart';
import 'package:paysense/shared/widgets/app_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).value;
    final settings = ref.watch(settingsProvider).value ?? const AppSettings();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
          children: [
            _SectionLabel('Account'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Profile',
                    subtitle: profile?.fullName.isNotEmpty == true
                        ? profile!.fullName
                        : 'Edit your profile details',
                    onTap: () =>
                        Navigator.of(context).pushNamed(AppRoutes.profileSetup),
                  ),
                  const _TileDivider(),
                  _SettingsTile(
                    icon: Icons.lock_outline_rounded,
                    label: 'Change password',
                    onTap: () => Navigator.of(
                      context,
                    ).pushNamed(AppRoutes.changePassword),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionLabel('Security'),
            AppCard(
              padding: EdgeInsets.zero,
              child: _AppLockSection(
                onToggle: (value) => _handleAppLockToggle(context, ref, value),
                onAuthMethodTap: () => _showAuthMethodPicker(context, ref),
                onTimeoutTap: () => _showLockTimeoutPicker(context, ref),
                onChangePinTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.appLockPinSetup),
              ),
            ),
            const SizedBox(height: 18),
            _SectionLabel('Preferences'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.currency_exchange_rounded,
                    label: 'Currency',
                    subtitle:
                        '${profile?.currency ?? 'INR'} (${CurrencyFormatter.symbolFor(profile?.currency ?? 'INR')})',
                    onTap: () => _showCurrencyPicker(context, ref, profile),
                  ),
                  const _TileDivider(),
                  _SettingsTile(
                    icon: Icons.public_rounded,
                    label: 'Country',
                    subtitle: profile?.country.isNotEmpty == true
                        ? profile!.country
                        : 'Not set',
                    onTap: () => _showCountryEditor(context, ref, profile),
                  ),
                  const _TileDivider(),
                  _NotificationToggles(settings: settings, ref: ref),
                  const _TileDivider(),
                  _SettingsTile(
                    icon: Icons.palette_outlined,
                    label: 'App appearance',
                    subtitle: _themeModeLabel(settings.themeMode),
                    onTap: () => _showThemePicker(context, ref, settings),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionLabel('Automation'),
            AppCard(
              padding: EdgeInsets.zero,
              child: _SmsAutomationSection(
                enabled: settings.smsAutomationEnabled,
                pendingReviewCount:
                    ref.watch(smsReviewItemsProvider).value?.length ?? 0,
                onToggle: (value) => _handleSmsAutomationToggle(context, ref, value),
                onReviewTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.smsReview),
              ),
            ),
            const SizedBox(height: 18),
            _SectionLabel('Connected Financial Accounts'),
            Builder(
              builder: (context) {
                final connections = ref.watch(accountAggregatorConnectionsProvider).value ?? const [];
                final activeCount = connections.where((c) => c.status != ConnectionStatus.revoked).length;
                return AppCard(
                  padding: EdgeInsets.zero,
                  child: _SettingsTile(
                    icon: Icons.account_balance_outlined,
                    label: activeCount == 0
                        ? 'Connect your bank accounts'
                        : '$activeCount account${activeCount == 1 ? '' : 's'} connected',
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.connectedAccounts),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            _SectionLabel('Data'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.file_download_outlined,
                    label: 'Export My Data',
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.dataExport),
                  ),
                  const _TileDivider(),
                  _SettingsTile(
                    icon: Icons.delete_outline_rounded,
                    label: 'Clear financial data',
                    labelColor: AppColors.danger,
                    onTap: () => _handleClearFinancialData(context, ref),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionLabel('About'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  const _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    label: 'App version',
                    subtitle: '1.0.0',
                  ),
                  const _TileDivider(),
                  _SettingsTile(
                    icon: Icons.article_outlined,
                    label: 'About PaySense',
                    onTap: () => _showAboutDialogSheet(context),
                  ),
                  const _TileDivider(),
                  _SettingsTile(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy & Terms',
                    onTap: () => _showPrivacyPlaceholder(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _SectionLabel('Account'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.logout_rounded,
                    label: 'Log Out',
                    labelColor: AppColors.danger,
                    onTap: () => _handleLogout(context, ref),
                  ),
                  const _TileDivider(),
                  _SettingsTile(
                    icon: Icons.delete_forever_rounded,
                    label: 'Delete Account',
                    labelColor: AppColors.danger,
                    onTap: () => Navigator.of(context).pushNamed(AppRoutes.accountDeletion),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _themeModeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return 'System default';
      case AppThemeMode.light:
        return 'Light';
      case AppThemeMode.dark:
        return 'Dark';
    }
  }

  Future<void> _handleAppLockToggle(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    final notifier = ref.read(appLockSettingsProvider.notifier);

    if (!enable) {
      await notifier.setEnabled(false);
      return;
    }

    final hasPin = ref.read(appLockSettingsProvider).value?.hasPinConfigured ?? false;
    if (!hasPin) {
      // A PIN fallback is required before App Lock can be enabled, so a
      // biometric-only setup can never strand the user outside their app.
      await Navigator.of(context).pushNamed(AppRoutes.appLockPinSetup);
      final pinNowConfigured =
          ref.read(appLockSettingsProvider).value?.hasPinConfigured ?? false;
      if (!pinNowConfigured) {
        return; // User backed out without setting a PIN — don't enable.
      }
    }

    await notifier.setEnabled(true);
  }

  /// Permission is only ever requested here, at the moment the user turns
  /// this feature on — never at app startup, never as a prerequisite for
  /// anything else in the app. Denied/permanently-denied both leave the
  /// setting off and the rest of PaySense fully usable.
  Future<void> _handleSmsAutomationToggle(
    BuildContext context,
    WidgetRef ref,
    bool enable,
  ) async {
    if (!enable) {
      await ref.read(settingsProvider.notifier).setSmsAutomationEnabled(false);
      return;
    }

    final status = await Permission.sms.request();
    if (!context.mounted) {
      return;
    }

    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status.isPermanentlyDenied
                ? 'SMS permission is permanently denied. Enable it from '
                    'system app settings to use automatic SMS transactions.'
                : 'SMS permission wasn\'t granted, so this stays off.',
          ),
        ),
      );
      return;
    }

    await ref.read(settingsProvider.notifier).setSmsAutomationEnabled(true);
  }

  void _showAuthMethodPicker(BuildContext context, WidgetRef ref) {
    final settings = ref.read(appLockSettingsProvider).value;
    final biometricAvailable = ref.read(biometricAvailableProvider).value ?? false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Authentication method'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (biometricAvailable)
              ListTile(
                title: const Text('Biometrics'),
                trailing: settings?.method == LockAuthMethod.biometric
                    ? Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () async {
                  Navigator.of(dialogContext).pop();
                  await ref
                      .read(appLockSettingsProvider.notifier)
                      .setMethod(LockAuthMethod.biometric);
                },
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  'Biometric authentication isn\'t available on this device.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ),
            ListTile(
              title: const Text('PIN'),
              trailing: settings?.method == LockAuthMethod.pin
                  ? Icon(Icons.check_rounded, color: AppColors.primary)
                  : null,
              onTap: () async {
                Navigator.of(dialogContext).pop();
                final hasPin = settings?.hasPinConfigured ?? false;
                if (!hasPin) {
                  await Navigator.of(
                    context,
                  ).pushNamed(AppRoutes.appLockPinSetup);
                }
                await ref
                    .read(appLockSettingsProvider.notifier)
                    .setMethod(LockAuthMethod.pin);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLockTimeoutPicker(BuildContext context, WidgetRef ref) {
    final settings = ref.read(appLockSettingsProvider).value;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lock after'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: LockTimeout.values.map((timeout) {
            return ListTile(
              title: Text(timeout.label),
              trailing: settings?.timeout == timeout
                  ? Icon(Icons.check_rounded, color: AppColors.primary)
                  : null,
              onTap: () async {
                Navigator.of(dialogContext).pop();
                await ref
                    .read(appLockSettingsProvider.notifier)
                    .setTimeout(timeout);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showCurrencyPicker(
    BuildContext context,
    WidgetRef ref,
    UserProfile? profile,
  ) {
    final current = profile?.currency ?? 'INR';
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Select currency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: CurrencyFormatter.supportedCurrencies.map((code) {
            return ListTile(
              title: Text('$code (${CurrencyFormatter.symbolFor(code)})'),
              trailing: code == current
                  ? Icon(Icons.check_rounded, color: AppColors.primary)
                  : null,
              onTap: () async {
                Navigator.of(dialogContext).pop();
                await _updateProfileField(ref, currency: code);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showCountryEditor(
    BuildContext context,
    WidgetRef ref,
    UserProfile? profile,
  ) {
    final controller = TextEditingController(text: profile?.country ?? '');
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Country'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'India'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              await _updateProfileField(ref, country: controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateProfileField(
    WidgetRef ref, {
    String? currency,
    String? country,
  }) async {
    final profile = ref.read(userProfileProvider).value;
    if (profile == null) {
      return;
    }
    await ref.read(userProfileProvider.notifier).saveProfile(
      profile.copyWith(
        currency: currency,
        country: country,
        updatedAt: DateTime.now(),
      ),
    );
  }

  void _showThemePicker(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('App appearance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppThemeMode.values.map((mode) {
            return ListTile(
              title: Text(_themeModeLabel(mode)),
              trailing: mode == settings.themeMode
                  ? Icon(Icons.check_rounded, color: AppColors.primary)
                  : null,
              onTap: () async {
                Navigator.of(dialogContext).pop();
                await ref.read(settingsProvider.notifier).setThemeMode(mode);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _handleClearFinancialData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear financial data?'),
        content: const Text(
          'This permanently deletes all transactions, budgets, goals, '
          'recurring payments, bills, loans, and wallets on this device. '
          'Your account, profile, and settings are kept. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(settingsProvider.notifier).clearFinancialData();

    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Financial data cleared.')),
    );
  }

  void _showAboutDialogSheet(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('About PaySense'),
        content: const Text(
          'PaySense is an independent personal finance companion designed to restore mindful financial awareness in modern digital payments.\n\n'
          'Featuring Decision Coach ("Think Before You Pay"), Pain of Paying post-purchase evaluation, Safe-to-Spend cash-flow forecasting, Fun Funds, and local SMS transaction detection.\n\n'
          'Version 1.0.0 • All financial data remains stored locally on your device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyPlaceholder(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Privacy & Data Governance'),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '• On-Device Data Storage: All transaction history, account balances, budgets, loans, and goals are stored locally on your device via Hive.\n\n'
                '• SMS Transaction Detection: Bank and UPI SMS parsing occurs entirely on-device. SMS permissions are requested only upon explicit user toggle. Raw SMS content is never transmitted externally.\n\n'
                '• AI Context Sanitization: AI features use minimal aggregated summary data. Full account numbers, PINs, passwords, and sensitive credentials are never sent to external AI servers.\n\n'
                '• Independent Application: PaySense is an independent personal finance guide. PaySense is not a bank, financial institution, or payment processor, and cannot directly access or move your bank funds.\n\n'
                '• Data Control: You can export your data to CSV or wipe local financial databases at any time from Settings.',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text(
          'You can log back in anytime. Your financial data stays safely stored on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(authProvider.notifier).logout();

    if (!context.mounted) {
      return;
    }

    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  const _TileDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, color: AppColors.divider, indent: 56);
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.labelColor,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? labelColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: labelColor ?? AppColors.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: labelColor ?? AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationToggles extends StatelessWidget {
  const _NotificationToggles({required this.settings, required this.ref});

  final AppSettings settings;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final masterOn = settings.allowNotifications;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Allow Notifications',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Switch(
                value: masterOn,
                activeThumbColor: AppColors.primary,
                onChanged: (value) async {
                  if (value) {
                    await NotificationService.instance.requestNotificationsPermission();
                  }
                  ref.read(settingsProvider.notifier).setAllowNotifications(value);
                },
              ),
            ],
          ),
          if (masterOn) ...[
            const _TileDivider(),
            _NotificationSwitchRow(
              label: 'Daily Money Check-In',
              subtitle: '10-second daily sentiment & streak check-in',
              value: settings.dailyCheckInNotifications,
              onChanged: (value) =>
                  ref.read(settingsProvider.notifier).setDailyCheckInNotifications(value),
            ),
            _NotificationSwitchRow(
              label: 'Safe-to-Spend Alerts',
              subtitle: 'Notifies when spending room becomes tight',
              value: settings.safeToSpendNotifications,
              onChanged: (value) =>
                  ref.read(settingsProvider.notifier).setSafeToSpendNotifications(value),
            ),
            _NotificationSwitchRow(
              label: 'Important Money Insights',
              subtitle: 'Critical & high-priority financial changes',
              value: settings.importantInsightNotifications,
              onChanged: (value) =>
                  ref.read(settingsProvider.notifier).setImportantInsightNotifications(value),
            ),
            _NotificationSwitchRow(
              label: 'Goal Reminders',
              subtitle: 'Approaching goal timelines & target alerts',
              value: settings.goalReminderNotifications,
              onChanged: (value) =>
                  ref.read(settingsProvider.notifier).setGoalReminderNotifications(value),
            ),
            _NotificationSwitchRow(
              label: 'Weekly Money Story',
              subtitle: 'Weekly spending & savings snapshot',
              value: settings.weeklyStoryNotifications,
              onChanged: (value) =>
                  ref.read(settingsProvider.notifier).setWeeklyStoryNotifications(value),
            ),
            _NotificationSwitchRow(
              label: 'Quiet Hours (10:00 PM – 8:00 AM)',
              subtitle: 'Suppresses background notifications overnight',
              value: settings.quietHoursEnabled,
              onChanged: (value) =>
                  ref.read(settingsProvider.notifier).setQuietHoursEnabled(value),
            ),
            const _TileDivider(),
            _NotificationSwitchRow(
              label: 'Bill reminders',
              value: settings.billReminders,
              onChanged: (value) =>
                  ref.read(settingsProvider.notifier).setBillReminders(value),
            ),
            _NotificationSwitchRow(
              label: 'Recurring payment reminders',
              value: settings.recurringReminders,
              onChanged: (value) =>
                  ref.read(settingsProvider.notifier).setRecurringReminders(value),
            ),
            _NotificationSwitchRow(
              label: 'Loan/EMI reminders',
              value: settings.loanReminders,
              onChanged: (value) =>
                  ref.read(settingsProvider.notifier).setLoanReminders(value),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotificationSwitchRow extends StatelessWidget {
  const _NotificationSwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w500),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary, fontSize: 10),
                ),
              ],
            ],
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: AppColors.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SmsAutomationSection extends StatelessWidget {
  const _SmsAutomationSection({
    required this.enabled,
    required this.pendingReviewCount,
    required this.onToggle,
    required this.onReviewTap,
  });

  final bool enabled;
  final int pendingReviewCount;
  final ValueChanged<bool> onToggle;
  final VoidCallback onReviewTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.sms_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Automatic SMS Transactions',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Automatically detect supported bank transactions from SMS.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                activeThumbColor: AppColors.primary,
                onChanged: onToggle,
              ),
            ],
          ),
        ),
        if (enabled) ...[
          const _TileDivider(),
          _SettingsTile(
            icon: Icons.fact_check_outlined,
            label: 'Detected transactions',
            subtitle: pendingReviewCount > 0
                ? '$pendingReviewCount waiting for review'
                : 'Nothing waiting for review',
            onTap: onReviewTap,
          ),
        ],
        const _TileDivider(),
        _SettingsTile(
          icon: Icons.bug_report_outlined,
          label: 'Automation diagnostics',
          subtitle: 'Check permission & processing status',
          onTap: () => showDialog<void>(
            context: context,
            builder: (context) => const _SmsDiagnosticsDialog(),
          ),
        ),
      ],
    );
  }
}

/// Read-only, real-device debugging aid for the SMS automation pipeline —
/// lets a manual tester see which stage is failing (permission never
/// granted vs. events stuck in the native queue vs. a processing error)
/// without needing device logs. Never shows raw SMS body/sender text, and
/// never logs anything itself; it only reads counters and the
/// already-sanitized last-error string [AppSettingsRepository] holds.
class _SmsDiagnosticsDialog extends ConsumerStatefulWidget {
  const _SmsDiagnosticsDialog();

  @override
  ConsumerState<_SmsDiagnosticsDialog> createState() =>
      _SmsDiagnosticsDialogState();
}

class _SmsDiagnosticsDialogState extends ConsumerState<_SmsDiagnosticsDialog> {
  bool _loading = true;
  PermissionStatus? _permissionStatus;
  int _pendingNativeCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await Permission.sms.status;
    final pending = await SmsChannel().fetchPending();
    if (!mounted) {
      return;
    }
    setState(() {
      _permissionStatus = status;
      _pendingNativeCount = pending.length;
      _loading = false;
    });
  }

  String _permissionLabel(PermissionStatus? status) {
    if (status == null) {
      return '—';
    }
    if (status.isGranted) {
      return 'Granted';
    }
    if (status.isPermanentlyDenied) {
      return 'Permanently denied';
    }
    return 'Denied';
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider).value;
    final pendingReviewCount = ref.watch(smsReviewItemsProvider).value?.length ?? 0;
    final processedFingerprints = SmsFingerprintRepository.instance.count();
    final lastStatus = AppSettingsRepository.instance.smsLastProcessingStatus();
    final lastError = AppSettingsRepository.instance.smsLastProcessingError();
    final lastAt = AppSettingsRepository.instance.smsLastProcessingAt();

    return AlertDialog(
      title: const Text('Automation diagnostics'),
      content: _loading
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DiagnosticRow('SMS permission', _permissionLabel(_permissionStatus)),
                  _DiagnosticRow(
                    'Automation',
                    (settings?.smsAutomationEnabled ?? false) ? 'Enabled' : 'Disabled',
                  ),
                  _DiagnosticRow('Pending native SMS', '$_pendingNativeCount'),
                  _DiagnosticRow('Processed fingerprints', '$processedFingerprints'),
                  _DiagnosticRow('Pending review', '$pendingReviewCount'),
                  _DiagnosticRow(
                    'Last SMS processing',
                    switch (lastStatus) {
                      'success' => 'Success',
                      'failed' => 'Failed',
                      _ => 'Never',
                    },
                  ),
                  if (lastStatus == 'failed' && lastError != null)
                    _DiagnosticRow('Last processing error', lastError),
                  if (lastAt != null)
                    _DiagnosticRow('Last run at', _formatTimestamp(lastAt)),
                  const _DiagnosticRow('Receiver status', 'Configured'),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
  }
}

class _DiagnosticRow extends StatelessWidget {
  const _DiagnosticRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppLockSection extends ConsumerWidget {
  const _AppLockSection({
    required this.onToggle,
    required this.onAuthMethodTap,
    required this.onTimeoutTap,
    required this.onChangePinTap,
  });

  final ValueChanged<bool> onToggle;
  final VoidCallback onAuthMethodTap;
  final VoidCallback onTimeoutTap;
  final VoidCallback onChangePinTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(appLockSettingsProvider).value ?? const AppLockSettings();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Lock',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Protect PaySense when you're away from the app.",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: settings.enabled,
                activeThumbColor: AppColors.primary,
                onChanged: onToggle,
              ),
            ],
          ),
        ),
        if (settings.enabled) ...[
          const _TileDivider(),
          _SettingsTile(
            icon: settings.method == LockAuthMethod.biometric
                ? Icons.fingerprint_rounded
                : Icons.pin_outlined,
            label: 'Authentication method',
            subtitle: settings.method == LockAuthMethod.biometric
                ? 'Biometrics'
                : 'PIN',
            onTap: onAuthMethodTap,
          ),
          const _TileDivider(),
          _SettingsTile(
            icon: Icons.timer_outlined,
            label: 'Lock after',
            subtitle: settings.timeout.label,
            onTap: onTimeoutTap,
          ),
          const _TileDivider(),
          _SettingsTile(
            icon: Icons.password_rounded,
            label: settings.hasPinConfigured ? 'Change PIN' : 'Set up PIN',
            onTap: onChangePinTap,
          ),
        ],
      ],
    );
  }
}
