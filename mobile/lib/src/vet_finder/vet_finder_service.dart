import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/supabase_providers.dart';
import 'vet.dart';

/// Calls the /find-vets Edge Function (the key-hiding Places proxy). Returns a
/// clean list of [Vet]; an empty list on any failure so the UI can fall back to
/// native maps without erroring.
class VetFinderService {
  VetFinderService(this._client);

  final SupabaseClient _client;

  Future<List<Vet>> _invoke(Map<String, dynamic> body) async {
    try {
      final res = await _client.functions.invoke('find-vets', body: body);
      final data = res.data;
      if (data is Map && data['vets'] is List) {
        return (data['vets'] as List)
            .map((v) => Vet.fromJson((v as Map).cast<String, dynamic>()))
            .toList(growable: false);
      }
    } catch (_) {
      // Swallow — caller degrades to the native-maps fallback.
    }
    return const <Vet>[];
  }

  Future<List<Vet>> findNearby(double lat, double lng) => _invoke({'lat': lat, 'lng': lng});

  Future<List<Vet>> findByQuery(String query) => _invoke({'query': query});
}

final vetFinderServiceProvider = Provider<VetFinderService>((ref) {
  return VetFinderService(ref.watch(supabaseClientProvider));
});
