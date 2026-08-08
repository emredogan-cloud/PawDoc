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
import 'community_onboarding_screen.dart';
import 'community_repository.dart';
import 'community_sections.dart';
import 'create_post_screen.dart';
import 'nearby_screen.dart';

/// Mockup `community_feed`, over the community graph that exists.
///
/// The reference is a social feed: posts with photo carousels and video,
/// "128" reactions, "23 Comments · 7 Shares · 1 Save", Like/Comment/Share/Save
/// rows, hashtags, a Following/Trending/Health/Training/Stories rail, a
/// Photo/Poll/Ask composer, and a verified veterinarian answering a health
/// question in-feed.
///
/// **There is no posts table.** The community is five tables —
/// `community_profiles`, `community_connections`, `community_messages`,
/// `walk_proposals`, `community_reports` — so there are no posts, reactions,
/// comments, shares, saves, follows, hashtags, media or groups to render. What
/// there is, is people: who wants to connect with you, who you are connected
/// to, and who is discoverable near you.
///
/// So this screen is the reference's composition carrying that: the header and
/// its notification bell (which counts **real incoming requests**), the
/// segmented rail, the composer card, and a column of member cards in the
/// post-card's shape. Every number on the page is counted from rows.
///
/// **Deliberately not built as decoration:** reaction, comment, share and save
/// counts; a Trending segment (nothing is ranked); Stories; polls; and the
/// in-feed veterinarian — a verified-vet badge answering health questions
/// inside a triage app is the single most dangerous element in the reference
/// set, because it borrows PawDoc's authority for advice PawDoc did not write
/// and cannot stand behind. The composer's post-type chips keep their place
/// and say *Soon*, which is this program's convention for a control the schema
/// cannot hold.
class CommunityHomeScreen extends ConsumerStatefulWidget {
  const CommunityHomeScreen({super.key});

  @override
  ConsumerState<CommunityHomeScreen> createState() =>
      _CommunityHomeScreenState();
}

/// The rail's segments. The reference's are content categories; ours are the
/// relationships the graph actually stores.
enum FeedSegment {
  all('All', LucideIcons.house),
  requests('Requests', LucideIcons.userPlus),
  connections('Connections', LucideIcons.messageCircle),
  nearby('Nearby', LucideIcons.mapPin);

  const FeedSegment(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _CommunityHomeScreenState extends ConsumerState<CommunityHomeScreen> {
  FeedSegment _segment = FeedSegment.all;

  List<CommunityProfile> _nearby = const [];
  bool _nearbyLoading = true;
  Object? _nearbyError;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadNearby);
  }

  Future<void> _loadNearby() async {
    setState(() {
      _nearbyLoading = true;
      _nearbyError = null;
    });
    try {
      final me = await ref.read(myCommunityProfileProvider.future);
      if (!mounted) return;
      final cell = me?.geohash;
      final people = cell == null
          ? const <CommunityProfile>[]
          : await ref
              .read(communityRepositoryProvider)
              .discover(geohashNeighbors(cell));
      if (!mounted) return;
      setState(() {
        _nearby = people;
        _nearbyLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _nearbyLoading = false;
          _nearbyError = e;
        });
      }
    }
  }

  Future<void> _refresh() async {
    ref.invalidate(communityConnectionsProvider);
    ref.invalidate(myCommunityProfileProvider);
    await _loadNearby();
  }

  /// Editing goes to the composer; **joining does not.**
  ///
  /// `CommunityOnboardingScreen` is the consent gate — the screen *is* the
  /// consent, stating what is shared and what is not before a profile row
  /// exists. A second path that created that row from a form with a shorter
  /// privacy story would be a quiet weakening of it, so a non-member is sent
  /// there and the composer only ever edits.
  Future<void> _openComposer({required bool isMember}) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => isMember
            ? const CreatePostScreen()
            : const CommunityOnboardingScreen(),
      ),
    );
    if (changed == true) await _refresh();
  }

  void _openNearby() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => const NearbyPetOwnersScreen(),
    ));
  }

  Future<void> _leave() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave the community?'),
        content: const Text(
            'Your profile, connections, and chats will be deleted. '
            'This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Stay')),
          TextButton(
            key: const Key('community_leave_confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Leave',
                style: TextStyle(
                    color: Theme.of(dialogContext).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(communityRepositoryProvider).leaveCommunity();
    ref.invalidate(myCommunityProfileProvider);
    if (mounted) Navigator.of(context).pop();
  }

  void _showMenu(int requestCount) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => HealthSheet(
        title: 'Community',
        children: [
          HealthSettingRow(
            key: const Key('community_menu_requests'),
            icon: LucideIcons.userPlus,
            label: 'Requests for you',
            value: '$requestCount',
            onTap: () {
              Navigator.pop(sheetContext);
              setState(() => _segment = FeedSegment.requests);
            },
          ),
          HealthSettingRow(
            key: const Key('community_menu_profile'),
            icon: LucideIcons.userPen,
            label: 'Your community profile',
            value: 'Edit',
            onTap: () {
              Navigator.pop(sheetContext);
              _openComposer(isMember: true);
            },
          ),
          HealthSettingRow(
            key: const Key('community_leave_button'),
            icon: LucideIcons.logOut,
            label: 'Leave the community',
            value: '',
            valueColor: AppColors.emergencyDark,
            onTap: () {
              Navigator.pop(sheetContext);
              _leave();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider) ?? '';
    final meAsync = ref.watch(myCommunityProfileProvider);
    final me = meAsync.maybeWhen(data: (p) => p, orElse: () => null);
    final connectionsAsync = ref.watch(communityConnectionsProvider);

    return connectionsAsync.when(
      loading: () => _shell(
        requestCount: 0,
        me: me,
        children: [gap(4), const _CardSkeleton(), const _CardSkeleton()],
      ),
      error: (e, _) => _shell(
        requestCount: 0,
        me: me,
        children: [
          gap(4),
          _Notice(
            noticeKey: const Key('community_error'),
            icon: LucideIcons.cloudOff,
            text: 'Could not load the community just now. Pull to retry.',
          ),
        ],
      ),
      data: (connections) {
        final incoming =
            connections.where((c) => c.isIncomingFor(uid)).toList();
        final accepted = connections
            .where((c) => c.status == ConnectionStatus.accepted)
            .toList();
        final linked = {
          for (final c in connections)
            if (c.status != ConnectionStatus.declined) c.otherParty(uid),
        };
        final strangers = [
          for (final p in _nearby)
            if (!linked.contains(p.userId)) p,
        ];

        final showRequests =
            _segment == FeedSegment.all || _segment == FeedSegment.requests;
        final showConnections =
            _segment == FeedSegment.all || _segment == FeedSegment.connections;
        final showNearby =
            _segment == FeedSegment.all || _segment == FeedSegment.nearby;

        return _shell(
          requestCount: incoming.length,
          me: me,
          children: [
            gap(4),
            _ComposerCard(
              me: me,
              onOpen: () => _openComposer(isMember: me != null),
              onFindPeople: _openNearby,
            ),
            gap(16),
            if (showRequests) ...[
              HealthSectionHead(
                title: 'Requests for you',
                actionLabel: '${incoming.length}',
                chevron: false,
              ),
              gap(9),
              if (incoming.isEmpty)
                _Notice(
                  noticeKey: const Key('community_no_requests'),
                  icon: LucideIcons.inbox,
                  text: 'No one is waiting on you. Requests appear here when '
                      'someone nearby asks to connect.',
                )
              else
                for (final connection in incoming)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _RequestCard(connection: connection, uid: uid),
                  ),
              gap(16),
            ],
            if (showConnections) ...[
              HealthSectionHead(
                title: 'Your connections',
                actionLabel: '${accepted.length}',
                chevron: false,
              ),
              gap(9),
              if (accepted.isEmpty)
                _Notice(
                  noticeKey: const Key('community_no_connections'),
                  icon: LucideIcons.messageCircle,
                  text: 'No connections yet — say hi to someone nearby below.',
                )
              else
                for (final connection in accepted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _ConnectionCard(connection: connection, uid: uid),
                  ),
              gap(16),
            ],
            if (showNearby) ...[
              HealthSectionHead(
                title: 'Nearby pet people',
                actionLabel: 'See all',
                onAction: _openNearby,
              ),
              gap(9),
              if (_nearbyLoading)
                const _CardSkeleton()
              else if (_nearbyError != null)
                _Notice(
                  noticeKey: const Key('community_nearby_error'),
                  icon: LucideIcons.cloudOff,
                  text: 'Could not look up your area just now. Pull to retry.',
                )
              else if (me?.geohash == null)
                _Notice(
                  noticeKey: const Key('community_no_area'),
                  icon: LucideIcons.mapPinOff,
                  text: 'Share your approximate area in your community '
                      'profile to discover people nearby.',
                )
              else if (strangers.isEmpty)
                _Notice(
                  noticeKey: const Key('community_nearby_empty'),
                  icon: LucideIcons.users,
                  text: "No one new nearby yet — you're early! Check back "
                      'soon.',
                )
              else
                for (final person in strangers.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _NearbyCard(
                      person: person,
                      myCell: me?.geohash,
                      onConnect: () async {
                        await ref
                            .read(communityRepositoryProvider)
                            .sendRequest(person.userId);
                        await _refresh();
                      },
                    ),
                  ),
            ],
            gap(8),
          ],
        );
      },
    );
  }

  Widget _shell({
    required int requestCount,
    required CommunityProfile? me,
    required List<Widget> children,
  }) {
    return Stack(
      children: [
        HealthRecordScaffold(
          onRefresh: _refresh,
          appBar: PetModuleAppBar(
            title: 'Community',
            icon: LucideIcons.pawPrint,
            subtitle: 'Share. Learn. Support.',
            onBack: () => Navigator.of(context).maybePop(),
            actionsWidth: 100,
            actions: [
              _BellButton(
                count: requestCount,
                onTap: () => setState(() => _segment = FeedSegment.requests),
              ),
              HealthCircleButton(
                key: const Key('community_search_button'),
                icon: LucideIcons.search,
                tooltip: 'Find people nearby',
                onTap: _openNearby,
              ),
              HealthCircleButton(
                key: const Key('community_menu_button'),
                icon: LucideIcons.ellipsisVertical,
                tooltip: 'Community options',
                onTap: () => _showMenu(requestCount),
              ),
            ],
          ),
          bottomNav: const PawNavBar(detached: true),
          children: [
            gap(2),
            HealthBleed(
              child: SizedBox(
                height: 38,
                child: ListView(
                  key: const Key('community_segments'),
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: kRecordGutter),
                  children: [
                    for (final s in FeedSegment.values) ...[
                      _SegmentChip(
                        segment: s,
                        selected: _segment == s,
                        onTap: () => setState(() => _segment = s),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ),
            ...children,
          ],
        ),
        // The reference's floating compose button, over the nav bar.
        Positioned(
          right: 18,
          bottom: 86,
          child: FloatingActionButton(
            key: const Key('community_fab'),
            heroTag: 'community_fab',
            // Material 3 defaults this to a rounded square; the reference
            // draws the round compose button the rest of the app uses.
            shape: const CircleBorder(),
            backgroundColor: AppColors.lime500,
            foregroundColor: Colors.black,
            onPressed: () => _openComposer(isMember: me != null),
            child: const Icon(LucideIcons.userPen),
          ),
        ),
      ],
    );
  }
}

/// The header bell. Its badge is the number of people actually waiting on the
/// owner — the reference draws a "3" over nothing.
class _BellButton extends StatelessWidget {
  const _BellButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        HealthCircleButton(
          key: const Key('community_bell'),
          icon: LucideIcons.bell,
          tooltip: 'Requests for you',
          onTap: onTap,
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 4,
            child: Container(
              key: const Key('community_bell_badge'),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              constraints: const BoxConstraints(minWidth: 15),
              decoration: BoxDecoration(
                color: AppColors.emergencyDark,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text('$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      height: 1.3,
                      fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }
}

/// The reference's "What's on your mind?" card, in the one authoring shape
/// PawDoc has: your own community profile.
class _ComposerCard extends StatelessWidget {
  const _ComposerCard({
    required this.me,
    required this.onOpen,
    required this.onFindPeople,
  });

  final CommunityProfile? me;
  final VoidCallback onOpen;
  final VoidCallback onFindPeople;

  @override
  Widget build(BuildContext context) {
    final bio = me?.bio ?? '';
    return Container(
      key: const Key('community_composer'),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: HealthTone.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            key: const Key('community_composer_open'),
            onTap: onOpen,
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                if (me != null)
                  CommunityAvatar(profile: me!, size: 40)
                else
                  const HealthGlyphDisc(
                      icon: LucideIcons.userPlus,
                      tint: AppColors.lime500,
                      size: 40),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        me == null
                            ? 'Join the community'
                            : 'How you appear to members',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        me == null
                            ? 'Opt in to meet pet people near you.'
                            : bio.isEmpty
                                ? 'Add a bio so people know who you are.'
                                : bio,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: HealthTone.muted,
                            fontSize: 12,
                            height: 1.35),
                      ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronRight,
                    size: 17, color: HealthTone.faint),
              ],
            ),
          ),
          const SizedBox(height: 11),
          Divider(
              height: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.06)),
          const SizedBox(height: 11),
          // The reference's Photo / Poll / Ask row. Two of the three have no
          // table behind them and say so; the third is the real action.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              CommunityActionButton(
                key: const Key('community_edit_profile'),
                label: me == null ? 'Join' : 'Edit profile',
                icon: LucideIcons.userPen,
                filled: true,
                onTap: onOpen,
              ),
              CommunityActionButton(
                key: const Key('community_find_people'),
                label: 'Find people',
                icon: LucideIcons.search,
                onTap: onFindPeople,
              ),
              const CommunitySoonChip(
                key: Key('community_soon_post'),
                label: 'Post',
                icon: LucideIcons.image,
                reason: 'Posts, photos and polls need a place to live — '
                    'PawDoc has no posts table yet. Connections and messages '
                    'are what the community holds today.',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Resolves the other party's profile for a connection row.
final _profileForProvider = FutureProvider.autoDispose
    .family<CommunityProfile?, String>((ref, userId) async {
  final map =
      await ref.watch(communityRepositoryProvider).profilesById([userId]);
  return map[userId];
});

/// The post card's shape, carrying an incoming connection request.
class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.connection, required this.uid});

  final CommunityConnection connection;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final other = connection.otherParty(uid);
    final profile = ref.watch(_profileForProvider(other));
    final p = profile.maybeWhen(data: (p) => p, orElse: () => null);
    final repo = ref.read(communityRepositoryProvider);

    return _MemberCard(
      cardKey: Key('community_request_${connection.id}'),
      profile: p,
      badge: 'Wants to connect',
      actions: [
        CommunityActionButton(
          key: Key('community_accept_${connection.id}'),
          label: 'Accept',
          icon: LucideIcons.check,
          filled: true,
          onTap: () async {
            await repo.respond(connection.id, ConnectionStatus.accepted);
            ref.invalidate(communityConnectionsProvider);
          },
        ),
        CommunityActionButton(
          key: Key('community_decline_${connection.id}'),
          label: 'Decline',
          icon: LucideIcons.x,
          onTap: () async {
            await repo.respond(connection.id, ConnectionStatus.declined);
            ref.invalidate(communityConnectionsProvider);
          },
        ),
      ],
    );
  }
}

/// The post card's shape, carrying an accepted connection.
class _ConnectionCard extends ConsumerWidget {
  const _ConnectionCard({required this.connection, required this.uid});

  final CommunityConnection connection;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final other = connection.otherParty(uid);
    final profile = ref.watch(_profileForProvider(other));
    final p = profile.maybeWhen(data: (p) => p, orElse: () => null);

    void open() {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) =>
            CommunityChatScreen(connection: connection, otherProfile: p),
      ));
    }

    return _MemberCard(
      cardKey: Key('community_connection_${connection.id}'),
      profile: p,
      badge: 'Connected',
      onTap: open,
      actions: [
        CommunityActionButton(
          key: Key('community_message_${connection.id}'),
          label: 'Message',
          icon: LucideIcons.messageCircle,
          filled: true,
          onTap: open,
        ),
      ],
    );
  }
}

/// The post card's shape, carrying a discoverable stranger.
class _NearbyCard extends StatelessWidget {
  const _NearbyCard({
    required this.person,
    required this.myCell,
    required this.onConnect,
  });

  final CommunityProfile person;
  final String? myCell;
  final Future<void> Function() onConnect;

  @override
  Widget build(BuildContext context) {
    return _MemberCard(
      cardKey: Key('community_nearby_${person.userId}'),
      profile: person,
      badge: approxDistanceLabel(myCell, person.geohash),
      actions: [
        if (person.allowRequests)
          CommunityActionButton(
            key: Key('community_request_btn_${person.userId}'),
            label: 'Connect',
            icon: LucideIcons.userPlus,
            filled: true,
            onTap: onConnect,
          )
        else
          CommunityActionButton(
            key: Key('community_closed_${person.userId}'),
            label: 'Not taking requests',
            icon: LucideIcons.userX,
            onTap: null,
          ),
      ],
    );
  }
}

/// The reference's post card, generalised: an avatar, a name with a badge, a
/// meta line, the body, and an action row. What varies is what fills it.
class _MemberCard extends StatelessWidget {
  const _MemberCard({
    required this.cardKey,
    required this.profile,
    required this.badge,
    required this.actions,
    this.onTap,
  });

  final Key cardKey;
  final CommunityProfile? profile;
  final String badge;
  final List<Widget> actions;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final species = p == null ? '' : p.speciesTags.map(speciesLabel).join(' · ');
    return Material(
      color: HealthTone.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: cardKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (p != null)
                    CommunityAvatar(profile: p, size: 42)
                  else
                    const HealthGlyphDisc(
                        icon: LucideIcons.user,
                        tint: AppColors.lime500,
                        size: 42),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p?.displayName ?? 'A community member',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14.5,
                                height: 1.2,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (badge.isNotEmpty)
                              Flexible(
                                child: HealthPill(
                                    label: badge, tint: AppColors.lime500),
                              ),
                            if (badge.isNotEmpty && species.isNotEmpty)
                              const SizedBox(width: 7),
                            if (species.isNotEmpty)
                              Flexible(
                                child: Text(species,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        color: HealthTone.muted,
                                        fontSize: 11.5)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if ((p?.bio ?? '').isNotEmpty) ...[
                const SizedBox(height: 9),
                Text(p!.bio!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: HealthTone.muted, fontSize: 12.5, height: 1.4)),
              ],
              const SizedBox(height: 11),
              Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ),
        ),
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
      padding: const EdgeInsets.all(13),
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

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) => Container(
        height: 118,
        margin: const EdgeInsets.only(bottom: 9),
        decoration: BoxDecoration(
          color: HealthTone.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
      );
}

class _SegmentChip extends StatelessWidget {
  const _SegmentChip({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final FeedSegment segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = AppColors.lime500;
    return Material(
      color: selected ? accent.withValues(alpha: 0.14) : HealthTone.card,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        key: Key('community_segment_${segment.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
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
              Icon(segment.icon,
                  size: 14, color: selected ? accent : HealthTone.muted),
              const SizedBox(width: 6),
              Text(segment.label,
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
