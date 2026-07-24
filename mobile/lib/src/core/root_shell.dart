import 'package:flutter/material.dart';

import '../account/account_screen.dart';
import '../assistant/assistant_screen.dart';
import '../health/history_timeline_screen.dart';
import '../home/home_screen.dart';
import '../pets/pets_list_screen.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';

/// Root tab shell (launch-hardening obj 12): a persistent bottom navigation over
/// the four primary destinations, reusing the EXISTING screens and routes.
///
/// Design choices that keep flows intact:
/// - Mounted only at `/` (signed-in home). `/sign-in`, `/onboarding`, and all
///   pushed detail screens (capture, result, family, etc.) render WITHOUT tabs,
///   exactly as before — they push over this shell.
/// - Tabs are a local [IndexedStack] (state preserved per tab); the go_router
///   route table, auth redirect, and deep links (`/pets`, `/history`, `/family`,
///   `/invite/:token`, `/r/:code`) are UNCHANGED, so nothing that used
///   `context.go/push` breaks.
/// - Each tab screen keeps its own Scaffold/AppBar; with no route to pop, those
///   AppBars correctly show no back button while in a tab.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _index = 0;

  // Next Evolution Phase 4: the Assistant is a permanent center destination.
  static const _pages = <Widget>[
    HomeScreen(),
    PetsListScreen(),
    AssistantScreen(),
    HealthHistoryScreen(),
    AccountScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppColors.ink900,
          surfaceTintColor: Colors.transparent,
          indicatorColor: PawPalette.teal.withValues(alpha: 0.28),
          labelTextStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? PawPalette.mint
                  : AppColors.ink300,
            ),
          ),
        ),
        child: NavigationBar(
          key: const Key('root_bottom_nav'),
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.pets_outlined),
              selectedIcon: Icon(Icons.pets_rounded),
              label: 'Pets',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome_rounded),
              label: 'Assistant',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_outline_rounded),
              selectedIcon: Icon(Icons.favorite_rounded),
              label: 'Health',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
