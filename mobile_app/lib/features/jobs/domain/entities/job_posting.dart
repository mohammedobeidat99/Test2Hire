enum JobType {
  fullTime,
  partTime,
  contract,
  internship,
  remote,
}

extension JobTypeExtension on JobType {
  String toShortString() {
    switch (this) {
      case JobType.fullTime:
        return 'FULL_TIME';
      case JobType.partTime:
        return 'PART_TIME';
      case JobType.contract:
        return 'CONTRACT';
      case JobType.internship:
        return 'INTERNSHIP';
      case JobType.remote:
        return 'REMOTE';
    }
  }

  String get displayName {
    switch (this) {
      case JobType.fullTime:
        return 'Full Time';
      case JobType.partTime:
        return 'Part Time';
      case JobType.contract:
        return 'Contract';
      case JobType.internship:
        return 'Internship';
      case JobType.remote:
        return 'Remote';
    }
  }

  String localizedName(bool isArabic) {
    if (!isArabic) return displayName;
    switch (this) {
      case JobType.fullTime:
        return 'دوام كامل';
      case JobType.partTime:
        return 'دوام جزئي';
      case JobType.contract:
        return 'عقد محدد';
      case JobType.internship:
        return 'تدريب عملي';
      case JobType.remote:
        return 'عن بُعد';
    }
  }

  static JobType fromString(String val) {
    switch (val.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_')) {
      case 'FULL_TIME':
      case 'FULLTIME':
        return JobType.fullTime;
      case 'PART_TIME':
      case 'PARTTIME':
        return JobType.partTime;
      case 'CONTRACT':
        return JobType.contract;
      case 'INTERNSHIP':
        return JobType.internship;
      case 'REMOTE':
        return JobType.remote;
      default:
        return JobType.fullTime;
    }
  }
}

enum WorkplaceType {
  onSite,
  hybrid,
  remote,
}

extension WorkplaceTypeExtension on WorkplaceType {
  String toShortString() {
    switch (this) {
      case WorkplaceType.onSite:
        return 'ON_SITE';
      case WorkplaceType.hybrid:
        return 'HYBRID';
      case WorkplaceType.remote:
        return 'REMOTE';
    }
  }

  String get displayName {
    switch (this) {
      case WorkplaceType.onSite:
        return 'On-Site';
      case WorkplaceType.hybrid:
        return 'Hybrid';
      case WorkplaceType.remote:
        return 'Remote';
    }
  }

  String localizedName(bool isArabic) {
    if (!isArabic) return displayName;
    switch (this) {
      case WorkplaceType.onSite:
        return 'حضوري';
      case WorkplaceType.hybrid:
        return 'هجين';
      case WorkplaceType.remote:
        return 'عن بُعد';
    }
  }

  static WorkplaceType fromString(String val) {
    switch (val.toUpperCase().replaceAll('-', '_').replaceAll(' ', '_')) {
      case 'ON_SITE':
      case 'ONSITE':
        return WorkplaceType.onSite;
      case 'HYBRID':
        return WorkplaceType.hybrid;
      case 'REMOTE':
        return WorkplaceType.remote;
      default:
        return WorkplaceType.onSite;
    }
  }
}

enum ExperienceLevel {
  entry,
  mid,
  senior,
  lead,
  executive,
}

extension ExperienceLevelExtension on ExperienceLevel {
  String toShortString() {
    switch (this) {
      case ExperienceLevel.entry:
        return 'ENTRY';
      case ExperienceLevel.mid:
        return 'MID';
      case ExperienceLevel.senior:
        return 'SENIOR';
      case ExperienceLevel.lead:
        return 'LEAD';
      case ExperienceLevel.executive:
        return 'EXECUTIVE';
    }
  }

  String get displayName {
    switch (this) {
      case ExperienceLevel.entry:
        return 'Entry Level (0-2 yrs)';
      case ExperienceLevel.mid:
        return 'Mid Level (2-5 yrs)';
      case ExperienceLevel.senior:
        return 'Senior Level (5+ yrs)';
      case ExperienceLevel.lead:
        return 'Team Lead / Tech Lead';
      case ExperienceLevel.executive:
        return 'Executive / Director';
    }
  }

  String localizedName(bool isArabic) {
    if (!isArabic) return displayName;
    switch (this) {
      case ExperienceLevel.entry:
        return 'مبتدئ (0-2 سنة)';
      case ExperienceLevel.mid:
        return 'متوسط (2-5 سنوات)';
      case ExperienceLevel.senior:
        return 'متقدم (5+ سنوات)';
      case ExperienceLevel.lead:
        return 'قائد تقني / فريق';
      case ExperienceLevel.executive:
        return 'مدير تنفيذي';
    }
  }

  static ExperienceLevel fromString(String val) {
    switch (val.toUpperCase()) {
      case 'ENTRY':
        return ExperienceLevel.entry;
      case 'MID':
        return ExperienceLevel.mid;
      case 'SENIOR':
        return ExperienceLevel.senior;
      case 'LEAD':
        return ExperienceLevel.lead;
      case 'EXECUTIVE':
        return ExperienceLevel.executive;
      default:
        return ExperienceLevel.mid;
    }
  }
}

enum JobStatus {
  draft,
  published,
  closed,
  archived,
}

extension JobStatusExtension on JobStatus {
  String toShortString() {
    switch (this) {
      case JobStatus.draft:
        return 'DRAFT';
      case JobStatus.published:
        return 'PUBLISHED';
      case JobStatus.closed:
        return 'CLOSED';
      case JobStatus.archived:
        return 'ARCHIVED';
    }
  }

  String get displayName {
    switch (this) {
      case JobStatus.draft:
        return 'Draft';
      case JobStatus.published:
        return 'Published';
      case JobStatus.closed:
        return 'Closed';
      case JobStatus.archived:
        return 'Archived';
    }
  }

  static JobStatus fromString(String val) {
    switch (val.toUpperCase()) {
      case 'PUBLISHED':
      case 'OPEN':
        return JobStatus.published;
      case 'CLOSED':
        return JobStatus.closed;
      case 'ARCHIVED':
        return JobStatus.archived;
      case 'DRAFT':
      default:
        return JobStatus.draft;
    }
  }
}

class JobLocation {
  final String city;
  final String country;

  const JobLocation({
    required this.city,
    required this.country,
  });

  String get formatted => city.isNotEmpty ? '$city, $country' : country;
}

class JobSalaryRange {
  final double? min;
  final double? max;
  final String currency;
  final bool isNegotiable;
  final bool isDisclosed;

  const JobSalaryRange({
    this.min,
    this.max,
    this.currency = 'USD',
    this.isNegotiable = false,
    this.isDisclosed = true,
  });

  String get formatted {
    if (!isDisclosed) return 'Confidential';
    if (min != null && max != null) {
      return '${min!.toStringAsFixed(0)} - ${max!.toStringAsFixed(0)} $currency';
    }
    if (min != null) return 'From ${min!.toStringAsFixed(0)} $currency';
    if (max != null) return 'Up to ${max!.toStringAsFixed(0)} $currency';
    if (isNegotiable) return 'Negotiable';
    return 'Competitive';
  }
}

class JobPosting {
  final String id;
  final String companyId;
  final String companyName;
  final String? companyLogoUrl;
  final String title;
  final String description;
  final List<String> requirements;
  final List<String> responsibilities;
  final List<String> benefits;
  final JobType jobType;
  final WorkplaceType workplaceType;
  final ExperienceLevel experienceLevel;
  final JobLocation location;
  final JobSalaryRange? salaryRange;
  final List<String> requiredSkills;
  final List<String> optionalSkills;
  final JobStatus status;
  final DateTime? deadline;
  final int applicantsCount;
  final String? examId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const JobPosting({
    required this.id,
    required this.companyId,
    required this.companyName,
    this.companyLogoUrl,
    required this.title,
    required this.description,
    this.requirements = const [],
    this.responsibilities = const [],
    this.benefits = const [],
    this.jobType = JobType.fullTime,
    this.workplaceType = WorkplaceType.onSite,
    this.experienceLevel = ExperienceLevel.mid,
    required this.location,
    this.salaryRange,
    this.requiredSkills = const [],
    this.optionalSkills = const [],
    this.status = JobStatus.draft,
    this.deadline,
    this.applicantsCount = 0,
    this.examId,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPublished => status == JobStatus.published;
  bool get isDraft => status == JobStatus.draft;
  bool get isClosed => status == JobStatus.closed;
  bool get isArchived => status == JobStatus.archived;
  bool get hasExpired => deadline != null && deadline!.isBefore(DateTime.now());

  JobPosting copyWith({
    String? id,
    String? companyId,
    String? companyName,
    String? companyLogoUrl,
    String? title,
    String? description,
    List<String>? requirements,
    List<String>? responsibilities,
    List<String>? benefits,
    JobType? jobType,
    WorkplaceType? workplaceType,
    ExperienceLevel? experienceLevel,
    JobLocation? location,
    JobSalaryRange? salaryRange,
    List<String>? requiredSkills,
    List<String>? optionalSkills,
    JobStatus? status,
    DateTime? deadline,
    int? applicantsCount,
    String? examId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JobPosting(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
      title: title ?? this.title,
      description: description ?? this.description,
      requirements: requirements ?? this.requirements,
      responsibilities: responsibilities ?? this.responsibilities,
      benefits: benefits ?? this.benefits,
      jobType: jobType ?? this.jobType,
      workplaceType: workplaceType ?? this.workplaceType,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      location: location ?? this.location,
      salaryRange: salaryRange ?? this.salaryRange,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      optionalSkills: optionalSkills ?? this.optionalSkills,
      status: status ?? this.status,
      deadline: deadline ?? this.deadline,
      applicantsCount: applicantsCount ?? this.applicantsCount,
      examId: examId ?? this.examId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
