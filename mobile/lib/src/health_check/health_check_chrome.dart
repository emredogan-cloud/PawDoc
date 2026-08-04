import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/design_tokens.dart';
import '../theme/paw_components.dart';
import '../theme/paw_ui.dart';

/// Chrome shared by the four AI-Health-Check screens (`ai_health_check_start`,
/// `photo_analysis_upload`, `symptom_selection`, `ai_analysis_loading`).
///
/// The mockups give the flow one identity: a circled back button, a centred
/// title, a circled help button, and — from the second screen on — a node rail
/// showing where you are. Both are here so no screen re-draws them.

/// The circled back / title / help header.
class HealthCheckAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HealthCheckAppBar({this.title = 'AI Health Check', this.onHelp, super.key});

  final String title;
  final VoidCallback? onHelp;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: 64,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
          child: Row(
            children: [
              _CircleButton(
                icon: LucideIcons.chevronLeft,
                tooltip: 'Back',
                onTap: () => Navigator.of(context).maybePop(),
                color: Colors.white,
              ),
              Expanded(
                child: Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700)),
              ),
              _CircleButton(
                icon: LucideIcons.circleHelp,
                tooltip: 'How this works',
                onTap: onHelp ?? () => _showHelp(context),
                color: t.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _showHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF0A0F0B),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => const SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppSpace.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How the AI health check works',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              SizedBox(height: AppSpace.s12),
              Text(
                'You describe what you are seeing and, if it helps, add a '
                'photo. PawDoc reviews it and tells you what to do next and '
                'by when.\n\n'
                'It is guidance, not a diagnosis, and it is never a '
                'replacement for professional veterinary care. If something '
                'looks like an emergency, contact a vet straight away.',
                style: TextStyle(
                    color: Color(0xFF9BA5A0), fontSize: 14, height: 1.45),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    required this.color,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;
  final Color color;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF141B14),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, size: 21, color: color),
          ),
        ),
      );
}

/// Where you are in the check. The mockups draw four nodes on the photo and
/// details screens and five once the analysis starts, so the count is a
/// parameter rather than a constant.
class HealthCheckSteps extends StatelessWidget {
  const HealthCheckSteps({
    required this.current,
    required this.steps,
    super.key,
  });

  /// 0-based.
  final int current;

  /// (icon, label)
  final List<(IconData, String)> steps;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Semantics(
      label: 'Step ${current + 1} of ${steps.length}: ${steps[current].$2}',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < steps.length; i++) ...[
              if (i > 0)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 23),
                    child: Container(
                      height: 1.6,
                      color: i <= current
                          ? t.accent
                          : Colors.white.withValues(alpha: 0.14),
                    ),
                  ),
                ),
              _Node(
                icon: steps[i].$1,
                label: steps[i].$2,
                index: i,
                state: i < current
                    ? _NodeState.done
                    : i == current
                        ? _NodeState.active
                        : _NodeState.pending,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _NodeState { done, active, pending }

class _Node extends StatelessWidget {
  const _Node({
    required this.icon,
    required this.label,
    required this.index,
    required this.state,
  });

  final IconData icon;
  final String label;
  final int index;
  final _NodeState state;

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    final active = state == _NodeState.active;
    final done = state == _NodeState.done;
    return SizedBox(
      width: 64,
      child: Column(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? t.accent : const Color(0xFF141B14),
              border: Border.all(
                color: active
                    ? t.accent
                    : done
                        ? t.accent
                        : Colors.white.withValues(alpha: 0.16),
                width: active ? 2 : 1.4,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                          color: t.accent.withValues(alpha: 0.45),
                          blurRadius: 18,
                          spreadRadius: -2)
                    ]
                  : null,
            ),
            child: Icon(
              done ? LucideIcons.check : icon,
              size: 21,
              color: done
                  ? const Color(0xFF06140A)
                  : active
                      ? t.accent
                      : const Color(0xFF6C766F),
            ),
          ),
          const SizedBox(height: 5),
          Container(
            width: 19,
            height: 19,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active || done
                  ? t.accent.withValues(alpha: 0.9)
                  : const Color(0xFF232B23),
            ),
            child: Text('${index + 1}',
                style: TextStyle(
                    color: active || done
                        ? const Color(0xFF06140A)
                        : const Color(0xFF8A948D),
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 4),
          Text(label,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                  color: active ? t.accent : const Color(0xFF9BA5A0),
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
        ],
      ),
    );
  }
}

/// The steps the flow draws before the analysis starts.
const healthCheckSteps4 = <(IconData, String)>[
  (LucideIcons.check, 'Start'),
  (LucideIcons.camera, 'Photo'),
  (LucideIcons.clipboardList, 'Details'),
  (LucideIcons.brain, 'AI Analysis'),
];

/// …and once it does, with the result step revealed.
const healthCheckSteps5 = <(IconData, String)>[
  (LucideIcons.check, 'Start'),
  (LucideIcons.camera, 'Photo'),
  (LucideIcons.clipboardList, 'Details'),
  (LucideIcons.activity, 'AI Analysis'),
  (LucideIcons.user, 'Results'),
];

/// The disclaimer strip every screen in the flow closes with.
class HealthCheckDisclaimer extends StatelessWidget {
  const HealthCheckDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final t = PawTone.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(LucideIcons.shieldCheck, size: 15, color: t.accent),
        const SizedBox(width: 6),
        const Flexible(
          child: Text('Not a replacement for professional veterinary care.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF8A948D), fontSize: 12.5)),
        ),
      ],
    );
  }
}

/// The flow's page shell: chrome on top, content scrolling, a pinned action.
///
/// Same reasoning as onboarding — the mockups all put their CTA at the foot of
/// the screen, and at readable type the content runs past the viewport.
class HealthCheckScaffold extends StatelessWidget {
  const HealthCheckScaffold({
    required this.body,
    this.footer,
    this.title = 'AI Health Check',
    super.key,
  });

  final List<Widget> body;
  final Widget? footer;
  final String title;

  @override
  Widget build(BuildContext context) {
    return PawBackground(
      variant: PawSurface.dark,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: HealthCheckAppBar(title: title),
        body: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppSpace.s16, AppSpace.s8, AppSpace.s16, AppSpace.s16),
                children: body,
              ),
            ),
            if (footer != null)
              DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x000A0F0B), Color(0xFF060906)],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpace.s16, AppSpace.s12, AppSpace.s16, AppSpace.s8),
                    child: footer,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
