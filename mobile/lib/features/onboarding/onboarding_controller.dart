/// Onboarding draft state.
///
/// The user enters pet info screen-by-screen; the controller persists each
/// field change to SharedPreferences so that backgrounding + restoring
/// the app does not lose progress.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/pet.dart';
import '../../shared/services/logger.dart';

@immutable
class OnboardingDraft {
  const OnboardingDraft({
    this.name,
    this.species,
    this.birthDate,
    this.sex,
    this.weightKg,
    this.breed,
    this.notes,
  });

  factory OnboardingDraft.empty() => const OnboardingDraft();

  factory OnboardingDraft.fromJson(Map<String, dynamic> json) =>
      OnboardingDraft(
        name: json['name'] as String?,
        species: PetSpecies.tryParse(json['species'] as String?),
        birthDate: json['birth_date'] != null
            ? DateTime.tryParse(json['birth_date'] as String)
            : null,
        sex: PetSex.tryParse(json['sex'] as String?),
        weightKg: (json['weight_kg'] as num?)?.toDouble(),
        breed: json['breed'] as String?,
        notes: json['notes'] as String?,
      );

  Map<String, dynamic> toJson() => {
    if (name != null) 'name': name,
    if (species != null) 'species': species!.apiValue,
    if (birthDate != null) 'birth_date': birthDate!.toIso8601String(),
    if (sex != null) 'sex': sex!.apiValue,
    if (weightKg != null) 'weight_kg': weightKg,
    if (breed != null) 'breed': breed,
    if (notes != null) 'notes': notes,
  };

  final String? name;
  final PetSpecies? species;
  final DateTime? birthDate;
  final PetSex? sex;
  final double? weightKg;
  final String? breed;
  final String? notes;

  OnboardingDraft copyWith({
    String? name,
    PetSpecies? species,
    DateTime? birthDate,
    PetSex? sex,
    double? weightKg,
    String? breed,
    String? notes,
    bool clearBirthDate = false,
    bool clearWeight = false,
  }) {
    return OnboardingDraft(
      name: name ?? this.name,
      species: species ?? this.species,
      birthDate: clearBirthDate ? null : (birthDate ?? this.birthDate),
      sex: sex ?? this.sex,
      weightKg: clearWeight ? null : (weightKg ?? this.weightKg),
      breed: breed ?? this.breed,
      notes: notes ?? this.notes,
    );
  }

  /// Validate the draft and return a (message, isFatal) pair when invalid.
  /// Returns null when ready to submit.
  String? validate() {
    if (species == null) return 'Pick a species first.';
    if (name == null || name!.trim().isEmpty) return 'Give your pet a name.';
    if (name!.trim().length > 60) return 'Name is too long (max 60).';
    if (birthDate != null && birthDate!.isAfter(DateTime.now())) {
      return 'Birth date is in the future.';
    }
    if (birthDate != null &&
        DateTime.now().difference(birthDate!).inDays > 30 * 365) {
      return 'That age seems implausible — double-check the year.';
    }
    if (weightKg != null && weightKg! <= 0) return 'Weight must be positive.';
    if (weightKg != null && weightKg! > 200) return 'Weight seems too high.';
    if (breed != null && breed!.length > 80) {
      return 'Breed name is too long (max 80).';
    }
    if (notes != null && notes!.length > 500) {
      return 'Notes are too long (max 500 characters).';
    }
    return null;
  }
}

class OnboardingController extends StateNotifier<OnboardingDraft> {
  OnboardingController(this._prefs) : super(_initial(_prefs));

  static const _kDraftKey = 'pawdoc.onboarding.draft.v1';

  final SharedPreferences _prefs;
  Timer? _saveTimer;
  static final _log = AppLogger.of('onboarding.controller');

  static OnboardingDraft _initial(SharedPreferences prefs) {
    final raw = prefs.getString(_kDraftKey);
    if (raw == null) return OnboardingDraft.empty();
    try {
      return OnboardingDraft.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on Object catch (e) {
      _log.warning('draft_restore_failed', e);
      return OnboardingDraft.empty();
    }
  }

  void update(OnboardingDraft next) {
    state = next;
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), _save);
  }

  Future<void> _save() async {
    await _prefs.setString(_kDraftKey, jsonEncode(state.toJson()));
  }

  Future<void> clear() async {
    state = OnboardingDraft.empty();
    await _prefs.remove(_kDraftKey);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }
}

/// Async provider for SharedPreferences. Built once; subsequent reads are
/// instant.
final sharedPreferencesProvider = FutureProvider<SharedPreferences>(
  (ref) => SharedPreferences.getInstance(),
);

/// Onboarding controller — only available once SharedPreferences resolves.
final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingDraft>((ref) {
      final prefsAsync = ref.watch(sharedPreferencesProvider);
      // We declare the provider keepAlive only when prefs has resolved.
      final prefs = prefsAsync.value;
      if (prefs == null) {
        throw StateError(
          'onboardingControllerProvider read before sharedPreferencesProvider resolved.',
        );
      }
      return OnboardingController(prefs);
    });
