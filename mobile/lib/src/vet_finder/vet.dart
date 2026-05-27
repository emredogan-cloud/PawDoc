/// A nearby veterinary clinic, mirroring the clean JSON from /find-vets. The
/// Places API key never reaches the client — only this normalized shape does.
class Vet {
  const Vet({
    required this.name,
    this.phone,
    this.openNow,
    this.address,
    this.lat,
    this.lng,
    this.distanceMeters,
  });

  final String name;
  final String? phone;
  final bool? openNow;
  final String? address;
  final double? lat;
  final double? lng;
  final int? distanceMeters;

  factory Vet.fromJson(Map<String, dynamic> json) => Vet(
        name: json['name'] as String? ?? 'Veterinary clinic',
        phone: json['phone'] as String?,
        openNow: json['openNow'] as bool?,
        address: json['address'] as String?,
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        distanceMeters: (json['distanceMeters'] as num?)?.toInt(),
      );
}
