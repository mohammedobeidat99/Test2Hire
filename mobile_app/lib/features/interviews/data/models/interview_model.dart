import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/interview.dart';

class InterviewModel extends Interview {
  const InterviewModel({
    required super.id,
    required super.applicationId,
    required super.jobId,
    required super.jobTitle,
    required super.companyId,
    required super.companyName,
    super.companyLogoUrl,
    required super.candidateId,
    required super.candidateName,
    required super.candidateEmail,
    required super.title,
    super.description,
    super.type,
    super.status,
    super.meetingUrl,
    super.location,
    super.slots,
    super.selectedSlotIndex,
    super.interviewerNames,
    super.feedback,
    super.declineReason,
    super.createdAt,
    super.updatedAt,
  });

  factory InterviewModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    return InterviewModel.fromMap(doc.data() ?? {}, doc.id);
  }

  factory InterviewModel.fromMap(Map<String, dynamic> data, String id) {
    DateTime? parseTimestamp(dynamic val) {
      if (val is Timestamp) return val.toDate().toLocal();
      if (val is DateTime) return val.toLocal();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val).toLocal();
      if (val != null) return DateTime.tryParse(val.toString())?.toLocal();
      return null;
    }

    final rawSlots = data['slots'];
    final List<InterviewSlot> slotsList = [];
    if (rawSlots is List) {
      for (int i = 0; i < rawSlots.length; i++) {
        final item = rawSlots[i];
        if (item is Map) {
          slotsList.add(InterviewSlot.fromMap(Map<String, dynamic>.from(item), i));
        }
      }
    }
    if (slotsList.isEmpty && data['scheduledAt'] != null) {
      final scheduled = parseTimestamp(data['scheduledAt']);
      if (scheduled != null) {
        final durationMins = (data['durationMinutes'] as num?)?.toInt() ?? 45;
        slotsList.add(
          InterviewSlot(
            slotIndex: 0,
            startTime: scheduled,
            endTime: scheduled.add(Duration(minutes: durationMins)),
            isSelected: true,
          ),
        );
      }
    }

    final rawFeedback = data['feedback'];
    final feedbackData = rawFeedback is Map ? Map<String, dynamic>.from(rawFeedback) : null;

    final rawInterviewers = data['interviewerNames'];
    final List<String> interviewers = [];
    if (rawInterviewers is List) {
      for (final name in rawInterviewers) {
        if (name != null) interviewers.add(name.toString());
      }
    }

    return InterviewModel(
      id: id,
      applicationId: data['applicationId'] as String? ?? '',
      jobId: data['jobId'] as String? ?? '',
      jobTitle: data['jobTitle'] as String? ?? '',
      companyId: data['companyId'] as String? ?? '',
      companyName: data['companyName'] as String? ?? '',
      companyLogoUrl: data['companyLogoUrl'] as String?,
      candidateId: data['candidateId'] as String? ?? '',
      candidateName: data['candidateName'] as String? ?? '',
      candidateEmail: data['candidateEmail'] as String? ?? '',
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      type: InterviewTypeExtension.fromString(data['type'] as String?),
      status: InterviewStatusExtension.fromString(data['status'] as String?),
      meetingUrl: data['meetingUrl'] as String?,
      location: data['location'] as String?,
      slots: slotsList,
      selectedSlotIndex: (data['selectedSlotIndex'] as num?)?.toInt(),
      interviewerNames: interviewers,
      feedback: feedbackData != null ? InterviewFeedback.fromMap(feedbackData) : null,
      declineReason: data['declineReason'] as String?,
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: parseTimestamp(data['updatedAt']),
    );
  }

  factory InterviewModel.fromDomain(Interview interview) {
    return InterviewModel(
      id: interview.id,
      applicationId: interview.applicationId,
      jobId: interview.jobId,
      jobTitle: interview.jobTitle,
      companyId: interview.companyId,
      companyName: interview.companyName,
      companyLogoUrl: interview.companyLogoUrl,
      candidateId: interview.candidateId,
      candidateName: interview.candidateName,
      candidateEmail: interview.candidateEmail,
      title: interview.title,
      description: interview.description,
      type: interview.type,
      status: interview.status,
      meetingUrl: interview.meetingUrl,
      location: interview.location,
      slots: interview.slots,
      selectedSlotIndex: interview.selectedSlotIndex,
      interviewerNames: interview.interviewerNames,
      feedback: interview.feedback,
      declineReason: interview.declineReason,
      createdAt: interview.createdAt,
      updatedAt: interview.updatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'applicationId': applicationId,
      'jobId': jobId,
      'jobTitle': jobTitle,
      'companyId': companyId,
      'companyName': companyName,
      'companyLogoUrl': companyLogoUrl,
      'candidateId': candidateId,
      'candidateName': candidateName,
      'candidateEmail': candidateEmail,
      'title': title,
      'description': description,
      'type': type.toShortString(),
      'status': status.toShortString(),
      'meetingUrl': meetingUrl,
      'location': location,
      'slots': slots.map((s) => s.toMap()).toList(),
      'selectedSlotIndex': selectedSlotIndex,
      'interviewerNames': interviewerNames,
      'feedback': feedback?.toMap(),
      'declineReason': declineReason,
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
