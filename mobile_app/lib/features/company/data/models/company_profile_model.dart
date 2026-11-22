import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/company_profile.dart';

class CompanyProfileModel extends CompanyProfile {
  const CompanyProfileModel({
    required super.id,
    required super.ownerUid,
    required super.name,
    super.legalName,
    required super.industry,
    super.website,
    super.logoUrl,
    super.coverUrl,
    super.description = '',
    super.location,
    required super.contactEmail,
    super.contactPhone,
    super.teamSize,
    super.verificationStatus = CompanyVerificationStatus.pending,
    super.verificationNotes,
    super.verifiedAt,
    super.createdAt,
    super.updatedAt,
  });

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  factory CompanyProfileModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    CompanyLocation? loc;
    final rawLoc = data['location'];
    if (rawLoc is Map) {
      final lMap = Map<String, dynamic>.from(rawLoc);
      loc = CompanyLocation(
        city: lMap['city'] as String? ?? data['city'] as String? ?? '',
        country: lMap['country'] as String? ?? data['country'] as String? ?? '',
        address: lMap['address'] as String?,
      );
    } else if (rawLoc is String && rawLoc.trim().isNotEmpty) {
      final parts = rawLoc.split(',');
      loc = CompanyLocation(
        city: data['city'] as String? ?? parts.first.trim(),
        country: data['country'] as String? ??
            (parts.length > 1 ? parts.sublist(1).join(',').trim() : ''),
      );
    } else if ((data['city'] as String?)?.isNotEmpty == true ||
        (data['country'] as String?)?.isNotEmpty == true) {
      loc = CompanyLocation(
        city: data['city'] as String? ?? '',
        country: data['country'] as String? ?? '',
      );
    }

    return CompanyProfileModel(
      id: doc.id,
      ownerUid: data['ownerUid'] as String? ?? doc.id,
      name: data['name'] as String? ?? '',
      legalName: data['legalName'] as String?,
      industry: data['industry'] as String? ?? 'Technology',
      website: data['website'] as String?,
      logoUrl: data['logoUrl'] as String?,
      coverUrl: data['coverUrl'] as String?,
      description: data['description'] as String? ?? '',
      location: loc,
      contactEmail: data['contactEmail'] as String? ?? '',
      contactPhone: data['contactPhone'] as String?,
      teamSize: data['teamSize'] as String? ?? data['size'] as String?,
      verificationStatus: CompanyVerificationStatusExtension.fromString(
        data['verificationStatus'] as String? ?? 'PENDING',
      ),
      verificationNotes: data['verificationNotes'] as String?,
      verifiedAt: _parseDateTime(data['verifiedAt']),
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'legalName': legalName,
      'industry': industry,
      'website': website,
      'description': description,
      'contactPhone': contactPhone,
      'teamSize': teamSize,
      'location': location != null
          ? {
              'city': location!.city,
              'country': location!.country,
              'address': location!.address,
            }
          : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
