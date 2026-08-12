import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/shared/models/app_lock_settings.dart';
import 'package:paysense/shared/providers/app_lock_provider.dart';

import 'app_lock_screen.dart';

/// Wraps the whole app (via `MaterialApp.builder`) and shows [AppLockScreen]
/// on top of everything when locked. Tracks only how long the app has been
/// backgrounded — normal in-app navigation never touches
/// [AppLifecycleState], so it never triggers a lock. The account session
/// ([authProvider]) is completely untouched here; this only gates
/// re-entry to an already-logged-in app.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  DateTime? _backgroundedAt;

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
      if (!lockEnabled || backgroundedAt == null) {
        return;
      }
      final elapsed = DateTime.now().difference(backgroundedAt);
      if (elapsed >= settings.timeout.duration) {
        ref.read(appLockStateProvider.notifier).state = true;
      }
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
