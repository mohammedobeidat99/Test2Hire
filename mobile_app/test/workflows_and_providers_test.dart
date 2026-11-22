import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/errors/failures.dart';
import 'package:mobile_app/core/providers/locale_provider.dart';
import 'package:mobile_app/core/services/session_service.dart';
import 'package:mobile_app/core/widgets/app_button.dart';
import 'package:mobile_app/core/widgets/app_text_field.dart';
import 'package:mobile_app/core/widgets/status_badge.dart';
import 'package:mobile_app/features/applications/domain/entities/job_application.dart';
import 'package:mobile_app/features/applications/domain/repositories/application_repository.dart';
import 'package:mobile_app/features/applications/presentation/providers/candidate_applications_provider.dart';
import 'package:mobile_app/features/applications/presentation/providers/company_applicants_provider.dart';
import 'package:mobile_app/features/assessments/data/models/take_home_challenge_model.dart';
import 'package:mobile_app/features/auth/domain/entities/app_user.dart';
import 'package:mobile_app/features/evaluation/domain/entities/candidate_scorecard.dart';
import 'package:mobile_app/features/evaluation/domain/repositories/evaluation_repository.dart';
import 'package:mobile_app/features/evaluation/presentation/providers/evaluation_provider.dart';
import 'package:mobile_app/features/exams/domain/entities/exam_template.dart';
import 'package:mobile_app/features/exams/domain/repositories/exam_repository.dart';
import 'package:mobile_app/features/exams/presentation/providers/candidate_exams_provider.dart';
import 'package:mobile_app/features/exams/presentation/providers/company_exams_provider.dart';
import 'package:mobile_app/features/interviews/data/models/interview_model.dart';
import 'package:mobile_app/features/interviews/domain/entities/interview.dart';
import 'package:mobile_app/features/jobs/domain/entities/job_posting.dart';
import 'package:mobile_app/features/jobs/domain/repositories/job_repository.dart';
import 'package:mobile_app/features/jobs/presentation/providers/candidate_jobs_provider.dart';
import 'package:mobile_app/features/jobs/presentation/providers/company_jobs_provider.dart';
import 'package:mobile_app/features/notifications/data/models/notification_model.dart';
import 'package:mobile_app/features/notifications/domain/entities/notification_item.dart';
import 'package:mobile_app/features/questions/domain/entities/question.dart';
import 'package:mobile_app/features/questions/domain/entities/question_bank.dart';
import 'package:mobile_app/features/questions/domain/repositories/question_repository.dart';
import 'package:mobile_app/features/questions/presentation/providers/questions_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// In-memory Repository Fakes
// ---------------------------------------------------------------------------

class _FakeJobRepo implements JobRepository {
  final StreamController<List<JobPosting>> companyController =
      StreamController<List<JobPosting>>.broadcast();
  final StreamController<List<JobPosting>> publishedController =
      StreamController<List<JobPosting>>.broadcast();

  List<JobPosting> storedJobs = [];
  Failure? failureToThrow;
  JobPosting? lastCreatedJob;
  String? lastUpdatedStatusJobId;
  JobStatus? lastUpdatedStatus;
  String? lastDeletedJobId;

  @override
  Future<String> createJob(JobPosting job) async {
    if (failureToThrow != null) throw failureToThrow!;
    lastCreatedJob = job;
    return 'created_job_1';
  }

  @override
  Future<void> deleteJob(String jobId) async {
    if (failureToThrow != null) throw failureToThrow!;
    lastDeletedJobId = jobId;
  }

  @override
  Future<List<JobPosting>> getCompanyJobs(
    String companyId, {
    JobStatus? status,
  }) async {
    if (failureToThrow != null) throw failureToThrow!;
    return storedJobs;
  }

  @override
  Future<JobPosting> getJobById(String jobId) async {
    if (failureToThrow != null) throw failureToThrow!;
    return storedJobs.firstWhere((j) => j.id == jobId);
  }

  @override
  Future<List<JobPosting>> getPublishedJobs({
    String? searchQuery,
    JobType? jobType,
    WorkplaceType? workplaceType,
    ExperienceLevel? experienceLevel,
    List<String>? skills,
  }) async {
    if (failureToThrow != null) throw failureToThrow!;
    return storedJobs;
  }

  @override
  Stream<List<JobPosting>> listenCompanyJobs(String companyId) =>
      companyController.stream;

  @override
  Stream<List<JobPosting>> listenPublishedJobs({
    String? searchQuery,
    JobType? jobType,
    WorkplaceType? workplaceType,
    ExperienceLevel? experienceLevel,
    List<String>? skills,
  }) =>
      publishedController.stream;

  @override
  Future<void> updateJob(JobPosting job) async {
    if (failureToThrow != null) throw failureToThrow!;
  }

  @override
  Future<void> updateJobStatus(String jobId, JobStatus status) async {
    if (failureToThrow != null) throw failureToThrow!;
    lastUpdatedStatusJobId = jobId;
    lastUpdatedStatus = status;
  }

  void dispose() {
    companyController.close();
    publishedController.close();
  }
}

class _FakeApplicationRepo implements ApplicationRepository {
  final StreamController<List<JobApplication>> candidateController =
      StreamController<List<JobApplication>>.broadcast();
  final StreamController<List<JobApplication>> applicantsController =
      StreamController<List<JobApplication>>.broadcast();

  List<JobApplication> candidateApps = [];
  List<JobApplication> jobApplicants = [];
  bool appliedFlag = false;
  Failure? failureToThrow;
  AiParsedCv parsedCvToReturn = const AiParsedCv(
    extractedSkills: ['Flutter', 'Dart'],
    yearsOfExperience: 4,
    cvMatchScore: 90,
    aiRecommendation: 'STRONG_MATCH',
  );
  String? lastWithdrawnId;
  ApplicationStatus? lastStatusUpdated;
  String? lastRejectionReason;

  @override
  Future<List<JobApplication>> getCandidateApplications(
    String candidateId,
  ) async {
    if (failureToThrow != null) throw failureToThrow!;
    return candidateApps;
  }

  @override
  Future<List<JobApplication>> getJobApplicants(String jobId) async {
    if (failureToThrow != null) throw failureToThrow!;
    return jobApplicants;
  }

  @override
  Future<bool> hasCandidateApplied(String jobId, String candidateId) async {
    if (failureToThrow != null) throw failureToThrow!;
    return appliedFlag;
  }

  @override
  Stream<List<JobApplication>> listenCandidateApplications(String candidateId) =>
      candidateController.stream;

  @override
  Stream<List<JobApplication>> listenJobApplicants(String jobId) =>
      applicantsController.stream;

  @override
  Future<AiParsedCv> parseResumeWithAI(String applicationId) async {
    if (failureToThrow != null) throw failureToThrow!;
    return parsedCvToReturn;
  }

  @override
  Future<String> submitApplication(JobApplication application) async {
    if (failureToThrow != null) throw failureToThrow!;
    return 'app_created_1';
  }

  @override
  Future<void> updateApplicationStatus(
    String applicationId,
    ApplicationStatus status, {
    String? reason,
  }) async {
    if (failureToThrow != null) throw failureToThrow!;
    lastStatusUpdated = status;
    lastRejectionReason = reason;
  }

  @override
  Future<void> withdrawApplication(String applicationId) async {
    if (failureToThrow != null) throw failureToThrow!;
    lastWithdrawnId = applicationId;
  }

  void dispose() {
    candidateController.close();
    applicantsController.close();
  }
}

class _FakeExamRepo implements ExamRepository {
  List<ExamTemplate> exams = [];
  List<ExamAttempt> attempts = [];
  Failure? failureToThrow;
  int loadExamsCalls = 0;

  @override
  Future<AssignExamResult> assignExam({
    required String examId,
    required String applicationId,
    required String candidateId,
    String? jobId,
    int? durationMinutes,
    int? deadlineDays,
  }) async {
    if (failureToThrow != null) throw failureToThrow!;
    return AssignExamResult(
      attemptId: 'att_new',
      token: 'tok_new',
      durationMinutes: durationMinutes ?? 45,
    );
  }

  @override
  Future<String> createExam(ExamTemplate exam) async {
    if (failureToThrow != null) throw failureToThrow!;
    return 'exam_new';
  }

  @override
  Future<void> deleteExam(String examId) async {
    if (failureToThrow != null) throw failureToThrow!;
  }

  @override
  Future<List<ExamAttempt>> getCandidateAttempts(String candidateId) async {
    if (failureToThrow != null) throw failureToThrow!;
    return attempts;
  }

  @override
  Future<List<ExamTemplate>> getCompanyExams(String companyId) async {
    loadExamsCalls++;
    if (failureToThrow != null) throw failureToThrow!;
    return exams;
  }

  @override
  Future<ExamTemplate> getExamById(String examId) async => exams.first;

  @override
  Stream<List<ExamAttempt>> listenCandidateAttempts(String candidateId) =>
      const Stream.empty();

  @override
  Stream<List<ExamTemplate>> listenCompanyExams(String companyId) =>
      const Stream.empty();

  @override
  Future<String> quickGenerateExamForRole({
    required String companyId,
    required String roleTitle,
  }) async {
    if (failureToThrow != null) throw failureToThrow!;
    return 'exam_ai_1';
  }

  @override
  Future<void> updateExam(ExamTemplate exam) async {
    if (failureToThrow != null) throw failureToThrow!;
  }
}

class _FakeQuestionRepo implements QuestionRepository {
  List<Question> storedQuestions = [];
  List<Question> generatedQuestions = [];
  Failure? failureToThrow;

  @override
  Future<int> bulkImportQuestions(String bankId, List<Question> questions) async {
    if (failureToThrow != null) throw failureToThrow!;
    return questions.length;
  }

  @override
  Future<String> createQuestion(Question question) async {
    if (failureToThrow != null) throw failureToThrow!;
    return 'q_created';
  }

  @override
  Future<String> createQuestionBank(QuestionBank bank) async => 'bank_1';

  @override
  Future<void> deleteQuestion(String questionId, String bankId) async {
    if (failureToThrow != null) throw failureToThrow!;
  }

  @override
  Future<void> deleteQuestionBank(String bankId) async {}

  @override
  Future<List<Question>> generateQuestionsWithAI({
    required String companyId,
    required String bankId,
    required String jobTitle,
    List<String> requiredSkills = const [],
    String difficulty = 'MID',
    int questionCount = 5,
    String questionType = 'SINGLE_CHOICE',
  }) async {
    if (failureToThrow != null) throw failureToThrow!;
    return generatedQuestions;
  }

  @override
  Future<List<QuestionBank>> getQuestionBanks(String companyId) async => [];

  @override
  Future<List<Question>> getQuestions(
    String bankId, {
    QuestionDifficulty? difficulty,
    QuestionType? type,
    String? searchQuery,
  }) async {
    if (failureToThrow != null) throw failureToThrow!;
    return storedQuestions;
  }

  @override
  Stream<List<QuestionBank>> listenQuestionBanks(String companyId) =>
      const Stream.empty();

  @override
  Stream<List<Question>> listenQuestions(String bankId) =>
      const Stream.empty();

  @override
  Future<void> updateQuestion(Question question) async {
    if (failureToThrow != null) throw failureToThrow!;
  }

  @override
  Future<void> updateQuestionBank(QuestionBank bank) async {}
}

class _FakeEvaluationRepo implements EvaluationRepository {
  final StreamController<CandidateScorecard?> scorecardController =
      StreamController<CandidateScorecard?>.broadcast();
  final StreamController<List<CandidateScorecard>> rankingsController =
      StreamController<List<CandidateScorecard>>.broadcast();

  CandidateScorecard? scorecardToReturn;
  List<CandidateScorecard> rankingsToReturn = [];
  bool shouldThrow = false;

  @override
  Future<CandidateScorecard> calculateScorecard({
    required String applicationId,
    ScorecardWeights? customWeights,
  }) async {
    if (shouldThrow) throw Exception('Scorecard computation failed');
    return scorecardToReturn!;
  }

  @override
  Future<List<CandidateScorecard>> getJobRankings(String jobId) async =>
      rankingsToReturn;

  @override
  Future<CandidateScorecard?> getScorecard(String applicationId) async =>
      scorecardToReturn;

  @override
  Stream<List<CandidateScorecard>> listenJobRankings(String jobId) =>
      rankingsController.stream;

  @override
  Stream<CandidateScorecard?> listenScorecard(String applicationId) =>
      scorecardController.stream;

  @override
  Future<void> recalculateJobRankings(String jobId) async {
    if (shouldThrow) throw Exception('Recalculate rankings failed');
  }

  void dispose() {
    scorecardController.close();
    rankingsController.close();
  }
}

JobPosting _makeJob({
  required String id,
  required String title,
  String description = '',
  JobStatus status = JobStatus.published,
  int applicantsCount = 0,
  List<String> requiredSkills = const [],
  JobSalaryRange? salaryRange,
  DateTime? createdAt,
}) {
  return JobPosting(
    id: id,
    companyId: 'comp_1',
    companyName: 'Apex',
    title: title,
    description: description,
    location: const JobLocation(city: 'Amman', country: 'Jordan'),
    status: status,
    applicantsCount: applicantsCount,
    requiredSkills: requiredSkills,
    salaryRange: salaryRange,
    createdAt: createdAt,
  );
}

JobApplication _makeApp({
  required String id,
  required String jobId,
  ApplicationStatus status = ApplicationStatus.applied,
  double? examScore,
  int? overallFitScore,
  DateTime? appliedAt,
}) {
  return JobApplication(
    id: id,
    jobId: jobId,
    jobTitle: 'Engineer',
    companyId: 'comp_1',
    companyName: 'Apex',
    candidateId: 'cand_1',
    candidateName: 'Ahmad',
    candidateEmail: 'ahmad@test.com',
    cvUrl: 'https://cv.pdf',
    cvFileName: 'cv.pdf',
    status: status,
    examScore: examScore,
    overallFitScore: overallFitScore,
    appliedAt: appliedAt,
  );
}

void main() {
  group('CompanyJobsProvider workflow & validation logic', () {
    late _FakeJobRepo repo;
    late CompanyJobsProvider provider;

    setUp(() {
      repo = _FakeJobRepo();
      provider = CompanyJobsProvider(jobRepository: repo);
    });

    tearDown(() {
      provider.dispose();
      repo.dispose();
    });

    test('computes status counts, totalApplicantsCount, and status filtering', () async {
      repo.storedJobs = [
        _makeJob(id: '1', title: 'A', status: JobStatus.published, applicantsCount: 5),
        _makeJob(id: '2', title: 'B', status: JobStatus.draft, applicantsCount: 0),
        _makeJob(id: '3', title: 'C', status: JobStatus.closed, applicantsCount: 12),
        _makeJob(id: '4', title: 'D', status: JobStatus.published, applicantsCount: 3),
      ];

      await provider.loadCompanyJobs('comp_1');

      expect(provider.totalJobsCount, 4);
      expect(provider.publishedJobsCount, 2);
      expect(provider.draftJobsCount, 1);
      expect(provider.closedJobsCount, 1);
      expect(provider.totalApplicantsCount, 20);

      provider.setStatusFilter(JobStatus.published);
      expect(provider.jobs.map((j) => j.id), ['1', '4']);

      provider.setStatusFilter(null);
      expect(provider.jobs.length, 4);
    });

    test('createJob trims inputs, deletes locally, and surfaces Failure messages', () async {
      final createdId = await provider.createJob(
        companyId: 'comp_1',
        companyName: 'Apex',
        title: '  Flutter Lead  ',
        description: '  Lead mobile architecture  ',
        jobType: JobType.fullTime,
        workplaceType: WorkplaceType.remote,
        experienceLevel: ExperienceLevel.lead,
        location: const JobLocation(city: 'Amman', country: 'Jordan'),
        status: JobStatus.published,
      );

      expect(createdId, 'created_job_1');
      expect(repo.lastCreatedJob?.title, 'Flutter Lead');
      expect(repo.lastCreatedJob?.description, 'Lead mobile architecture');
      expect(provider.successMessage, 'Job vacancy successfully published!');

      repo.storedJobs = [_makeJob(id: 'j_del', title: 'Temp')];
      await provider.loadCompanyJobs('comp_1');
      final deleted = await provider.deleteJob('j_del');
      expect(deleted, isTrue);
      expect(provider.allJobs, isEmpty);

      provider.clearMessages();
      expect(provider.successMessage, isNull);
      expect(provider.errorMessage, isNull);

      repo.failureToThrow = const ValidationFailure('Invalid salary band');
      final failedId = await provider.createJob(
        companyId: 'comp_1',
        companyName: 'Apex',
        title: 'Role',
        description: 'Desc',
        jobType: JobType.fullTime,
        workplaceType: WorkplaceType.onSite,
        experienceLevel: ExperienceLevel.entry,
        location: const JobLocation(city: 'Amman', country: 'Jordan'),
        status: JobStatus.draft,
      );
      expect(failedId, isNull);
      expect(provider.errorMessage, 'Invalid salary band');
      expect(provider.isSaving, isFalse);
    });
  });

  group('CandidateJobsProvider discovery, matching & SharedPreferences', () {
    late _FakeJobRepo repo;
    late CandidateJobsProvider provider;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repo = _FakeJobRepo();
      provider = CandidateJobsProvider(jobRepository: repo);
    });

    tearDown(() {
      provider.dispose();
      repo.dispose();
    });

    test('calculates skill match boundaries and sorts/filters by category & sortOption', () async {
      repo.storedJobs = [
        _makeJob(
          id: 'eng',
          title: 'Flutter Developer',
          requiredSkills: ['Flutter', 'Dart', 'Firebase'],
          salaryRange: const JobSalaryRange(min: 2000, max: 3500),
          createdAt: DateTime(2026, 10, 1),
        ),
        _makeJob(
          id: 'ai',
          title: 'ML Research Scientist',
          description: 'Python AI modeling',
          requiredSkills: ['Python'],
          salaryRange: const JobSalaryRange(min: 5000, max: 7000),
          createdAt: DateTime(2026, 10, 10),
        ),
        _makeJob(
          id: 'design',
          title: 'Senior UX Designer',
          requiredSkills: const ['Figma', 'UX'],
          salaryRange: const JobSalaryRange(min: 3000),
          createdAt: DateTime(2026, 10, 5),
        ),
      ];
      await provider.fetchJobs();

      // Empty requiredSkills -> 100%, case/whitespace insensitive matching
      expect(
        provider.calculateSkillMatch(
          _makeJob(id: 'any', title: 'Any', requiredSkills: const []),
          [],
        ),
        100,
      );
      expect(
        provider.calculateSkillMatch(repo.storedJobs[0], [' flutter ', 'DART']),
        67,
      );

      // Newest first (default)
      expect(
        provider.getSortedAndFilteredJobs([]).map((j) => j.id),
        ['ai', 'design', 'eng'],
      );

      // Salary high to low
      provider.setSortOption(JobSortOption.salaryHighToLow);
      expect(
        provider.getSortedAndFilteredJobs([]).map((j) => j.id),
        ['ai', 'eng', 'design'],
      );

      // Best match (eng: 100%, design: 50%, ai: 0%)
      provider.setSortOption(JobSortOption.bestMatch);
      expect(
        provider
            .getSortedAndFilteredJobs(['Flutter', 'Dart', 'Firebase', 'Figma'])
            .map((j) => j.id),
        ['eng', 'design', 'ai'],
      );

      // Category filtering & clearFilters
      provider.setCategory('Data & AI');
      expect(provider.hasActiveFilters, isTrue);
      expect(provider.getSortedAndFilteredJobs([]).map((j) => j.id), ['ai']);

      provider.clearFilters();
      expect(provider.hasActiveFilters, isFalse);
      expect(provider.selectedCategory, 'All');
    });

    test('recordJobViewed deduplicates and caps history at 15 items', () async {
      for (int i = 1; i <= 18; i++) {
        await provider.recordJobViewed('job_$i');
      }

      expect(provider.recentlyViewedJobIds.length, 15);
      expect(provider.recentlyViewedJobIds.first, 'job_18');
      expect(provider.recentlyViewedJobIds.last, 'job_4');

      // Viewing an existing item moves it back to index 0 without duplicating
      await provider.recordJobViewed('job_10');
      expect(provider.recentlyViewedJobIds.length, 15);
      expect(provider.recentlyViewedJobIds.first, 'job_10');
    });
  });

  group('CandidateApplicationsProvider & CompanyApplicantsProvider workflows', () {
    late _FakeApplicationRepo repo;
    late CandidateApplicationsProvider candidateProvider;
    late CompanyApplicantsProvider companyProvider;

    setUp(() {
      repo = _FakeApplicationRepo();
      candidateProvider = CandidateApplicationsProvider(repository: repo);
      companyProvider = CompanyApplicantsProvider(repository: repo);
    });

    tearDown(() {
      candidateProvider.dispose();
      companyProvider.dispose();
      repo.dispose();
    });

    test('CandidateApplicationsProvider submits, withdraws, merges stream, and tracks activeCount', () async {
      final appId = await candidateProvider.submitApplication(
        jobId: 'job_1',
        jobTitle: 'Flutter Dev',
        companyId: 'comp_1',
        companyName: 'Apex',
        candidateId: 'cand_1',
        candidateName: 'Ahmad',
        candidateEmail: 'ahmad@test.com',
        cvUrl: 'https://cv.pdf',
        cvFileName: 'cv.pdf',
      );

      expect(appId, 'app_created_1');
      expect(candidateProvider.isJobApplied('job_1'), isTrue);
      expect(candidateProvider.totalCount, 1);
      expect(candidateProvider.activeCount, 1);

      // Withdraw flips status & applied map, decreasing activeCount
      final ok = await candidateProvider.withdraw('app_created_1');
      expect(ok, isTrue);
      expect(candidateProvider.isJobApplied('job_1'), isFalse);
      expect(candidateProvider.totalCount, 1);
      expect(candidateProvider.activeCount, 0);
      expect(repo.lastWithdrawnId, 'app_created_1');

      // Listen merges remote snapshot with unsynced local apps and sorts newest first
      candidateProvider.listenApplications('cand_1');
      repo.candidateController.add([
        _makeApp(
          id: 'remote_new',
          jobId: 'job_2',
          status: ApplicationStatus.selected,
          appliedAt: DateTime.now().add(const Duration(days: 1)),
        ),
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(candidateProvider.applications.first.id, 'remote_new');
      expect(candidateProvider.isJobApplied('job_2'), isTrue);
    });

    test('CompanyApplicantsProvider computes counts, composite AI score, and mutually exclusive sorts', () async {
      repo.jobApplicants = [
        _makeApp(
          id: 'a1',
          jobId: 'j1',
          status: ApplicationStatus.applied,
          examScore: 80.0,
          overallFitScore: 60,
        ),
        _makeApp(
          id: 'a2',
          jobId: 'j1',
          status: ApplicationStatus.passed,
          examScore: 95.0,
          overallFitScore: 90,
        ),
        _makeApp(
          id: 'a3',
          jobId: 'j1',
          status: ApplicationStatus.interviewScheduled,
          examScore: 60.0,
          overallFitScore: 78,
        ),
        _makeApp(
          id: 'a4',
          jobId: 'j1',
          status: ApplicationStatus.rejected,
          examScore: 40.0,
          overallFitScore: 50,
        ),
      ];

      await companyProvider.loadJobApplicants('j1');

      expect(companyProvider.totalCount, 4);
      expect(companyProvider.appliedCount, 1);
      expect(companyProvider.examCount, 1); // passed
      expect(companyProvider.interviewCount, 1);
      expect(companyProvider.rejectedCount, 1);
      // Top performers: a1 (exam >= 70), a2 (passed & exam >= 70), a3 (fit >= 75)
      expect(companyProvider.topPerformersCount, 3);

      // Mutually exclusive sorting
      companyProvider.toggleSortByExamScore();
      expect(companyProvider.sortByExamScore, isTrue);
      expect(companyProvider.sortByFitScore, isFalse);
      expect(companyProvider.applicants.map((a) => a.id), ['a2', 'a1', 'a3', 'a4']);

      companyProvider.toggleSortByFitScore();
      expect(companyProvider.sortByFitScore, isTrue);
      expect(companyProvider.sortByExamScore, isFalse);
      expect(companyProvider.applicants.map((a) => a.id), ['a2', 'a3', 'a1', 'a4']);

      // Composite score formula: ((examScore * 0.6) + (cvMatchScore * 0.4)).round()
      // For a1: examScore 80 * 0.6 (48) + cvMatchScore 90 * 0.4 (36) = 84
      final parsed = await companyProvider.parseApplicantCv('a1');
      expect(parsed?.cvMatchScore, 90);
      final updatedA1 = companyProvider.allApplicants.firstWhere((a) => a.id == 'a1');
      expect(updatedA1.overallFitScore, 84);

      // Status update with rejection reason
      final moved = await companyProvider.updateApplicantStatus(
        'a3',
        ApplicationStatus.rejected,
        reason: 'Role filled',
      );
      expect(moved, isTrue);
      expect(repo.lastStatusUpdated, ApplicationStatus.rejected);
      expect(repo.lastRejectionReason, 'Role filled');
    });
  });

  group('CompanyExamsProvider, CandidateExamsProvider, QuestionsProvider & EvaluationProvider', () {
    late _FakeExamRepo examRepo;
    late _FakeQuestionRepo questionRepo;
    late _FakeEvaluationRepo evalRepo;
    late CompanyExamsProvider companyExams;
    late CandidateExamsProvider candidateExams;
    late QuestionsProvider questionsProvider;
    late EvaluationProvider evalProvider;

    setUp(() {
      examRepo = _FakeExamRepo();
      questionRepo = _FakeQuestionRepo();
      evalRepo = _FakeEvaluationRepo();
      companyExams = CompanyExamsProvider(repository: examRepo);
      candidateExams = CandidateExamsProvider(repository: examRepo);
      questionsProvider = QuestionsProvider(repository: questionRepo);
      evalProvider = EvaluationProvider(repository: evalRepo);
    });

    tearDown(() {
      companyExams.dispose();
      candidateExams.dispose();
      questionsProvider.dispose();
      evalProvider.dispose();
      evalRepo.dispose();
    });

    test('CompanyExamsProvider and CandidateExamsProvider manage templates and attempts', () async {
      examRepo.exams = [
        const ExamTemplate(
          id: 'ex_1',
          companyId: 'comp_1',
          title: 'Dart Core',
          description: 'Core language',
        ),
      ];
      await companyExams.loadCompanyExams('comp_1');
      expect(companyExams.totalExamsCount, 1);

      final assigned = await companyExams.assignExam(
        examId: 'ex_1',
        applicationId: 'app_1',
        candidateId: 'cand_1',
        durationMinutes: 60,
      );
      expect(assigned?.assessmentUrl, 'https://test2here-72346.web.app/exam/tok_new');

      final aiExamId = await companyExams.quickGenerateExamForRole(
        companyId: 'comp_1',
        roleTitle: 'Flutter Architect',
      );
      expect(aiExamId, 'exam_ai_1');
      expect(examRepo.loadExamsCalls, 2);

      final deleted = await companyExams.deleteExam('ex_1');
      expect(deleted, isTrue);
      expect(companyExams.totalExamsCount, 0);

      examRepo.attempts = [
        const ExamAttempt(
          id: 'at_1',
          examId: 'ex_1',
          examTitle: 'T1',
          companyId: 'comp_1',
          candidateId: 'cand_1',
          candidateName: 'A',
          candidateEmail: 'a@t.com',
          jobId: 'j1',
          jobTitle: 'Dev',
          applicationId: 'ap1',
          token: 't1',
          status: ExamAttemptStatus.invited,
        ),
        const ExamAttempt(
          id: 'at_2',
          examId: 'ex_1',
          examTitle: 'T1',
          companyId: 'comp_1',
          candidateId: 'cand_1',
          candidateName: 'A',
          candidateEmail: 'a@t.com',
          jobId: 'j1',
          jobTitle: 'Dev',
          applicationId: 'ap2',
          token: 't2',
          status: ExamAttemptStatus.inProgress,
        ),
        const ExamAttempt(
          id: 'at_3',
          examId: 'ex_1',
          examTitle: 'T1',
          companyId: 'comp_1',
          candidateId: 'cand_1',
          candidateName: 'A',
          candidateEmail: 'a@t.com',
          jobId: 'j1',
          jobTitle: 'Dev',
          applicationId: 'ap3',
          token: 't3',
          status: ExamAttemptStatus.graded,
        ),
      ];
      await candidateExams.loadCandidateAttempts('cand_1');
      expect(candidateExams.pendingCount, 1);
      expect(candidateExams.inProgressCount, 1);
      expect(candidateExams.completedCount, 1);
    });

    test('QuestionsProvider filters by difficulty, type, and tag search and updates totals', () async {
      questionRepo.storedQuestions = [
        const Question(
          id: 'q1',
          bankId: 'b1',
          companyId: 'c1',
          title: 'Isolates in Dart',
          description: 'Concurrency',
          type: QuestionType.singleChoice,
          difficulty: QuestionDifficulty.easy,
          points: 5,
          tags: ['async', 'dart'],
        ),
        const Question(
          id: 'q2',
          bankId: 'b1',
          companyId: 'c1',
          title: 'Implement LRU Cache',
          description: 'O(1) get and put',
          type: QuestionType.coding,
          difficulty: QuestionDifficulty.hard,
          points: 20,
          tags: ['algorithms'],
        ),
      ];

      await questionsProvider.loadQuestions('b1');
      expect(questionsProvider.totalCount, 2);
      expect(questionsProvider.totalPoints, 25);
      expect(questionsProvider.easyCount, 1);
      expect(questionsProvider.hardCount, 1);
      expect(questionsProvider.mcqCount, 1);
      expect(questionsProvider.codingCount, 1);

      questionsProvider.setDifficultyFilter(QuestionDifficulty.hard);
      expect(questionsProvider.questions.map((q) => q.id), ['q2']);

      questionsProvider.setDifficultyFilter(null);
      questionsProvider.setTypeFilter(QuestionType.singleChoice);
      questionsProvider.setSearchQuery('async');
      expect(questionsProvider.questions.map((q) => q.id), ['q1']);

      questionRepo.generatedQuestions = [
        const Question(
          id: 'q3',
          bankId: 'b1',
          companyId: 'c1',
          title: 'Stream vs Future',
          description: 'Reactive Dart',
          type: QuestionType.shortAnswer,
          points: 10,
        ),
      ];
      questionsProvider.setTypeFilter(null);
      questionsProvider.setSearchQuery(null);
      await questionsProvider.generateQuestionsWithAI(
        companyId: 'c1',
        bankId: 'b1',
        jobTitle: 'Dart Engineer',
      );
      expect(questionsProvider.totalCount, 3);
      expect(questionsProvider.totalPoints, 35);
    });

    test('EvaluationProvider sorts rankings by breakdown metrics and captures errors', () async {
      evalRepo.rankingsToReturn = [
        const CandidateScorecard(
          id: 's1',
          applicationId: 'a1',
          jobId: 'j1',
          companyId: 'c1',
          candidateId: 'u1',
          candidateName: 'One',
          candidateEmail: 'one@t.com',
          compositeScore: 80,
          recommendation: ScorecardRecommendation.recommended,
          breakdown: ScoreBreakdown(
            cvMatchScore: 95,
            examScore: 70,
            interviewScore: 75,
          ),
        ),
        const CandidateScorecard(
          id: 's2',
          applicationId: 'a2',
          jobId: 'j1',
          companyId: 'c1',
          candidateId: 'u2',
          candidateName: 'Two',
          candidateEmail: 'two@t.com',
          compositeScore: 88,
          recommendation: ScorecardRecommendation.stronglyRecommended,
          breakdown: ScoreBreakdown(
            cvMatchScore: 60,
            examScore: 98,
            interviewScore: 90,
          ),
        ),
      ];

      await evalProvider.recalculateJobRankings('j1');
      expect(evalProvider.jobRankings.map((s) => s.id), ['s2', 's1']);

      evalProvider.setSortFilter(RankingSortFilter.cvMatch);
      expect(evalProvider.jobRankings.map((s) => s.id), ['s1', 's2']);

      evalProvider.setRecommendationFilter(
        ScorecardRecommendation.stronglyRecommended,
      );
      expect(evalProvider.jobRankings.map((s) => s.id), ['s2']);

      evalRepo.shouldThrow = true;
      await evalProvider.calculateScorecard(applicationId: 'a1');
      expect(evalProvider.errorMessage, contains('Scorecard computation failed'));
      expect(evalProvider.isCalculating, isFalse);
    });
  });

  group('LocaleProvider & SessionService persistence', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await SessionService.init();
      await SessionService.clearSession();
    });

    test('LocaleProvider loads persisted locale and toggles between ar and en', () async {
      SharedPreferences.setMockInitialValues({'selected_locale_code': 'en'});
      final provider = LocaleProvider();
      await Future<void>.delayed(Duration.zero);

      expect(provider.locale, const Locale('en'));
      expect(provider.isArabic, isFalse);

      await provider.toggleLocale();
      expect(provider.locale, const Locale('ar'));
      expect(provider.isArabic, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('selected_locale_code'), 'ar');
    });

    test('SessionService caches user, email verification, credentials, and onboarding', () async {
      expect(SessionService.hasCachedSession, isFalse);
      expect(SessionService.hasSeenOnboarding, isFalse);

      const user = AppUser(
        uid: 'u_99',
        email: 'maya@apex.com',
        role: UserRole.company,
        fullName: 'Maya',
        isEmailVerified: false,
        isProfileComplete: true,
      );

      await SessionService.saveUser(user);
      expect(SessionService.hasCachedSession, isTrue);
      expect(SessionService.getCachedUser()?.isCompany, isTrue);
      expect(SessionService.getCachedUser()?.isEmailVerified, isFalse);

      await SessionService.updateEmailVerified(true);
      expect(SessionService.getCachedUser()?.isEmailVerified, isTrue);

      await SessionService.saveBiometricCredentials(
        email: '  maya@apex.com  ',
        password: 'secret-pass',
      );
      final creds = await SessionService.getBiometricCredentials();
      expect(creds?.email, 'maya@apex.com');
      // Plaintext password must never be persisted or returned.
      expect(creds?.password, '');

      await SessionService.setOnboardingSeen();
      expect(SessionService.hasSeenOnboarding, isTrue);

      await SessionService.clearSession();
      expect(SessionService.hasCachedSession, isFalse);
      expect(SessionService.getCachedUser(), isNull);
    });
  });

  group('Core UI & Form Validation Widget Tests', () {
    testWidgets('StatusBadge maps server statuses and falls back cleanly on unknown strings', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge(status: 'UNDER_REVIEW'),
                StatusBadge(status: 'selected'),
                StatusBadge(status: 'CUSTOM_UNKNOWN'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Under Review'), findsOneWidget);
      expect(find.text('Selected'), findsOneWidget);
      expect(find.text('CUSTOM_UNKNOWN'), findsOneWidget);
    });

    testWidgets('AppButton handles enabled, disabled, and loading states', (
      tester,
    ) async {
      var tapCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              text: 'Publish Job',
              icon: Icons.check,
              onPressed: () => tapCount++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Publish Job'));
      await tester.pump();
      expect(tapCount, 1);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              text: 'Publish Job',
              isLoading: true,
              onPressed: () => tapCount++,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(AppButton));
      await tester.pump();
      expect(tapCount, 1);
    });

    testWidgets('AppTextField enforces Form validation and accepts valid input', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Form(
              key: formKey,
              child: AppTextField(
                label: 'Job Title',
                hint: 'e.g. Senior Flutter Engineer',
                controller: controller,
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Title required' : null,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Job Title'), findsOneWidget);
      expect(formKey.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.text('Title required'), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField),
        'Principal Mobile Architect',
      );
      expect(formKey.currentState!.validate(), isTrue);
      await tester.pump();
      expect(find.text('Title required'), findsNothing);
    });
  });

  group('Cross-user isolation, assignment scoping, timezone & notification models', () {
    test('CandidateApplicationsProvider purges User A data when switching to User B', () async {
      final repo = _FakeApplicationRepo();
      final provider = CandidateApplicationsProvider(repository: repo);

      await provider.submitApplication(
        jobId: 'job_user_a',
        jobTitle: 'Backend Engineer',
        companyId: 'comp_1',
        companyName: 'Apex',
        candidateId: 'cand_A',
        candidateName: 'User A',
        candidateEmail: 'a@test.com',
        cvUrl: 'https://cv-a.pdf',
        cvFileName: 'cv-a.pdf',
      );
      expect(provider.isJobApplied('job_user_a'), isTrue);
      expect(provider.applications.length, 1);

      repo.candidateApps = [
        JobApplication(
          id: 'app_user_b',
          jobId: 'job_user_b',
          jobTitle: 'QA Lead',
          companyId: 'comp_2',
          companyName: 'Nova',
          candidateId: 'cand_B',
          candidateName: 'User B',
          candidateEmail: 'b@test.com',
          cvUrl: 'https://cv-b.pdf',
          cvFileName: 'cv-b.pdf',
          appliedAt: DateTime(2026, 5, 1),
        ),
      ];

      await provider.loadApplications('cand_B');
      expect(provider.isJobApplied('job_user_a'), isFalse);
      expect(provider.isJobApplied('job_user_b'), isTrue);
      expect(provider.applications.length, 1);
      expect(provider.applications.first.candidateId, 'cand_B');

      provider.listenApplications('cand_C');
      repo.candidateController.add(const []);
      await Future<void>.delayed(Duration.zero);
      expect(provider.applications, isEmpty);
      expect(provider.isJobApplied('job_user_b'), isFalse);

      provider.dispose();
      repo.dispose();
    });

    test('TakeHomeChallengeModel.fromMap and toMap preserve candidateId and applicationId', () {
      final model = TakeHomeChallengeModel.fromMap({
        'companyId': 'comp_1',
        'companyName': 'Acme',
        'jobId': 'job_10',
        'jobTitle': 'Mobile Lead',
        'candidateId': 'cand_42',
        'applicationId': 'app_84',
        'title': 'Offline Sync Task',
        'brief': 'Implement offline cache',
        'detailedInstructions': 'Support Hive & Firestore sync',
        'difficulty': 'INTERMEDIATE',
        'deadlineDays': 4,
        'createdAt': '2026-05-10T10:00:00.000Z',
      }, 'chal_1');

      expect(model.id, 'chal_1');
      expect(model.candidateId, 'cand_42');
      expect(model.applicationId, 'app_84');

      final serialized = model.toMap();
      expect(serialized['candidateId'], 'cand_42');
      expect(serialized['applicationId'], 'app_84');
      expect(serialized['jobId'], 'job_10');
    });

    test('InterviewSlot and InterviewModel convert UTC timestamps to local time and synthesize scheduledAt fallback', () {
      const utcStart = '2026-05-10T14:00:00.000Z';
      const utcEnd = '2026-05-10T14:45:00.000Z';

      final slot = InterviewSlot.fromMap({
        'slotIndex': 0,
        'startTime': utcStart,
        'endTime': utcEnd,
        'isSelected': true,
      }, 0);

      expect(slot.startTime.isUtc, isFalse);
      expect(slot.endTime.isUtc, isFalse);
      expect(slot.startTime, DateTime.parse(utcStart).toLocal());
      expect(slot.endTime, DateTime.parse(utcEnd).toLocal());

      final interview = InterviewModel.fromMap({
        'applicationId': 'app_1',
        'jobId': 'job_1',
        'jobTitle': 'Flutter Engineer',
        'companyId': 'comp_1',
        'companyName': 'Apex',
        'candidateId': 'cand_1',
        'candidateName': 'Sara',
        'candidateEmail': 'sara@test.com',
        'title': 'Technical Interview',
        'scheduledAt': utcStart,
        'durationMinutes': 60,
      }, 'int_1');

      expect(interview.slots.length, 1);
      expect(interview.slots.first.isSelected, isTrue);
      expect(interview.slots.first.startTime.isUtc, isFalse);
      expect(
        interview.slots.first.endTime.difference(interview.slots.first.startTime).inMinutes,
        60,
      );
    });

    test('NotificationModel.fromMap preserves entityId and data payload', () {
      final notif = NotificationModel.fromMap({
        'userId': 'comp_1',
        'title': 'New Applicant',
        'body': 'Sara applied for Flutter Engineer',
        'type': 'NEW_APPLICATION',
        'actionUrl': '/company/applicants?applicationId=app_99&jobId=job_42',
        'entityId': 'app_99',
        'data': {'jobId': 'job_42', 'candidateId': 'cand_1'},
        'isRead': false,
      }, 'notif_1');

      expect(notif.id, 'notif_1');
      expect(notif.type, NotificationType.application);
      expect(notif.entityId, 'app_99');
      expect(notif.data?['jobId'], 'job_42');
      expect(notif.data?['candidateId'], 'cand_1');
    });
  });
}
