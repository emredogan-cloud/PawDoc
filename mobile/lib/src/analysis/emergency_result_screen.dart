import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../analytics/analytics.dart';
import '../config/legal_urls.dart';
import '../emergency/emergency_help_screen.dart';
import '../health_check/health_check_chrome.dart';
import '../health_check/result_sections.dart';
import '../home/home_sections.dart';
import '../models/analysis_result.dart';
import '../theme/app_assets.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import '../vet_finder/maps_links.dart';
import 'result_l10n.dart';

/// EMERGENCY result, built to mockup `ai_analysis_result_emergency`.
///
/// **Owner decision D-7 (2026-08-04).** CLAUDE.md rule 4 and D-1 allow this
/// surface only help contacts, first aid, the disclaimer and the acknowledgment
/// gate, which is why the risk card, the "why it's serious" list, the concern
/// card and the score dial were previously omitted. The owner has authorised
/// rebuilding those four sections **with PawDoc copy** — the mockup stays a
/// visual reference, never a copy source. So:
///
/// | Mockup | Shipped |
/// |---|---|
/// | "Emergency Risk Level · High" | "Care Priority · Immediate" — an urgency, not a grade |
/// | "Why it's serious:" (AI conclusions) | "Why we're flagging this" — the observations that triggered it |
/// | "Potential Concern: Skin Infection" | "Immediate Veterinary Assessment Recommended / Observed changes requiring veterinary review" |
/// | "Health Score 36 · At Risk" | "Review Status · Needs Immediate Attention" — no number graded against health |
/// | "…for faster diagnosis" | "…so they have everything you've recorded" |
///
/// Nothing about the gate changed: back is blocked until the user
/// acknowledges, the vet CTA is never paywalled, and this screen still
/// carries **zero motion widgets** (`no_motion_on_safety_surfaces_test`) —
/// static is safest here, so there is no stagger, no rig and no animated glow.
class EmergencyResultScreen extends ConsumerStatefulWidget {
  const EmergencyResultScreen(
      {super.key, required this.result, this.petName, this.petSpecies});

  final AnalysisResult result;
  final String? petName;

  /// Fills the mockup's photo slot with a STILL portrait. Never the living
  /// rig — this screen renders zero motion widgets, permanently.
  final String? petSpecies;

  @override
  ConsumerState<EmergencyResultScreen> createState() =>
      _EmergencyResultScreenState();
}

class _EmergencyResultScreenState extends ConsumerState<EmergencyResultScreen> {
  bool _acknowledged = false;

  /// Safety-locked emergency red. The mockup runs it as an accent on the
  /// near-black canvas rather than as a full-bleed fill; the signal is carried
  /// by the rail, the hero, every glyph and the CTA, so the red path is no
  /// less unmistakable.
  static const _red = AppColors.emergencyLight;
  static const _redBright = AppColors.emergencyDark;

  @override
  void initState() {
    super.initState();
    Analytics.emergencyTriggered();
    Analytics.resultViewed('EMERGENCY');
  }

  Future<void> _findVet() async {
    // OS maps deep link: the maps app handles location itself, so this needs
    // no permission, no network to OUR servers, and works in an emergency.
    unawaited(Analytics.vetFinderOpened());
    await launchUrl(emergencyVetSearchMapsUri(),
        mode: LaunchMode.externalApplication);
  }

  void _firstAid() => Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EmergencyHelpScreen()));

  Future<void> _share() async {
    final r = widget.result;
    await SharePlus.instance.share(ShareParams(
      text: 'PawDoc check — urgent.\n${r.observation}\n\n'
          'Recorded via PawDoc 🐾',
    ));
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    // CR #11 (Phase 5.4): localized strings. `l!` is safe — AppLocalizations
    // is set up via the MaterialApp delegates; if missing in dev/test we'd
    // fail fast (acceptable, since this screen is safety-critical).
    final l = AppLocalizations.of(context)!;

    // What triggered the escalation, in the owner's own terms. Observations,
    // never conclusions — and the hardcoded floor is appended so the list is
    // never empty even when the payload carries nothing specific.
    // Deliberately does NOT repeat the observation — the hero already carries
    // it, and printing it twice made the card read as two separate findings.
    final flags = <String>[
      ...r.visibleSymptoms,
      'PawDoc flags this kind of description for urgent review',
      'Signs like this are assessed in person, not from a photo',
      'Waiting can make some situations harder to treat',
    ];

    return PopScope(
      canPop: _acknowledged, // acknowledgment gate — unchanged
      child: PawBackground(
        variant: PawSurface.dark,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: const HealthCheckAppBar(tint: _redBright),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
                AppSpace.s16, AppSpace.s8, AppSpace.s16, AppSpace.s24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const HealthCheckSteps(
                  current: 4,
                  steps: healthCheckSteps5,
                  tint: _redBright,
                  currentIcon: LucideIcons.circleAlert,
                ),
                const SizedBox(height: AppSpace.s20),
                _Hero(
                    title: l.emergencyTitle,
                    result: r,
                    l: l,
                    species: widget.petSpecies),
                const SizedBox(height: AppSpace.s12),

                // ---- D-7 §1: urgency, not a grade -----------------------
                HomeCard(
                  accent: _red.withValues(alpha: 0.55),
                  glow: 0.16,
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 44,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 54,
                              height: 54,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _red.withValues(alpha: 0.12),
                                border: Border.all(
                                    color: _redBright.withValues(alpha: 0.55)),
                              ),
                              child: const Icon(LucideIcons.shieldAlert,
                                  size: 26, color: _redBright),
                            ),
                            const SizedBox(height: 10),
                            const Text('Care Priority',
                                style: TextStyle(
                                    color: Color(0xFFB8C2BB), fontSize: 12.5)),
                            const SizedBox(height: 2),
                            const Text('Immediate',
                                style: TextStyle(
                                    color: _redBright,
                                    fontSize: 24,
                                    height: 1.1,
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            const Text(
                                'Contact a veterinarian now — do not wait to '
                                'see if it settles.',
                                style: TextStyle(
                                    color: Color(0xFFB8C2BB),
                                    fontSize: 12,
                                    height: 1.35)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 56,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Why we’re flagging this',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 9),
                            for (final f in flags)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 7),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Padding(
                                      padding: EdgeInsets.only(top: 5),
                                      child: _Dot(),
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(f,
                                          style: const TextStyle(
                                              color: Color(0xFFDCE3DE),
                                              fontSize: 12,
                                              height: 1.35)),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.s12),

                // ---- help contacts (rule 4, always permitted) -----------
                HomeCard(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(children: [
                        Icon(LucideIcons.circlePlus,
                            size: 17, color: _redBright),
                        SizedBox(width: 7),
                        Text('What to do now',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      ]),
                      const SizedBox(height: 10),
                      HomeQuickActions(items: [
                        (
                          const Key('emergency_find_vet'),
                          LucideIcons.phone,
                          'Call a Vet Now',
                          'Find & call vets near you',
                          _findVet,
                          _redBright,
                        ),
                        (
                          const Key('emergency_find_24_7'),
                          LucideIcons.mapPin,
                          'Find 24/7 Vet',
                          'Locate nearest clinics',
                          _findVet,
                          _redBright,
                        ),
                        (
                          const Key('emergency_directions'),
                          LucideIcons.car,
                          'Directions',
                          'Get there fastest',
                          _findVet,
                          _redBright,
                        ),
                        (
                          const Key('emergency_first_aid'),
                          LucideIcons.bookOpen,
                          'First Aid',
                          'Steps while you go',
                          _firstAid,
                          _redBright,
                        ),
                      ]),
                      const SizedBox(height: 12),
                      // ---- first aid (rule 4, always permitted) ---------
                      HomeCard(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(children: [
                              Icon(LucideIcons.heartPulse,
                                  size: 17, color: _redBright),
                              SizedBox(width: 7),
                              Text('While you’re on the way',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700)),
                            ]),
                            const SizedBox(height: 10),
                            const ResultActionRow(
                              icon: LucideIcons.house,
                              title: 'Keep your pet calm',
                              detail:
                                  'Reduce stress. A quiet, dim space helps.',
                              tint: _redBright,
                            ),
                            const ResultActionRow(
                              icon: LucideIcons.thermometer,
                              title: 'Do not give any medication',
                              detail:
                                  'Human medicines can be harmful. Wait for '
                                  'your vet.',
                              tint: _redBright,
                            ),
                            const ResultActionRow(
                              icon: LucideIcons.droplet,
                              title: 'Avoid pressure on the area',
                              detail:
                                  'Do not squeeze, press or clean it yourself.',
                              tint: _redBright,
                            ),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                key: const Key('emergency_first_aid_guide'),
                                onPressed: _firstAid,
                                style: TextButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(LucideIcons.bookOpen,
                                        size: 16, color: _redBright),
                                    SizedBox(width: 7),
                                    Text('View Full First Aid Guide',
                                        style: TextStyle(
                                            color: _redBright,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                    Icon(LucideIcons.chevronRight,
                                        size: 16, color: _redBright),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.s12),

                // ---- D-7 §2: hand the record over, no "diagnosis" -------
                ResultAssistantStrip(
                  icon: LucideIcons.fileText,
                  title: 'Share this with your vet',
                  detail: 'Send what you recorded so they have it before you '
                      'arrive.',
                  buttonIcon: LucideIcons.share2,
                  buttonLabel: 'Share',
                  buttonKey: const Key('emergency_share'),
                  onAsk: _share,
                  tint: _redBright,
                ),
                const SizedBox(height: AppSpace.s12),

                // ---- D-7 §3 + §4: the closing pair ----------------------
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(
                        child: ResultStatusCard(
                          label: 'Next step',
                          value: 'Immediate Veterinary Assessment',
                          caption:
                              'Observed changes requiring veterinary review.',
                          tint: _redBright,
                          icon: LucideIcons.stethoscope,
                        ),
                      ),
                      const SizedBox(width: AppSpace.s8),
                      Expanded(
                        child: ResultStatusCard(
                          label: 'Review Status',
                          // A status, not a score: no number is graded against
                          // this animal's health (D-2 stands).
                          value: 'Needs Immediate Attention',
                          caption: 'Awaiting veterinary review.',
                          tint: _redBright,
                          ring: 1.0,
                          ringLabel: '!',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpace.s16),

                // ---- the gate (rule 4, always permitted) ---------------
                CheckboxListTile(
                  key: const Key('emergency_ack_checkbox'),
                  value: _acknowledged,
                  onChanged: (v) => setState(() => _acknowledged = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  tileColor: _red.withValues(alpha: 0.10),
                  checkColor: Colors.white,
                  activeColor: _red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: _red.withValues(alpha: 0.45)),
                  ),
                  title: Text(l.emergencyAcknowledge,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13.5, height: 1.35)),
                ),
                const SizedBox(height: AppSpace.s12),
                FilledButton(
                  key: const Key('emergency_continue'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _red.withValues(alpha: 0.35),
                    disabledForegroundColor:
                        Colors.white.withValues(alpha: 0.6),
                    shape: const StadiumBorder(),
                    minimumSize: const Size.fromHeight(58),
                    textStyle: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  onPressed:
                      _acknowledged ? () => Navigator.of(context).maybePop() : null,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.siren, size: 19),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                            _acknowledged
                                ? l.actionContinue
                                : 'I Understand, Take Me to Help',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const Icon(LucideIcons.chevronRight, size: 19),
                    ],
                  ),
                ),
                if (r.disclaimerRequired) ...[
                  const SizedBox(height: AppSpace.s16),
                  HealthCheckDisclaimer(
                    tint: _redBright,
                    extraLine: l.emergencyDisclaimer,
                  ),
                  const SizedBox(height: AppSpace.s8),
                  Center(
                    child: GestureDetector(
                      onTap: () => LegalUrls.open(LegalUrls.emergency),
                      child: const Text(
                        'Read the full Emergency Disclaimer',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF8A948D),
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The mockup's split hero: the siren, the two-weight headline, the deck, and
/// the submitted photo on the right.
class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.result,
    required this.l,
    this.species,
  });

  final String title;
  final AnalysisResult result;
  final AppLocalizations l;
  final String? species;

  @override
  Widget build(BuildContext context) {
    const red = _EmergencyResultScreenState._red;
    const bright = _EmergencyResultScreenState._redBright;
    return HomeCard(
      accent: red.withValues(alpha: 0.55),
      glow: 0.20,
      padding: const EdgeInsets.all(14),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 55,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(LucideIcons.siren, size: 24, color: bright),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 19,
                              height: 1.15,
                              fontWeight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  // M0 F-3: dynamic values are display-localized (template +
                  // urgency mapping); unknown values pass through verbatim.
                  Text(localizedPrimaryConcern(l, result.observation),
                      style: const TextStyle(
                          color: Color(0xFFDCE3DE),
                          fontSize: 13,
                          height: 1.4)),
                  const SizedBox(height: 8),
                  Text(
                      l.emergencyRecommendedPrefix(
                          localizedUrgency(l, result.urgencyTimeframe)),
                      style: const TextStyle(
                          color: bright,
                          fontSize: 13,
                          height: 1.4,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 45,
              child: AspectRatio(
                aspectRatio: 0.94,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF161010),
                      border: Border.all(color: red.withValues(alpha: 0.35)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: species == null
                        ? const Center(
                            child: Icon(LucideIcons.imageOff,
                                size: 28, color: Color(0xFF6C5F5F)),
                          )
                        : Image.asset(AppAssets.species(species!),
                            fit: BoxFit.cover, excludeFromSemantics: true),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: _EmergencyResultScreenState._redBright),
      );
}
