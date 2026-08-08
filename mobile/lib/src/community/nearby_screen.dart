import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../auth/supabase_providers.dart';
import '../core/geohash.dart';
import '../core/paw_nav_bar.dart';
import '../health/health_sections.dart';
import '../pets/pet.dart' show speciesLabel;
import '../theme/design_tokens.dart';
import 'community_chat_screen.dart';
import 'community_models.dart';
import 'community_repository.dart';
import 'community_sections.dart';

/// Mockup `nearby_pet_owners`, over `CommunityRepository.discover`.
///
/// The search field, the species rail, the people list, the per-person actions
/// and the tally strip are the reference's, carrying real rows.
///
/// **The map is the one block that could not be built, and the reason is the
/// best thing about this feature.** The reference plots five members on a
/// street map at 0.2, 0.3, 0.4, 0.5 and 0.6 miles from a "You" pin, with named
/// parks and street labels around them. PawDoc stores no coordinates for a
/// member — only a five-character geohash *cell*, about 4.9 km across, chosen
/// at opt-in and never refined. There is nothing to plot, on purpose: a pet
/// owner's home is exactly the datum a stranger should not be able to walk
/// toward, and a map that resolves to a tenth of a mile is a map to a door.
///
/// So the map's slot holds what the app really knows — your cell, the block of
/// nine it searches, how many discoverable members are in it, and a plain
/// statement of what other members can see. Distances stay
/// [approxDistanceLabel]'s cell-to-cell approximations ("Under ~2 km",
/// "~5 km away"), never a decimal.
///
/// **Also absent:** "Active now" / "Active 10m ago" presence, which is not
/// stored and would be a location-adjacent leak if it were; the follow button
/// (no follows table); the breed under each name (`community_profiles` holds
/// species tags, not breeds); the member photographs (no avatar column); and
/// the "New" filter (nothing records when a member joined that the client can
/// read).
class NearbyPetOwnersScreen extends ConsumerStatefulWidget {
  const NearbyPetOwnersScreen({super.key});

  @override
  ConsumerState<NearbyPetOwnersScreen> createState() =>
      _NearbyPetOwnersScreenState();
}

class _NearbyPetOwnersScreenState
    extends ConsumerState<NearbyPetOwnersScreen> {
  final _search = TextEditingController();

  String _query = '';
  SpeciesFilter _species = SpeciesFilter.all;
  PeopleOrder _order = PeopleOrder.distance;

  List<CommunityProfile> _people = const [];
  CommunityProfile? _me;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Both fetches are awaited into state rather than handed to a
  /// `FutureBuilder`.
  ///
  /// The first cut passed `discover()`'s future straight to a builder that
  /// read `snapshot.data ?? const []` — so a failed lookup rendered as *"Nobody
  /// discoverable in your area yet — you are early"*. A network error that
  /// reads as an empty community is the wrong answer told confidently, and the
  /// profile fetch was already handled this way one line above it.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    CommunityProfile? me;
    try {
      me = await ref.read(myCommunityProfileProvider.future);
      if (!mounted) return;
      // Set before the second hop, so a discovery failure still knows whether
      // the caller is a member and can say the right thing about it.
      setState(() => _me = me);
      final cell = me?.geohash;
      final people = cell == null
          ? const <CommunityProfile>[]
          : await ref
              .read(communityRepositoryProvider)
              .discover(geohashNeighbors(cell));
      if (!mounted) return;
      setState(() {
        _people = people;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e;
        });
      }
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(myCommunityProfileProvider);
    ref.invalidate(communityConnectionsProvider);
    await _load();
  }

  Future<void> _connect(CommunityProfile person) async {
    try {
      await ref.read(communityRepositoryProvider).sendRequest(person.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Request sent to ${person.displayName}.')));
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not send the request. Try again.')));
      }
    }
  }

  void _openChat(CommunityConnection connection, CommunityProfile person) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => CommunityChatScreen(
        connection: connection,
        otherProfile: person,
      ),
    ));
  }

  void _showSortSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: 'Order the list',
        children: [
          for (final o in PeopleOrder.values)
            HealthSettingRow(
              key: Key('nearby_order_${o.name}'),
              icon: o.icon,
              label: o.label,
              value: _order == o ? 'Selected' : '',
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() => _order = o);
              },
            ),
        ],
      ),
    );
  }

  void _showPrivacySheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const HealthSheet(
        title: 'What nearby means',
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4, 2, 4, 14),
            child: Text(
              'PawDoc never stores where you are. When you joined the '
              'community it saved a single five-character area code — a cell '
              'roughly 5 km across — and that is the only location-shaped '
              'thing it has about you or anyone else.\n\n'
              '$kCommunityPrivacyLine\n\n'
              'Distances here are measured between area codes, not between '
              'people, which is why they read "~4 km" and never "0.3 mi". '
              'Nobody can be plotted on a map, including you.',
              style: TextStyle(
                  color: HealthTone.muted, fontSize: 13.5, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider) ?? '';
    final connectionsAsync = ref.watch(communityConnectionsProvider);
    final connections = connectionsAsync.maybeWhen(
        data: (c) => c, orElse: () => const <CommunityConnection>[]);

    return HealthRecordScaffold(
      onRefresh: _refresh,
      appBar: PetModuleAppBar(
        title: 'Nearby Pet Owners',
        icon: LucideIcons.mapPin,
        subtitle: 'Connect. Share. Meet.',
        actions: [
          HealthCircleButton(
            key: const Key('nearby_privacy_button'),
            icon: LucideIcons.shield,
            tooltip: 'What nearby means',
            onTap: _showPrivacySheet,
          ),
        ],
      ),
      bottomNav: const PawNavBar(detached: true),
      children: [
        gap(2),
        HealthSearchField(
          controller: _search,
          autofocus: false,
          fieldKey: const Key('nearby_search'),
          hint: 'Search names, bios or pets…',
          onChanged: (v) => setState(() => _query = v),
        ),
        gap(10),
        HealthBleed(
          child: SizedBox(
            height: 38,
            child: ListView(
              key: const Key('nearby_species_rail'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: kRecordGutter),
              children: [
                for (final s in SpeciesFilter.values) ...[
                  _SpeciesChip(
                    filter: s,
                    selected: _species == s,
                    onTap: () => setState(() => _species = s),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
        gap(12),
        _AreaCard(
          me: _me,
          loading: _loading,
          onExplain: _showPrivacySheet,
        ),
        gap(16),
        if (_error != null)
          _Notice(
            noticeKey: const Key('nearby_error'),
            icon: LucideIcons.cloudOff,
            text: 'Could not load the community just now. Pull to retry.',
          )
        else if (_me == null && !_loading)
          _Notice(
            noticeKey: const Key('nearby_not_member'),
            icon: LucideIcons.userPlus,
            text: 'You have not joined the community yet. Joining is what '
                'creates your profile and your area code.',
          )
        else if (_me != null && _me!.geohash == null)
          _Notice(
            noticeKey: const Key('nearby_no_area'),
            icon: LucideIcons.mapPinOff,
            text: 'You joined without sharing an approximate area, so there '
                'is nowhere to search from. Add one in your community '
                'profile to appear in — and see — nearby discovery.',
          )
        else if (_loading)
          const _Skeleton()
        else
          Builder(
            builder: (context) {
              final all = _people;
              final people = filterPeople(
                all,
                species: _species,
                query: _query,
                order: _order,
                myCell: _me?.geohash,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  HealthSectionHead(
                    title: 'People near you',
                    actionLabel: _order.label,
                    actionBoxed: true,
                    actionIcon: _order.icon,
                    onAction: _showSortSheet,
                  ),
                  gap(9),
                  if (all.isEmpty)
                    _Notice(
                      noticeKey: const Key('nearby_empty'),
                      icon: LucideIcons.users,
                      text: 'Nobody discoverable in your area yet — you are '
                          'early. This searches the nine area codes around '
                          'yours, so it fills up as the community grows.',
                    )
                  else if (people.isEmpty)
                    _Notice(
                      noticeKey: const Key('nearby_no_match'),
                      icon: LucideIcons.search,
                      text: 'No one here matches that. Clear the search or '
                          'pick All to see everyone nearby.',
                    )
                  else
                    for (final person in people)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: _PersonCard(
                          person: person,
                          myCell: _me?.geohash,
                          connection: _connectionWith(connections, uid, person),
                          uid: uid,
                          onConnect: () => _connect(person),
                          onMessage: (c) => _openChat(c, person),
                        ),
                      ),
                  gap(6),
                  CommunityTallyStrip(people: all),
                ],
              );
            },
          ),
        gap(8),
      ],
    );
  }

  CommunityConnection? _connectionWith(
    List<CommunityConnection> connections,
    String uid,
    CommunityProfile person,
  ) {
    for (final c in connections) {
      if (c.involves(uid) && c.otherParty(uid) == person.userId) return c;
    }
    return null;
  }
}

/// The map's slot, holding what the app actually knows about where you are.
class _AreaCard extends StatelessWidget {
  const _AreaCard({
    required this.me,
    required this.loading,
    required this.onExplain,
  });

  final CommunityProfile? me;
  final bool loading;
  final VoidCallback onExplain;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.lime500;
    final cell = me?.geohash;
    return Container(
      key: const Key('nearby_area_card'),
      padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
      decoration: BoxDecoration(
        color: HealthTone.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          // Concentric rings: the reference's radius diagram, with nothing
          // plotted inside it because there is nothing to plot.
          SizedBox(
            width: 74,
            height: 74,
            child: Stack(
              alignment: Alignment.center,
              children: [
                _Ring(size: 74, alpha: 0.14),
                _Ring(size: 52, alpha: 0.24),
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.18),
                    border: Border.all(color: accent),
                  ),
                  child: const Icon(LucideIcons.pawPrint,
                      size: 13, color: accent),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your area',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(
                  loading
                      ? 'Checking…'
                      : cell == null
                          ? 'No area set — nothing to search from.'
                          : 'Area code $cell · about 5 km across. PawDoc '
                              'searches the nine codes around it.',
                  style: const TextStyle(
                      color: HealthTone.muted, fontSize: 12, height: 1.35),
                ),
                const SizedBox(height: 8),
                CommunityActionButton(
                  key: const Key('nearby_explain'),
                  label: 'What members can see',
                  icon: LucideIcons.shield,
                  onTap: onExplain,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({required this.size, required this.alpha});

  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
              color: AppColors.lime500.withValues(alpha: alpha)),
        ),
      );
}

class _SpeciesChip extends StatelessWidget {
  const _SpeciesChip({
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final SpeciesFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.lime500;
    return Material(
      color: selected ? accent.withValues(alpha: 0.14) : HealthTone.card,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        key: Key('nearby_species_${filter.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
                color: selected
                    ? accent
                    : Colors.white.withValues(alpha: 0.09)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(filter.icon,
                  size: 14, color: selected ? accent : HealthTone.muted),
              const SizedBox(width: 6),
              Text(filter.label,
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

/// One member, in the reference's card shape.
class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.person,
    required this.myCell,
    required this.connection,
    required this.uid,
    required this.onConnect,
    required this.onMessage,
  });

  final CommunityProfile person;
  final String? myCell;
  final CommunityConnection? connection;
  final String uid;
  final VoidCallback onConnect;
  final ValueChanged<CommunityConnection> onMessage;

  @override
  Widget build(BuildContext context) {
    final distance = approxDistanceLabel(myCell, person.geohash);
    final species = person.speciesTags.map(speciesLabel).join(' · ');
    final status = connection?.status;

    return Container(
      key: Key('nearby_person_${person.userId}'),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CommunityAvatar(profile: person),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(person.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14.5,
                            height: 1.2,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (distance.isNotEmpty) distance,
                        if (species.isNotEmpty) species,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: HealthTone.muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if ((person.bio ?? '').isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(person.bio!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: HealthTone.muted, fontSize: 12.5, height: 1.4)),
          ],
          const SizedBox(height: 11),
          Row(
            children: [
              if (status == ConnectionStatus.accepted)
                CommunityActionButton(
                  key: Key('nearby_message_${person.userId}'),
                  label: 'Message',
                  icon: LucideIcons.messageCircle,
                  filled: true,
                  onTap: () => onMessage(connection!),
                )
              else if (status == ConnectionStatus.pending)
                CommunityActionButton(
                  key: Key('nearby_pending_${person.userId}'),
                  label: connection!.isIncomingFor(uid)
                      ? 'Wants to connect'
                      : 'Request sent',
                  icon: LucideIcons.clock,
                  onTap: null,
                )
              else if (status == ConnectionStatus.blocked)
                CommunityActionButton(
                  key: Key('nearby_blocked_${person.userId}'),
                  label: 'Blocked',
                  icon: LucideIcons.ban,
                  onTap: null,
                )
              else if (person.allowRequests)
                CommunityActionButton(
                  key: Key('nearby_connect_${person.userId}'),
                  label: 'Connect',
                  icon: LucideIcons.userPlus,
                  filled: true,
                  onTap: onConnect,
                )
              else
                CommunityActionButton(
                  key: Key('nearby_closed_${person.userId}'),
                  label: 'Not taking requests',
                  icon: LucideIcons.userX,
                  onTap: null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.noticeKey,
    required this.icon,
    required this.text,
  });

  final Key noticeKey;
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: noticeKey,
      padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
      decoration: BoxDecoration(
        color: HealthTone.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: HealthTone.muted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    color: HealthTone.muted, fontSize: 12.5, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (var i = 0; i < 2; i++)
            Container(
              key: Key('nearby_skeleton_$i'),
              height: 108,
              margin: const EdgeInsets.only(bottom: 9),
              decoration: BoxDecoration(
                color: HealthTone.card,
                borderRadius: BorderRadius.circular(18),
                border:
                    Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
            ),
        ],
      );
}
