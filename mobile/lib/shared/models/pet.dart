/// Pet domain model — mirrors the `public.pets` row + a couple of derived
/// fields useful to the UI (computed age, display species).
///
/// The model is immutable. Updates go through `PetsController.update(...)`
/// which round-trips through Supabase.
library;

import 'package:flutter/foundation.dart';

enum PetSpecies {
  dog,
  cat,
  rabbit,
  bird,
  reptile,
  other;

  /// What the API expects in the `species` column (matches the DB CHECK).
  String get apiValue => name;

  String get displayName => switch (this) {
    PetSpecies.dog => 'Dog',
    PetSpecies.cat => 'Cat',
    PetSpecies.rabbit => 'Rabbit',
    PetSpecies.bird => 'Bird',
    PetSpecies.reptile => 'Reptile',
    PetSpecies.other => 'Other',
  };

  /// Emoji used in the species picker grid. Not localised; intentionally
  /// universal-friendly.
  String get emoji => switch (this) {
    PetSpecies.dog => '🐶',
    PetSpecies.cat => '🐱',
    PetSpecies.rabbit => '🐰',
    PetSpecies.bird => '🦜',
    PetSpecies.reptile => '🦎',
    PetSpecies.other => '🐾',
  };

  static PetSpecies? tryParse(String? raw) {
    if (raw == null) return null;
    for (final s in PetSpecies.values) {
      if (s.apiValue == raw.toLowerCase()) return s;
    }
    return null;
  }
}

enum PetSex {
  male,
  female,
  unknown;

  String get apiValue => name;
  String get displayName => switch (this) {
    PetSex.male => 'Male',
    PetSex.female => 'Female',
    PetSex.unknown => 'Prefer not to say',
  };

  static PetSex? tryParse(String? raw) {
    if (raw == null) return null;
    for (final s in PetSex.values) {
      if (s.apiValue == raw.toLowerCase()) return s;
    }
    return null;
  }
}

@immutable
class Pet {
  const Pet({
    required this.id,
    required this.userId,
    required this.name,
    required this.species,
    this.breed,
    this.birthDate,
    this.sex,
    this.weightKg,
    this.photoUrl,
    this.medicalNotes,
    this.isActive = true,
    required this.createdAt,
  });

  factory Pet.fromJson(Map<String, dynamic> json) {
    final species = PetSpecies.tryParse(json['species'] as String?);
    if (species == null) {
      throw FormatException(
        'pet.species missing or invalid: ${json['species']}',
      );
    }
    return Pet(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      species: species,
      breed: json['breed'] as String?,
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'] as String)
          : null,
      sex: PetSex.tryParse(json['sex'] as String?),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      photoUrl: json['photo_url'] as String?,
      medicalNotes: json['medical_notes'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String userId;
  final String name;
  final PetSpecies species;
  final String? breed;
  final DateTime? birthDate;
  final PetSex? sex;
  final double? weightKg;
  final String? photoUrl;
  final String? medicalNotes;
  final bool isActive;
  final DateTime createdAt;

  /// Whole years; null when DOB unknown.
  int? get ageYears {
    final dob = birthDate;
    if (dob == null) return null;
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      years -= 1;
    }
    return years < 0 ? 0 : years;
  }
}

/// Payload used to create a pet. The DB fills in id / created_at;
/// user_id is set by the caller from auth.uid().
@immutable
class PetCreate {
  const PetCreate({
    required this.userId,
    required this.name,
    required this.species,
    this.breed,
    this.birthDate,
    this.sex,
    this.weightKg,
    this.medicalNotes,
  });

  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'name': name,
    'species': species.apiValue,
    if (breed != null && breed!.isNotEmpty) 'breed': breed,
    if (birthDate != null)
      'birth_date':
          '${birthDate!.year.toString().padLeft(4, '0')}-'
          '${birthDate!.month.toString().padLeft(2, '0')}-'
          '${birthDate!.day.toString().padLeft(2, '0')}',
    if (sex != null) 'sex': sex!.apiValue,
    if (weightKg != null) 'weight_kg': weightKg,
    if (medicalNotes != null && medicalNotes!.isNotEmpty)
      'medical_notes': medicalNotes,
  };

  final String userId;
  final String name;
  final PetSpecies species;
  final String? breed;
  final DateTime? birthDate;
  final PetSex? sex;
  final double? weightKg;
  final String? medicalNotes;
}
