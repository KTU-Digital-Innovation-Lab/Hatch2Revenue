class FarmProfile {
  final String farmName;
  final String ownerName;
  final String location;
  final String phone;
  final String email;
  final String farmSize;

  const FarmProfile({
    this.farmName = '',
    this.ownerName = '',
    this.location = '',
    this.phone = '',
    this.email = '',
    this.farmSize = '',
  });

  FarmProfile copyWith({
    String? farmName,
    String? ownerName,
    String? location,
    String? phone,
    String? email,
    String? farmSize,
  }) {
    return FarmProfile(
      farmName: farmName ?? this.farmName,
      ownerName: ownerName ?? this.ownerName,
      location: location ?? this.location,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      farmSize: farmSize ?? this.farmSize,
    );
  }
}
