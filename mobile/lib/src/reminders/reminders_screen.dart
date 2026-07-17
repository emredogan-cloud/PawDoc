import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/app_image.dart';
import '../core/dates.dart';
import '../pets/active_pet.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import '../notifications/local_notifications.dart';
import 'reminder_form_screen.dart';
import 'reminders_repository.dart';

/// Manage health reminders for the active pet. Reached from the Health History
/// screen. Reactive to the active pet (Phase 3.1 switcher).
class RemindersScreen extends ConsumerWidget {
  const RemindersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pet = ref.watch(activePetProvider);
    if (pet == null) {
      return PawBackground(
        variant: PawSurface.dark,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Reminders',
                style: TextStyle(color: AppColors.ink50)),
          ),
          body: const Center(
            child: Text(
              'Add a pet to set reminders.',
              style: TextStyle(color: AppColors.ink300),
            ),
          ),
        ),
      );
    }

    final reminders = ref.watch(remindersForPetProvider(pet.id!));

    return PawBackground(
      variant: PawSurface.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            '${pet.name} · reminders',
            style: const TextStyle(
                color: AppColors.ink50, fontWeight: FontWeight.w600),
          ),
        ),
        body: RefreshIndicator(
          color: PawPalette.mint,
          backgroundColor: const Color(0xFF123A31),
          onRefresh: () async => ref.invalidate(remindersForPetProvider(pet.id!)),
          child: reminders.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: PawPalette.mint),
            ),
            error: (e, _) => ListView(
              padding: const EdgeInsets.all(AppSpace.s16),
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpace.s24),
                  child: Text(
                    'Could not load reminders:\n$e',
                    style: const TextStyle(color: AppColors.ink300),
                  ),
                ),
              ],
            ),
            data: (list) => _RemindersBody(
              petId: pet.id!,
              petName: pet.name,
              reminders: list,
              ref: ref,
            ),
          ),
        ),
        floatingActionButton: _NewReminderButton(
          petId: pet.id!,
          petName: pet.name,
          ref: ref,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — splits list into upcoming / completed sections.
// ---------------------------------------------------------------------------

class _RemindersBody extends StatelessWidget {
  const _RemindersBody({
    required this.petId,
    required this.petName,
    required this.reminders,
    required this.ref,
  });

  final String petId;
  final String petName;
  final List<dynamic> reminders;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final upcoming = reminders.where((r) => !r.isSent).toList();
    final completed = reminders.where((r) => r.isSent).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppSpace.s16, AppSpace.s8, AppSpace.s16, 96),
      children: [
        // ---- Hero section ----
        _HeroSection(),
        const SizedBox(height: AppSpace.s24),

        if (reminders.isEmpty) ...[
          _EmptyState(),
        ] else ...[
          // ---- Upcoming ----
          if (upcoming.isNotEmpty) ...[
            _SectionHeader(label: 'Upcoming'),
            const SizedBox(height: AppSpace.s8),
            ...upcoming.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s8),
                  child: _ReminderCard(
                    reminder: r,
                    isCompleted: false,
                    onDelete: () async {
                      await ref
                          .read(remindersRepositoryProvider)
                          .delete(r.id!);
                      ref.invalidate(remindersForPetProvider(petId));
                    },
                    onEdit: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ReminderFormScreen(
                            petId: petId, petName: petName, existing: r),
                      ));
                      ref.invalidate(remindersForPetProvider(petId));
                    },
                  ),
                )),
            const SizedBox(height: AppSpace.s16),
          ],

          // ---- Completed ----
          if (completed.isNotEmpty) ...[
            _SectionHeader(label: 'Completed'),
            const SizedBox(height: AppSpace.s8),
            ...completed.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s8),
                  child: _ReminderCard(
                    reminder: r,
                    isCompleted: true,
                    onDelete: () async {
                      await ref
                          .read(remindersRepositoryProvider)
                          .delete(r.id!);
                      ref.invalidate(remindersForPetProvider(petId));
                    },
                  ),
                )),
            const SizedBox(height: AppSpace.s16),
          ],
        ],

        // ---- Tip card ----
        _NotificationTipCard(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Hero: bell illustration + headline + subtitle
// ---------------------------------------------------------------------------

class _HeroSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpace.s8),
        AppImage(
          AppAssets.onbBellDuo,
          height: 110,
          fallback: const Icon(
            Icons.notifications_active_rounded,
            size: 56,
            color: PawPalette.mint,
          ),
        ),
        const SizedBox(height: AppSpace.s16),
        const Text(
          'Never miss what matters',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.ink50,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpace.s8),
        const Text(
          'Set reminders for vaccines, meds, vet visits,\nand more.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.ink300,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.alarm_add_rounded,
              size: 48,
              color: PawPalette.mint.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpace.s16),
            const Text(
              'No reminders yet.',
              style: TextStyle(
                color: AppColors.ink50,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpace.s4),
            const Text(
              'Tap "New reminder" to add one.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.ink300, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section header ("Upcoming" / "Completed") in mint
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: PawPalette.mint,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual reminder card
// ---------------------------------------------------------------------------

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.isCompleted,
    required this.onDelete,
    this.onEdit,
  });

  final dynamic reminder;
  final bool isCompleted;
  final VoidCallback onDelete;

  /// Upcoming reminders open the edit form on tap (J6 — delete-only is gone).
  final VoidCallback? onEdit;

  IconData _iconForType(String type) {
    final t = type.toLowerCase();
    if (t.contains('vacc') || t.contains('dhpp') || t.contains('booster')) {
      return Icons.vaccines_rounded;
    }
    if (t.contains('med') || t.contains('flea') || t.contains('tick') ||
        t.contains('tablet')) {
      return Icons.medication_rounded;
    }
    if (t.contains('vet') || t.contains('check') || t.contains('visit')) {
      return Icons.local_hospital_rounded;
    }
    return Icons.alarm_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconColor = isCompleted
        ? AppColors.ink300
        : PawPalette.mint;
    final titleColor = isCompleted ? AppColors.ink300 : AppColors.ink50;
    final subtitleColor = AppColors.ink300;

    return PawCard(
      onTap: onEdit, // upcoming rows open the edit form; completed rows inert
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s12, vertical: AppSpace.s12),
      child: Row(
        children: [
          // Leading icon tile
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isCompleted
                  ? Colors.white.withValues(alpha: 0.04)
                  : PawPalette.teal.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: isCompleted
                ? Icon(Icons.check_circle_outline_rounded,
                    size: 20, color: AppColors.ink300)
                : Icon(_iconForType(reminder.reminderType),
                    size: 20, color: iconColor),
          ),
          const SizedBox(width: AppSpace.s12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date + time row
                Row(
                  children: [
                    Text(
                      shortDate(reminder.dueDate),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: isCompleted
                            ? AppColors.ink300.withValues(alpha: 0.7)
                            : PawPalette.mint,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s4),
                // Type (title)
                Text(
                  reminder.reminderType,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: titleColor,
                  ),
                ),
                if (isCompleted) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Done',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: subtitleColor),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s8),

          // Trailing: bell (upcoming) or delete
          Column(
            children: [
              IconButton(
                tooltip: 'Delete reminder',
                icon: Icon(
                  isCompleted
                      ? Icons.delete_outline_rounded
                      : Icons.notifications_none_rounded,
                  size: 20,
                  color: AppColors.ink300,
                ),
                onPressed: onDelete,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              if (!isCompleted)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: AppColors.ink300,
                ),
            ],
          ),
        ],
      ),
    );
  }

}

// ---------------------------------------------------------------------------
// Notification tip card
// ---------------------------------------------------------------------------

class _NotificationTipCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return PawCard(
      padding: const EdgeInsets.all(AppSpace.s12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: PawPalette.teal.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.lightbulb_outline_rounded,
              size: 18,
              color: PawPalette.mint,
            ),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Text(
              'Tip: Enable notifications to get reminded on time.',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.ink300),
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          GestureDetector(
            key: const Key('reminders_enable_notifications'),
            onTap: () async {
              // J6: this used to be a decorative no-op — it now actually asks.
              final granted = await ref
                  .read(localNotificationsProvider)
                  .ensurePermission();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(granted
                      ? 'Notifications are on.'
                      : 'Enable notifications in system settings to get reminded.')));
            },
            child: const Text(
              'Enable now',
              style: TextStyle(
                color: PawPalette.mint,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// "New reminder" floating action button (key preserved)
// ---------------------------------------------------------------------------

class _NewReminderButton extends StatelessWidget {
  const _NewReminderButton({
    required this.petId,
    required this.petName,
    required this.ref,
  });

  final String petId;
  final String petName;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return PawPrimaryButton(
      key: const Key('add_reminder_fab'),
      onPressed: () async {
        await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) =>
              ReminderFormScreen(petId: petId, petName: petName),
        ));
        ref.invalidate(remindersForPetProvider(petId));
      },
      icon: Icons.add_rounded,
      expand: false,
      child: const Text('New reminder'),
    );
  }
}
