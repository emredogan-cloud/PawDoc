import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../health/history_timeline_screen.dart';
import '../home/home_screen.dart';
import '../onboarding/pending_pet.dart';
import '../pets/pets_list_screen.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import 'paw_nav_bar.dart';

/// Root tab shell.
///
/// Four destinations plus a centre action button. Mounted only at `/`;
/// `/sign-in`, `/onboarding` and every pushed detail screen render without
/// tabs, exactly as before. Tabs are a local [IndexedStack] (state preserved
/// per tab) and the go_router table, auth redirect and deep links are
/// UNCHANGED, so nothing using `context.go/push` breaks.
///
/// The bar itself lives in `paw_nav_bar.dart` — the record mockups draw it on
/// pushed screens too, and it selects the tab through [rootTabProvider] so
/// there is only ever one shell.
///
/// **Emergency is a permanent destination.** The mockups' Variant B puts
/// Premium in this slot on nine screens (conflict C-7 / review V-24), which
/// would displace the fastest route to GET_HELP_NOW behind a paywall surface.
/// `CLAUDE.md` forbids that, so Premium is reached from Account and contextual
/// upsells instead, and Emergency is reachable in one tap from every tab —
/// stronger than the previous shell, where it lived only on Home.
///
/// Assistant moved from a tab into the centre sheet: it is an *action* ("ask
/// about something") alongside photo and text capture, and four destinations
/// keeps every target comfortably above 48dp at 320dp width. Account keeps its
/// existing Home app-bar entry point, so nothing became unreachable.
class RootShell extends ConsumerStatefulWidget {
  const RootShell({super.key});

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  @override
  void initState() {
    super.initState();
    // The pet collected during the pre-auth onboarding journey has no owner
    // until now. This is the first authenticated surface every sign-in path
    // lands on — Google, email, guest and a returning user alike — so it is
    // the one place the draft can be flushed once.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => PendingPet.flush(ref));
  }

  static const _pages = <Widget>[
    HomeScreen(),
    PetsListScreen(),
    HealthHistoryScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return PawSystemScope(
      system: PawSystem.b,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(
          index: ref.watch(rootTabProvider),
          children: _pages,
        ),
        bottomNavigationBar: const PawNavBar(),
      ),
    );
  }
}
