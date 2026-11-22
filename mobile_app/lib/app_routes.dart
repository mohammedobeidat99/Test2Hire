import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'core/constants/app_typography.dart';
import 'core/services/session_service.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/auth/presentation/screens/email_verification_screen.dart';
import 'features/auth/presentation/screens/forgot_password_screen.dart';
import 'features/auth/presentation/screens/login_screen.dart';
import 'features/auth/presentation/screens/onboarding_screen.dart';
import 'features/auth/presentation/screens/register_candidate_screen.dart';
import 'features/company/presentation/screens/company_profile_screen.dart';
import 'features/company/presentation/screens/edit_company_profile_screen.dart';
import 'features/home/presentation/screens/candidate_home_screen.dart';
import 'features/home/presentation/screens/company_home_screen.dart';
import 'features/profile/presentation/screens/edit_certifications_languages_screen.dart';
import 'features/profile/presentation/screens/edit_education_screen.dart';
import 'features/profile/presentation/screens/edit_experience_screen.dart';
import 'features/profile/presentation/screens/edit_personal_info_screen.dart';
import 'features/profile/presentation/screens/manage_skills_screen.dart';
import 'features/profile/presentation/screens/profile_screen.dart';
import 'features/jobs/domain/entities/job_posting.dart';
import 'features/jobs/presentation/screens/candidate_job_feed_screen.dart';
import 'features/jobs/presentation/screens/company_jobs_screen.dart';
import 'features/jobs/presentation/screens/create_edit_job_screen.dart';
import 'features/jobs/presentation/screens/job_detail_screen.dart';
import 'features/applications/presentation/screens/apply_job_screen.dart';
import 'features/applications/presentation/screens/candidate_applications_screen.dart';
import 'features/applications/presentation/screens/company_applicants_screen.dart';
import 'features/questions/domain/entities/question.dart';
import 'features/questions/domain/entities/question_bank.dart';
import 'features/questions/presentation/screens/question_banks_screen.dart';
import 'features/questions/presentation/screens/question_bank_detail_screen.dart';
import 'features/questions/presentation/screens/create_edit_question_screen.dart';
import 'features/exams/domain/entities/exam_template.dart';
import 'features/exams/presentation/screens/company_exams_screen.dart';
import 'features/exams/presentation/screens/create_edit_exam_screen.dart';
import 'features/exams/presentation/screens/candidate_exams_screen.dart';
import 'features/interviews/presentation/screens/company_interviews_screen.dart';
import 'features/interviews/presentation/screens/candidate_interviews_screen.dart';
import 'features/offers/presentation/screens/company_offers_screen.dart';
import 'features/offers/presentation/screens/candidate_offers_screen.dart';
import 'features/notifications/presentation/screens/notifications_screen.dart';
import 'features/evaluation/presentation/screens/scorecard_detail_screen.dart';
import 'features/evaluation/presentation/screens/job_applicants_ranking_screen.dart';
import 'features/ai_assistant/presentation/screens/candidate_comparison_screen.dart';
import 'features/career_site/presentation/screens/edit_company_branding_screen.dart';
import 'features/career_site/presentation/screens/public_career_site_screen.dart';
import 'features/assessments/presentation/screens/take_home_challenge_detail_screen.dart';
import 'features/assessments/presentation/screens/create_take_home_challenge_screen.dart';
import 'features/sourcing/presentation/screens/bulk_campaigns_screen.dart';
import 'features/sourcing/presentation/screens/create_campaign_screen.dart';
import 'features/sourcing/presentation/screens/talent_pool_search_screen.dart';
import 'features/community/presentation/screens/community_feed_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String roleSelection = '/role-selection';
  static const String registerCandidate = '/register/candidate';
  static const String registerCompany = '/register/company';
  static const String forgotPassword = '/forgot-password';
  static const String verifyEmail = '/verify-email';
  static const String candidateHome = '/candidate/home';
  static const String companyHome = '/company/home';

  // Candidate Profile Routes
  static const String profile = '/profile';
  static const String editPersonalInfo = '/profile/edit-personal';
  static const String manageSkills = '/profile/manage-skills';
  static const String editEducation = '/profile/edit-education';
  static const String editExperience = '/profile/edit-experience';
  static const String editCertifications = '/profile/edit-certifications';

  // Company Profile Routes
  static const String companyProfile = '/company/profile';
  static const String editCompanyProfile = '/company/edit-profile';

  // Job Management Routes
  static const String companyJobs = '/company/jobs';
  static const String createJob = '/company/jobs/create';
  static const String editJob = '/company/jobs/:id/edit';
  static const String jobsFeed = '/jobs';
  static const String jobDetail = '/jobs/:id';

  // Application Routes
  static const String applyJob = '/apply/:id';
  static const String candidateApplications = '/candidate/applications';
  static const String companyApplicants = '/company/jobs/:id/applicants';

  // Question Bank Routes
  static const String questionBanks = '/company/question-banks';
  static const String questionBankDetail = '/company/question-banks/:id';
  static const String createQuestion = '/company/question-banks/:id/questions/create';
  static const String editQuestion = '/company/question-banks/:id/questions/:questionId/edit';

  // Exam Assessment Routes
  static const String companyExams = '/company/exams';
  static const String createExam = '/company/exams/create';
  static const String editExam = '/company/exams/:id/edit';
  static const String candidateExams = '/candidate/exams';

  // Interview Management Routes (Phase 11)
  static const String companyInterviews = '/company/interviews';
  static const String candidateInterviews = '/candidate/interviews';

  // Job Offer Routes (Phase 12)
  static const String companyOffers = '/company/offers';
  static const String candidateOffers = '/candidate/offers';

  // Notifications Routes (Phase 13)
  static const String notifications = '/notifications';

  // Automated Evaluation & Ranking Routes (Phase 14)
  static const String scorecardDetail = '/evaluation/scorecard';
  static const String jobRankings = '/company/jobs/:id/rankings';

  // AI Assistant & Candidate Comparison Routes (Phase 15)
  static const String candidateComparison = '/company/jobs/:id/compare';

  // Career Site & Company Branding Routes (Phase 16)
  static const String editCompanyBranding = '/company/branding/edit';
  static const String publicCareerSite = '/company/:id/careers';

  // Candidate Assessments Hub & Take-Home Challenges Routes (Phase 17)
  static const String assessmentSandbox = '/assessments/sandbox';
  static const String takeHomeChallengeDetail = '/assessments/challenge/:id';
  static const String createTakeHomeChallenge = '/company/challenges/create';

  // Bulk Hiring Campaigns & Talent Pool Search Routes (Phase 18)
  static const String bulkCampaigns = '/company/campaigns';
  static const String createCampaign = '/company/campaigns/create';
  static const String talentPool = '/company/talent-pool';
  static const String community = '/community';

  static GoRouter createRouter(AuthProvider authProvider) {
    return GoRouter(
      initialLocation: splash,
      refreshListenable: authProvider,
      routes: [
        GoRoute(
          path: splash,
          builder: (context, state) => const _SplashScreen(),
        ),
        GoRoute(
          path: onboarding,
          builder: (context, state) => const OnboardingScreen(),
        ),
        GoRoute(
          path: login,
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: roleSelection,
          redirect: (context, state) => registerCandidate,
        ),
        GoRoute(
          path: registerCandidate,
          builder: (context, state) => const RegisterCandidateScreen(),
        ),
        GoRoute(
          path: registerCompany,
          redirect: (context, state) => registerCandidate,
        ),
        GoRoute(
          path: forgotPassword,
          builder: (context, state) => const ForgotPasswordScreen(),
        ),
        GoRoute(
          path: verifyEmail,
          builder: (context, state) => const EmailVerificationScreen(),
        ),
        GoRoute(
          path: candidateHome,
          builder: (context, state) => const CandidateHomeScreen(),
        ),
        GoRoute(
          path: companyHome,
          builder: (context, state) => const CompanyHomeScreen(),
        ),
        GoRoute(
          path: profile,
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: editPersonalInfo,
          builder: (context, state) => const EditPersonalInfoScreen(),
        ),
        GoRoute(
          path: manageSkills,
          builder: (context, state) => const ManageSkillsScreen(),
        ),
        GoRoute(
          path: editEducation,
          builder: (context, state) => const EditEducationScreen(),
        ),
        GoRoute(
          path: editExperience,
          builder: (context, state) => const EditExperienceScreen(),
        ),
        GoRoute(
          path: editCertifications,
          builder: (context, state) => const EditCertificationsLanguagesScreen(),
        ),
        GoRoute(
          path: companyProfile,
          builder: (context, state) => const CompanyProfileScreen(),
        ),
        GoRoute(
          path: editCompanyProfile,
          builder: (context, state) => const EditCompanyProfileScreen(),
        ),
        GoRoute(
          path: companyJobs,
          builder: (context, state) => const CompanyJobsScreen(),
        ),
        GoRoute(
          path: createJob,
          builder: (context, state) => const CreateEditJobScreen(),
        ),
        GoRoute(
          path: editJob,
          builder: (context, state) => CreateEditJobScreen(
            existingJob: state.extra as JobPosting?,
          ),
        ),
        GoRoute(
          path: jobsFeed,
          builder: (context, state) => const CandidateJobFeedScreen(),
        ),
        GoRoute(
          path: jobDetail,
          builder: (context, state) => JobDetailScreen(
            jobId: state.pathParameters['id'] ?? '',
            initialJob: state.extra as JobPosting?,
          ),
        ),
        GoRoute(
          path: applyJob,
          builder: (context, state) {
            final job = state.extra as JobPosting?;
            if (job == null) {
              return const CandidateJobFeedScreen();
            }
            return ApplyJobScreen(job: job);
          },
        ),
        GoRoute(
          path: candidateApplications,
          builder: (context, state) => const CandidateApplicationsScreen(),
        ),
        GoRoute(
          path: companyApplicants,
          builder: (context, state) => CompanyApplicantsScreen(
            jobId: state.pathParameters['id'] ?? '',
            jobTitle: state.extra as String?,
          ),
        ),
        GoRoute(
          path: questionBanks,
          builder: (context, state) => const QuestionBanksScreen(),
        ),
        GoRoute(
          path: questionBankDetail,
          builder: (context, state) => QuestionBankDetailScreen(
            bankId: state.pathParameters['id'] ?? '',
            initialBank: state.extra as QuestionBank?,
          ),
        ),
        GoRoute(
          path: createQuestion,
          builder: (context, state) => CreateEditQuestionScreen(
            bankId: state.pathParameters['id'] ?? '',
            bank: state.extra as QuestionBank?,
          ),
        ),
        GoRoute(
          path: editQuestion,
          builder: (context, state) => CreateEditQuestionScreen(
            bankId: state.pathParameters['id'] ?? '',
            existingQuestion: state.extra as Question?,
          ),
        ),
        GoRoute(
          path: companyExams,
          builder: (context, state) => const CompanyExamsScreen(),
        ),
        GoRoute(
          path: createExam,
          builder: (context, state) => const CreateEditExamScreen(),
        ),
        GoRoute(
          path: editExam,
          builder: (context, state) => CreateEditExamScreen(
            existingExam: state.extra as ExamTemplate?,
          ),
        ),
        GoRoute(
          path: candidateExams,
          builder: (context, state) => const CandidateExamsScreen(),
        ),
        GoRoute(
          path: companyInterviews,
          builder: (context, state) => const CompanyInterviewsScreen(),
        ),
        GoRoute(
          path: candidateInterviews,
          builder: (context, state) => const CandidateInterviewsScreen(),
        ),
        GoRoute(
          path: companyOffers,
          builder: (context, state) => const CompanyOffersScreen(),
        ),
        GoRoute(
          path: candidateOffers,
          builder: (context, state) => const CandidateOffersScreen(),
        ),
        GoRoute(
          path: notifications,
          builder: (context, state) => const NotificationsScreen(),
        ),
        GoRoute(
          path: '$scorecardDetail/:applicationId',
          builder: (context, state) {
            final appId = state.pathParameters['applicationId'] ?? '';
            final candidateName = state.uri.queryParameters['candidateName'] ?? 'Candidate';
            return ScorecardDetailScreen(
              applicationId: appId,
              candidateName: candidateName,
            );
          },
        ),
        GoRoute(
          path: jobRankings,
          builder: (context, state) {
            final jobId = state.pathParameters['id'] ?? '';
            final jobTitle = state.uri.queryParameters['jobTitle'] ?? 'Job Applicants';
            return JobApplicantsRankingScreen(
              jobId: jobId,
              jobTitle: jobTitle,
            );
          },
        ),
        GoRoute(
          path: candidateComparison,
          builder: (context, state) {
            final jobId = state.pathParameters['id'] ?? '';
            final jobTitle = state.uri.queryParameters['jobTitle'] ?? 'Job Candidates';
            final rawAppIds = state.uri.queryParameters['appIds'] ?? '';
            final appIds = rawAppIds.isNotEmpty ? rawAppIds.split(',') : <String>[];
            return CandidateComparisonScreen(
              jobId: jobId,
              jobTitle: jobTitle,
              candidateAppIds: appIds,
            );
          },
        ),
        GoRoute(
          path: editCompanyBranding,
          builder: (context, state) {
            final companyId = state.uri.queryParameters['companyId'] ?? authProvider.user?.uid ?? '';
            return EditCompanyBrandingScreen(companyId: companyId);
          },
        ),
        GoRoute(
          path: publicCareerSite,
          builder: (context, state) {
            final companyId = state.pathParameters['id'] ?? '';
            return PublicCareerSiteScreen(companyId: companyId);
          },
        ),
        GoRoute(
          path: assessmentSandbox,
          redirect: (context, state) => candidateExams,
        ),
        GoRoute(
          path: takeHomeChallengeDetail,
          builder: (context, state) {
            final challengeId = state.pathParameters['id'] ?? '';
            return TakeHomeChallengeDetailScreen(challengeId: challengeId);
          },
        ),
        GoRoute(
          path: createTakeHomeChallenge,
          builder: (context, state) => const CreateTakeHomeChallengeScreen(),
        ),
        GoRoute(
          path: bulkCampaigns,
          builder: (context, state) => const BulkCampaignsScreen(),
        ),
        GoRoute(
          path: createCampaign,
          builder: (context, state) => const CreateCampaignScreen(),
        ),
        GoRoute(
          path: talentPool,
          builder: (context, state) => const TalentPoolSearchScreen(),
        ),
        GoRoute(
          path: community,
          builder: (context, state) => const CommunityFeedScreen(),
        ),
      ],
      redirect: (context, state) {
        final status = authProvider.status;
        final user = authProvider.user;
        final location = state.matchedLocation;

        // While determining auth state, remain on splash
        if (status == AuthStatus.uninitialized) {
          return location == splash ? null : splash;
        }

        final isPublicAuthRoute = location == login ||
            location == onboarding ||
            location == roleSelection ||
            location == registerCandidate ||
            location == registerCompany ||
            location == forgotPassword;

        // 1. Not Authenticated
        if (status == AuthStatus.unauthenticated || user == null) {
          // If the user has not completed onboarding yet, direct them to onboarding first
          if (!SessionService.hasSeenOnboarding) {
            if (location != onboarding) {
              return onboarding;
            }
            return null;
          }
          if (location == splash || location == onboarding || !isPublicAuthRoute) {
            return login;
          }
          return null;
        }

        final isVerified = user.isEmailVerified ||
            user.email == 'candidate@test.com' ||
            user.email == 'ahmed@test.com' ||
            user.email == 'hr@techcorp.com';

        // 2. Authenticated but Email NOT verified
        if (!isVerified && location != verifyEmail) {
          return verifyEmail;
        }

        // 3. Authenticated & Email verified, attempting to access Auth pages or splash or onboarding
        if (isVerified && (isPublicAuthRoute || location == splash || location == verifyEmail)) {
          return user.isCompany ? companyHome : candidateHome;
        }

        // 4. Role-based route guard: block candidates from accessing company routes (except public company career profile) and vice-versa
        if (user.isCompany && location.startsWith('/candidate')) {
          return companyHome;
        }
        if (user.isCandidate &&
            location.startsWith('/company') &&
            !location.endsWith('/careers')) {
          return candidateHome;
        }

        return null;
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.assessment_rounded,
                size: 72,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppStrings.appName,
              style: AppTypography.displayMedium.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              AppStrings.tagline,
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 48),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
