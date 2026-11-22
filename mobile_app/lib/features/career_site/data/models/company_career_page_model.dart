import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/company_career_page.dart';

class CompanyCareerPageModel extends CompanyCareerPage {
  const CompanyCareerPageModel({
    required super.companyId,
    required super.companyName,
    super.logoUrl,
    required super.industry,
    required super.description,
    required super.location,
    super.branding,
    super.activeJobsCount = 0,
    super.isApproved = true,
  });

  factory CompanyCareerPageModel.fromFirestore(DocumentSnapshot doc, [int activeJobs = 0]) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return CompanyCareerPageModel.fromMap(data, doc.id, activeJobs);
  }

  factory CompanyCareerPageModel.fromMap(Map<String, dynamic> data, [String? id, int activeJobs = 0]) {
    final locationData = data['location'];
    String locString = '';
    if (locationData is Map) {
      final locMap = Map<String, dynamic>.from(locationData);
      final city = (locMap['city'] ?? '').toString().trim();
      final country = (locMap['country'] ?? '').toString().trim();
      locString = [city, country].where((s) => s.isNotEmpty).join(', ');
    } else if (locationData is String && locationData.trim().isNotEmpty) {
      locString = locationData.trim();
    }
    if (locString.isEmpty) {
      final flatCity = (data['city'] ?? '').toString().trim();
      final flatCountry = (data['country'] ?? '').toString().trim();
      locString = [flatCity, flatCountry].where((s) => s.isNotEmpty).join(', ');
    }

    final brandingData = data['branding'] is Map
        ? Map<String, dynamic>.from(data['branding'] as Map)
        : null;
    var branding = CompanyBranding.fromMap(brandingData);
    if ((branding.websiteUrl == null || branding.websiteUrl!.isEmpty) &&
        data['website'] is String &&
        (data['website'] as String).isNotEmpty) {
      branding = branding.copyWith(websiteUrl: data['website'] as String);
    }
    if ((branding.coverImageUrl == null || branding.coverImageUrl!.isEmpty) &&
        data['coverImageUrl'] is String &&
        (data['coverImageUrl'] as String).isNotEmpty) {
      branding = branding.copyWith(coverImageUrl: data['coverImageUrl'] as String);
    }

    final rawStatus = (data['verificationStatus'] ?? data['status'] ?? 'PENDING')
        .toString()
        .toUpperCase();

    return CompanyCareerPageModel(
      companyId: id ?? data['id'] ?? '',
      companyName: data['name'] ?? data['companyName'] ?? 'Verified Company',
      logoUrl: data['logoUrl'] as String?,
      industry: data['industry'] ?? 'Technology & Enterprise',
      description: data['description'] ?? '',
      location: locString.isNotEmpty ? locString : 'Remote / Global',
      branding: branding,
      activeJobsCount: activeJobs,
      isApproved: rawStatus == 'APPROVED',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyId': companyId,
      'companyName': companyName,
      'logoUrl': logoUrl,
      'industry': industry,
      'description': description,
      'location': location,
      'branding': branding.toMap(),
      'isApproved': isApproved,
    };
  }
}
