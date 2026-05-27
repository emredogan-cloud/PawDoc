import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../analytics/analytics.dart';
import '../auth/supabase_providers.dart';
import '../health/health_event.dart';
import '../pets/pet.dart';
import 'health_report.dart';

/// Fetches a pet's latest analysis + recent events (RLS-scoped), builds the
/// Markdown report, and hands it to the OS share sheet.
class HealthReportService {
  HealthReportService(this._client);

  final SupabaseClient _client;

  Future<String> buildForPet(Pet pet) async {
    Map<String, dynamic>? latest;
    final analyses = await _client
        .from('analyses')
        .select('triage_level, primary_concern, full_response, created_at')
        .eq('pet_id', pet.id!)
        .order('created_at', ascending: false)
        .limit(1);
    if ((analyses as List).isNotEmpty) {
      latest = (analyses.first as Map).cast<String, dynamic>();
    }
    final rows = await _client
        .from('health_events')
        .select()
        .eq('pet_id', pet.id!)
        .order('event_date', ascending: false)
        .limit(10);
    final events = (rows as List)
        .map((e) => HealthEvent.fromJson((e as Map).cast<String, dynamic>()))
        .toList(growable: false);
    return buildHealthReport(pet: pet, latestAnalysis: latest, events: events);
  }

  Future<void> exportForPet(Pet pet) async {
    final report = await buildForPet(pet);
    await Analytics.healthReportExported();
    await SharePlus.instance.share(
      ShareParams(text: report, subject: 'PawDoc Health Report — ${pet.name}'),
    );
  }
}

final healthReportServiceProvider = Provider<HealthReportService>((ref) {
  return HealthReportService(ref.watch(supabaseClientProvider));
});
