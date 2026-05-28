/// Pet model mirroring the `pets` table (Phase 1.1 schema).
/// Phase 5.1 adds the exotic species (guinea_pig) alongside the existing ones.
const List<String> kSpecies = ['dog', 'cat', 'rabbit', 'guinea_pig', 'bird', 'reptile', 'other'];

/// Display label (emoji + name) for a species value. Single source of truth used
/// by the onboarding grid + the pet-edit form so the two never drift.
String speciesLabel(String s) => switch (s) {
      'dog' => '🐶 Dog',
      'cat' => '🐱 Cat',
      'rabbit' => '🐰 Rabbit',
      'guinea_pig' => '🐹 Guinea pig',
      'bird' => '🦜 Bird',
      'reptile' => '🦎 Reptile',
      _ => '🐾 Other',
    };

class Pet {
  const Pet({
    this.id,
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
  });

  final String? id;
  final String userId;
  final String name;
  final String species;
  final String? breed;
  final DateTime? birthDate;
  final String? sex;
  final double? weightKg;
  final String? photoUrl;
  final String? medicalNotes;
  final bool isActive;

  factory Pet.fromJson(Map<String, dynamic> json) {
    final birth = json['birth_date'] as String?;
    return Pet(
      id: json['id'] as String?,
      userId: json['user_id'] as String,
      name: json['name'] as String,
      species: json['species'] as String,
      breed: json['breed'] as String?,
      birthDate: (birth == null || birth.isEmpty) ? null : DateTime.parse(birth),
      sex: json['sex'] as String?,
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      photoUrl: json['photo_url'] as String?,
      medicalNotes: json['medical_notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  /// Columns for insert/update. `user_id` is added by the repository (it must
  /// equal auth.uid() to satisfy the RLS WITH CHECK from Phase 1.1).
  Map<String, dynamic> toColumns() => {
        'name': name,
        'species': species,
        'breed': breed,
        'birth_date': birthDate?.toIso8601String().split('T').first,
        'sex': sex,
        'weight_kg': weightKg,
        'photo_url': photoUrl,
        'medical_notes': medicalNotes,
        'is_active': isActive,
      };

  Map<String, dynamic> toJson() => {'id': id, 'user_id': userId, ...toColumns()};

  Pet copyWith({
    String? name,
    String? species,
    String? breed,
    DateTime? birthDate,
    String? sex,
    double? weightKg,
    String? photoUrl,
    String? medicalNotes,
    bool? isActive,
  }) =>
      Pet(
        id: id,
        userId: userId,
        name: name ?? this.name,
        species: species ?? this.species,
        breed: breed ?? this.breed,
        birthDate: birthDate ?? this.birthDate,
        sex: sex ?? this.sex,
        weightKg: weightKg ?? this.weightKg,
        photoUrl: photoUrl ?? this.photoUrl,
        medicalNotes: medicalNotes ?? this.medicalNotes,
        isActive: isActive ?? this.isActive,
      );
}
