/// The pieces `emergency_hub` and `first_aid_guide` share.
///
/// **This file is bound by the emergency-path rule in `CLAUDE.md`.** Nothing
/// here may reach a model, a paywall, an affiliate or the network beyond the
/// two OS hand-offs below (a `tel:` dial and a maps deep link), and nothing
/// may render a risk level, a severity grade, or an assessment of an animal.
/// Both screens must stay usable with the radio off.
///
/// Presentation metadata for the first-aid cards lives here rather than in
/// `first_aid.dart` so that file stays pure content — a veterinarian reviewing
/// the copy (its standing founder gate) should not have to read past icon
/// names and tints to do it.
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../analytics/analytics.dart';
import '../health/health_sections.dart';
import '../theme/design_tokens.dart';
import '../vet_finder/maps_links.dart';
import 'first_aid.dart';

// ---------------------------------------------------------------------------
// Help contacts — the only two "actions" the red path has
// ---------------------------------------------------------------------------

const String kPoisonControlLabel = 'ASPCA Animal Poison Control (US)';
const String kPoisonControlNumber = '+18884264435'; // (888) 426-4435

/// A consultation fee applies to this line and the screen says so, because a
/// surprise charge is how an owner learns not to trust the next prompt.
const String kPoisonControlNote =
    '$kPoisonControlLabel — a consultation fee may apply.';

Future<void> dialPoisonControl() async {
  await Analytics.vetCalled();
  await launchUrl(Uri.parse('tel:$kPoisonControlNumber'));
}

Future<void> openEmergencyVetMaps() async {
  await Analytics.vetFinderOpened();
  await launchUrl(emergencyVetSearchMapsUri(),
      mode: LaunchMode.externalApplication);
}

// ---------------------------------------------------------------------------
// First-aid presentation
// ---------------------------------------------------------------------------

/// The order the guide lists its cards in — **fixed, and never sorted by
/// relevance, recency or anything a model produced** (review item V-27).
///
/// The reference sorts by "Most relevant ⌄" and badges four of its seven rows
/// "High Priority". Both were dropped. A relevance sort on an offline safety
/// surface implies a ranking the app cannot compute, and badging some rows
/// high-priority tells the reader the unbadged ones are not — which is the
/// false-negative direction, the failure this product exists to avoid. The
/// order carries the urgency instead, and the section head says so.
const List<String> kFirstAidOrder = [
  'bleeding',
  'choking',
  'bloat',
  'heatstroke',
  'seizure',
];

/// [kFirstAidTopics] in guide order. Any card missing from [kFirstAidOrder]
/// still appears, after the ordered ones — a new card must never be invisible
/// merely because this list was not updated with it.
List<FirstAidTopic> orderedFirstAidTopics() {
  final byId = {for (final t in kFirstAidTopics) t.id: t};
  return [
    for (final id in kFirstAidOrder)
      if (byId[id] != null) byId[id]!,
    for (final t in kFirstAidTopics)
      if (!kFirstAidOrder.contains(t.id)) t,
  ];
}

/// The glossy square the reference draws beside each topic. Shipped assets
/// exist for four of the five cards; [firstAidRailIcon] covers the rest.
///
/// They are all the same red on purpose. The reference tints its rows seven
/// different colours, which reads as a severity scale — a blue row beside a
/// red one says "this one is less urgent". Everything on this screen is
/// urgent.
String? firstAidGlyph(String id) => switch (id) {
      'bleeding' => 'assets/icons/firstaid/ic-fa-bleeding@3x.png',
      'choking' => 'assets/icons/firstaid/ic-fa-choking@3x.png',
      'heatstroke' => 'assets/icons/firstaid/ic-fa-heatstroke@3x.png',
      'bloat' => 'assets/icons/firstaid/ic-fa-vomiting@3x.png',
      _ => null,
    };

/// A first-aid card's glyph: the shipped sticker asset where one exists, and
/// the line glyph on a tinted square where it does not.
///
/// The stickers are 192px plates drawn with a **white frame and a drop shadow**
/// around the red square, on transparency. Dropped straight into a near-black
/// card that frame reads as a rendering fault — a white halo on four corners.
/// The red plate's bounding box is x∈[25,166], y∈[11,162], so the image is
/// scaled past the frame and re-centred on the plate, which sits about 10px
/// above the canvas centre.
class FirstAidGlyph extends StatelessWidget {
  const FirstAidGlyph({required this.id, this.size = 46, super.key});

  final String id;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = firstAidGlyph(id);
    if (asset == null) {
      return HealthGlyphDisc(
          icon: firstAidRailIcon(id),
          tint: AppColors.emergencyDark,
          size: size,
          square: true);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: SizedBox(
        width: size,
        height: size,
        child: Transform.scale(
          scale: 1.34,
          alignment: const Alignment(0, -0.14),
          child: Image.asset(asset, fit: BoxFit.cover),
        ),
      ),
    );
  }
}

/// One word for the category rail, where a card's full title does not fit.
///
/// The reference's rail is single words — Bleeding, Choking, Poisoning,
/// Heatstroke. "Swollen, hard belly" under a 44dp circle either shrinks to
/// unreadable or runs into its neighbour, so the rail names the category and
/// the row keeps the card's real title.
String firstAidShortLabel(String id) => switch (id) {
      'bleeding' => 'Bleeding',
      'choking' => 'Choking',
      'heatstroke' => 'Heat',
      'bloat' => 'Belly',
      'seizure' => 'Seizure',
      _ => 'Other',
    };

/// The line glyph the category rail draws, and the fallback for a card with no
/// shipped square.
IconData firstAidRailIcon(String id) => switch (id) {
      'bleeding' => LucideIcons.droplet,
      'choking' => LucideIcons.wind,
      'heatstroke' => LucideIcons.thermometer,
      'bloat' => LucideIcons.circleDot,
      'seizure' => LucideIcons.activity,
      _ => LucideIcons.ellipsis,
    };

/// Free-text search across a card's title, subtitle and body. Pure, so the
/// guide's filtering is unit-tested without a widget.
///
/// The body is searched too: an owner types what they can *see* ("blood",
/// "panting", "swallowed"), and those words live in the steps, not the titles.
List<FirstAidTopic> searchFirstAid(List<FirstAidTopic> topics, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return topics;
  return [
    for (final t in topics)
      if ('${t.title} ${t.subtitle} ${t.steps.join(' ')} ${t.never.join(' ')}'
          .toLowerCase()
          .contains(q))
        t,
  ];
}

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

/// The red call-to-action band both references pin near the bottom.
///
/// The reference's button reads **"Call Emergency · Available 24/7"**, over a
/// phone glyph, as though PawDoc ran a staffed line. It does not run one, and
/// it cannot promise any clinic's opening hours either. The band keeps its
/// geometry and its red, and offers the two contacts that are real: the OS
/// maps hand-off, and the poison-control number.
class EmergencyCallBand extends StatelessWidget {
  const EmergencyCallBand({
    this.title = 'Emergency?',
    this.subtitle = 'Get to a veterinarian — don’t wait on an app.',
    super.key,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    const red = AppColors.emergencyDark;
    return Container(
      key: const Key('emergency_call_band'),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          colors: [Color(0xFF2A0B0B), Color(0xFF160707)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border.all(color: red.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: red.withValues(alpha: 0.16),
                  border: Border.all(color: red.withValues(alpha: 0.55)),
                ),
                child: const Icon(LucideIcons.phone, size: 20, color: red),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: red,
                            fontSize: 17,
                            height: 1.15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            height: 1.25)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _RedButton(
            buttonKey: const Key('help_find_vet'),
            icon: LucideIcons.hospital,
            label: 'Find an emergency vet now',
            onTap: openEmergencyVetMaps,
          ),
          const SizedBox(height: 8),
          _RedButton(
            buttonKey: const Key('help_poison_control'),
            icon: LucideIcons.phoneCall,
            label: 'Call poison control',
            filled: false,
            onTap: dialPoisonControl,
          ),
          const SizedBox(height: 7),
          const Text(
            kPoisonControlNote,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.3),
          ),
        ],
      ),
    );
  }
}

class _RedButton extends StatelessWidget {
  const _RedButton({
    required this.buttonKey,
    required this.icon,
    required this.label,
    required this.onTap,
    this.filled = true,
  });

  final Key buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    const red = AppColors.emergencyLight;
    return Material(
      color: filled ? red : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        key: buttonKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: filled
                ? null
                : Border.all(color: AppColors.emergencyDark.withValues(alpha: 0.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 17,
                  color: filled ? Colors.white : AppColors.emergencyDark),
              const SizedBox(width: 8),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: filled ? Colors.white : AppColors.emergencyDark,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The honesty note both screens end on. Its wording is pinned by
/// `emergency_router_test` — the red path advertises that it needs neither the
/// network nor a model, because that is the promise that makes it trustworthy.
class EmergencyHonestyNote extends StatelessWidget {
  const EmergencyHonestyNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('emergency_honesty_note'),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: HealthTone.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.lightbulb,
              size: 18, color: AppColors.lime500),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'First aid buys time — it never replaces a veterinarian. '
              'This screen works offline and involves no AI.',
              style: TextStyle(
                  color: HealthTone.muted, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row in the guide's topic list: the glossy square (or its glyph
/// fallback), the title, what it looks like, and how many steps the card
/// carries.
///
/// The reference prints a **read time** on each row ("🕐 6 min"). It is
/// invented, and on this screen it is worse than invented — an owner holding a
/// bleeding animal reads "6 min" as a cost. The step count is a fact about the
/// card and is what the row shows instead.
class FirstAidRow extends StatelessWidget {
  const FirstAidRow({
    required this.topic,
    required this.onTap,
    this.showDivider = true,
    super.key,
  });

  final FirstAidTopic topic;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          key: Key('first_aid_${topic.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                FirstAidGlyph(id: topic.id),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(topic.title,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              height: 1.2,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(topic.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: HealthTone.muted,
                              fontSize: 12,
                              height: 1.3)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('${topic.steps.length} steps',
                    style: const TextStyle(
                        color: HealthTone.faint,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 4),
                const Icon(LucideIcons.chevronRight,
                    size: 17, color: HealthTone.faint),
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
              height: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.06)),
      ],
    );
  }
}

/// The circular category rail the reference draws under the search field.
///
/// Its entries are the cards that exist, plus `All`. The reference names seven
/// categories, three of which PawDoc ships no card for; a filter whose chips
/// lead to an empty list is a filter that teaches the owner the app has
/// nothing, at the moment they most need it to have something.
class FirstAidCategoryRail extends StatelessWidget {
  const FirstAidCategoryRail({
    required this.topics,
    required this.selected,
    required this.onSelect,
    super.key,
  });

  final List<FirstAidTopic> topics;

  /// Topic id, or `null` for *All*.
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: ListView(
        key: const Key('first_aid_rail'),
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kRecordGutter),
        children: [
          _RailTile(
            id: null,
            label: 'All',
            icon: LucideIcons.pawPrint,
            selected: selected == null,
            onTap: () => onSelect(null),
          ),
          for (final t in topics)
            _RailTile(
              id: t.id,
              label: firstAidShortLabel(t.id),
              icon: firstAidRailIcon(t.id),
              selected: selected == t.id,
              onTap: () => onSelect(t.id),
            ),
        ],
      ),
    );
  }
}

class _RailTile extends StatelessWidget {
  const _RailTile({
    required this.id,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String? id;
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.lime500;
    return SizedBox(
      width: 74,
      child: InkWell(
        key: Key('first_aid_cat_${id ?? 'all'}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected
                    ? accent.withValues(alpha: 0.16)
                    : Colors.white.withValues(alpha: 0.04),
                border: Border.all(
                    color: selected
                        ? accent
                        : Colors.white.withValues(alpha: 0.10)),
              ),
              child: Icon(icon,
                  size: 19, color: selected ? accent : HealthTone.muted),
            ),
            const SizedBox(height: 5),
            // The rail is a fixed height, so a label that would wrap has to be
            // told to shrink instead — inside a fixed row a Text reports its
            // unwrapped height and overflows the tile.
            SizedBox(
              height: 14,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label,
                    style: TextStyle(
                        color: selected ? accent : HealthTone.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
