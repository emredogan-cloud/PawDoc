// Phase 0 asset-pipeline guard. UiAssets is generated from disk
// (tool/gen_ui_assets.dart), but nothing stops a later edit from renaming a
// file, dropping a folder out of pubspec, or leaving a plate placeholder
// behind. Each of those fails silently at runtime — Flutter renders a grey box
// and the app still "works" — so the failure has to be caught here instead.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawdoc/src/theme/ui_assets.dart';

/// Every path UiAssets can hand out: flat constants + the runtime-keyed sets.
List<String> _allPaths() => [
      ...UiAssets.actionSet.values,
      ...UiAssets.anatomySet.values,
      ...UiAssets.breedCareSet.values,
      ...UiAssets.firstAidSet.values,
      ...UiAssets.medicationSet.values,
      ...UiAssets.memorySet.values,
      ...UiAssets.notificationSet.values,
      ...UiAssets.recordSet.values,
      ...UiAssets.symptomSet.values,
      ...UiAssets.vaccineSet.values,
      ...UiAssets.vitalSet.values,
      ...UiAssets.weatherSet.values,
      // Representative constants from each single-asset family.
      UiAssets.aiAssistantAvatar,
      UiAssets.brdLogoMark,
      UiAssets.petBuddyHeroCutout,
      UiAssets.prm3dShieldPaw,
      UiAssets.emgShieldAlert,
      UiAssets.onbHeroDogCatHalo,
    ];

void main() {
  group('UiAssets', () {
    test('every referenced asset exists on disk', () {
      final missing = _allPaths().where((p) => !File(p).existsSync()).toList();
      expect(missing, isEmpty, reason: 'UiAssets points at missing files:\n'
          '${missing.join('\n')}');
    });

    test('every referenced asset is reachable through pubspec', () {
      final declared = File('pubspec.yaml')
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.startsWith('- assets/'))
          .map((l) => l.substring(2))
          .toList();

      bool covered(String path) => declared.any((d) =>
          d.endsWith('/') ? path.startsWith(d) : d == path);

      final undeclared = _allPaths().where((p) => !covered(p)).toSet().toList();
      expect(undeclared, isEmpty,
          reason: 'assets exist but are not declared in pubspec.yaml, so they '
              'will be absent from the bundle:\n${undeclared.join('\n')}');
    });

    test('no unexpanded plate placeholders survived the pipeline', () {
      final bad = Directory('assets')
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => f.path)
          .where((p) => !p.contains('/_plates/'))
          .where((p) =>
              p.contains('<') ||
              p.contains('{') ||
              p.contains(' + ') ||
              p.endsWith('.png.png') ||
              p.endsWith('.webp.png') ||
              p.endsWith('.svg.png'))
          .toList();
      expect(bad, isEmpty,
          reason: 'placeholder-named plates left in the bundle:\n'
              '${bad.join('\n')}');
    });

    test('the raw source plates are never bundled', () {
      final declared = File('pubspec.yaml')
          .readAsLinesSync()
          .map((l) => l.trim())
          .where((l) => l.startsWith('- assets/'));
      expect(declared.where((d) => d.contains('_plates')), isEmpty,
          reason: 'assets/_plates/ is ~150 MB of source material and must stay '
              'out of the app bundle');
    });

    test('icon families are complete', () {
      // Counts come from UI_ASSET_SPECIFICATION §6.9-§6.10 inventories; a short
      // family means a plate sliced into fewer cells than it should have.
      expect(UiAssets.symptomSet, hasLength(24));
      expect(UiAssets.anatomySet, hasLength(12));
      expect(UiAssets.breedCareSet, hasLength(12));
      expect(UiAssets.vaccineSet, hasLength(8));
      expect(UiAssets.firstAidSet, hasLength(8));
      expect(UiAssets.actionSet, hasLength(8));
      expect(UiAssets.recordSet, hasLength(8));
      expect(UiAssets.weatherSet, hasLength(8));
      expect(UiAssets.notificationSet, hasLength(6));
      expect(UiAssets.medicationSet, hasLength(4));
      expect(UiAssets.memorySet, hasLength(24));
    });
  });
}
