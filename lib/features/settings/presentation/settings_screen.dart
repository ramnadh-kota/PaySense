import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/routes/app_routes.dart';
import 'package:paysense/shared/models/app_lock_settings.dart';
import 'package:paysense/shared/models/app_settings.dart';
import 'package:paysense/shared/providers/app_lock_provider.dart';
import 'package:paysense/shared/providers/auth_provider.dart';
import 'package:paysense/shared/providers/settings_provider.dart';
import 'package:paysense/shared/providers/user_profile_provider.dart';
import 'package:paysense/shared/models/user_profile.dart';
import 'package:paysense/shared/utils/currency_formatter.dart';
import 'package:paysense/shared/utils/financial_data_exporter.dart';
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
            const SizedBox(height: 24),
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
            const SizedBox(height: 24),
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
            const SizedBox(height: 24),
            _SectionLabel('Data'),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _SettingsTile(
                    icon: Icons.file_download_outlined,
                    label: 'Export financial data',
                    onTap: () => _handleExport(context),
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
            const SizedBox(height: 24),
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
            const SizedBox(height: 24),
            _SectionLabel('Account'),
            AppCard(
              padding: EdgeInsets.zero,
              child: _SettingsTile(
                icon: Icons.logout_rounded,
                label: 'Log Out',
                labelColor: AppColors.danger,
                onTap: () => _handleLogout(context, ref),
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
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Future<void> _handleExport(BuildContext context) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String? resultPath;
    String? errorMessage;
    try {
      resultPath = await FinancialDataExporter.instance.exportToFile();
    } catch (e) {
      errorMessage = e.toString();
    }

    if (!context.mounted) {
      return;
    }
    Navigator.of(context).pop();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(errorMessage == null ? 'Export complete' : 'Export failed'),
        content: Text(
          errorMessage == null
              ? 'Your financial data was exported to:\n\n$resultPath\n\n'
                  'The file stays on this device — PaySense doesn\'t upload '
                  'or share it anywhere.'
              : 'Something went wrong: $errorMessage',
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
          'PaySense is an AI-powered personal finance app that helps you '
          'track spending, budgets, goals, bills, and loans — all stored '
          'locally on your device.',
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
        title: const Text('Privacy & Terms'),
        content: const Text(
          'PaySense doesn\'t have published privacy policy or terms of '
          'service documents yet. All data stays on this device and is not '
          'sent anywhere.',
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notifications',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          _NotificationSwitchRow(
            label: 'Bill reminders',
            value: settings.billReminders,
            onChanged: (value) =>
                ref.read(settingsProvider.notifier).setBillReminders(value),
          ),
          _NotificationSwitchRow(
            label: 'Recurring payment reminders',
            value: settings.recurringReminders,
            onChanged: (value) => ref
                .read(settingsProvider.notifier)
                .setRecurringReminders(value),
          ),
          _NotificationSwitchRow(
            label: 'Loan/EMI reminders',
            value: settings.loanReminders,
            onChanged: (value) =>
                ref.read(settingsProvider.notifier).setLoanReminders(value),
          ),
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
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
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
