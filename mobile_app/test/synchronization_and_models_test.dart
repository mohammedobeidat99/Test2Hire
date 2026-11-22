import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/applications/domain/entities/job_application.dart';
import 'package:mobile_app/features/community/domain/entities/community_post.dart';
import 'package:mobile_app/features/interviews/domain/entities/interview.dart';
import 'package:mobile_app/features/interviews/domain/repositories/interview_repository.dart';
import 'package:mobile_app/features/interviews/presentation/providers/candidate_interviews_provider.dart';
import 'package:mobile_app/features/jobs/domain/entities/job_posting.dart';
import 'package:mobile_app/features/jobs/domain/repositories/job_repository.dart';
import 'package:mobile_app/features/jobs/presentation/providers/candidate_jobs_provider.dart';
import 'package:mobile_app/features/offers/domain/entities/job_offer.dart';
import 'package:mobile_app/features/offers/domain/repositories/offer_repository.dart';
import 'package:mobile_app/features/offers/presentation/providers/candidate_offers_provider.dart';

class FakeJobRepository implements JobRepository {
  @override
  Future<String> createJob(JobPosting job) async => job.id;

  @override
  Future<void> deleteJob(String jobId) async {}

  @override
  Future<List<JobPosting>> getCompanyJobs(
    String companyId, {
    JobStatus? status,
  }) async => [];

  @override
  Future<JobPosting> getJobById(String jobId) async => const JobPosting(
        id: 'job_1',
        companyId: 'comp_1',
        companyName: 'Apex',
        title: 'Engineer',
        description: 'Desc',
        location: JobLocation(city: 'Amman', country: 'Jordan'),
      );

  @override
  Future<List<JobPosting>> getPublishedJobs({
    String? searchQuery,
    JobType? jobType,
    WorkplaceType? workplaceType,
    ExperienceLevel? experienceLevel,
    List<String>? skills,
  }) async => [];

  @override
  Stream<List<JobPosting>> listenCompanyJobs(String companyId) =>
      const Stream.empty();

  @override
  Stream<List<JobPosting>> listenPublishedJobs({
    String? searchQuery,
    JobType? jobType,
    WorkplaceType? workplaceType,
    ExperienceLevel? experienceLevel,
    List<String>? skills,
  }) => const Stream.empty();

  @override
  Future<void> updateJob(JobPosting job) async {}

  @override
  Future<void> updateJobStatus(String jobId, JobStatus status) async {}
}

class FakeOfferRepository implements OfferRepository {
  final StreamController<List<JobOffer>> controller =
      StreamController<List<JobOffer>>.broadcast();
  bool shouldFailRespond = false;
  String? lastRespondedOfferId;
  String? lastResponse;

  @override
  Future<String> extendJobOffer({
    required String applicationId,
    required double offeredSalary,
    String salaryCurrency = 'USD',
    SalaryPeriod salaryPeriod = SalaryPeriod.annual,
    String? startDate,
    int expiresInDays = 7,
    List<String> benefits = const [],
    String termsAndNotes = '',
  }) async => 'offer_1';

  @override
  Future<List<JobOffer>> getCandidateOffers(String candidateId) async => [];

  @override
  Future<List<JobOffer>> getCompanyOffers(String companyId) async => [];

  @override
  Stream<List<JobOffer>> listenCandidateOffers(String candidateId) =>
      controller.stream;

  @override
  Stream<List<JobOffer>> listenCompanyOffers(String companyId) =>
      controller.stream;

  @override
  Future<void> respondToOffer({
    required String offerId,
    required String response,
    String? declineReason,
  }) async {
    if (shouldFailRespond) {
      throw Exception('Simulated network error');
    }
    lastRespondedOfferId = offerId;
    lastResponse = response;
  }

  @override
  Future<void> withdrawOffer({required String offerId, String? reason}) async {}
}

class FakeInterviewRepository implements InterviewRepository {
  final StreamController<List<Interview>> controller =
      StreamController<List<Interview>>.broadcast();
  bool shouldFailRespond = false;
  String? lastInterviewId;
  String? lastResponse;

  @override
  Future<void> cancelInterview(String interviewId, {String? reason}) async {}

  @override
  Future<List<Interview>> getCandidateInterviews(String candidateId) async => [];

  @override
  Future<List<Interview>> getCompanyInterviews(String companyId) async => [];

  @override
  Stream<List<Interview>> listenCandidateInterviews(String candidateId) =>
      controller.stream;

  @override
  Stream<List<Interview>> listenCompanyInterviews(String companyId) =>
      controller.stream;

  @override
  Future<void> respondToInterview({
    required String interviewId,
    required String response,
    int? selectedSlotIndex,
    String? declineReason,
  }) async {
    if (shouldFailRespond) {
      throw Exception('Simulated interview network error');
    }
    lastInterviewId = interviewId;
    lastResponse = response;
  }

  @override
  Future<String> scheduleInterview({
    required String applicationId,
    required String title,
    required String description,
    required InterviewType interviewType,
    String? meetingUrl,
    String? location,
    required List<InterviewSlot> slots,
    List<String> interviewerNames = const [],
  }) async => 'int_1';

  @override
  Future<void> submitInterviewFeedback({
    required String interviewId,
    required int score,
    required String recommendation,
    required String notes,
  }) async {}
}

void main() {
  group('Domain Entities & Status Serialization', () {
    test('JobOffer formats salary and maps server status accurately', () {
      final offer = JobOffer(
        id: 'off_101',
        applicationId: 'app_1',
        jobId: 'job_1',
        jobTitle: 'Senior Flutter Architect',
        companyId: 'comp_1',
        companyName: 'Apex Recruitment',
        candidateId: 'cand_1',
        candidateName: 'Ahmad',
        candidateEmail: 'candidate@test.com',
        offeredSalary: 18500,
        salaryCurrency: 'SAR',
        salaryPeriod: SalaryPeriod.monthly,
        status: OfferStatusX.fromServerString('PENDING_CANDIDATE'),
      );

      expect(offer.isPending, isTrue);
      expect(offer.formattedSalary, equals('SAR 18,500 / month'));
      expect(
        OfferStatusX.fromServerString('ACCEPTED'),
        equals(OfferStatus.accepted),
      );
    });

    test('Interview status and activeSlot resolution work across Web & Mobile formats', () {
      final start = DateTime(2026, 11, 15, 10, 0);
      final end = DateTime(2026, 11, 15, 10, 45);
      final slot = InterviewSlot.fromMap({
        'slotIndex': 0,
        'startTime': start.toIso8601String(),
        'endTime': end.toIso8601String(),
        'isSelected': true,
      }, 0);

      final interview = Interview(
        id: 'int_202',
        applicationId: 'app_1',
        jobId: 'job_1',
        jobTitle: 'Senior Flutter Architect',
        companyId: 'comp_1',
        companyName: 'Apex Recruitment',
        candidateId: 'cand_1',
        candidateName: 'Ahmad',
        candidateEmail: 'candidate@test.com',
        title: 'Technical Round',
        status: InterviewStatusExtension.fromString('PENDING_CANDIDATE'),
        slots: [slot],
      );

      expect(interview.isPendingCandidate, isTrue);
      expect(interview.activeSlot?.startTime, equals(start));
    });

    test('JobApplication withdrawal eligibility and exam assignment flags', () {
      const app = JobApplication(
        id: 'app_1',
        jobId: 'job_1',
        jobTitle: 'Flutter Engineer',
        companyId: 'comp_1',
        companyName: 'Apex',
        candidateId: 'cand_1',
        candidateName: 'Ahmad',
        candidateEmail: 'candidate@test.com',
        cvUrl: 'https://example.com/cv.pdf',
        cvFileName: 'cv.pdf',
        status: ApplicationStatus.applied,
        examToken: 'TOKEN123',
      );

      expect(app.canWithdraw, isTrue);
      expect(app.hasExamAssigned, isTrue);
      expect(app.isTerminal, isFalse);
    });
  });

  group('CandidateOffersProvider Optimistic Sync & Rollback', () {
    late FakeOfferRepository fakeRepo;
    late CandidateOffersProvider provider;

    setUp(() {
      fakeRepo = FakeOfferRepository();
      provider = CandidateOffersProvider(repository: fakeRepo);
    });

    test('optimistically updates offer status to ACCEPTED and persists via repository', () async {
      provider.listenCandidateOffers('cand_1');
      fakeRepo.controller.add([
        const JobOffer(
          id: 'offer_1',
          applicationId: 'app_1',
          jobId: 'job_1',
          jobTitle: 'Flutter Engineer',
          companyId: 'comp_1',
          companyName: 'Apex',
          candidateId: 'cand_1',
          candidateName: 'Ahmad',
          candidateEmail: 'candidate@test.com',
          offeredSalary: 15000,
          status: OfferStatus.pendingCandidate,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(provider.pendingOffers.length, equals(1));

      final ok = await provider.respondToOffer(
        offerId: 'offer_1',
        response: 'ACCEPT',
      );

      expect(ok, isTrue);
      expect(provider.offers.first.status, equals(OfferStatus.accepted));
      expect(fakeRepo.lastRespondedOfferId, equals('offer_1'));
      expect(fakeRepo.lastResponse, equals('ACCEPT'));
    });

    test('rolls back optimistic update if backend call fails', () async {
      provider.listenCandidateOffers('cand_1');
      fakeRepo.controller.add([
        const JobOffer(
          id: 'offer_2',
          applicationId: 'app_1',
          jobId: 'job_1',
          jobTitle: 'Flutter Engineer',
          companyId: 'comp_1',
          companyName: 'Apex',
          candidateId: 'cand_1',
          candidateName: 'Ahmad',
          candidateEmail: 'candidate@test.com',
          offeredSalary: 15000,
          status: OfferStatus.pendingCandidate,
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      fakeRepo.shouldFailRespond = true;
      final ok = await provider.respondToOffer(
        offerId: 'offer_2',
        response: 'ACCEPT',
      );

      expect(ok, isFalse);
      expect(provider.offers.first.status, equals(OfferStatus.pendingCandidate));
      expect(provider.errorMessage, isNotNull);
    });
  });

  group('CandidateInterviewsProvider Optimistic Sync & Rollback', () {
    late FakeInterviewRepository fakeRepo;
    late CandidateInterviewsProvider provider;

    setUp(() {
      fakeRepo = FakeInterviewRepository();
      provider = CandidateInterviewsProvider(repository: fakeRepo);
    });

    test('optimistically confirms interview attendance and syncs with repository', () async {
      provider.listenCandidateInterviews('cand_1');
      fakeRepo.controller.add([
        Interview(
          id: 'int_1',
          applicationId: 'app_1',
          jobId: 'job_1',
          jobTitle: 'Flutter Lead',
          companyId: 'comp_1',
          companyName: 'Apex',
          candidateId: 'cand_1',
          candidateName: 'Ahmad',
          candidateEmail: 'candidate@test.com',
          title: 'Tech Interview',
          status: InterviewStatus.pendingCandidate,
          slots: [
            InterviewSlot(
              slotIndex: 0,
              startTime: DateTime(2026, 11, 20, 14, 0),
              endTime: DateTime(2026, 11, 20, 14, 45),
            ),
          ],
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(provider.pendingInterviews.length, equals(1));

      final ok = await provider.respondToInterview(
        interviewId: 'int_1',
        response: 'ACCEPT',
        selectedSlotIndex: 0,
      );

      expect(ok, isTrue);
      expect(provider.interviews.first.status, equals(InterviewStatus.confirmed));
      expect(provider.confirmedInterviews.length, equals(1));
      expect(fakeRepo.lastInterviewId, equals('int_1'));
    });
  });

  group('Community Posts, Comments & Jobs Discovery Logic', () {
    test('CommunityPost serializes and tracks likedBy state accurately', () {
      final post = CommunityPost.fromMap({
        'authorId': 'user_1',
        'authorName': 'Ahmad Sami',
        'authorHeadline': 'Senior Flutter Engineer',
        'authorRole': 'CANDIDATE',
        'content': 'Excited to share my latest architecture insight!',
        'tags': ['Tech & Engineering', 'Career Advice'],
        'likedBy': ['user_2', 'user_3'],
        'likesCount': 2,
        'commentsCount': 1,
        'createdAt': DateTime(2026, 10, 30).toIso8601String(),
      }, 'post_1');

      expect(post.isLikedBy('user_2'), isTrue);
      expect(post.isLikedBy('user_1'), isFalse);
      expect(post.likesCount, equals(2));
      expect(post.tags.length, equals(2));
    });

    test('CommunityComment parses and preserves fields', () {
      final comment = CommunityComment.fromMap({
        'postId': 'post_1',
        'authorId': 'comp_1',
        'authorName': 'Apex Global Technologies',
        'authorHeadline': 'Verified Employer',
        'authorRole': 'COMPANY',
        'content': 'Great architectural breakdown!',
        'createdAt': DateTime(2026, 10, 30).toIso8601String(),
      }, 'comment_1');

      expect(comment.postId, equals('post_1'));
      expect(comment.authorRole, equals('COMPANY'));
      expect(comment.content, contains('architectural'));
    });

    test('CandidateJobsProvider calculates skill match score and toggles saved jobs', () async {
      final jobsProvider = CandidateJobsProvider(jobRepository: FakeJobRepository());
      const job = JobPosting(
        id: 'job_99',
        companyId: 'comp_1',
        companyName: 'Apex Global',
        title: 'Full-Stack Flutter & Cloud Engineer',
        description: 'Build cross-platform mobile and web apps.',
        location: JobLocation(city: 'Amman', country: 'Jordan'),
        requiredSkills: ['Flutter', 'Dart', 'Firebase', 'TypeScript'],
      );

      final match = jobsProvider.calculateSkillMatch(
        job,
        ['Flutter', 'Dart', 'Firebase'],
      );
      expect(match, equals(75));

      expect(jobsProvider.isJobSaved('job_99'), isFalse);
      await jobsProvider.toggleSaveJob('job_99');
      expect(jobsProvider.isJobSaved('job_99'), isTrue);
      await jobsProvider.toggleSaveJob('job_99');
      expect(jobsProvider.isJobSaved('job_99'), isFalse);
    });
  });
}
