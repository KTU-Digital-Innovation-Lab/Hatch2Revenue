class FarmProfile {
  final String farmName;
  final String ownerName;
  final String farmType;
  final String farmSize;
  final String country;
  final String region;
  final String location;
  final String phone;
  final String email;

  const FarmProfile({
    this.farmName = '',
    this.ownerName = '',
    this.farmType = '',
    this.farmSize = '',
    this.country = '',
    this.region = '',
    this.location = '',
    this.phone = '',
    this.email = '',
  });

  FarmProfile copyWith({
    String? farmName,
    String? ownerName,
    String? farmType,
    String? farmSize,
    String? country,
    String? region,
    String? location,
    String? phone,
    String? email,
  }) {
    return FarmProfile(
      farmName: farmName ?? this.farmName,
      ownerName: ownerName ?? this.ownerName,
      farmType: farmType ?? this.farmType,
      farmSize: farmSize ?? this.farmSize,
      country: country ?? this.country,
      region: region ?? this.region,
      location: location ?? this.location,
      phone: phone ?? this.phone,
      email: email ?? this.email,
    );
  }
}
