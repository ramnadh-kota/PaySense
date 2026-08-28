import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:paysense/app/providers/navigation_provider.dart';
import 'package:paysense/core/constants/app_colors.dart';
import '../ai/ai_screen.dart';
import '../analytics/analytics_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../profile/profile_screen.dart';
import '../transactions/presentation/add_expense_screen.dart';
import '../wallet/wallet_screen.dart';

class NavigationScreen extends ConsumerWidget {
  const NavigationScreen({super.key});

  final List<Widget> _pages = const [
    DashboardScreen(),
    WalletScreen(),
    AnalyticsScreen(),
    AiScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navigationIndexProvider);
    final items = <_NavItem>[
      _NavItem(icon: Icons.home_rounded, label: 'Home'),
      _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Wallet'),
      _NavItem(icon: Icons.auto_graph_rounded, label: 'Analytics'),
      _NavItem(icon: Icons.auto_awesome_rounded, label: 'AI'),
      _NavItem(icon: Icons.person_rounded, label: 'Profile'),
    ];

    return Scaffold(
      // The FAB below is docked (NudgedFabLocation) so it visually floats
      // ~40dp above the bottom bar's top edge, straddling the boundary
      // between `body` and `bottomNavigationBar`. Scaffold paints the FAB
      // as an overlay ON TOP of body content regardless of each tab's own
      // scroll padding, so without this reservation the FAB permanently
      // covers whatever happens to be at the bottom of a tab's content
      // (confirmed on-device on Dashboard and Analytics). Reserving this
      // clearance ONCE here — rather than adding matching bottom padding
      // to every individual tab screen — guarantees it for all five tabs,
      // including any added later, with a single source of truth.
      body: Padding(
        padding: const EdgeInsets.only(bottom: kFabBottomClearance),
        child: _pages[selectedIndex],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => const AddExpenseScreen(),
            ),
          );
        },
        backgroundColor: AppColors.accent,
        child: const Icon(Icons.add_rounded),
      ),
      floatingActionButtonLocation: const NudgedFabLocation(),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: SizedBox(
          height: 70,
          child: Row(
            children: List.generate(items.length, (index) {
              final item = items[index];
              final isSelected = selectedIndex == index;
              return Expanded(
                child: InkWell(
                  onTap: () =>
                      ref.read(navigationIndexProvider.notifier).state = index,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        item.icon,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;

  const _NavItem({required this.icon, required this.label});
}

/// Bottom padding reserved on every tab's body so [NudgedFabLocation]'s FAB
/// never overlaps content. Derivation: a standard FAB is 56dp, and
/// `centerDocked` centers it ON the body/bottomNavigationBar boundary — so
/// it extends 28dp above that boundary by default. `NudgedFabLocation`
/// nudges it up another 12dp (`dy`), for 40dp of overlap into the body.
/// Rounded up to 56dp to also clear the FAB's shadow/highlight halo.
const double kFabBottomClearance = 56;

/// [FloatingActionButtonLocation.centerDocked], nudged slightly left and up
/// so the FAB no longer sits directly over bottom-center screen content
/// (e.g. the Analytics tab's charts) while staying just as thumb-reachable
/// and still docked into the bottom bar's notch.
class NudgedFabLocation extends FloatingActionButtonLocation {
  const NudgedFabLocation();

  /// Shift applied to `centerDocked`'s offset: negative x moves left,
  /// negative y moves up.
  static const double dx = -24;
  static const double dy = -12;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final centerDocked = FloatingActionButtonLocation.centerDocked.getOffset(
      scaffoldGeometry,
    );
    return Offset(centerDocked.dx + dx, centerDocked.dy + dy);
  }

  @override
  String toString() => 'NudgedFabLocation';
}
