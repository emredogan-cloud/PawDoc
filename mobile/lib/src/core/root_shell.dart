import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../assistant/assistant_screen.dart';
import '../capture/camera_screen.dart';
import '../emergency/emergency_help_screen.dart';
import '../health/history_timeline_screen.dart';
import '../home/home_screen.dart';
import '../onboarding/pending_pet.dart';
import '../pets/pets_list_screen.dart';
import '../text_input/symptom_text_screen.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';

/// Root tab shell.
///
/// Four destinations plus a centre action button. Mounted only at `/`;
/// `/sign-in`, `/onboarding` and every pushed detail screen render without
/// tabs, exactly as before. Tabs are a local [IndexedStack] (state preserved
/// per tab) and the go_router table, auth redirect and deep links are
/// UNCHANGED, so nothing using `context.go/push` breaks.
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
  int _index = 0;

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

  void _openEmergency() {
    // Pushed rather than swapped into the IndexedStack: the red path must be
    // dismissible back to wherever the user was, and must never become a tab
    // whose state persists between visits.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EmergencyHelpScreen()),
    );
  }

  Future<void> _openActionSheet() async {
    final nav = Navigator.of(context);
    final choice = await showModalBottomSheet<_QuickAction>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ActionSheet(),
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case _QuickAction.photo:
        await nav.push(MaterialPageRoute(builder: (_) => const CameraScreen()));
      case _QuickAction.symptoms:
        await nav.push(
            MaterialPageRoute(builder: (_) => const SymptomTextScreen()));
      case _QuickAction.assistant:
        await nav.push(MaterialPageRoute(builder: (_) => const AssistantScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PawSystemScope(
      system: PawSystem.b,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: IndexedStack(index: _index, children: _pages),
        bottomNavigationBar: _PawNavBar(
          index: _index,
          onSelect: (i) => setState(() => _index = i),
          onCentre: _openActionSheet,
          onEmergency: _openEmergency,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _PawNavBar extends StatelessWidget {
  const _PawNavBar({
    required this.index,
    required this.onSelect,
    required this.onCentre,
    required this.onEmergency,
  });

  final int index;
  final ValueChanged<int> onSelect;
  final VoidCallback onCentre;
  final VoidCallback onEmergency;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Container(
      decoration: BoxDecoration(
        color: t.canvas,
        border: Border(top: BorderSide(color: t.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              _NavItem(
                icon: LucideIcons.house,
                label: 'Home',
                selected: index == 0,
                onTap: () => onSelect(0),
              ),
              _NavItem(
                icon: LucideIcons.pawPrint,
                label: 'Pets',
                selected: index == 1,
                onTap: () => onSelect(1),
              ),
              _CentreButton(onTap: onCentre),
              _NavItem(
                icon: LucideIcons.heartPulse,
                label: 'Health',
                selected: index == 2,
                onTap: () => onSelect(2),
              ),
              // Never `selected`: it pushes a screen rather than switching a
              // tab, and it carries the safety-locked red, not the brand lime.
              _NavItem(
                key: const Key('root_nav_emergency'),
                icon: LucideIcons.circleAlert,
                label: 'Emergency',
                selected: false,
                color: AppColors.emergency(Theme.of(context).brightness),
                onTap: onEmergency,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.color,
    super.key,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final c = color ?? (selected ? t.accent : t.textMuted);
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: c),
              const SizedBox(height: 3),
              // Labels are never dropped at large text scales — an icon-only
              // nav is unusable for anyone who cannot read the pictogram.
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: c,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CentreButton extends StatelessWidget {
  const _CentreButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Expanded(
      child: Center(
        child: Semantics(
          button: true,
          label: 'New check',
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Container(
              key: const Key('root_nav_centre'),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: t.accent, width: 2),
                color: t.accentWash(0.14),
              ),
              child: Icon(LucideIcons.plus, size: 26, color: t.accent),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

// "Log event" is deliberately absent: the form requires a pet, and the shell
// has no active-pet context. It stays on Home and Health, where one is selected.
enum _QuickAction { photo, symptoms, assistant }

class _ActionSheet extends StatelessWidget {
  const _ActionSheet();

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return PawSystemScope(
      system: PawSystem.b,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpace.s16),
                decoration: BoxDecoration(
                  color: t.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              PawListRow(
                title: 'Photo check',
                subtitle: 'Take or upload a photo',
                leading: const PawIconTile(child: PawIcon(LucideIcons.camera)),
                onTap: () => Navigator.pop(context, _QuickAction.photo),
              ),
              const SizedBox(height: AppSpace.s8),
              PawListRow(
                title: 'Describe symptoms',
                subtitle: 'Type what you are seeing',
                leading: const PawIconTile(child: PawIcon(LucideIcons.pencil)),
                onTap: () => Navigator.pop(context, _QuickAction.symptoms),
              ),
              const SizedBox(height: AppSpace.s8),
              PawListRow(
                title: 'Ask PawDoc AI',
                subtitle: 'General pet-care questions',
                leading:
                    const PawIconTile(child: PawIcon(LucideIcons.messageCircle)),
                onTap: () => Navigator.pop(context, _QuickAction.assistant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
