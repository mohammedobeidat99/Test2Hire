
enum OfferStatus {
  pendingCandidate,
  accepted,
  declined,
  expired,
  withdrawn,
}

enum SalaryPeriod {
  monthly,
  annual,
}

extension OfferStatusX on OfferStatus {
  String toServerString() {
    switch (this) {
      case OfferStatus.pendingCandidate:
        return 'PENDING_CANDIDATE';
      case OfferStatus.accepted:
        return 'ACCEPTED';
      case OfferStatus.declined:
        return 'DECLINED';
      case OfferStatus.expired:
        return 'EXPIRED';
      case OfferStatus.withdrawn:
        return 'WITHDRAWN';
    }
  }

  static OfferStatus fromServerString(String? val) {
    switch (val?.toUpperCase()) {
      case 'ACCEPTED':
        return OfferStatus.accepted;
      case 'DECLINED':
        return OfferStatus.declined;
      case 'EXPIRED':
        return OfferStatus.expired;
      case 'WITHDRAWN':
        return OfferStatus.withdrawn;
      case 'PENDING_CANDIDATE':
      default:
        return OfferStatus.pendingCandidate;
    }
  }

  String get displayName {
    switch (this) {
      case OfferStatus.pendingCandidate:
        return 'Pending Decision';
      case OfferStatus.accepted:
        return 'Accepted';
      case OfferStatus.declined:
        return 'Declined';
      case OfferStatus.expired:
        return 'Expired';
      case OfferStatus.withdrawn:
        return 'Withdrawn';
    }
  }
}

extension SalaryPeriodX on SalaryPeriod {
  String toServerString() {
    switch (this) {
      case SalaryPeriod.monthly:
        return 'MONTHLY';
      case SalaryPeriod.annual:
        return 'ANNUAL';
    }
  }

  static SalaryPeriod fromServerString(String? val) {
    switch (val?.toUpperCase()) {
      case 'MONTHLY':
        return SalaryPeriod.monthly;
      case 'ANNUAL':
      default:
        return SalaryPeriod.annual;
    }
  }

  String get displayName {
    switch (this) {
      case SalaryPeriod.monthly:
        return '/ month';
      case SalaryPeriod.annual:
        return '/ year';
    }
  }
}

class JobOffer {
  final String id;
  final String applicationId;
  final String jobId;
  final String jobTitle;
  final String companyId;
  final String companyName;
  final String? companyLogoUrl;
  final String candidateId;
  final String candidateName;
  final String candidateEmail;
  final double offeredSalary;
  final String salaryCurrency;
  final SalaryPeriod salaryPeriod;
  final String? startDate;
  final DateTime? expiresAt;
  final List<String> benefits;
  final String termsAndNotes;
  final OfferStatus status;
  final String? declineReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const JobOffer({
    required this.id,
    required this.applicationId,
    required this.jobId,
    required this.jobTitle,
    required this.companyId,
    required this.companyName,
    this.companyLogoUrl,
    required this.candidateId,
    required this.candidateName,
    required this.candidateEmail,
    required this.offeredSalary,
    this.salaryCurrency = 'USD',
    this.salaryPeriod = SalaryPeriod.annual,
    this.startDate,
    this.expiresAt,
    this.benefits = const [],
    this.termsAndNotes = '',
    this.status = OfferStatus.pendingCandidate,
    this.declineReason,
    this.createdAt,
    this.updatedAt,
  });

  bool get isPending => status == OfferStatus.pendingCandidate;
  bool get isAccepted => status == OfferStatus.accepted;
  bool get isDeclined => status == OfferStatus.declined;
  bool get isWithdrawn => status == OfferStatus.withdrawn;
  bool get isExpired =>
      status == OfferStatus.expired ||
      (isPending && expiresAt != null && DateTime.now().isAfter(expiresAt!));

  String get formattedSalary {
    final formattedNum = offeredSalary.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return '$salaryCurrency $formattedNum ${salaryPeriod.displayName}';
  }

  JobOffer copyWith({
    String? id,
    String? applicationId,
    String? jobId,
    String? jobTitle,
    String? companyId,
    String? companyName,
    String? companyLogoUrl,
    String? candidateId,
    String? candidateName,
    String? candidateEmail,
    double? offeredSalary,
    String? salaryCurrency,
    SalaryPeriod? salaryPeriod,
    String? startDate,
    DateTime? expiresAt,
    List<String>? benefits,
    String? termsAndNotes,
    OfferStatus? status,
    String? declineReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return JobOffer(
      id: id ?? this.id,
      applicationId: applicationId ?? this.applicationId,
      jobId: jobId ?? this.jobId,
      jobTitle: jobTitle ?? this.jobTitle,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      companyLogoUrl: companyLogoUrl ?? this.companyLogoUrl,
      candidateId: candidateId ?? this.candidateId,
      candidateName: candidateName ?? this.candidateName,
      candidateEmail: candidateEmail ?? this.candidateEmail,
      offeredSalary: offeredSalary ?? this.offeredSalary,
      salaryCurrency: salaryCurrency ?? this.salaryCurrency,
      salaryPeriod: salaryPeriod ?? this.salaryPeriod,
      startDate: startDate ?? this.startDate,
      expiresAt: expiresAt ?? this.expiresAt,
      benefits: benefits ?? this.benefits,
      termsAndNotes: termsAndNotes ?? this.termsAndNotes,
      status: status ?? this.status,
      declineReason: declineReason ?? this.declineReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is JobOffer &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
