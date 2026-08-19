import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/shared/models/app_lock_settings.dart';
import 'package:paysense/shared/providers/app_lock_provider.dart';
import 'package:paysense/shared/providers/sms_automation_provider.dart';
import 'package:paysense/shared/repositories/app_settings_repository.dart';

import 'app_lock_screen.dart';

/// Wraps the whole app (via `MaterialApp.builder`) and shows [AppLockScreen]
/// on top of everything when locked. Tracks only how long the app has been
/// backgrounded — normal in-app navigation never touches
/// [AppLifecycleState], so it never triggers a lock. The account session
/// ([authProvider]) is completely untouched here; this only gates
/// re-entry to an already-logged-in app.
///
/// Also the single place that drains the native SMS queue on app *resume*
/// (not just cold launch — see [SplashScreen]'s own flush). Without this, a
/// bank SMS that arrives while PaySense is merely backgrounded (not force-
/// closed — the overwhelmingly common real-world case) would sit in the
/// native queue until the user eventually fully restarts the app, which
/// reads as "SMS automation doesn't work" even though every individual
/// pipeline stage is correct in isolation.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;
  bool _smsFlushInProgress = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final settings = ref.read(appLockSettingsProvider).value;
    final lockEnabled = settings != null &&
        settings.enabled &&
        settings.hasPinConfigured; // guaranteed fallback, never strands the user

    if (state == AppLifecycleState.paused) {
      if (lockEnabled) {
        _backgroundedAt = DateTime.now();
      }
      return;
    }

    if (state == AppLifecycleState.resumed) {
      final backgroundedAt = _backgroundedAt;
      _backgroundedAt = null;

      unawaited(_flushPendingSmsIfEnabled());

      if (!lockEnabled || backgroundedAt == null) {
        return;
      }
      final elapsed = DateTime.now().difference(backgroundedAt);
      if (elapsed >= settings.timeout.duration) {
        ref.read(appLockStateProvider.notifier).state = true;
      }
    }
  }

  /// Fire-and-forget, same failure posture as Splash's own flush: never
  /// blocks/crashes the resume transition, and the in-flight guard means a
  /// rapid background/foreground flap can't overlap two drains of the same
  /// native queue.
  Future<void> _flushPendingSmsIfEnabled() async {
    if (_smsFlushInProgress) {
      return;
    }
    if (!AppSettingsRepository.instance.smsAutomationEnabled()) {
      return;
    }
    _smsFlushInProgress = true;
    try {
      await ref.read(smsTransactionProcessorProvider).processPending();
      await AppSettingsRepository.instance.recordSmsProcessingSuccess();
    } catch (e) {
      // Best-effort — retried on the next resume or app launch.
      await AppSettingsRepository.instance.recordSmsProcessingFailure(
        'Resume SMS processing failed: ${e.runtimeType}',
      );
    } finally {
      _smsFlushInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = ref.watch(appLockStateProvider);
    return Stack(
      children: [
        widget.child,
        if (isLocked) const AppLockScreen(),
      ],
    );
  }
}
