import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/candidate_profile.dart';

class CandidateProfileModel extends CandidateProfile {
  const CandidateProfileModel({
    required super.uid,
    required super.email,
    required super.fullName,
    super.headline,
    super.about,
    super.phoneNumber,
    super.location,
    super.photoUrl,
    super.skills = const [],
    super.education = const [],
    super.experience = const [],
    super.certifications = const [],
    super.languages = const [],
    super.cvUrl,
    super.cvFileName,
    super.isProfileComplete = false,
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

  static String? _parseLocation(dynamic val) {
    if (val is String) return val;
    if (val is Map) {
      final map = Map<String, dynamic>.from(val);
      final city = map['city']?.toString().trim() ?? '';
      final country = map['country']?.toString().trim() ?? '';
      final combined = [city, country].where((s) => s.isNotEmpty).join(', ');
      return combined.isNotEmpty ? combined : null;
    }
    return null;
  }

  factory CandidateProfileModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};

    return CandidateProfileModel(
      uid: doc.id,
      email: data['email'] as String? ?? '',
      fullName: data['fullName'] as String? ?? '',
      headline: data['headline'] as String?,
      about: data['about'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      location: _parseLocation(data['location']),
      photoUrl: data['photoUrl'] as String?,
      skills: (data['skills'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      education: (data['education'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) {
            final item = Map<String, dynamic>.from(e);
            return EducationItem(
              institution: item['institution'] as String? ?? '',
              degree: item['degree'] as String? ?? '',
              fieldOfStudy: item['fieldOfStudy'] as String? ?? '',
              startDate: _parseDateTime(item['startDate']) ?? DateTime.now(),
              endDate: _parseDateTime(item['endDate']),
              isCurrent: item['isCurrent'] as bool? ?? false,
            );
          }).toList() ??
          [],
      experience: (data['experience'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) {
            final item = Map<String, dynamic>.from(e);
            return ExperienceItem(
              company: item['company'] as String? ?? '',
              title: item['title'] as String? ?? '',
              location: _parseLocation(item['location']),
              startDate: _parseDateTime(item['startDate']) ?? DateTime.now(),
              endDate: _parseDateTime(item['endDate']),
              isCurrent: item['isCurrent'] as bool? ?? false,
              description: item['description'] as String?,
            );
          }).toList() ??
          [],
      certifications: (data['certifications'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) {
            final item = Map<String, dynamic>.from(e);
            return CertificationItem(
              name: item['name'] as String? ?? '',
              issuingOrganization: item['issuingOrganization'] as String? ?? '',
              issueDate: _parseDateTime(item['issueDate']) ?? DateTime.now(),
              credentialUrl: item['credentialUrl'] as String?,
            );
          }).toList() ??
          [],
      languages: (data['languages'] as List<dynamic>?)
              ?.whereType<Map>()
              .map((e) {
            final item = Map<String, dynamic>.from(e);
            return LanguageItem(
              language: item['language'] as String? ?? '',
              proficiency: LanguageProficiencyExtension.fromString(
                item['proficiency'] as String? ?? 'BASIC',
              ),
            );
          }).toList() ??
          [],
      cvUrl: data['cvUrl'] as String?,
      cvFileName: data['cvFileName'] as String?,
      isProfileComplete: data['isProfileComplete'] as bool? ?? false,
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fullName': fullName,
      'headline': headline,
      'about': about,
      'phoneNumber': phoneNumber,
      'location': location,
      'photoUrl': photoUrl,
      'skills': skills,
      'education': education
          .map((e) => {
                'institution': e.institution,
                'degree': e.degree,
                'fieldOfStudy': e.fieldOfStudy,
                'startDate': Timestamp.fromDate(e.startDate),
                'endDate': e.endDate != null ? Timestamp.fromDate(e.endDate!) : null,
                'isCurrent': e.isCurrent,
              })
          .toList(),
      'experience': experience
          .map((e) => {
                'company': e.company,
                'title': e.title,
                'location': e.location,
                'startDate': Timestamp.fromDate(e.startDate),
                'endDate': e.endDate != null ? Timestamp.fromDate(e.endDate!) : null,
                'isCurrent': e.isCurrent,
                'description': e.description,
              })
          .toList(),
      'certifications': certifications
          .map((e) => {
                'name': e.name,
                'issuingOrganization': e.issuingOrganization,
                'issueDate': Timestamp.fromDate(e.issueDate),
                'credentialUrl': e.credentialUrl,
              })
          .toList(),
      'languages': languages
          .map((e) => {
                'language': e.language,
                'proficiency': e.proficiency.name.toUpperCase(),
              })
          .toList(),
      'cvUrl': cvUrl,
      'cvFileName': cvFileName,
      'isProfileComplete': completionPercentage >= 70,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
