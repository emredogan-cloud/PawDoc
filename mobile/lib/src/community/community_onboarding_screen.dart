import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/geohash.dart';
import '../pets/pet.dart' show Pet, kSpecies, speciesLabel;
import '../pets/pets_repository.dart';
import '../theme/design_tokens.dart';
import '../theme/paw_ui.dart';
import '../walks/location_service.dart';
import 'community_models.dart';
import 'community_repository.dart';

/// Explicit opt-in for Paw Community (Next Evolution Phase 6). The screen IS
/// the consent: it states exactly what is shared (display name, bio, species,
/// approximate area — a ~2 km cell, never coordinates), what is not, and how
/// to leave. Joining creates the profile row; leaving deletes it and the
/// whole graph cascades away.
class CommunityOnboardingScreen extends ConsumerStatefulWidget {
  const CommunityOnboardingScreen({super.key});

  @override
  ConsumerState<CommunityOnboardingScreen> createState() =>
      _CommunityOnboardingScreenState();
}

class _CommunityOnboardingScreenState
    extends ConsumerState<CommunityOnboardingScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final Set<String> _species = {};
  bool _discoverable = true;
  bool _allowRequests = true;
  bool _shareArea = true;
  bool _joining = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Suggest species from the user's pets once they load.
    Future.microtask(() async {
      List<Pet> pets;
      try {
        pets = await ref.read(petsListProvider.future);
      } catch (_) {
        return;
      }
      if (!mounted || pets.isEmpty) return;
      setState(() {
        for (final pet in pets) {
          _species.add(pet.species);
        }
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _error = 'Pick a display name (at least 2 characters).');
      return;
    }
    setState(() {
      _joining = true;
      _error = null;
    });

    String? cell;
    if (_shareArea) {
      final location = await ref.read(locationServiceProvider).current();
      if (location is LocationGranted) {
        cell = geohashEncode(location.lat, location.lon, precision: 5);
      }
      // Denied → join without an area (reachable, not nearby-discoverable);
      // the user can add it later from the profile editor.
    }

    try {
      await ref.read(communityRepositoryProvider).saveProfile(
            CommunityProfile(
              userId: '', // repository injects auth.uid()
              displayName: name,
              bio: _bioController.text.trim().isEmpty
                  ? null
                  : _bioController.text.trim(),
              speciesTags: _species.toList(),
              geohash: cell,
              isDiscoverable: _discoverable,
              allowRequests: _allowRequests,
            ),
          );
      ref.invalidate(myCommunityProfileProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _joining = false;
          _error = 'Could not join right now. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PawScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Paw Community'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.s16),
        children: [
          Text('Meet pet people nearby',
              style: theme.textTheme.headlineSmall
                  ?.copyWith(color: AppColors.ink50)),
          const SizedBox(height: AppSpace.s8),
          Text(
            'Opt in to discover owners around you, connect, chat, and plan '
            'walks together.',
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.ink300),
          ),
          const SizedBox(height: AppSpace.s16),

          // The consent card — exactly what is and is not shared.
          PawCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('What others can see',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(color: PawPalette.mint)),
                const SizedBox(height: AppSpace.s8),
                const _ConsentRow(
                    icon: Icons.badge_outlined,
                    text: 'Your display name, bio, and pet species'),
                const _ConsentRow(
                    icon: Icons.location_on_outlined,
                    text:
                        'Only your approximate area (a ~2 km zone) — never your '
                        'address or exact location'),
                const _ConsentRow(
                    icon: Icons.visibility_off_outlined,
                    text:
                        'Nothing else: no email, no pet health data, no photos'),
                const _ConsentRow(
                    icon: Icons.logout_rounded,
                    text:
                        'Leave anytime — your profile, connections, and chats '
                        'are deleted together'),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s16),

          TextField(
            key: const Key('community_name_field'),
            controller: _nameController,
            maxLength: 40,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Display name',
              hintText: "Rex's human",
              counterText: '',
            ),
          ),
          const SizedBox(height: AppSpace.s12),
          TextField(
            key: const Key('community_bio_field'),
            controller: _bioController,
            maxLength: 160,
            minLines: 2,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Bio (optional)',
              hintText: 'Early-morning walker, always up for park meetups',
              counterText: '',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpace.s12),
          Text('Your pets',
              style:
                  theme.textTheme.titleSmall?.copyWith(color: AppColors.ink50)),
          const SizedBox(height: AppSpace.s8),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              for (final species in kSpecies)
                FilterChip(
                  key: Key('community_species_$species'),
                  label: Text(speciesLabel(species)),
                  selected: _species.contains(species),
                  onSelected: (selected) => setState(() {
                    selected ? _species.add(species) : _species.remove(species);
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),

          SwitchListTile(
            key: const Key('community_share_area'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Share my approximate area'),
            subtitle: const Text(
                'Needed to appear in nearby discovery (a ~2 km zone only)'),
            value: _shareArea,
            onChanged: (v) => setState(() => _shareArea = v),
          ),
          SwitchListTile(
            key: const Key('community_discoverable'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Show me in nearby discovery'),
            subtitle: const Text('Off = only people you contact can see you'),
            value: _discoverable,
            onChanged: (v) => setState(() => _discoverable = v),
          ),
          SwitchListTile(
            key: const Key('community_allow_requests'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Allow connection requests'),
            value: _allowRequests,
            onChanged: (v) => setState(() => _allowRequests = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.s8),
            Text(_error!,
                key: const Key('community_join_error'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: AppSpace.s16),
          PawPrimaryButton(
            key: const Key('community_join_button'),
            icon: Icons.pets_rounded,
            onPressed: _joining ? null : _join,
            child: _joining
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Join the community'),
          ),
          const SizedBox(height: AppSpace.s8),
          Text(
            'Be kind. No spam, no harassment — you can report or block anyone, '
            'and reports are reviewed.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(color: AppColors.ink300),
          ),
          const SizedBox(height: AppSpace.s24),
        ],
      ),
    );
  }
}

class _ConsentRow extends StatelessWidget {
  const _ConsentRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: PawPalette.mint),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Text(text,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.ink50)),
            ),
          ],
        ),
      );
}
