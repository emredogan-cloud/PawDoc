import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/supabase_providers.dart';
import '../core/app_views.dart';
import '../core/geohash.dart';
import '../core/motion.dart';
import '../pets/pet.dart' show speciesEmoji;
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import 'community_chat_screen.dart';
import 'community_models.dart';
import 'community_repository.dart';

/// Community hub: incoming requests, nearby discovery, and connections.
/// Everything here assumes membership (the Home entry gates on it).
class CommunityHomeScreen extends ConsumerStatefulWidget {
  const CommunityHomeScreen({super.key});

  @override
  ConsumerState<CommunityHomeScreen> createState() =>
      _CommunityHomeScreenState();
}

class _CommunityHomeScreenState extends ConsumerState<CommunityHomeScreen> {
  Future<List<CommunityProfile>>? _nearby;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadNearby);
  }

  Future<void> _loadNearby() async {
    final me = await ref.read(myCommunityProfileProvider.future);
    if (!mounted) return;
    final cell = me?.geohash;
    setState(() {
      _nearby = cell == null
          ? Future.value(const <CommunityProfile>[])
          : ref
              .read(communityRepositoryProvider)
              .discover(geohashNeighbors(cell));
    });
  }

  Future<void> _refresh() async {
    ref.invalidate(communityConnectionsProvider);
    ref.invalidate(myCommunityProfileProvider);
    await _loadNearby();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uid = ref.watch(currentUserIdProvider) ?? '';
    final connectionsAsync = ref.watch(communityConnectionsProvider);

    return PawScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Paw Community'),
        actions: [
          IconButton(
            key: const Key('community_leave_button'),
            tooltip: 'Leave community',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _leave,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: connectionsAsync.when(
          loading: () => ListView(
            padding: const EdgeInsets.all(AppSpace.s16),
            children: const [SkeletonCard(height: 96), SkeletonCard(height: 96)],
          ),
          error: (e, _) => AppErrorView(
              message: 'Could not load the community.', onRetry: _refresh),
          data: (connections) {
            final incoming =
                connections.where((c) => c.isIncomingFor(uid)).toList();
            final outgoing =
                connections.where((c) => c.isOutgoingFor(uid)).toList();
            final accepted = connections
                .where((c) => c.status == ConnectionStatus.accepted)
                .toList();
            final connectedIds = {
              for (final c in connections)
                if (c.status != ConnectionStatus.declined) c.otherParty(uid),
            };
            return ListView(
              padding: const EdgeInsets.all(AppSpace.s16),
              children: [
                if (incoming.isNotEmpty) ...[
                  _SectionTitle('Requests for you'),
                  for (final connection in incoming)
                    _RequestCard(connection: connection, uid: uid),
                  const SizedBox(height: AppSpace.s8),
                ],
                _SectionTitle('Your connections'),
                if (accepted.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s8),
                    child: Text(
                      'No connections yet — say hi to someone nearby below.',
                      key: const Key('community_no_connections'),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.ink300),
                    ),
                  ),
                for (final connection in accepted)
                  _ConnectionCard(connection: connection, uid: uid),
                const SizedBox(height: AppSpace.s8),
                _SectionTitle('Nearby pet people'),
                _NearbyList(
                  nearby: _nearby,
                  connectedIds: connectedIds,
                  outgoingIds: {for (final c in outgoing) c.otherParty(uid)},
                  onRequested: _refresh,
                ),
                const SizedBox(height: AppSpace.s24),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s8),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: PawPalette.mint)),
      );
}

/// Resolves the other party's profile for a connection row.
final _profileForProvider = FutureProvider.autoDispose
    .family<CommunityProfile?, String>((ref, userId) async {
  final map =
      await ref.watch(communityRepositoryProvider).profilesById([userId]);
  return map[userId];
});

class _RequestCard extends ConsumerWidget {
  const _RequestCard({required this.connection, required this.uid});

  final CommunityConnection connection;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final other = connection.otherParty(uid);
    final profile = ref.watch(_profileForProvider(other));
    final repo = ref.read(communityRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: PawCard(
        key: Key('community_request_${connection.id}'),
        padding: const EdgeInsets.all(AppSpace.s12),
        radius: AppRadius.md,
        child: Row(
          children: [
            const Icon(Icons.person_add_alt_rounded,
                color: PawPalette.mint, size: 22),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Text(
                profile.maybeWhen(
                    data: (p) => p?.displayName ?? 'A community member',
                    orElse: () => '…'),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(color: AppColors.ink50),
              ),
            ),
            TextButton(
              key: Key('community_decline_${connection.id}'),
              onPressed: () async {
                await repo.respond(connection.id, ConnectionStatus.declined);
                ref.invalidate(communityConnectionsProvider);
              },
              child: const Text('Decline'),
            ),
            FilledButton(
              key: Key('community_accept_${connection.id}'),
              onPressed: () async {
                await repo.respond(connection.id, ConnectionStatus.accepted);
                ref.invalidate(communityConnectionsProvider);
              },
              child: const Text('Accept'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionCard extends ConsumerWidget {
  const _ConnectionCard({required this.connection, required this.uid});

  final CommunityConnection connection;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final other = connection.otherParty(uid);
    final profile = ref.watch(_profileForProvider(other));
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: PawCard(
        key: Key('community_connection_${connection.id}'),
        padding: const EdgeInsets.all(AppSpace.s12),
        radius: AppRadius.md,
        onTap: () {
          final p = profile.maybeWhen(data: (p) => p, orElse: () => null);
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => CommunityChatScreen(
              connection: connection,
              otherProfile: p,
            ),
          ));
        },
        child: Row(
          children: [
            const Icon(Icons.chat_bubble_outline_rounded,
                color: PawPalette.mint, size: 22),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.maybeWhen(
                        data: (p) => p?.displayName ?? 'A community member',
                        orElse: () => '…'),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: AppColors.ink50),
                  ),
                  profile.maybeWhen(
                    data: (p) => (p?.bio ?? '').isEmpty
                        ? const SizedBox.shrink()
                        : Text(p!.bio!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.ink300)),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.ink300),
          ],
        ),
      ),
    );
  }
}

class _NearbyList extends ConsumerWidget {
  const _NearbyList({
    required this.nearby,
    required this.connectedIds,
    required this.outgoingIds,
    required this.onRequested,
  });

  final Future<List<CommunityProfile>>? nearby;
  final Set<String> connectedIds;
  final Set<String> outgoingIds;
  final Future<void> Function() onRequested;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final me = ref.watch(myCommunityProfileProvider).maybeWhen(
        data: (p) => p, orElse: () => null);
    if (nearby == null) return const SkeletonCard(height: 96);
    return FutureBuilder<List<CommunityProfile>>(
      future: nearby,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SkeletonCard(height: 96);
        }
        final people = snap.data ?? const <CommunityProfile>[];
        if (me?.geohash == null) {
          return Text(
            'Share your approximate area (community profile) to discover '
            'people nearby.',
            key: const Key('community_no_area'),
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.ink300),
          );
        }
        if (people.isEmpty) {
          return Text(
            'No one nearby yet — you\'re early! Check back soon.',
            key: const Key('community_nearby_empty'),
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.ink300),
          );
        }
        return Column(
          children: [
            for (final person in people)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s8),
                child: PawCard(
                  key: Key('community_nearby_${person.userId}'),
                  padding: const EdgeInsets.all(AppSpace.s12),
                  radius: AppRadius.md,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(person.displayName,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(color: AppColors.ink50)),
                            const SizedBox(height: 2),
                            Text(
                              [
                                for (final s in person.speciesTags)
                                  speciesEmoji(s),
                                approxDistanceLabel(
                                    me?.geohash, person.geohash),
                              ].where((s) => s.isNotEmpty).join('  '),
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: AppColors.ink300),
                            ),
                            if ((person.bio ?? '').isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(person.bio!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: AppColors.ink300)),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpace.s8),
                      if (connectedIds.contains(person.userId))
                        const Icon(Icons.check_circle_rounded,
                            color: PawPalette.mint)
                      else if (outgoingIds.contains(person.userId))
                        Text('Requested',
                            style: theme.textTheme.labelSmall
                                ?.copyWith(color: AppColors.ink300))
                      else if (person.allowRequests)
                        OutlinedButton(
                          key: Key('community_request_btn_${person.userId}'),
                          onPressed: () async {
                            await ref
                                .read(communityRepositoryProvider)
                                .sendRequest(person.userId);
                            await onRequested();
                          },
                          child: const Text('Connect'),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
