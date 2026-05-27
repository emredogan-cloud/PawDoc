import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../analytics/analytics.dart';
import 'maps_links.dart';
import 'vet.dart';
import 'vet_finder_service.dart';

enum _Mode { locating, list, manual }

/// Nearby vets, triggered from the EMERGENCY / MONITOR result screens. Asks for
/// location; on grant it shows the nearest clinics (call + directions). On
/// denial or any failure it degrades GRACEFULLY — never crashes or blocks:
/// a manual ZIP/city search, plus an always-available "Open Maps" deep link
/// (the Phase 1.4 native-maps fallback).
class VetFinderScreen extends ConsumerStatefulWidget {
  const VetFinderScreen({super.key, this.emergency = false});

  final bool emergency;

  @override
  ConsumerState<VetFinderScreen> createState() => _VetFinderScreenState();
}

class _VetFinderScreenState extends ConsumerState<VetFinderScreen> {
  _Mode _mode = _Mode.locating;
  List<Vet> _vets = const [];
  bool _searching = false;
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    Analytics.vetFinderOpened();
    _locate();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return _toManual();
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        return _toManual();
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      ).timeout(const Duration(seconds: 12));
      final vets = await ref.read(vetFinderServiceProvider).findNearby(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _vets = vets;
        _mode = _Mode.list;
      });
    } catch (_) {
      _toManual(); // permission/timeout/anything -> manual + maps fallback
    }
  }

  void _toManual() {
    if (mounted) setState(() => _mode = _Mode.manual);
  }

  Future<void> _searchManual() async {
    final q = _query.text.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    final vets = await ref.read(vetFinderServiceProvider).findByQuery(q);
    if (!mounted) return;
    setState(() {
      _vets = vets;
      _searching = false;
      _mode = _Mode.list;
    });
  }

  Future<void> _openMaps() =>
      launchUrl(vetSearchMapsUri(_query.text), mode: LaunchMode.externalApplication);

  Future<void> _call(Vet vet) async {
    final uri = telUri(vet.phone);
    if (uri == null) return;
    await Analytics.vetCalled();
    await launchUrl(uri);
  }

  Future<void> _directions(Vet vet) async {
    if (vet.lat == null || vet.lng == null) return _openMaps();
    await launchUrl(directionsUri(vet.lat!, vet.lng!), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.emergency ? 'Emergency vets nearby' : 'Nearby vets')),
      body: switch (_mode) {
        _Mode.locating => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Finding vets near you…'),
              ],
            ),
          ),
        _Mode.manual => _manualView(),
        _Mode.list => _listView(),
      },
    );
  }

  Widget _openMapsButton() => OutlinedButton.icon(
        key: const Key('vet_open_maps'),
        onPressed: _openMaps,
        icon: const Icon(Icons.map),
        label: const Text('Open in Maps'),
      );

  Widget _manualView() => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "We couldn't use your location. Enter a ZIP code or city to search, "
            'or open Maps directly.',
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('vet_manual_query'),
            controller: _query,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchManual(),
            decoration: const InputDecoration(
              labelText: 'ZIP code or city',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const Key('vet_manual_search'),
            onPressed: _searching ? null : _searchManual,
            icon: _searching
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.search),
            label: Text(_searching ? 'Searching…' : 'Search vets'),
          ),
          const SizedBox(height: 8),
          _openMapsButton(),
        ],
      );

  Widget _listView() {
    if (_vets.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            "We couldn't load nearby vets right now. You can open Maps to find one.",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _openMapsButton(),
        ],
      );
    }
    return ListView.separated(
      itemCount: _vets.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: _openMapsButton(),
          );
        }
        final vet = _vets[i - 1];
        final bits = <String>[
          if (distanceLabel(vet.distanceMeters).isNotEmpty) distanceLabel(vet.distanceMeters),
          if (vet.openNow == true) 'Open now' else if (vet.openNow == false) 'Closed',
          if (vet.address != null) vet.address!,
        ];
        return ListTile(
          leading: const Icon(Icons.local_hospital_outlined),
          title: Text(vet.name),
          subtitle: bits.isEmpty ? null : Text(bits.join(' · ')),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (telUri(vet.phone) != null)
                IconButton(
                  tooltip: 'Call',
                  icon: const Icon(Icons.call),
                  onPressed: () => _call(vet),
                ),
              IconButton(
                tooltip: 'Directions',
                icon: const Icon(Icons.directions),
                onPressed: () => _directions(vet),
              ),
            ],
          ),
        );
      },
    );
  }
}
