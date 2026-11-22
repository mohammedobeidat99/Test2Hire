enum InterviewType {
  videoCall,
  inPerson,
  phone,
}

extension InterviewTypeExtension on InterviewType {
  String toShortString() {
    switch (this) {
      case InterviewType.videoCall:
        return 'VIDEO_CALL';
      case InterviewType.inPerson:
        return 'IN_PERSON';
      case InterviewType.phone:
        return 'PHONE';
    }
  }

  String get displayName {
    switch (this) {
      case InterviewType.videoCall:
        return 'Video Call';
      case InterviewType.inPerson:
        return 'In Person';
      case InterviewType.phone:
        return 'Phone Screen';
    }
  }

  static InterviewType fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'IN_PERSON':
        return InterviewType.inPerson;
      case 'PHONE':
        return InterviewType.phone;
      case 'VIDEO_CALL':
      default:
        return InterviewType.videoCall;
    }
  }
}

enum InterviewStatus {
  pendingCandidate,
  confirmed,
  completed,
  cancelled,
  declined,
}

extension InterviewStatusExtension on InterviewStatus {
  String toShortString() {
    switch (this) {
      case InterviewStatus.pendingCandidate:
        return 'PENDING_CANDIDATE';
      case InterviewStatus.confirmed:
        return 'CONFIRMED';
      case InterviewStatus.completed:
        return 'COMPLETED';
      case InterviewStatus.cancelled:
        return 'CANCELLED';
      case InterviewStatus.declined:
        return 'DECLINED';
    }
  }

  String get displayName {
    switch (this) {
      case InterviewStatus.pendingCandidate:
        return 'Pending RSVP';
      case InterviewStatus.confirmed:
        return 'Confirmed';
      case InterviewStatus.completed:
        return 'Completed';
      case InterviewStatus.cancelled:
        return 'Cancelled';
      case InterviewStatus.declined:
        return 'Declined';
    }
  }

  static InterviewStatus fromString(String? val) {
    switch (val?.toUpperCase()) {
      case 'CONFIRMED':
        return InterviewStatus.confirmed;
      case 'COMPLETED':
        return InterviewStatus.completed;
      case 'CANCELLED':
        return InterviewStatus.cancelled;
      case 'DECLINED':
        return InterviewStatus.declined;
      case 'PENDING_CANDIDATE':
      default:
        return InterviewStatus.pendingCandidate;
    }
  }
}

DateTime? _parseInterviewDate(dynamic val) {
  if (val == null) return null;
  if (val is DateTime) return val.toLocal();
  if (val is int) return DateTime.fromMillisecondsSinceEpoch(val).toLocal();
  try {
    final dynamic dyn = val;
    final converted = dyn.toDate();
    if (converted is DateTime) return converted.toLocal();
  } catch (_) {}
  final parsed = DateTime.tryParse(val.toString());
  return parsed?.toLocal();
}

class InterviewSlot {
  final int slotIndex;
  final DateTime startTime;
  final DateTime endTime;
  final bool isSelected;

  const InterviewSlot({
    required this.slotIndex,
    required this.startTime,
    required this.endTime,
    this.isSelected = false,
  });

  factory InterviewSlot.fromMap(Map<String, dynamic> map, int index) {
    return InterviewSlot(
      slotIndex: (map['slotIndex'] as num?)?.toInt() ?? index,
      startTime: _parseInterviewDate(map['startTime']) ?? DateTime.now(),
      endTime: _parseInterviewDate(map['endTime']) ?? DateTime.now(),
      isSelected: map['isSelected'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'slotIndex': slotIndex,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'isSelected': isSelected,
    };
  }

  InterviewSlot copyWith({
    int? slotIndex,
    DateTime? startTime,
    DateTime? endTime,
    bool? isSelected,
  }) {
    return InterviewSlot(
      slotIndex: slotIndex ?? this.slotIndex,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

class InterviewFeedback {
  final String interviewerId;
  final int score;
  final String recommendation; // RECOMMEND_HIRE, NEUTRAL, DO_NOT_HIRE
  final String notes;
  final DateTime? submittedAt;

  const InterviewFeedback({
    required this.interviewerId,
    required this.score,
    required this.recommendation,
    required this.notes,
    this.submittedAt,
  });

  factory InterviewFeedback.fromMap(Map<String, dynamic> map) {
    return InterviewFeedback(
      interviewerId: map['interviewerId'] as String? ?? '',
      score: (map['score'] as num?)?.toInt() ?? 0,
      recommendation: map['recommendation'] as String? ?? 'NEUTRAL',
      notes: map['notes'] as String? ?? '',
      submittedAt: _parseInterviewDate(map['submittedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'interviewerId': interviewerId,
      'score': score,
      'recommendation': recommendation,
      'notes': notes,
      'submittedAt': submittedAt?.toIso8601String(),
    };
  }
}

class Interview {
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
  final String title;
  final String description;
  final InterviewType type;
  final InterviewStatus status;
  final String? meetingUrl;
  final String? location;
  final List<InterviewSlot> slots;
  final int? selectedSlotIndex;
  final List<String> interviewerNames;
  final InterviewFeedback? feedback;
  final String? declineReason;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Interview({
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
    required this.title,
    this.description = '',
    this.type = InterviewType.videoCall,
    this.status = InterviewStatus.pendingCandidate,
    this.meetingUrl,
    this.location,
    this.slots = const [],
    this.selectedSlotIndex,
    this.interviewerNames = const [],
    this.feedback,
    this.declineReason,
    this.createdAt,
    this.updatedAt,
  });

  InterviewSlot? get activeSlot {
    final idx = selectedSlotIndex;
    if (idx != null && idx >= 0 && idx < slots.length) {
      return slots[idx];
    }
    if (slots.isNotEmpty) return slots.first;
    return null;
  }

  bool get isConfirmed => status == InterviewStatus.confirmed;
  bool get isPendingCandidate => status == InterviewStatus.pendingCandidate;
  bool get isCompleted => status == InterviewStatus.completed;
  bool get isCancelled => status == InterviewStatus.cancelled;
  bool get isDeclined => status == InterviewStatus.declined;

  Interview copyWith({
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
    String? title,
    String? description,
    InterviewType? type,
    InterviewStatus? status,
    String? meetingUrl,
    String? location,
    List<InterviewSlot>? slots,
    int? selectedSlotIndex,
    List<String>? interviewerNames,
    InterviewFeedback? feedback,
    String? declineReason,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Interview(
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
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      status: status ?? this.status,
      meetingUrl: meetingUrl ?? this.meetingUrl,
      location: location ?? this.location,
      slots: slots ?? this.slots,
      selectedSlotIndex: selectedSlotIndex ?? this.selectedSlotIndex,
      interviewerNames: interviewerNames ?? this.interviewerNames,
      feedback: feedback ?? this.feedback,
      declineReason: declineReason ?? this.declineReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
