import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../assistant/assistant_screen.dart';
import '../capture/camera_screen.dart';
import '../emergency/emergency_help_screen.dart';
import '../text_input/symptom_text_screen.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';

/// Which root tab [RootShell] is showing.
///
/// Lifted out of the shell's `State` so a **pushed** screen can select a tab
/// too. Every mockup in the record set (`conversation_history`,
/// `health_timeline`, `weight_tracking`, `medication_tracker`,
/// `vaccination_manager`) draws the bottom bar, and a bar that cannot navigate
/// is a picture of a bar.
class RootTab extends Notifier<int> {
  @override
  int build() => 0;

  void select(int index) => state = index;
}

final rootTabProvider = NotifierProvider<RootTab, int>(RootTab.new);

/// The app's bottom navigation, as the mockups draw it: an inset rounded slab
/// with a hairline, four destinations and the centre action ring.
///
/// **Emergency is a permanent destination.** The mockups put *Settings* (and,
/// in Variant B, *Premium*) in this slot — conflict C-7 / review V-24 — which
/// would displace the fastest route to GET_HELP_NOW. `CLAUDE.md` forbids that,
/// so the composition, height, radius and glow of the mockup's bar are
/// reproduced while its destination list is not. `root_shell_test.dart` pins
/// this.
///
/// [detached] is set by screens pushed **over** the shell. They render the same
/// bar, and selecting a destination unwinds to the shell with that tab already
/// chosen rather than stacking a second copy of it.
class PawNavBar extends ConsumerWidget {
  const PawNavBar({this.detached = false, super.key});

  final bool detached;

  void _select(BuildContext context, WidgetRef ref, int index) {
    ref.read(rootTabProvider.notifier).select(index);
    if (detached) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  void _openEmergency(BuildContext context) {
    // Pushed rather than swapped into the IndexedStack: the red path must be
    // dismissible back to wherever the user was, and must never become a tab
    // whose state persists between visits.
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EmergencyHelpScreen()),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(rootTabProvider);
    final selected = detached ? -1 : index;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFF0A0F0B),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Row(
            children: [
              _NavItem(
                icon: LucideIcons.house,
                label: 'Home',
                selected: selected == 0,
                onTap: () => _select(context, ref, 0),
              ),
              _NavItem(
                icon: LucideIcons.pawPrint,
                label: 'Pets',
                selected: selected == 1,
                onTap: () => _select(context, ref, 1),
              ),
              PawNavCentreButton(
                onTap: () => openQuickActionSheet(context),
              ),
              _NavItem(
                icon: LucideIcons.heartPulse,
                label: 'Health',
                selected: selected == 2,
                onTap: () => _select(context, ref, 2),
              ),
              // Never `selected`: it pushes a screen rather than switching a
              // tab, and it carries the safety-locked red, not the brand lime.
              _NavItem(
                key: const Key('root_nav_emergency'),
                icon: LucideIcons.circleAlert,
                label: 'Emergency',
                selected: false,
                color: AppColors.emergency(Theme.of(context).brightness),
                onTap: () => _openEmergency(context),
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
          borderRadius: BorderRadius.circular(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 21, color: c),
              const SizedBox(height: 2),
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

/// The centre ring. Outlined rather than filled — mockup `010-home-page`, the
/// one this bar was first built against, draws it that way, and the record
/// mockups' filled variant would read as a floating action button sitting on
/// top of the bar rather than inside it.
class PawNavCentreButton extends StatelessWidget {
  const PawNavCentreButton({required this.onTap, super.key});

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
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: t.accent, width: 2),
                color: t.accentWash(0.14),
                boxShadow: [
                  BoxShadow(
                      color: t.accent.withValues(alpha: 0.22),
                      blurRadius: 18,
                      spreadRadius: -4),
                ],
              ),
              child: Icon(LucideIcons.plus, size: 25, color: t.accent),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// The centre action sheet
// ---------------------------------------------------------------------------

// "Log event" is deliberately absent: the form requires a pet, and the shell
// has no active-pet context. It stays on Home and Health, where one is selected.
enum QuickAction { photo, symptoms, assistant }

/// Opens the centre sheet and performs the chosen action.
Future<void> openQuickActionSheet(BuildContext context) async {
  final nav = Navigator.of(context);
  final choice = await showModalBottomSheet<QuickAction>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ActionSheet(),
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case QuickAction.photo:
      await nav.push(MaterialPageRoute(builder: (_) => const CameraScreen()));
    case QuickAction.symptoms:
      await nav.push(
          MaterialPageRoute(builder: (_) => const SymptomTextScreen()));
    case QuickAction.assistant:
      await nav.push(MaterialPageRoute(builder: (_) => const AssistantScreen()));
  }
}

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
                onTap: () => Navigator.pop(context, QuickAction.photo),
              ),
              const SizedBox(height: AppSpace.s8),
              PawListRow(
                title: 'Describe symptoms',
                subtitle: 'Type what you are seeing',
                leading: const PawIconTile(child: PawIcon(LucideIcons.pencil)),
                onTap: () => Navigator.pop(context, QuickAction.symptoms),
              ),
              const SizedBox(height: AppSpace.s8),
              PawListRow(
                title: 'Ask PawDoc AI',
                subtitle: 'General pet-care questions',
                leading:
                    const PawIconTile(child: PawIcon(LucideIcons.messageCircle)),
                onTap: () => Navigator.pop(context, QuickAction.assistant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
