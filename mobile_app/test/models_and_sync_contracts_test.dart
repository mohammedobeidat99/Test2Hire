import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/applications/data/models/job_application_model.dart';
import 'package:mobile_app/features/applications/domain/entities/job_application.dart';
import 'package:mobile_app/features/auth/data/models/user_model.dart';
import 'package:mobile_app/features/career_site/data/models/company_career_page_model.dart';
import 'package:mobile_app/features/career_site/domain/entities/company_career_page.dart';
import 'package:mobile_app/features/community/domain/entities/community_post.dart';
import 'package:mobile_app/features/company/data/models/company_profile_model.dart';
import 'package:mobile_app/features/evaluation/data/models/candidate_scorecard_model.dart';
import 'package:mobile_app/features/evaluation/domain/entities/candidate_scorecard.dart';
import 'package:mobile_app/features/exams/data/models/exam_template_model.dart';
import 'package:mobile_app/features/exams/domain/entities/exam_template.dart';
import 'package:mobile_app/features/interviews/data/models/interview_model.dart';
import 'package:mobile_app/features/interviews/domain/entities/interview.dart';
import 'package:mobile_app/features/jobs/data/models/job_posting_model.dart';
import 'package:mobile_app/features/jobs/domain/entities/job_posting.dart';
import 'package:mobile_app/features/offers/data/models/job_offer_model.dart';
import 'package:mobile_app/features/offers/domain/entities/job_offer.dart';
import 'package:mobile_app/features/profile/data/models/candidate_profile_model.dart';
import 'package:mobile_app/features/profile/domain/entities/candidate_profile.dart';
import 'package:mobile_app/features/questions/data/models/question_bank_model.dart';
import 'package:mobile_app/features/questions/data/models/question_model.dart';
import 'package:mobile_app/features/questions/domain/entities/question.dart';

import 'helpers/fake_firestore_helpers.dart';

void main() {
  group('JobPosting & JobPostingModel serialization and contracts', () {
    test('round-trips full JobPosting via fromFirestore, fromDomain, and toFirestore', () {
      final created = DateTime(2026, 10, 1, 9, 30);
      final deadline = DateTime(2026, 12, 31, 23, 59);
      final doc = FakeDocumentSnapshot('job_1', {
        'companyId': 'comp_1',
        'companyName': 'Apex Global',
        'companyLogoUrl': 'https://example.com/logo.png',
        'title': 'Senior Flutter Engineer',
        'description': 'Build cross-platform apps.',
        'requirements': ['3+ yrs Flutter', 'Dart 3'],
        'responsibilities': ['Lead architecture'],
        'benefits': ['Health insurance'],
        'jobType': 'CONTRACT',
        'workplaceType': 'HYBRID',
        'experienceLevel': 'SENIOR',
        'location': {'city': 'Amman', 'country': 'Jordan'},
        'salaryRange': {
          'min': 3000,
          'max': 4500,
          'currency': 'JOD',
          'isNegotiable': true,
          'isDisclosed': true,
        },
        'requiredSkills': ['Flutter', 'Dart'],
        'optionalSkills': ['GraphQL'],
        'status': 'PUBLISHED',
        'deadline': Timestamp.fromDate(deadline),
        'applicantsCount': 14,
        'examId': 'exam_42',
        'createdAt': Timestamp.fromDate(created),
        'updatedAt': Timestamp.fromDate(created),
      });

      final model = JobPostingModel.fromFirestore(doc);

      expect(model.id, 'job_1');
      expect(model.companyName, 'Apex Global');
      expect(model.jobType, JobType.contract);
      expect(model.workplaceType, WorkplaceType.hybrid);
      expect(model.experienceLevel, ExperienceLevel.senior);
      expect(model.location.formatted, 'Amman, Jordan');
      expect(model.salaryRange?.formatted, '3000 - 4500 JOD');
      expect(model.status, JobStatus.published);
      expect(model.isPublished, isTrue);
      expect(model.applicantsCount, 14);
      expect(model.examId, 'exam_42');
      expect(model.deadline, deadline);
      expect(model.createdAt, created);

      final roundTripped = JobPostingModel.fromDomain(model).toFirestore();
      expect(roundTripped['jobType'], 'CONTRACT');
      expect(roundTripped['workplaceType'], 'HYBRID');
      expect(roundTripped['experienceLevel'], 'SENIOR');
      expect(roundTripped['status'], 'PUBLISHED');
      expect(roundTripped['location'], {'city': 'Amman', 'country': 'Jordan'});
      expect((roundTripped['salaryRange'] as Map)['currency'], 'JOD');
      expect(roundTripped['deadline'], isA<Timestamp>());
      expect(roundTripped['updatedAt'], isA<FieldValue>());
    });

    test('parses web legacy type alias, String location, and defaults safely', () {
      final model = JobPostingModel.fromMap({
        'type': 'part-time',
        'workplaceType': 'remote',
        'location': 'Dubai, United Arab Emirates',
      }, 'job_legacy');

      expect(model.id, 'job_legacy');
      expect(model.companyName, '');
      expect(model.jobType, JobType.partTime);
      expect(model.workplaceType, WorkplaceType.remote);
      expect(model.experienceLevel, ExperienceLevel.mid);
      expect(model.location.city, 'Dubai');
      expect(model.location.country, 'United Arab Emirates');
      expect(model.status, JobStatus.draft);
      expect(model.isDraft, isTrue);

      final emptyLocationModel = JobPostingModel.fromMap({}, 'job_empty');
      expect(emptyLocationModel.location.formatted, '');
      expect(emptyLocationModel.requiredSkills, isEmpty);
      expect(emptyLocationModel.hasExpired, isFalse);
    });

    test('JobSalaryRange.formatted and enum extensions handle all edge cases', () {
      expect(
        const JobSalaryRange(min: 2000, max: 5000, isDisclosed: false).formatted,
        'Confidential',
      );
      expect(
        const JobSalaryRange(min: 2500, currency: 'EUR').formatted,
        'From 2500 EUR',
      );
      expect(
        const JobSalaryRange(max: 6000, currency: 'USD').formatted,
        'Up to 6000 USD',
      );
      expect(
        const JobSalaryRange(isNegotiable: true).formatted,
        'Negotiable',
      );
      expect(const JobSalaryRange().formatted, 'Competitive');

      expect(JobTypeExtension.fromString('full time'), JobType.fullTime);
      expect(JobTypeExtension.fromString('UNKNOWN'), JobType.fullTime);
      expect(JobType.internship.localizedName(true), 'تدريب عملي');
      expect(WorkplaceType.onSite.localizedName(true), 'حضوري');
      expect(ExperienceLevel.lead.localizedName(true), 'قائد تقني / فريق');
      expect(JobStatusExtension.fromString('ARCHIVED'), JobStatus.archived);
      expect(JobStatusExtension.fromString('CLOSED'), JobStatus.closed);

      final expiredJob = JobPosting(
        id: 'j_exp',
        companyId: 'c1',
        companyName: 'Co',
        title: 'Old Job',
        description: 'Desc',
        location: const JobLocation(city: 'Amman', country: 'JO'),
        deadline: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(expiredJob.hasExpired, isTrue);
    });
  });

  group('JobApplication & JobApplicationModel serialization and contracts', () {
    test('parses Timestamp, ISO String, and epoch millis dates + AiParsedCv', () {
      final appliedMs = DateTime(2026, 11, 1, 8, 0).millisecondsSinceEpoch;
      final expiresIso = '2026-12-01T12:00:00.000Z';
      final updatedTs = Timestamp.fromDate(DateTime(2026, 11, 5, 10, 0));

      final app = JobApplicationModel.fromMap({
        'jobId': 'job_10',
        'jobTitle': 'Backend Architect',
        'companyId': 'comp_10',
        'companyName': 'CloudNine',
        'candidateId': 'cand_10',
        'candidateName': 'Lina Ahmad',
        'candidateEmail': 'lina@example.com',
        'cvUrl': 'https://storage.example.com/cv.pdf',
        'cvFileName': 'lina_cv.pdf',
        'status': 'EXAM_COMPLETED',
        'examScore': 88.5,
        'examAttemptId': 'att_10',
        'examToken': 'tok_xyz',
        'examDurationMinutes': 60,
        'examExpiresAt': expiresIso,
        'aiParsedCv': {
          'extractedSkills': ['Dart', 'Node.js', 'SQL'],
          'yearsOfExperience': 6,
          'educationLevel': 'MSc Computer Science',
          'summary': 'Strong distributed systems engineer.',
          'matchedSkills': ['Node.js', 'SQL'],
          'missingSkills': ['Kubernetes'],
          'cvMatchScore': 82,
          'aiRecommendation': 'STRONG_MATCH',
          'aiRationale': 'Exceeds core backend requirements.',
        },
        'cvMatchScore': 82,
        'overallFitScore': 86,
        'aiRecommendation': 'STRONG_MATCH',
        'appliedAt': appliedMs,
        'updatedAt': updatedTs,
      }, 'app_10');

      expect(app.id, 'app_10');
      expect(app.status, ApplicationStatus.examCompleted);
      expect(app.examScore, 88.5);
      expect(app.examExpiresAt, DateTime.parse(expiresIso));
      expect(
        app.appliedAt,
        DateTime.fromMillisecondsSinceEpoch(appliedMs),
      );
      expect(app.updatedAt, updatedTs.toDate());
      expect(app.aiParsedCv?.extractedSkills, ['Dart', 'Node.js', 'SQL']);
      expect(app.aiParsedCv?.yearsOfExperience, 6);
      expect(app.isTopPerformer, isTrue);
      expect(app.hasExamAssigned, isTrue);

      final firestoreMap = JobApplicationModel.fromDomain(app).toFirestore();
      expect(firestoreMap['status'], 'EXAM_COMPLETED');
      expect((firestoreMap['aiParsedCv'] as Map)['cvMatchScore'], 82);
      expect(firestoreMap['examExpiresAt'], isA<Timestamp>());
    });

    test('handles status transitions, terminal flags, and top performer boundary', () {
      for (final status in ApplicationStatus.values) {
        final raw = status.toShortString();
        expect(ApplicationStatusExtension.fromString(raw), status);
      }
      expect(
        ApplicationStatusExtension.fromString('UNRECOGNIZED'),
        ApplicationStatus.applied,
      );

      const boundaryBelow = JobApplication(
        id: 'a1',
        jobId: 'j1',
        jobTitle: 'Dev',
        companyId: 'c1',
        companyName: 'Co',
        candidateId: 'u1',
        candidateName: 'User',
        candidateEmail: 'u@test.com',
        cvUrl: 'https://cv',
        cvFileName: 'cv.pdf',
        status: ApplicationStatus.underReview,
        examScore: 69.9,
      );
      expect(boundaryBelow.canWithdraw, isTrue);
      expect(boundaryBelow.isTopPerformer, isFalse);
      expect(boundaryBelow.isTerminal, isFalse);

      final boundaryAt70 = boundaryBelow.copyWith(
        status: ApplicationStatus.rejected,
        examScore: 70.0,
      );
      expect(boundaryAt70.isTopPerformer, isTrue);
      expect(boundaryAt70.canWithdraw, isFalse);
      expect(boundaryAt70.isTerminal, isTrue);
    });
  });

  group('ExamTemplate, ExamAttempt & QuestionModel cross-platform contracts', () {
    test('ExamTemplateModel round-trips cross-platform exam configuration flags', () {
      final created = DateTime(2026, 10, 12, 14, 0);
      final doc = FakeDocumentSnapshot('exam_1', {
        'companyId': 'comp_1',
        'title': 'Flutter System Design',
        'description': 'Covers state management and async architecture.',
        'durationMinutes': 90,
        'passingPercentage': 75,
        'questionIds': ['q1', 'q2', 'q3'],
        'bankIds': ['bank_1'],
        'randomizeQuestions': false,
        'randomizeOptions': true,
        'proctoringEnabled': true,
        'totalQuestions': 3,
        'totalPoints': 30,
        'isArchived': false,
        'createdAt': Timestamp.fromDate(created),
        'updatedAt': created.toIso8601String(),
      });

      final template = ExamTemplateModel.fromFirestore(doc);
      expect(template.id, 'exam_1');
      expect(template.durationMinutes, 90);
      expect(template.passingPercentage, 75);
      expect(template.questionIds, ['q1', 'q2', 'q3']);
      expect(template.randomizeQuestions, isFalse);
      expect(template.randomizeOptions, isTrue);
      expect(template.proctoringEnabled, isTrue);
      expect(template.createdAt, created);
      expect(template.updatedAt, created);

      final map = ExamTemplateModel.fromEntity(template).toFirestore();
      expect(map['durationMinutes'], 90);
      expect(map['questionIds'], ['q1', 'q2', 'q3']);
      expect(map['proctoringEnabled'], isTrue);
      expect(map['updatedAt'], isA<FieldValue>());
    });

    test('ExamAttemptModel & AssignExamResult verify web portal sync contract', () {
      final attemptDoc = FakeDocumentSnapshot('att_99', {
        'examId': 'exam_1',
        'examTitle': 'Flutter System Design',
        'companyId': 'comp_1',
        'candidateId': 'cand_1',
        'candidateName': 'Tariq',
        'candidateEmail': 'tariq@test.com',
        'jobId': 'job_1',
        'jobTitle': 'Mobile Lead',
        'applicationId': 'app_1',
        'token': 'SECURE_TOK_99',
        'status': 'GRADED',
        'durationMinutes': 60,
        'passingPercentage': 70,
        'totalQuestions': 10,
        'totalPoints': 100,
        'score': 85.0,
        'passed': true,
        'invitationSentAt': '2026-11-01T10:00:00.000Z',
        'expiresAt': '2026-11-08T10:00:00.000Z',
      });

      final attempt = ExamAttemptModel.fromFirestore(attemptDoc);
      expect(attempt.status, ExamAttemptStatus.graded);
      expect(attempt.isCompleted, isTrue);
      expect(attempt.isPending, isFalse);
      expect(attempt.isInProgress, isFalse);
      expect(attempt.score, 85.0);
      expect(attempt.passed, isTrue);
      expect(
        attempt.assessmentUrl,
        'https://test2here-72346.web.app/exam/SECURE_TOK_99',
      );

      for (final status in ExamAttemptStatus.values) {
        expect(
          ExamAttemptStatusExtension.fromString(status.toShortString()),
          status,
        );
      }
      expect(
        ExamAttemptStatusExtension.fromString('ASSIGNED'),
        ExamAttemptStatus.invited,
      );
      expect(
        ExamAttemptStatusExtension.fromString('COMPLETED'),
        ExamAttemptStatus.completed,
      );
      expect(
        ExamAttemptStatusExtension.fromString('TERMINATED'),
        ExamAttemptStatus.terminated,
      );
      expect(
        ExamAttemptStatusExtension.fromString('TERMINATED_VIOLATION'),
        ExamAttemptStatus.terminated,
      );

      final webCompletedAttempt = ExamAttemptModel.fromFirestore(
        FakeDocumentSnapshot('att_web_done', {
          'token': 'TOK_DONE',
          'status': 'COMPLETED',
        }),
      );
      expect(webCompletedAttempt.isCompleted, isTrue);
      expect(webCompletedAttempt.isPending, isFalse);

      final webTerminatedAttempt = ExamAttemptModel.fromFirestore(
        FakeDocumentSnapshot('att_web_term', {
          'token': 'TOK_TERM',
          'status': 'TERMINATED',
        }),
      );
      expect(webTerminatedAttempt.isTerminated, isTrue);
      expect(webTerminatedAttempt.isPending, isFalse);

      const assignResult = AssignExamResult(
        attemptId: 'att_99',
        token: 'SECURE_TOK_99',
        durationMinutes: 60,
      );
      expect(
        assignResult.assessmentUrl,
        'https://test2here-72346.web.app/exam/SECURE_TOK_99',
      );
    });

    test('QuestionModel serializes all 5 QuestionTypes (SINGLE_CHOICE, MULTIPLE_CHOICE, TRUE_FALSE, CODING, SHORT_ANSWER)', () {
      final typesToVerify = <Map<String, dynamic>>[
        {
          'id': 'q_single',
          'type': 'SINGLE_CHOICE',
          'difficulty': 'EASY',
          'points': 5,
          'options': [
            {'id': 'a', 'text': 'Const constructor', 'isCorrect': true},
            {'id': 'b', 'text': 'Dynamic cast', 'isCorrect': false},
          ],
          'correctAnswers': ['a'],
          'expectedMcq': true,
          'expectedCoding': false,
        },
        {
          'id': 'q_multi',
          'type': 'MULTIPLE_CHOICE',
          'difficulty': 'MEDIUM',
          'points': 10,
          'options': [
            {'id': 'a', 'text': 'StatelessWidget', 'isCorrect': true},
            {'id': 'b', 'text': 'StatefulWidget', 'isCorrect': true},
            {'id': 'c', 'text': 'ThreadWidget', 'isCorrect': false},
          ],
          'correctAnswers': ['a', 'b'],
          'expectedMcq': true,
          'expectedCoding': false,
        },
        {
          'id': 'q_tf',
          'type': 'TRUE_FALSE',
          'difficulty': 'EASY',
          'points': 2,
          'options': [
            {'id': 'true', 'text': 'True', 'isCorrect': true},
            {'id': 'false', 'text': 'False', 'isCorrect': false},
          ],
          'correctAnswers': ['true'],
          'expectedMcq': true,
          'expectedCoding': false,
        },
        {
          'id': 'q_code',
          'type': 'CODING',
          'difficulty': 'HARD',
          'points': 25,
          'options': <Map<String, dynamic>>[],
          'correctAnswers': <String>[],
          'sampleCodeSnippet': 'List<int> twoSum(List<int> nums, int target) {}',
          'programmingLanguage': 'dart',
          'expectedMcq': false,
          'expectedCoding': true,
        },
        {
          'id': 'q_short',
          'type': 'SHORT_ANSWER',
          'difficulty': 'MEDIUM',
          'points': 10,
          'options': <Map<String, dynamic>>[],
          'correctAnswers': ['BuildContext', 'widget tree'],
          'expectedMcq': false,
          'expectedCoding': false,
        },
      ];

      for (final spec in typesToVerify) {
        final doc = FakeDocumentSnapshot(spec['id'] as String, {
          'bankId': 'bank_1',
          'companyId': 'comp_1',
          'title': 'Title for ${spec['type']}',
          'description': 'Prompt for ${spec['type']}',
          'type': spec['type'],
          'difficulty': spec['difficulty'],
          'points': spec['points'],
          'options': spec['options'],
          'correctAnswers': spec['correctAnswers'],
          'sampleCodeSnippet': spec['sampleCodeSnippet'],
          'programmingLanguage': spec['programmingLanguage'],
          'tags': ['flutter', 'dart'],
        });

        final parsed = QuestionModel.fromFirestore(doc);
        expect(parsed.type.toShortString(), spec['type']);
        expect(parsed.difficulty.toShortString(), spec['difficulty']);
        expect(parsed.isMCQ, spec['expectedMcq']);
        expect(parsed.isCoding, spec['expectedCoding']);
        expect(parsed.points, spec['points']);
        expect(parsed.sampleCodeSnippet, spec['sampleCodeSnippet']);
        expect(parsed.programmingLanguage, spec['programmingLanguage']);

        final serialized = QuestionModel.fromEntity(parsed).toFirestore();
        expect(serialized['type'], spec['type']);
        expect(serialized['difficulty'], spec['difficulty']);
        expect(serialized['correctAnswers'], spec['correctAnswers']);
        expect((serialized['options'] as List).length, (spec['options'] as List).length);
      }

      // Unknown enum fallbacks remain safe
      expect(
        QuestionTypeExtension.fromString('UNKNOWN_TYPE'),
        QuestionType.singleChoice,
      );
      expect(
        QuestionDifficultyExtension.fromString('UNKNOWN_DIFF'),
        QuestionDifficulty.medium,
      );
    });

    test('QuestionBankModel parses and serializes bank metadata', () {
      final doc = FakeDocumentSnapshot('bank_1', {
        'companyId': 'comp_1',
        'title': 'Mobile Engineering Bank',
        'description': 'Flutter & iOS questions',
        'category': 'Mobile',
        'tags': ['dart', 'swift'],
        'questionsCount': 12,
        'totalPoints': 120,
        'isArchived': false,
      });

      final bank = QuestionBankModel.fromFirestore(doc);
      expect(bank.id, 'bank_1');
      expect(bank.category, 'Mobile');
      expect(bank.questionsCount, 12);
      expect(bank.totalPoints, 120);

      final updated = bank.copyWith(questionsCount: 15);
      final serialized = QuestionBankModel.fromEntity(updated).toFirestore();
      expect(serialized['questionsCount'], 15);
      expect(serialized['title'], 'Mobile Engineering Bank');
    });
  });

  group('CompanyProfileModel & CompanyCareerPageModel contracts', () {
    test('CompanyProfileModel parses Firestore doc and verification statuses', () {
      final verifiedAt = DateTime(2026, 9, 15, 11, 0);
      final doc = FakeDocumentSnapshot('comp_1', {
        'ownerUid': 'owner_1',
        'name': 'Apex Technologies',
        'legalName': 'Apex Tech LLC',
        'industry': 'FinTech',
        'website': 'https://apextech.example.com',
        'logoUrl': 'https://apextech.example.com/logo.png',
        'description': 'Enterprise hiring platform.',
        'location': {
          'city': 'Amman',
          'country': 'Jordan',
          'address': 'King Hussein Business Park',
        },
        'contactEmail': 'hr@apextech.example.com',
        'contactPhone': '+962790000000',
        'teamSize': '51-200',
        'verificationStatus': 'APPROVED',
        'verifiedAt': Timestamp.fromDate(verifiedAt),
      });

      final profile = CompanyProfileModel.fromFirestore(doc);
      expect(profile.id, 'comp_1');
      expect(profile.isApproved, isTrue);
      expect(profile.isPending, isFalse);
      expect(
        profile.location?.formatted,
        'King Hussein Business Park, Amman, Jordan',
      );
      expect(profile.verifiedAt, verifiedAt);

      final toMap = profile.toFirestore();
      expect(toMap['name'], 'Apex Technologies');
      expect((toMap['location'] as Map)['city'], 'Amman');
      expect(toMap['industry'], 'FinTech');
    });

    test('CompanyCareerPageModel parses Map/String location and branding color fallbacks', () {
      final careerPage = CompanyCareerPageModel.fromMap({
        'name': 'Apex Labs',
        'industry': 'AI',
        'website': 'https://apexlabs.io',
        'coverImageUrl': 'https://apexlabs.io/cover.jpg',
        'location': {'city': '', 'country': 'Jordan'},
        'verificationStatus': 'APPROVED',
        'branding': {
          'tagline': 'Build the future',
          'brandColorHex': '#0F766E',
          'perksAndBenefits': ['Remote flexibility'],
        },
      }, 'comp_2', 5);

      expect(careerPage.companyId, 'comp_2');
      expect(careerPage.companyName, 'Apex Labs');
      expect(careerPage.location, 'Jordan');
      expect(careerPage.activeJobsCount, 5);
      expect(careerPage.isApproved, isTrue);
      expect(careerPage.branding.websiteUrl, 'https://apexlabs.io');
      expect(careerPage.branding.coverImageUrl, 'https://apexlabs.io/cover.jpg');
      expect(careerPage.branding.brandColor, const Color(0xFF0F766E));

      // Invalid hex color falls back safely to default #1E40AF
      const invalidBranding = CompanyBranding(brandColorHex: 'NOT_HEX');
      expect(invalidBranding.brandColor, const Color(0xFF1E40AF));

      final map = careerPage.toMap();
      expect(map['isApproved'], isTrue);
      expect((map['branding'] as Map)['tagline'], 'Build the future');
    });
  });

  group('CommunityPost & CommunityComment contracts', () {
    test('parses timestamps, clamps negative counts, and falls back to likedBy.length', () {
      final millis = DateTime(2026, 10, 20, 12, 0).millisecondsSinceEpoch;
      final post = CommunityPost.fromMap({
        'authorId': 'u_1',
        'authorName': 'Sara',
        'authorHeadline': 'Tech Lead',
        'authorRole': 'CANDIDATE',
        'content': 'Clean architecture tip',
        'tags': ['Flutter'],
        'likedBy': ['u_2', 'u_3', 'u_4'],
        // Omit likesCount to verify fallback to likedBy.length
        'commentsCount': -4,
        'createdAt': millis,
        'updatedAt': '2026-10-21T08:00:00.000Z',
      }, 'post_99');

      expect(post.likesCount, 3);
      expect(post.commentsCount, 0);
      expect(post.isLikedBy('u_3'), isTrue);
      expect(post.isLikedBy('u_9'), isFalse);
      expect(post.createdAt, DateTime.fromMillisecondsSinceEpoch(millis));
      expect(post.updatedAt, DateTime.parse('2026-10-21T08:00:00.000Z'));

      final clampedNegativeLikes = CommunityPost.fromMap({
        'likesCount': -10,
      }, 'post_neg');
      expect(clampedNegativeLikes.likesCount, 0);
      expect(clampedNegativeLikes.authorName, 'Professional Member');

      final serialized = post.toMap();
      expect(serialized['createdAt'], isA<Timestamp>());
      expect(serialized['updatedAt'], isA<Timestamp>());
      expect(serialized['likedBy'], ['u_2', 'u_3', 'u_4']);
    });

    test('CommunityComment round-trips map fields and copyWith', () {
      final created = DateTime(2026, 11, 2, 9, 15);
      final comment = CommunityComment.fromMap({
        'postId': 'post_1',
        'authorId': 'u_5',
        'authorName': 'Omar',
        'authorHeadline': 'Recruiter',
        'authorRole': 'COMPANY',
        'content': 'Great point!',
        'createdAt': Timestamp.fromDate(created),
      }, 'c_1');

      expect(comment.createdAt, created);
      final edited = comment.copyWith(content: 'Updated point');
      expect(edited.content, 'Updated point');
      final map = edited.toMap();
      expect(map['postId'], 'post_1');
      expect(map['content'], 'Updated point');
      expect(map['createdAt'], isA<Timestamp>());
    });
  });

  group('JobOffer & JobOfferModel serialization and contracts', () {
    test('round-trips JobOfferModel and evaluates expiration and equality rules', () {
      final past = DateTime.now().subtract(const Duration(days: 2));
      final future = DateTime.now().add(const Duration(days: 5));

      final expiredPendingOffer = JobOfferModel.fromMap({
        'id': 'offer_exp',
        'applicationId': 'app_1',
        'jobId': 'job_1',
        'jobTitle': 'Staff Engineer',
        'companyId': 'comp_1',
        'companyName': 'Apex',
        'candidateId': 'cand_1',
        'candidateName': 'Nour',
        'candidateEmail': 'nour@test.com',
        'offeredSalary': 120000,
        'salaryCurrency': 'USD',
        'salaryPeriod': 'ANNUAL',
        'status': 'PENDING_CANDIDATE',
        'benefits': ['Equity', 'Remote stipend'],
        'expiresAt': past.toIso8601String(),
      });

      expect(expiredPendingOffer.id, 'offer_exp');
      expect(expiredPendingOffer.isPending, isTrue);
      expect(expiredPendingOffer.isExpired, isTrue);
      expect(expiredPendingOffer.formattedSalary, 'USD 120,000 / year');

      // Accepted offers are NOT marked expired even when expiresAt is in the past
      final acceptedPastOffer = expiredPendingOffer.copyWith(
        status: OfferStatus.accepted,
      );
      expect(acceptedPastOffer.isExpired, isFalse);
      expect(
        acceptedPastOffer ==
            expiredPendingOffer.copyWith(status: OfferStatus.declined),
        isTrue,
      );
      // JobOffer.operator== checks runtimeType == other.runtimeType
      expect(acceptedPastOffer == expiredPendingOffer, isFalse);

      final activeOffer = expiredPendingOffer.copyWith(expiresAt: future);
      expect(activeOffer.isExpired, isFalse);

      final map = JobOfferModel.fromFirestore(
        FakeDocumentSnapshot('offer_fs', expiredPendingOffer.toMap()),
      );
      expect(map.id, 'offer_fs');
      expect(map.benefits, ['Equity', 'Remote stipend']);
    });
  });

  group('Interview & InterviewModel serialization and contracts', () {
    test('round-trips slots, feedback, and activeSlot boundary selection', () {
      final s0Start = DateTime(2026, 11, 20, 10, 0);
      final s0End = DateTime(2026, 11, 20, 10, 45);
      final s1Start = DateTime(2026, 11, 21, 15, 0);
      final s1End = DateTime(2026, 11, 21, 15, 45);

      final interview = InterviewModel.fromMap({
        'applicationId': 'app_7',
        'jobId': 'job_7',
        'jobTitle': 'Platform Engineer',
        'companyId': 'comp_7',
        'companyName': 'Apex',
        'candidateId': 'cand_7',
        'candidateName': 'Zaid',
        'candidateEmail': 'zaid@test.com',
        'title': 'Architecture Deep Dive',
        'type': 'VIDEO_CALL',
        'status': 'CONFIRMED',
        'meetingUrl': 'https://meet.example.com/xyz',
        'slots': [
          {
            'slotIndex': 0,
            'startTime': Timestamp.fromDate(s0Start),
            'endTime': s0End.toIso8601String(),
            'isSelected': false,
          },
          {
            'slotIndex': 1,
            'startTime': s1Start.toIso8601String(),
            'endTime': s1End.toIso8601String(),
            'isSelected': true,
          },
        ],
        'selectedSlotIndex': 1,
        'interviewerNames': ['CTO', 'Principal Engineer'],
        'feedback': {
          'interviewerId': 'int_uid',
          'score': 9,
          'recommendation': 'RECOMMEND_HIRE',
          'notes': 'Strong concurrency fundamentals',
          'submittedAt': '2026-11-22T12:00:00.000Z',
        },
      }, 'iv_7');

      expect(interview.isConfirmed, isTrue);
      expect(interview.type, InterviewType.videoCall);
      expect(interview.activeSlot?.slotIndex, 1);
      expect(interview.activeSlot?.startTime, s1Start);
      expect(interview.feedback?.recommendation, 'RECOMMEND_HIRE');
      expect(interview.interviewerNames, ['CTO', 'Principal Engineer']);

      // Out-of-bounds selectedSlotIndex safely falls back to slots.first
      final outOfBounds = interview.copyWith(selectedSlotIndex: 99);
      expect(outOfBounds.activeSlot?.slotIndex, 0);

      // Empty slots returns null
      final noSlots = interview.copyWith(slots: const []);
      expect(noSlots.activeSlot, isNull);

      final serialized = InterviewModel.fromDomain(interview).toFirestore();
      expect(serialized['type'], 'VIDEO_CALL');
      expect(serialized['status'], 'CONFIRMED');
      expect((serialized['slots'] as List).length, 2);
      expect((serialized['feedback'] as Map)['score'], 9);
    });
  });

  group('UserModel, CandidateProfileModel & CandidateScorecardModel contracts', () {
    test('UserModel parses roles and merges Auth/Firestore email verification', () {
      final doc = FakeDocumentSnapshot('u_1', {
        'email': 'recruiter@apex.com',
        'role': 'COMPANY',
        'fullName': 'Maya',
        'isEmailVerified': false,
        'isProfileComplete': true,
        'createdAt': Timestamp.fromDate(DateTime(2026, 8, 1)),
      });

      final model = UserModel.fromFirestore(doc, isEmailVerified: true);
      expect(model.isCompany, isTrue);
      expect(model.isCandidate, isFalse);
      expect(model.isEmailVerified, isTrue);
      expect(model.toMap()['role'], 'COMPANY');
    });

    test('CandidateProfileModel computes completionPercentage and sets completeness >= 70', () {
      const emptyProfile = CandidateProfileModel(
        uid: 'c0',
        email: 'c0@test.com',
        fullName: '',
      );
      expect(emptyProfile.completionPercentage, 0);
      expect(emptyProfile.toFirestore()['isProfileComplete'], isFalse);

      final fullProfile = CandidateProfileModel.fromFirestore(
        FakeDocumentSnapshot('c1', {
          'email': 'c1@test.com',
          'fullName': 'Ahmad',
          'headline': 'Flutter Dev',
          'about': 'Passionate builder',
          'skills': ['Flutter', 'Dart', 'Firebase'],
          'education': [
            {
              'institution': 'JUST',
              'degree': 'BSc',
              'fieldOfStudy': 'CS',
              'startDate': Timestamp.fromDate(DateTime(2018, 9, 1)),
            },
          ],
          'experience': [
            {
              'company': 'Apex',
              'title': 'Engineer',
              'startDate': Timestamp.fromDate(DateTime(2022, 1, 1)),
            },
          ],
          'certifications': [
            {
              'name': 'Google Associate',
              'issuingOrganization': 'Google',
              'issueDate': Timestamp.fromDate(DateTime(2024, 5, 1)),
            },
          ],
          'languages': [
            {'language': 'Arabic', 'proficiency': 'NATIVE'},
          ],
          'cvUrl': 'https://example.com/cv.pdf',
        }),
      );

      expect(fullProfile.completionPercentage, 100);
      expect(fullProfile.languages.first.proficiency, LanguageProficiency.native);
      expect(fullProfile.toFirestore()['isProfileComplete'], isTrue);
    });

    test('CandidateScorecardModel serializes breakdown, weights, and recommendation', () {
      final doc = FakeDocumentSnapshot('sc_1', {
        'applicationId': 'app_1',
        'jobId': 'job_1',
        'companyId': 'comp_1',
        'candidateId': 'cand_1',
        'candidateName': 'Ahmad',
        'candidateEmail': 'ahmad@test.com',
        'compositeScore': 91,
        'ranking': 1,
        'recommendation': 'STRONGLY_RECOMMENDED',
        'weights': {
          'cvMatchWeight': 0.25,
          'examScoreWeight': 0.45,
          'interviewWeight': 0.30,
        },
        'breakdown': {
          'cvMatchScore': 88,
          'examScore': 95,
          'interviewScore': 89,
        },
        'calculatedAt': '2026-11-10T10:00:00.000Z',
      });

      final card = CandidateScorecardModel.fromFirestore(doc);
      expect(card.compositeScore, 91);
      expect(card.ranking, 1);
      expect(card.recommendation, ScorecardRecommendation.stronglyRecommended);
      expect(card.weights.examScoreWeight, 0.45);
      expect(card.breakdown.examScore, 95);

      final map = card.toMap();
      expect(map['recommendation'], 'STRONGLY_RECOMMENDED');
      expect((map['breakdown'] as Map)['interviewScore'], 89);
    });
  });

  group('Null Firestore Snapshot & Cross-Platform Status Regression Safety', () {
    test('all *Model.fromFirestore factories tolerate null/missing document data', () {
      final missingDoc = FakeDocumentSnapshot('missing_1', null, exists: false);

      expect(JobPostingModel.fromFirestore(missingDoc).id, 'missing_1');
      expect(JobApplicationModel.fromFirestore(missingDoc).id, 'missing_1');
      expect(ExamTemplateModel.fromFirestore(missingDoc).id, 'missing_1');
      expect(ExamAttemptModel.fromFirestore(missingDoc).id, 'missing_1');
      expect(QuestionModel.fromFirestore(missingDoc).id, 'missing_1');
      expect(QuestionBankModel.fromFirestore(missingDoc).id, 'missing_1');
      expect(CompanyProfileModel.fromFirestore(missingDoc).id, 'missing_1');
      expect(
        CompanyCareerPageModel.fromFirestore(missingDoc).companyId,
        'missing_1',
      );
      expect(JobOfferModel.fromFirestore(missingDoc).id, 'missing_1');
      expect(InterviewModel.fromFirestore(missingDoc).id, 'missing_1');
      expect(UserModel.fromFirestore(missingDoc).uid, 'missing_1');
      expect(CandidateProfileModel.fromFirestore(missingDoc).uid, 'missing_1');
      expect(CandidateScorecardModel.fromFirestore(missingDoc).id, 'missing_1');
    });

    test('ApplicationStatus maps OFFER_EXTENDED, HIRED, SHORTLISTED, and EXAM_PENDING', () {
      expect(
        ApplicationStatusExtension.fromString('OFFER_EXTENDED'),
        ApplicationStatus.offerExtended,
      );
      expect(
        ApplicationStatusExtension.fromString('HIRED'),
        ApplicationStatus.hired,
      );
      expect(
        ApplicationStatusExtension.fromString('SHORTLISTED'),
        ApplicationStatus.shortlisted,
      );
      expect(
        ApplicationStatusExtension.fromString('EXAM_PENDING'),
        ApplicationStatus.examPending,
      );
    });
  });
}
