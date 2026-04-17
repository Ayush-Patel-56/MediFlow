class Facility {
  final String id;
  final String name;
  final String email;
  final String type; // e.g., 'Primary Health Center', 'Community Health Center'
  final double latitude;
  final double longitude;

  Facility({
    required this.id,
    required this.name,
    required this.email,
    required this.type,
    required this.latitude,
    required this.longitude,
  });

  factory Facility.fromMap(Map<String, dynamic> map, String id) {
    return Facility(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      type: map['type'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
