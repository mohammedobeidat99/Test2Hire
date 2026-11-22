import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/job_posting.dart';

class JobPostingModel extends JobPosting {
  const JobPostingModel({
    required super.id,
    required super.companyId,
    required super.companyName,
    super.companyLogoUrl,
    required super.title,
    required super.description,
    super.requirements = const [],
    super.responsibilities = const [],
    super.benefits = const [],
    super.jobType = JobType.fullTime,
    super.workplaceType = WorkplaceType.onSite,
    super.experienceLevel = ExperienceLevel.mid,
    required super.location,
    super.salaryRange,
    super.requiredSkills = const [],
    super.optionalSkills = const [],
    super.status = JobStatus.draft,
    super.deadline,
    super.applicantsCount = 0,
    super.examId,
    super.createdAt,
    super.updatedAt,
  });

  factory JobPostingModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return JobPostingModel.fromMap(doc.data() ?? {}, doc.id);
  }

  static DateTime? _parseDateTime(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val);
    return null;
  }

  factory JobPostingModel.fromMap(Map<String, dynamic> data, String id) {
    // Location
    JobLocation loc;
    if (data['location'] is Map) {
      final locData = Map<String, dynamic>.from(data['location'] as Map);
      loc = JobLocation(
        city: locData['city'] as String? ?? '',
        country: locData['country'] as String? ?? '',
      );
    } else if (data['location'] is String && (data['location'] as String).isNotEmpty) {
      final locStr = data['location'] as String;
      final parts = locStr.split(',');
      loc = JobLocation(
        city: parts[0].trim(),
        country: parts.length > 1 ? parts.sublist(1).join(',').trim() : '',
      );
    } else {
      loc = const JobLocation(city: '', country: '');
    }

    // Salary Range
    JobSalaryRange? salary;
    if (data['salaryRange'] != null && data['salaryRange'] is Map) {
      final sData = Map<String, dynamic>.from(data['salaryRange'] as Map);
      salary = JobSalaryRange(
        min: (sData['min'] as num?)?.toDouble(),
        max: (sData['max'] as num?)?.toDouble(),
        currency: sData['currency'] as String? ?? 'USD',
        isNegotiable: sData['isNegotiable'] as bool? ?? false,
        isDisclosed: sData['isDisclosed'] as bool? ?? true,
      );
    }

    final rawJobType = data['jobType'] as String? ?? data['type'] as String? ?? 'FULL_TIME';

    return JobPostingModel(
      id: id,
      companyId: data['companyId'] as String? ?? '',
      companyName: data['companyName'] as String? ?? '',
      companyLogoUrl: data['companyLogoUrl'] as String?,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      requirements: (data['requirements'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      responsibilities: (data['responsibilities'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      benefits: (data['benefits'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      jobType: JobTypeExtension.fromString(rawJobType),
      workplaceType: WorkplaceTypeExtension.fromString(
          data['workplaceType'] as String? ?? 'ON_SITE'),
      experienceLevel: ExperienceLevelExtension.fromString(
          data['experienceLevel'] as String? ?? 'MID'),
      location: loc,
      salaryRange: salary,
      requiredSkills: (data['requiredSkills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      optionalSkills: (data['optionalSkills'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      status: JobStatusExtension.fromString(data['status'] as String? ?? 'DRAFT'),
      deadline: _parseDateTime(data['deadline']),
      applicantsCount: (data['applicantsCount'] as num?)?.toInt() ?? 0,
      examId: data['examId'] as String?,
      createdAt: _parseDateTime(data['createdAt']),
      updatedAt: _parseDateTime(data['updatedAt']),
    );
  }

  factory JobPostingModel.fromDomain(JobPosting job) {
    return JobPostingModel(
      id: job.id,
      companyId: job.companyId,
      companyName: job.companyName,
      companyLogoUrl: job.companyLogoUrl,
      title: job.title,
      description: job.description,
      requirements: job.requirements,
      responsibilities: job.responsibilities,
      benefits: job.benefits,
      jobType: job.jobType,
      workplaceType: job.workplaceType,
      experienceLevel: job.experienceLevel,
      location: job.location,
      salaryRange: job.salaryRange,
      requiredSkills: job.requiredSkills,
      optionalSkills: job.optionalSkills,
      status: job.status,
      deadline: job.deadline,
      applicantsCount: job.applicantsCount,
      examId: job.examId,
      createdAt: job.createdAt,
      updatedAt: job.updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'companyId': companyId,
      'companyName': companyName,
      'companyLogoUrl': companyLogoUrl,
      'title': title,
      'description': description,
      'requirements': requirements,
      'responsibilities': responsibilities,
      'benefits': benefits,
      'jobType': jobType.toShortString(),
      'workplaceType': workplaceType.toShortString(),
      'experienceLevel': experienceLevel.toShortString(),
      'location': {
        'city': location.city,
        'country': location.country,
      },
      'salaryRange': salaryRange != null
          ? {
              'min': salaryRange!.min,
              'max': salaryRange!.max,
              'currency': salaryRange!.currency,
              'isNegotiable': salaryRange!.isNegotiable,
              'isDisclosed': salaryRange!.isDisclosed,
            }
          : null,
      'requiredSkills': requiredSkills,
      'optionalSkills': optionalSkills,
      'status': status.toShortString(),
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'applicantsCount': applicantsCount,
      'examId': examId,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
