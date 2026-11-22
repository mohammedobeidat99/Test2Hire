class EducationItem {
  final String institution;
  final String degree;
  final String fieldOfStudy;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isCurrent;

  const EducationItem({
    required this.institution,
    required this.degree,
    required this.fieldOfStudy,
    required this.startDate,
    this.endDate,
    this.isCurrent = false,
  });
}

class ExperienceItem {
  final String company;
  final String title;
  final String? location;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isCurrent;
  final String? description;

  const ExperienceItem({
    required this.company,
    required this.title,
    this.location,
    required this.startDate,
    this.endDate,
    this.isCurrent = false,
    this.description,
  });
}

class CertificationItem {
  final String name;
  final String issuingOrganization;
  final DateTime issueDate;
  final String? credentialUrl;

  const CertificationItem({
    required this.name,
    required this.issuingOrganization,
    required this.issueDate,
    this.credentialUrl,
  });
}

enum LanguageProficiency {
  native,
  fluent,
  professional,
  intermediate,
  basic,
}

extension LanguageProficiencyExtension on LanguageProficiency {
  String toDisplayString() {
    switch (this) {
      case LanguageProficiency.native:
        return 'Native / Bilingual';
      case LanguageProficiency.fluent:
        return 'Fluent';
      case LanguageProficiency.professional:
        return 'Professional Working';
      case LanguageProficiency.intermediate:
        return 'Intermediate';
      case LanguageProficiency.basic:
        return 'Basic / Elementary';
    }
  }

  String localizedString(bool isArabic) {
    if (!isArabic) return toDisplayString();
    switch (this) {
      case LanguageProficiency.native:
        return 'اللغة الأم / ثنائي اللغة';
      case LanguageProficiency.fluent:
        return 'طلاقة تامة';
      case LanguageProficiency.professional:
        return 'مستوى احترافي للعمل';
      case LanguageProficiency.intermediate:
        return 'متوسط';
      case LanguageProficiency.basic:
        return 'أساسي / مبتدئ';
    }
  }

  static LanguageProficiency fromString(String val) {
    switch (val.toUpperCase()) {
      case 'NATIVE':
        return LanguageProficiency.native;
      case 'FLUENT':
        return LanguageProficiency.fluent;
      case 'PROFESSIONAL':
        return LanguageProficiency.professional;
      case 'INTERMEDIATE':
        return LanguageProficiency.intermediate;
      case 'BASIC':
      default:
        return LanguageProficiency.basic;
    }
  }
}

class LanguageItem {
  final String language;
  final LanguageProficiency proficiency;

  const LanguageItem({
    required this.language,
    required this.proficiency,
  });
}

class CandidateProfile {
  final String uid;
  final String email;
  final String fullName;
  final String? headline;
  final String? about;
  final String? phoneNumber;
  final String? location;
  final String? photoUrl;
  final List<String> skills;
  final List<EducationItem> education;
  final List<ExperienceItem> experience;
  final List<CertificationItem> certifications;
  final List<LanguageItem> languages;
  final String? cvUrl;
  final String? cvFileName;
  final bool isProfileComplete;
  final DateTime? updatedAt;

  const CandidateProfile({
    required this.uid,
    required this.email,
    required this.fullName,
    this.headline,
    this.about,
    this.phoneNumber,
    this.location,
    this.photoUrl,
    this.skills = const [],
    this.education = const [],
    this.experience = const [],
    this.certifications = const [],
    this.languages = const [],
    this.cvUrl,
    this.cvFileName,
    this.isProfileComplete = false,
    this.updatedAt,
  });

  /// Calculates profile completion percentage (0 - 100%).
  int get completionPercentage {
    int score = 0;
    // Basic info (20%)
    if (fullName.isNotEmpty && (headline?.isNotEmpty ?? false) && (about?.isNotEmpty ?? false)) {
      score += 20;
    } else if (fullName.isNotEmpty) {
      score += 10;
    }

    // Skills (20%)
    if (skills.length >= 3) {
      score += 20;
    } else if (skills.isNotEmpty) {
      score += 10;
    }

    // Education (15%)
    if (education.isNotEmpty) {
      score += 15;
    }

    // Work Experience (15%)
    if (experience.isNotEmpty) {
      score += 15;
    }

    // CV Upload (20%)
    if (cvUrl != null && cvUrl!.isNotEmpty) {
      score += 20;
    }

    // Certifications or Languages (10%)
    if (certifications.isNotEmpty || languages.isNotEmpty) {
      score += 10;
    }

    return score.clamp(0, 100);
  }
}
