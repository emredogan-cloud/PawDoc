/// The pieces the four community mockups share.
///
/// **What the references draw, and what PawDoc actually holds.** The reference
/// set draws a social network: a feed of posts with photo carousels and video,
/// reaction counts, comment threads, shares, saves, follows, verified
/// veterinarians answering questions, hashtags, polls, stories, interest groups
/// with member counts, a live map of people pinned at tenths of a mile, and
/// presence dots reading "Active now".
///
/// The schema is five tables: `community_profiles`, `community_connections`,
/// `community_messages`, `walk_proposals` and `community_reports`. There is no
/// posts table, no reactions table, no follows, no groups, no media column, no
/// presence, and — deliberately — no coordinates. A profile's only
/// location-shaped field is a five-character geohash **cell**, about 4.9 km
/// across, and that is the strongest privacy decision in the product: it means
/// the server could not plot its members on a map even if a screen asked it
/// to.
///
/// So these screens carry the references' composition over the graph that
/// exists — connections, requests, the people discoverable in your cell block,
/// the 1:1 conversation, the walk proposal. Where the reference draws a control
/// the schema cannot hold, the control keeps its place and says *Soon*, which
/// is the convention the rest of this program already uses.
library;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../health/health_sections.dart';
import '../pets/pet.dart' show speciesEmoji, speciesLabel;
import '../theme/design_tokens.dart';
import 'community_models.dart';

// ---------------------------------------------------------------------------
// Pure helpers — unit-tested without a widget
// ---------------------------------------------------------------------------

/// Up to two initials for a display name. `community_profiles` has no avatar
/// column, so every face in the references is a picture of a feature that does
/// not exist; a member is drawn as their initials over a species glyph.
String communityInitials(String displayName) {
  final words = displayName
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) {
    final w = words.first;
    return (w.length == 1 ? w : w.substring(0, 2)).toUpperCase();
  }
  return '${words.first[0]}${words.last[0]}'.toUpperCase();
}

/// Which species bucket the discovery rail puts a member in.
enum SpeciesFilter {
  all('All', LucideIcons.users),
  dogs('Dogs', LucideIcons.pawPrint),
  cats('Cats', LucideIcons.cat),
  other('Other pets', LucideIcons.bird);

  const SpeciesFilter(this.label, this.icon);

  final String label;
  final IconData icon;

  bool matches(CommunityProfile p) => switch (this) {
        SpeciesFilter.all => true,
        SpeciesFilter.dogs => p.speciesTags.contains('dog'),
        SpeciesFilter.cats => p.speciesTags.contains('cat'),
        SpeciesFilter.other =>
          p.speciesTags.any((s) => s != 'dog' && s != 'cat'),
      };
}

/// How the people list is ordered. The reference offers "Sort by: Distance"
/// over distances it prints to a tenth of a mile; ours orders by *cell*
/// distance, which is the only ordering the data supports.
enum PeopleOrder {
  distance('Nearest cell first', LucideIcons.mapPin),
  name('Name (A–Z)', LucideIcons.arrowDownAZ);

  const PeopleOrder(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Free-text search over the fields a profile actually has: the display name,
/// the bio, and the species words. Pure.
List<CommunityProfile> searchProfiles(
  List<CommunityProfile> people,
  String query,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return people;
  return [
    for (final p in people)
      if ('${p.displayName} ${p.bio ?? ''} '
              '${p.speciesTags.map(speciesLabel).join(' ')}'
          .toLowerCase()
          .contains(q))
        p,
  ];
}

/// Species filter + search + ordering, in one pure pass. [myCell] is only used
/// for the distance ordering and may be null.
List<CommunityProfile> filterPeople(
  List<CommunityProfile> people, {
  SpeciesFilter species = SpeciesFilter.all,
  String query = '',
  PeopleOrder order = PeopleOrder.distance,
  String? myCell,
}) {
  final out = [
    for (final p in searchProfiles(people, query))
      if (species.matches(p)) p,
  ];
  switch (order) {
    case PeopleOrder.name:
      out.sort((a, b) => a.displayName
          .toLowerCase()
          .compareTo(b.displayName.toLowerCase()));
    case PeopleOrder.distance:
      out.sort((a, b) {
        // A member with no shared cell sorts last rather than first: an
        // unknown distance is not a near one.
        final da = approxDistanceKm(myCell, a.geohash) ?? double.infinity;
        final db = approxDistanceKm(myCell, b.geohash) ?? double.infinity;
        final byDistance = da.compareTo(db);
        return byDistance != 0
            ? byDistance
            : a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase());
      });
  }
  return out;
}

/// The four tallies the reference's stats strip prints. Every one is counted
/// from the rows on screen — the reference prints "12 People nearby · 7 Dogs ·
/// 4 Cats · 1 Other Pets" over no data at all.
({int people, int dogs, int cats, int other}) speciesTally(
    List<CommunityProfile> people) {
  var dogs = 0, cats = 0, other = 0;
  for (final p in people) {
    if (p.speciesTags.contains('dog')) dogs++;
    if (p.speciesTags.contains('cat')) cats++;
    if (p.speciesTags.any((s) => s != 'dog' && s != 'cat')) other++;
  }
  return (people: people.length, dogs: dogs, cats: cats, other: other);
}

/// The community's standing conduct rules. Shown on the composer, where the
/// reference puts them, and enforced by the report/block controls that reach
/// `community_reports`.
const List<String> kCommunityGuidelines = [
  'Be kind. Everyone here is doing their best for an animal they love.',
  'No spam, no selling, no harassment.',
  'Never share someone else’s address, or your own.',
  'Health talk is for sharing experience — it is not veterinary advice, '
      'and nobody here can diagnose your pet.',
];

/// The line every community surface carries about what a member can see.
const String kCommunityPrivacyLine =
    'Members see your display name, bio and pet species, plus the approximate '
    'area you chose — never your address, your coordinates, your email or any '
    'of your pet’s health records.';

// ---------------------------------------------------------------------------
// Widgets
// ---------------------------------------------------------------------------

/// A member's face. `community_profiles` has no photo column, so this is
/// initials on a tinted disc with the species glyph corner-set — the same
/// shape the references draw, without pretending to a photograph.
class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({
    required this.profile,
    this.size = 46,
    super.key,
  });

  final CommunityProfile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.lime500;
    final emoji = profile.speciesTags.isEmpty
        ? ''
        : speciesEmoji(profile.speciesTags.first);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.38)),
            ),
            child: Text(
              communityInitials(profile.displayName),
              style: TextStyle(
                  color: accent,
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w700),
            ),
          ),
          if (emoji.isNotEmpty)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: size * 0.42,
                height: size * 0.42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: HealthTone.card,
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Text(emoji,
                    style: TextStyle(fontSize: size * 0.20, height: 1)),
              ),
            ),
        ],
      ),
    );
  }
}

/// The bordered lozenge the references use for a secondary community action —
/// "Message", "Follow", "Connect".
class CommunityActionButton extends StatelessWidget {
  const CommunityActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.filled = false,
    this.color,
    super.key,
  });

  final String label;
  final IconData icon;

  /// Null renders the button disabled — the *Soon* convention.
  final VoidCallback? onTap;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.lime500;
    final enabled = onTap != null;
    final fg = enabled
        ? (filled ? Colors.black : c)
        : HealthTone.faint;
    return Material(
      color: enabled && filled ? c : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
                color: filled && enabled
                    ? Colors.transparent
                    : (enabled ? c : HealthTone.faint)
                        .withValues(alpha: 0.45)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: fg,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The reference's four-cell tally strip, counted from real rows.
class CommunityTallyStrip extends StatelessWidget {
  const CommunityTallyStrip({required this.people, super.key});

  final List<CommunityProfile> people;

  @override
  Widget build(BuildContext context) {
    final t = speciesTally(people);
    return Container(
      key: const Key('community_tally'),
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        color: HealthTone.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _Tally(
                icon: LucideIcons.users,
                value: t.people,
                label: 'Discoverable'),
            const _TallyRule(),
            _Tally(icon: LucideIcons.pawPrint, value: t.dogs, label: 'Dogs'),
            const _TallyRule(),
            _Tally(icon: LucideIcons.cat, value: t.cats, label: 'Cats'),
            const _TallyRule(),
            _Tally(icon: LucideIcons.bird, value: t.other, label: 'Other pets'),
          ],
        ),
      ),
    );
  }
}

class _TallyRule extends StatelessWidget {
  const _TallyRule();

  @override
  Widget build(BuildContext context) => VerticalDivider(
      width: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.07));
}

class _Tally extends StatelessWidget {
  const _Tally({required this.icon, required this.value, required this.label});

  final IconData icon;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16, color: AppColors.lime500),
          const SizedBox(height: 5),
          Text('$value',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  height: 1.1,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          // A fixed-height slot: "Other pets" wraps to two lines at a large
          // text scale and would otherwise push the strip out of the card.
          SizedBox(
            height: 13,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label,
                  style: const TextStyle(
                      color: HealthTone.muted, fontSize: 10.5)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The conduct card the composer draws, and the privacy line every community
/// surface carries.
class CommunityGuidelinesCard extends StatelessWidget {
  const CommunityGuidelinesCard({this.compact = false, super.key});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.lime500;
    return Container(
      key: const Key('community_guidelines'),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
      decoration: BoxDecoration(
        color: HealthTone.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.shieldCheck, size: 17, color: accent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Community guidelines',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (compact)
            const Text(
              'Be kind, respectful and helpful. No spam, no harmful content, '
              'and nothing here is veterinary advice.',
              style: TextStyle(
                  color: HealthTone.muted, fontSize: 12, height: 1.4),
            )
          else
            for (final rule in kCommunityGuidelines)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(LucideIcons.check, size: 12, color: accent),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(rule,
                          style: const TextStyle(
                              color: HealthTone.muted,
                              fontSize: 12,
                              height: 1.4)),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// A control the reference draws that the schema cannot hold. Keeps its place,
/// says why, and does nothing — never deleted, never faked.
class CommunitySoonChip extends StatelessWidget {
  const CommunitySoonChip({
    required this.label,
    required this.icon,
    required this.reason,
    super.key,
  });

  final String label;
  final IconData icon;

  /// Shown when tapped: what is missing, in one sentence.
  final String reason;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.55,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(reason))),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 13, color: HealthTone.muted),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        color: HealthTone.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                  child: const Text('Soon',
                      style: TextStyle(
                          color: HealthTone.faint,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
