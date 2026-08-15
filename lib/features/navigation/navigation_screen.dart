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
      body: _pages[selectedIndex],
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
