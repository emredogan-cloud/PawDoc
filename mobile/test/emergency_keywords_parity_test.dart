// THE PARITY GATE (evolution Phase 3): the emergency keyword lists exist in
// three places — ai-service/app/safety.py (authoritative), the Edge mirror
// supabase/functions/_shared/emergency_keywords.mjs, and the client router
// lib/src/emergency/emergency_keywords.dart. Drift between them silently
// weakens the #1 safety guarantee, so this test parses the .mjs mirror from
// the sibling repo tree and byte-compares every list against the Dart copy.
// (py ≡ mjs parity is asserted node-side; Dart ≡ mjs here closes the triangle.)
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/emergency/emergency_keywords.dart';

/// Extracts the string arrays of the exported locale-keyed const maps from the
/// .mjs source. Deliberately dumb: quoted strings inside bracketed blocks.
Map<String, List<String>> _parseGlobal(String src) {
  final out = <String, List<String>>{};
  final map = RegExp(
          r'export const EMERGENCY_KEYWORDS_BY_LOCALE\s*=\s*\{(.*?)\n\};',
          dotAll: true)
      .firstMatch(src);
  expect(map, isNotNull, reason: 'EMERGENCY_KEYWORDS_BY_LOCALE not found in mjs');
  final body = map!.group(1)!;
  for (final loc in RegExp(r'\n\s*(\w+):\s*\[(.*?)\n\s*\]', dotAll: true)
      .allMatches(body)) {
    out[loc.group(1)!] = RegExp(r'"([^"]*)"')
        .allMatches(loc.group(2)!)
        .map((m) => m.group(1)!)
        .toList();
  }
  return out;
}

Map<String, Map<String, List<String>>> _parseSpecies(String src) {
  final out = <String, Map<String, List<String>>>{};
  final map = RegExp(
          r'export const SPECIES_EMERGENCY_KEYWORDS_BY_LOCALE\s*=\s*\{(.*?)\n\};',
          dotAll: true)
      .firstMatch(src);
  expect(map, isNotNull,
      reason: 'SPECIES_EMERGENCY_KEYWORDS_BY_LOCALE not found in mjs');
  final body = map!.group(1)!;
  for (final loc
      in RegExp(r'\n  (\w+):\s*\{(.*?)\n  \}', dotAll: true).allMatches(body)) {
    final species = <String, List<String>>{};
    for (final sp in RegExp(r'\n\s*(\w+):\s*\[(.*?)\n\s*\]', dotAll: true)
        .allMatches(loc.group(2)!)) {
      species[sp.group(1)!] = RegExp(r'"([^"]*)"')
          .allMatches(sp.group(2)!)
          .map((m) => m.group(1)!)
          .toList();
    }
    out[loc.group(1)!] = species;
  }
  return out;
}

void main() {
  final mjs = File('../supabase/functions/_shared/emergency_keywords.mjs');

  test('the Edge keyword mirror exists in the repo tree', () {
    expect(mjs.existsSync(), isTrue,
        reason: 'parity test must see the sibling Edge mirror');
  });

  test('GLOBAL keyword lists: Dart ≡ mjs, per locale, byte-for-byte', () {
    final parsed = _parseGlobal(mjs.readAsStringSync());
    expect(parsed.keys.toSet(), emergencyKeywordsByLocale.keys.toSet(),
        reason: 'locale sets must match');
    for (final loc in emergencyKeywordsByLocale.keys) {
      expect(
        const JsonEncoder().convert(emergencyKeywordsByLocale[loc]),
        const JsonEncoder().convert(parsed[loc]),
        reason: 'global $loc keyword list drifted between Dart and mjs',
      );
    }
  });

  test('SPECIES keyword lists: Dart ≡ mjs, per locale+species, byte-for-byte',
      () {
    final parsed = _parseSpecies(mjs.readAsStringSync());
    expect(parsed.keys.toSet(), speciesEmergencyKeywordsByLocale.keys.toSet());
    for (final loc in speciesEmergencyKeywordsByLocale.keys) {
      expect(parsed[loc]!.keys.toSet(),
          speciesEmergencyKeywordsByLocale[loc]!.keys.toSet(),
          reason: 'species sets for $loc must match');
      for (final sp in speciesEmergencyKeywordsByLocale[loc]!.keys) {
        expect(
          const JsonEncoder().convert(speciesEmergencyKeywordsByLocale[loc]![sp]),
          const JsonEncoder().convert(parsed[loc]![sp]),
          reason: '$loc/$sp keyword list drifted between Dart and mjs',
        );
      }
    }
  });

  test('expected coverage floor: 23 EN + 36 DE global keywords', () {
    expect(emergencyKeywordsByLocale['en'], hasLength(23));
    expect(emergencyKeywordsByLocale['de'], hasLength(36));
  });
}
