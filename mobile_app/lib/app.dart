import 'core/providers/locale_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'app_routes.dart';
import 'core/constants/app_strings.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/presentation/providers/auth_provider.dart';
import 'features/company/data/repositories/company_repository_impl.dart';
import 'features/company/presentation/providers/company_provider.dart';
import 'features/applications/data/datasources/application_remote_data_source.dart';
import 'features/applications/data/repositories/application_repository_impl.dart';
import 'features/applications/presentation/providers/candidate_applications_provider.dart';
import 'features/applications/presentation/providers/company_applicants_provider.dart';
import 'features/jobs/data/datasources/job_remote_data_source.dart';
import 'features/jobs/data/repositories/job_repository_impl.dart';
import 'features/jobs/presentation/providers/candidate_jobs_provider.dart';
import 'features/jobs/presentation/providers/company_jobs_provider.dart';
import 'features/profile/data/repositories/profile_repository_impl.dart';
import 'features/profile/presentation/providers/profile_provider.dart';
import 'features/questions/data/datasources/question_remote_data_source.dart';
import 'features/questions/data/repositories/question_repository_impl.dart';
import 'features/questions/presentation/providers/question_banks_provider.dart';
import 'features/questions/presentation/providers/questions_provider.dart';
import 'features/exams/data/datasources/exam_remote_data_source.dart';
import 'features/exams/data/repositories/exam_repository_impl.dart';
import 'features/exams/presentation/providers/company_exams_provider.dart';
import 'features/exams/presentation/providers/candidate_exams_provider.dart';
import 'features/interviews/data/datasources/interview_remote_data_source.dart';
import 'features/interviews/data/repositories/interview_repository_impl.dart';
import 'features/interviews/presentation/providers/company_interviews_provider.dart';
import 'features/interviews/presentation/providers/candidate_interviews_provider.dart';
import 'features/offers/data/datasources/offer_remote_data_source.dart';
import 'features/offers/data/repositories/offer_repository_impl.dart';
import 'features/offers/presentation/providers/company_offers_provider.dart';
import 'features/offers/presentation/providers/candidate_offers_provider.dart';
import 'features/notifications/data/datasources/notification_remote_data_source.dart';
import 'features/notifications/data/repositories/notification_repository_impl.dart';
import 'features/notifications/presentation/providers/notifications_provider.dart';
import 'features/evaluation/data/datasources/evaluation_remote_data_source.dart';
import 'features/evaluation/data/repositories/evaluation_repository_impl.dart';
import 'features/evaluation/presentation/providers/evaluation_provider.dart';
import 'features/ai_assistant/data/datasources/ai_assistant_remote_data_source.dart';
import 'features/ai_assistant/data/repositories/ai_assistant_repository_impl.dart';
import 'features/ai_assistant/presentation/providers/ai_assistant_provider.dart';
import 'features/career_site/data/datasources/career_page_remote_data_source.dart';
import 'features/career_site/data/repositories/career_page_repository_impl.dart';
import 'features/career_site/presentation/providers/career_page_provider.dart';
import 'features/assessments/data/datasources/assessments_remote_data_source.dart';
import 'features/assessments/data/repositories/assessments_hub_repository_impl.dart';
import 'features/assessments/presentation/providers/assessments_hub_provider.dart';
import 'features/sourcing/data/datasources/sourcing_remote_data_source.dart';
import 'features/sourcing/data/repositories/sourcing_repository_impl.dart';
import 'features/sourcing/presentation/providers/sourcing_provider.dart';
import 'features/community/presentation/providers/community_provider.dart';

class Test2HireApp extends StatefulWidget {
  final AuthProvider? authProvider;
  final ProfileProvider? profileProvider;
  final CompanyProvider? companyProvider;
  final CompanyJobsProvider? companyJobsProvider;
  final CandidateJobsProvider? candidateJobsProvider;
  final CandidateApplicationsProvider? candidateApplicationsProvider;
  final CompanyApplicantsProvider? companyApplicantsProvider;
  final QuestionBanksProvider? questionBanksProvider;
  final QuestionsProvider? questionsProvider;
  final CompanyExamsProvider? companyExamsProvider;
  final CandidateExamsProvider? candidateExamsProvider;
  final CompanyInterviewsProvider? companyInterviewsProvider;
  final CandidateInterviewsProvider? candidateInterviewsProvider;
  final CompanyOffersProvider? companyOffersProvider;
  final CandidateOffersProvider? candidateOffersProvider;
  final NotificationsProvider? notificationsProvider;
  final EvaluationProvider? evaluationProvider;
  final AiAssistantProvider? aiAssistantProvider;
  final CareerPageProvider? careerPageProvider;
  final AssessmentsHubProvider? assessmentsHubProvider;
  final SourcingProvider? sourcingProvider;
  final CommunityProvider? communityProvider;

  const Test2HireApp({
    super.key,
    this.authProvider,
    this.profileProvider,
    this.companyProvider,
    this.companyJobsProvider,
    this.candidateJobsProvider,
    this.candidateApplicationsProvider,
    this.companyApplicantsProvider,
    this.questionBanksProvider,
    this.questionsProvider,
    this.companyExamsProvider,
    this.candidateExamsProvider,
    this.companyInterviewsProvider,
    this.candidateInterviewsProvider,
    this.companyOffersProvider,
    this.candidateOffersProvider,
    this.notificationsProvider,
    this.evaluationProvider,
    this.aiAssistantProvider,
    this.careerPageProvider,
    this.assessmentsHubProvider,
    this.sourcingProvider,
    this.communityProvider,
  });

  @override
  State<Test2HireApp> createState() => _Test2HireAppState();
}

class _Test2HireAppState extends State<Test2HireApp> {
  final LocaleProvider _localeProvider = LocaleProvider();

  late final AuthProvider _authProvider;
  late final ProfileProvider _profileProvider;
  late final CompanyProvider _companyProvider;
  late final CompanyJobsProvider _companyJobsProvider;
  late final CandidateJobsProvider _candidateJobsProvider;
  late final CandidateApplicationsProvider _candidateApplicationsProvider;
  late final CompanyApplicantsProvider _companyApplicantsProvider;
  late final QuestionBanksProvider _questionBanksProvider;
  late final QuestionsProvider _questionsProvider;
  late final CompanyExamsProvider _companyExamsProvider;
  late final CandidateExamsProvider _candidateExamsProvider;
  late final CompanyInterviewsProvider _companyInterviewsProvider;
  late final CandidateInterviewsProvider _candidateInterviewsProvider;
  late final CompanyOffersProvider _companyOffersProvider;
  late final CandidateOffersProvider _candidateOffersProvider;
  late final NotificationsProvider _notificationsProvider;
  late final EvaluationProvider _evaluationProvider;
  late final AiAssistantProvider _aiAssistantProvider;
  late final CareerPageProvider _careerPageProvider;
  late final AssessmentsHubProvider _assessmentsHubProvider;
  late final SourcingProvider _sourcingProvider;
  late final CommunityProvider _communityProvider;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authProvider = widget.authProvider ??
        AuthProvider(authRepository: AuthRepositoryImpl());
    _profileProvider = widget.profileProvider ??
        ProfileProvider(profileRepository: ProfileRepositoryImpl());
    _companyProvider = widget.companyProvider ??
        CompanyProvider(companyRepository: CompanyRepositoryImpl());

    final jobRepo =
        JobRepositoryImpl(remoteDataSource: JobRemoteDataSourceImpl());
    _companyJobsProvider = widget.companyJobsProvider ??
        CompanyJobsProvider(jobRepository: jobRepo);
    _candidateJobsProvider = widget.candidateJobsProvider ??
        CandidateJobsProvider(jobRepository: jobRepo);

    final appRepo = ApplicationRepositoryImpl(
        remoteDataSource: ApplicationRemoteDataSourceImpl());
    _candidateApplicationsProvider = widget.candidateApplicationsProvider ??
        CandidateApplicationsProvider(repository: appRepo);
    _companyApplicantsProvider = widget.companyApplicantsProvider ??
        CompanyApplicantsProvider(repository: appRepo);

    final questionRepo = QuestionRepositoryImpl(
        remoteDataSource: QuestionRemoteDataSourceImpl());
    _questionBanksProvider = widget.questionBanksProvider ??
        QuestionBanksProvider(repository: questionRepo);
    _questionsProvider = widget.questionsProvider ??
        QuestionsProvider(repository: questionRepo);

    final examRepo = ExamRepositoryImpl(
        remoteDataSource: ExamRemoteDataSourceImpl());
    _companyExamsProvider = widget.companyExamsProvider ??
        CompanyExamsProvider(repository: examRepo);
    _candidateExamsProvider = widget.candidateExamsProvider ??
        CandidateExamsProvider(repository: examRepo);

    final interviewRepo = InterviewRepositoryImpl(
        remoteDataSource: InterviewRemoteDataSourceImpl());
    _companyInterviewsProvider = widget.companyInterviewsProvider ??
        CompanyInterviewsProvider(repository: interviewRepo);
    _candidateInterviewsProvider = widget.candidateInterviewsProvider ??
        CandidateInterviewsProvider(repository: interviewRepo);

    final offerRepo = OfferRepositoryImpl(
        remoteDataSource: OfferRemoteDataSourceImpl());
    _companyOffersProvider = widget.companyOffersProvider ??
        CompanyOffersProvider(repository: offerRepo);
    _candidateOffersProvider = widget.candidateOffersProvider ??
        CandidateOffersProvider(repository: offerRepo);

    final notificationRepo = NotificationRepositoryImpl(
        remoteDataSource: NotificationRemoteDataSourceImpl());
    _notificationsProvider = widget.notificationsProvider ??
        NotificationsProvider(repository: notificationRepo);

    final evaluationRepo = EvaluationRepositoryImpl(
        remoteDataSource: EvaluationRemoteDataSourceImpl());
    _evaluationProvider = widget.evaluationProvider ??
        EvaluationProvider(repository: evaluationRepo);

    final aiAssistantRepo = AiAssistantRepositoryImpl(
        remoteDataSource: AiAssistantRemoteDataSourceImpl());
    _aiAssistantProvider = widget.aiAssistantProvider ??
        AiAssistantProvider(repository: aiAssistantRepo);

    final careerPageRepo = CareerPageRepositoryImpl(
        remoteDataSource: CareerPageRemoteDataSourceImpl());
    _careerPageProvider = widget.careerPageProvider ??
        CareerPageProvider(repository: careerPageRepo);

    final assessmentsHubRepo = AssessmentsHubRepositoryImpl(
        remoteDataSource: AssessmentsRemoteDataSourceImpl());
    _assessmentsHubProvider = widget.assessmentsHubProvider ??
        AssessmentsHubProvider(repository: assessmentsHubRepo);

    final sourcingRepo = SourcingRepositoryImpl(
        remoteDataSource: SourcingRemoteDataSourceImpl());
    _sourcingProvider = widget.sourcingProvider ??
        SourcingProvider(repository: sourcingRepo);

    _communityProvider = widget.communityProvider ?? CommunityProvider();

    _router = AppRoutes.createRouter(_authProvider);
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
                ChangeNotifierProvider<LocaleProvider>.value(value: _localeProvider),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        ChangeNotifierProvider<ProfileProvider>.value(value: _profileProvider),
        ChangeNotifierProvider<CompanyProvider>.value(value: _companyProvider),
        ChangeNotifierProvider<CompanyJobsProvider>.value(
            value: _companyJobsProvider),
        ChangeNotifierProvider<CandidateJobsProvider>.value(
            value: _candidateJobsProvider),
        ChangeNotifierProvider<CandidateApplicationsProvider>.value(
            value: _candidateApplicationsProvider),
        ChangeNotifierProvider<CompanyApplicantsProvider>.value(
            value: _companyApplicantsProvider),
        ChangeNotifierProvider<QuestionBanksProvider>.value(
            value: _questionBanksProvider),
        ChangeNotifierProvider<QuestionsProvider>.value(
            value: _questionsProvider),
        ChangeNotifierProvider<CompanyExamsProvider>.value(
            value: _companyExamsProvider),
        ChangeNotifierProvider<CandidateExamsProvider>.value(
            value: _candidateExamsProvider),
        ChangeNotifierProvider<CompanyInterviewsProvider>.value(
            value: _companyInterviewsProvider),
        ChangeNotifierProvider<CandidateInterviewsProvider>.value(
            value: _candidateInterviewsProvider),
        ChangeNotifierProvider<CompanyOffersProvider>.value(
            value: _companyOffersProvider),
        ChangeNotifierProvider<CandidateOffersProvider>.value(
            value: _candidateOffersProvider),
        ChangeNotifierProvider<NotificationsProvider>.value(
            value: _notificationsProvider),
        ChangeNotifierProvider<EvaluationProvider>.value(
            value: _evaluationProvider),
        ChangeNotifierProvider<AiAssistantProvider>.value(
            value: _aiAssistantProvider),
        ChangeNotifierProvider<CareerPageProvider>.value(
            value: _careerPageProvider),
        ChangeNotifierProvider<AssessmentsHubProvider>.value(
            value: _assessmentsHubProvider),
        ChangeNotifierProvider<SourcingProvider>.value(
            value: _sourcingProvider),
        ChangeNotifierProvider<CommunityProvider>.value(
            value: _communityProvider),
      ],
      child: Selector<LocaleProvider, Locale>(
        selector: (_, localeProv) => localeProv.locale,
        builder: (context, locale, _) {
          return MaterialApp.router(
            locale: locale,
        title: AppStrings.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light,
                localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: _router,
          );
        },
      ),
    );
  }
}
