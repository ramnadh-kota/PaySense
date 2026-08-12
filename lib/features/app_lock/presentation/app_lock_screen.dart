import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/core/constants/app_colors.dart';
import 'package:paysense/core/services/biometric_service.dart';
import 'package:paysense/shared/models/app_lock_settings.dart';
import 'package:paysense/shared/providers/app_lock_provider.dart';

/// Shown as a full-screen overlay above the app (via MaterialApp.builder)
/// whenever [appLockStateProvider] is true. This gates re-entry only — the
/// account session in [authProvider] is never touched, so a successful
/// unlock simply hides this overlay and the app resumes exactly where it
/// was left.
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  String _enteredPin = '';
  bool _isAuthenticating = false;
  bool _biometricChecked = false;
  bool _biometricAvailable = false;
  bool _forcePinEntry = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeTriggerBiometric());
  }

  Future<void> _maybeTriggerBiometric() async {
    final settings = ref.read(appLockSettingsProvider).value;
    if (settings == null || settings.method != LockAuthMethod.biometric) {
      setState(() => _biometricChecked = true);
      return;
    }

    final available = await BiometricService.instance.isAvailable();
    if (!mounted) return;
    setState(() {
      _biometricAvailable = available;
      _biometricChecked = true;
    });
    if (available) {
      await _authenticateWithBiometrics();
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    setState(() {
      _isAuthenticating = true;
      _errorMessage = null;
    });
    final success = await BiometricService.instance.authenticate();
    if (!mounted) return;
    setState(() => _isAuthenticating = false);
    final settings = ref.read(appLockSettingsProvider).value;
    if (success) {
      _unlock();
    } else {
      setState(() {
        _errorMessage = 'Biometric authentication was not completed.';
        _forcePinEntry = settings?.hasPinConfigured ?? false;
      });
    }
  }

  void _unlock() {
    ref.read(appLockStateProvider.notifier).state = false;
  }

  void _onDigit(String digit) {
    if (_enteredPin.length >= 6) return;
    setState(() {
      _enteredPin += digit;
      _errorMessage = null;
    });
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    setState(
      () => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1),
    );
  }

  void _onSubmitPin() {
    final valid = ref.read(appLockSettingsProvider.notifier).verifyPin(_enteredPin);
    if (valid) {
      _unlock();
    } else {
      setState(() {
        _errorMessage = 'Incorrect PIN. Try again.';
        _enteredPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appLockSettingsProvider).value ?? const AppLockSettings();
    final showPinEntry =
        settings.method == LockAuthMethod.pin ||
        (_biometricChecked && !_biometricAvailable) ||
        _forcePinEntry;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              children: [
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 56,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'PaySense',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Welcome back',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.softCoral,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const Spacer(),
                if (showPinEntry) ...[
                  _PinDots(enteredLength: _enteredPin.length),
                  const SizedBox(height: 24),
                  _PinKeypad(
                    onDigit: _onDigit,
                    onBackspace: _onBackspace,
                    onSubmit: _enteredPin.length >= 4 ? _onSubmitPin : null,
                  ),
                  if (settings.method == LockAuthMethod.biometric &&
                      _biometricAvailable) ...[
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: _isAuthenticating ? null : _authenticateWithBiometrics,
                      icon: const Icon(Icons.fingerprint_rounded, color: Colors.white),
                      label: const Text(
                        'Use biometrics instead',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isAuthenticating ? null : _authenticateWithBiometrics,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: _isAuthenticating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.fingerprint_rounded),
                      label: const Text('Unlock with biometrics'),
                    ),
                  ),
                  if (settings.hasPinConfigured) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(() => _forcePinEntry = true),
                      child: const Text(
                        'Use PIN instead',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ],
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.enteredLength});

  final int enteredLength;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final filled = index < enteredLength;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? Colors.white : Colors.white.withValues(alpha: 0.3),
          ),
        );
      }),
    );
  }
}

class _PinKeypad extends StatelessWidget {
  const _PinKeypad({
    required this.onDigit,
    required this.onBackspace,
    required this.onSubmit,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onSubmit;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.map((digit) => _KeypadButton(
                label: digit,
                onTap: () => onDigit(digit),
              )).toList(),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(width: 64, height: 64),
              _KeypadButton(label: '0', onTap: () => onDigit('0')),
              SizedBox(
                width: 64,
                height: 64,
                child: IconButton(
                  onPressed: onBackspace,
                  icon: const Icon(Icons.backspace_outlined, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.2),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text('Unlock'),
          ),
        ),
      ],
    );
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Material(
        color: Colors.white.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
