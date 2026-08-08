import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/geohash.dart';
import '../health/health_sections.dart';
import '../pets/pet.dart' show Pet, kSpecies, speciesLabel;
import '../pets/pets_repository.dart';
import '../theme/design_tokens.dart';
import '../walks/location_service.dart';
import 'community_models.dart';
import 'community_repository.dart';
import 'community_sections.dart';

/// Mockup `create_post`, over the one thing a PawDoc member can publish to the
/// community: themselves.
///
/// The reference composes a social post — an audience picker, a 1500-character
/// body, a media tray with drag-to-reorder, location, hashtags, a mood, and a
/// "share to groups" rail with member counts. **None of it has anywhere to go.**
/// The community is five tables and not one of them holds a post, a photo, a
/// hashtag or a group.
///
/// What the schema does hold is a `community_profiles` row, and it happens to
/// have the same shape as the reference's form: an identity block, a counted
/// free-text field, a tag set, a location detail, and an audience setting. So
/// the composer composes that — the display name, the bio, the pet species,
/// the approximate area, and the two switches that decide who may find you.
/// Every field writes through `saveProfile`, and this is also the screen that
/// creates the row in the first place, which is what joining the community is.
///
/// **The blocks that stayed, disabled, saying *Soon*:** photo and video, poll,
/// story, hashtags, mood, and share-to-groups. The program's convention is
/// that a control the reference draws keeps its place and states what is
/// missing, rather than being deleted (which hides the intent) or wired to
/// nothing (which lies). The one the reference gets right is the guidelines
/// card, which ships as written, because the report and block controls behind
/// it are real.
///
/// **Location is the field that changed most.** The reference pins a post to
/// "Küçükçekmece Lake, Istanbul, Turkey". PawDoc never stores a place: opting
/// in captures a single five-character geohash cell about 5 km across, and
/// that is all any member ever sees. The row here says so, and refreshing it
/// re-reads the cell rather than a place name.
class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final Set<String> _species = {};

  String? _cell;
  bool _discoverable = true;
  bool _allowRequests = true;

  bool _loading = true;
  bool _saving = false;
  bool _locating = false;
  bool _isNew = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    CommunityProfile? me;
    try {
      me = await ref.read(myCommunityProfileProvider.future);
    } catch (_) {
      // A failed read is not a blank profile: fall through to the empty form
      // but say nothing about it being new until we know.
    }
    if (!mounted) return;
    if (me != null) {
      _name.text = me.displayName;
      _bio.text = me.bio ?? '';
      _species.addAll(me.speciesTags);
      _cell = me.geohash;
      _discoverable = me.isDiscoverable;
      _allowRequests = me.allowRequests;
    } else {
      // Suggest species from the pets the owner already keeps.
      try {
        final pets = await ref.read(petsListProvider.future);
        if (!mounted) return;
        for (final Pet pet in pets) {
          _species.add(pet.species);
        }
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _isNew = me == null;
      _loading = false;
    });
  }

  Future<void> _refreshArea() async {
    setState(() => _locating = true);
    final location = await ref.read(locationServiceProvider).current();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (location is LocationGranted) {
        _cell = geohashEncode(location.lat, location.lon, precision: 5);
      }
    });
    if (location is! LocationGranted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text(
            'Location is off, so there is no area to save. You can still '
            'join — you just will not appear in nearby discovery.'),
      ));
    }
  }

  void _clearArea() {
    setState(() => _cell = null);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Area removed. Save to apply — you will no longer '
          'appear in nearby discovery.'),
    ));
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Pick a display name (at least 2 characters).');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(communityRepositoryProvider).saveProfile(
            CommunityProfile(
              userId: '', // repository injects auth.uid()
              displayName: name,
              bio: _bio.text.trim().isEmpty ? null : _bio.text.trim(),
              speciesTags: _species.toList(),
              geohash: _cell,
              isDiscoverable: _discoverable,
              allowRequests: _allowRequests,
            ),
          );
      ref.invalidate(myCommunityProfileProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save right now. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return HealthRecordScaffold(
        appBar: const PetModuleAppBar(
          title: 'Community Profile',
          icon: LucideIcons.userPen,
          subtitle: 'Share. Learn. Support.',
        ),
        children: [gap(20), const Center(child: CircularProgressIndicator())],
      );
    }

    return HealthRecordScaffold(
      appBar: PetModuleAppBar(
        title: 'Community Profile',
        icon: LucideIcons.userPen,
        subtitle: 'Share. Learn. Support.',
        actionsWidth: 92,
        actions: [
          HealthActionPill(
            key: const Key('create_post_save'),
            label: _isNew ? 'Join' : 'Save',
            icon: LucideIcons.send,
            onTap: _saving ? null : _save,
          ),
        ],
      ),
      children: [
        gap(2),
        // 1 · "Who's posting?" — the identity block.
        const HealthNumberedHead(
            number: 1, title: 'Who you are', subtitle: 'What members see first'),
        gap(9),
        HealthCountedField(
          fieldKey: const Key('community_name_field'),
          controller: _name,
          maxLength: 40,
          hint: "e.g. Rex's human",
        ),
        gap(16),

        // 2 · "What's on your mind?" — the counted body.
        const HealthNumberedHead(
          number: 2,
          title: 'About you',
          subtitle: 'Say hello. This is your whole post.',
          suffix: '(Optional)',
        ),
        gap(9),
        HealthCountedField(
          fieldKey: const Key('community_bio_field'),
          controller: _bio,
          maxLength: 160,
          minLines: 3,
          maxLines: 5,
          hint: 'e.g. Early-morning walker, always up for park meetups',
        ),
        gap(10),
        // The reference's Photo / Poll / Ask / Story row.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            CommunitySoonChip(
              key: Key('create_post_soon_media'),
              label: 'Photo / Video',
              icon: LucideIcons.image,
              reason: 'A community profile has no media column, and photos '
                  'would need their own storage scope and moderation pass.',
            ),
            CommunitySoonChip(
              key: Key('create_post_soon_poll'),
              label: 'Poll',
              icon: LucideIcons.chartColumn,
              reason: 'Polls need a posts table to hang from. PawDoc has none '
                  'yet.',
            ),
            CommunitySoonChip(
              key: Key('create_post_soon_ask'),
              label: 'Ask',
              icon: LucideIcons.circleHelp,
              reason: 'Questions to the community need a posts table. For a '
                  'health question, the AI check and your vet are the two '
                  'routes PawDoc stands behind.',
            ),
          ],
        ),
        gap(18),

        // 3 · "Add details" — the tags that exist.
        const HealthNumberedHead(
            number: 3,
            title: 'Your pets',
            subtitle: 'Members filter by species',
            suffix: '(Optional)'),
        gap(9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final species in kSpecies)
              _SpeciesToggle(
                species: species,
                selected: _species.contains(species),
                onTap: () => setState(() {
                  if (!_species.remove(species)) _species.add(species);
                }),
              ),
          ],
        ),
        gap(10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: const [
            CommunitySoonChip(
              key: Key('create_post_soon_tags'),
              label: 'Hashtags',
              icon: LucideIcons.tag,
              reason: 'Tags need something to tag. They arrive with posts.',
            ),
            CommunitySoonChip(
              key: Key('create_post_soon_mood'),
              label: 'Mood',
              icon: LucideIcons.smile,
              reason: 'A mood belongs to a post, and there are no posts yet.',
            ),
            CommunitySoonChip(
              key: Key('create_post_soon_groups'),
              label: 'Share to groups',
              icon: LucideIcons.users,
              reason: 'Groups are not part of the community schema — there '
                  'are no groups to join, and none with 12.4K members.',
            ),
          ],
        ),
        gap(18),

        // 4 · Location, which is an area code and nothing else.
        const HealthNumberedHead(
            number: 4,
            title: 'Your area',
            subtitle: 'An area code, never a place',
            suffix: '(Optional)'),
        gap(9),
        Container(
          key: const Key('community_area_row'),
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
          decoration: BoxDecoration(
            color: HealthTone.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.mapPin,
                      size: 16, color: AppColors.lime500),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _cell == null
                          ? 'No area set'
                          : 'Area code $_cell · about 5 km across',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'PawDoc stores this single code and nothing else about where '
                'you are — no address, no coordinates, no place name. Without '
                'one you can still connect and chat; you simply will not '
                'appear in nearby discovery.',
                style: TextStyle(
                    color: HealthTone.muted, fontSize: 11.5, height: 1.4),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  CommunityActionButton(
                    key: const Key('community_area_refresh'),
                    label: _locating
                        ? 'Checking…'
                        : (_cell == null ? 'Use my area' : 'Update'),
                    icon: LucideIcons.locateFixed,
                    onTap: _locating ? null : _refreshArea,
                  ),
                  if (_cell != null)
                    CommunityActionButton(
                      key: const Key('community_area_clear'),
                      label: 'Remove',
                      icon: LucideIcons.x,
                      onTap: _clearArea,
                    ),
                ],
              ),
            ],
          ),
        ),
        gap(18),

        // 5 · "Public / Anyone on PawDoc Community" — the audience picker.
        const HealthNumberedHead(
            number: 5, title: 'Who can find you', subtitle: 'Change it anytime'),
        gap(9),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
          decoration: BoxDecoration(
            color: HealthTone.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            children: [
              _SwitchRow(
                rowKey: const Key('community_discoverable'),
                icon: LucideIcons.eye,
                label: 'Show me in nearby discovery',
                caption: 'Off means only people you contact can see you.',
                value: _discoverable,
                onChanged: (v) => setState(() => _discoverable = v),
              ),
              Divider(
                  height: 1,
                  thickness: 1,
                  color: Colors.white.withValues(alpha: 0.06)),
              _SwitchRow(
                rowKey: const Key('community_allow_requests'),
                icon: LucideIcons.userPlus,
                label: 'Allow connection requests',
                caption: 'Off means nobody new can reach you.',
                value: _allowRequests,
                onChanged: (v) => setState(() => _allowRequests = v),
              ),
            ],
          ),
        ),
        gap(16),
        const CommunityGuidelinesCard(),
        gap(12),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: HealthTone.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: const Text(
            kCommunityPrivacyLine,
            style:
                TextStyle(color: HealthTone.muted, fontSize: 12, height: 1.45),
          ),
        ),
        if (_error != null) ...[
          gap(10),
          Text(_error!,
              key: const Key('community_join_error'),
              style: const TextStyle(
                  color: AppColors.emergencyDark, fontSize: 12.5)),
        ],
        gap(12),
        HealthPrimaryCta(
          key: const Key('community_join_button'),
          label: _saving
              ? 'Saving…'
              : (_isNew ? 'Join the community' : 'Save profile'),
          icon: LucideIcons.pawPrint,
          enabled: !_saving,
          onTap: _save,
        ),
        gap(8),
      ],
    );
  }
}

class _SpeciesToggle extends StatelessWidget {
  const _SpeciesToggle({
    required this.species,
    required this.selected,
    required this.onTap,
  });

  final String species;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.lime500;
    return Material(
      color: selected ? accent.withValues(alpha: 0.14) : HealthTone.card,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        key: Key('community_species_$species'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        // No `alignment:` on the Container. A Container given an alignment
        // expands to its incoming constraints, and inside a `Wrap` those are
        // loose to the full row — which made every species chip full width,
        // one per line. The Row centres the label instead.
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
                color:
                    selected ? accent : Colors.white.withValues(alpha: 0.09)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(speciesLabel(species),
                  style: TextStyle(
                      color: selected ? accent : HealthTone.muted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.rowKey,
    required this.icon,
    required this.label,
    required this.caption,
    required this.value,
    required this.onChanged,
  });

  final Key rowKey;
  final IconData icon;
  final String label;
  final String caption;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.lime500),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(caption,
                    style: const TextStyle(
                        color: HealthTone.muted, fontSize: 11, height: 1.3)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            key: rowKey,
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.black,
            activeTrackColor: AppColors.lime500,
          ),
        ],
      ),
    );
  }
}
