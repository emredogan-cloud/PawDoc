import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'breed.dart';

/// Where catalog content comes from. v1 ships bundled assets (offline, zero
/// latency); the seam exists so a remote catalog (CDN/Supabase) can slot in
/// later without touching any UI — the path to hundreds of breeds.
abstract class BreedsSource {
  Future<BreedCatalog> load();
}

/// Bundled-asset catalog (schema_version 1).
class AssetBreedsSource implements BreedsSource {
  const AssetBreedsSource();

  static const breedsPath = 'assets/breeds/breeds_v1.json';
  static const creditsPath = 'assets/breeds/credits.json';

  @override
  Future<BreedCatalog> load() async {
    final breedsRaw =
        jsonDecode(await rootBundle.loadString(breedsPath)) as Map<String, dynamic>;
    final version = breedsRaw['schema_version'];
    if (version != 1) {
      throw FormatException('unsupported breeds schema_version: $version');
    }
    final breeds = ((breedsRaw['breeds'] as List).cast<Map<String, dynamic>>())
        .map(Breed.fromJson)
        .toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));

    final creditsRaw =
        jsonDecode(await rootBundle.loadString(creditsPath)) as List;
    final credits = <String, BreedCredit>{
      for (final c in creditsRaw.cast<Map<String, dynamic>>())
        c['slug'] as String: BreedCredit.fromJson(c),
    };
    return BreedCatalog(breeds: breeds, credits: credits);
  }
}

final breedsSourceProvider =
    Provider<BreedsSource>((ref) => const AssetBreedsSource());

/// The loaded encyclopedia catalog (cached for the app session — content is
/// static per release, so autoDispose would only re-parse JSON on revisit).
final breedCatalogProvider = FutureProvider<BreedCatalog>((ref) {
  return ref.watch(breedsSourceProvider).load();
});
