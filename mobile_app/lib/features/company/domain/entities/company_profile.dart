enum CompanyVerificationStatus {
  pending,
  approved,
  rejected,
  suspended,
}

extension CompanyVerificationStatusExtension on CompanyVerificationStatus {
  String toShortString() {
    switch (this) {
      case CompanyVerificationStatus.pending:
        return 'PENDING';
      case CompanyVerificationStatus.approved:
        return 'APPROVED';
      case CompanyVerificationStatus.rejected:
        return 'REJECTED';
      case CompanyVerificationStatus.suspended:
        return 'SUSPENDED';
    }
  }

  static CompanyVerificationStatus fromString(String status) {
    switch (status.toUpperCase()) {
      case 'APPROVED':
        return CompanyVerificationStatus.approved;
      case 'REJECTED':
        return CompanyVerificationStatus.rejected;
      case 'SUSPENDED':
        return CompanyVerificationStatus.suspended;
      case 'PENDING':
      default:
        return CompanyVerificationStatus.pending;
    }
  }
}

class CompanyLocation {
  final String city;
  final String country;
  final String? address;

  const CompanyLocation({
    required this.city,
    required this.country,
    this.address,
  });

  String get formatted => address != null && address!.isNotEmpty
      ? '$address, $city, $country'
      : '$city, $country';
}

class CompanyProfile {
  final String id;
  final String ownerUid;
  final String name;
  final String? legalName;
  final String industry;
  final String? website;
  final String? logoUrl;
  final String? coverUrl;
  final String description;
  final CompanyLocation? location;
  final String contactEmail;
  final String? contactPhone;
  final String? teamSize;
  final CompanyVerificationStatus verificationStatus;
  final String? verificationNotes;
  final DateTime? verifiedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const CompanyProfile({
    required this.id,
    required this.ownerUid,
    required this.name,
    this.legalName,
    required this.industry,
    this.website,
    this.logoUrl,
    this.coverUrl,
    this.description = '',
    this.location,
    required this.contactEmail,
    this.contactPhone,
    this.teamSize,
    this.verificationStatus = CompanyVerificationStatus.pending,
    this.verificationNotes,
    this.verifiedAt,
    this.createdAt,
    this.updatedAt,
  });

  bool get isApproved => verificationStatus == CompanyVerificationStatus.approved;
  bool get isPending => verificationStatus == CompanyVerificationStatus.pending;
  bool get isRejected => verificationStatus == CompanyVerificationStatus.rejected;
  bool get isSuspended => verificationStatus == CompanyVerificationStatus.suspended;
}
