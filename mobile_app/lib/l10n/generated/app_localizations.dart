import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Test2Hire'**
  String get appTitle;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navJobs.
  ///
  /// In en, this message translates to:
  /// **'Jobs'**
  String get navJobs;

  /// No description provided for @navCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get navCommunity;

  /// No description provided for @navAssessments.
  ///
  /// In en, this message translates to:
  /// **'Assessments'**
  String get navAssessments;

  /// No description provided for @navProfile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back,'**
  String get welcomeBack;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search jobs, companies, skills, or discussions...'**
  String get searchHint;

  /// No description provided for @searchJobsHint.
  ///
  /// In en, this message translates to:
  /// **'Search jobs, companies, posts...'**
  String get searchJobsHint;

  /// No description provided for @applied.
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get applied;

  /// No description provided for @assessments.
  ///
  /// In en, this message translates to:
  /// **'Assessments'**
  String get assessments;

  /// No description provided for @interviews.
  ///
  /// In en, this message translates to:
  /// **'Interviews'**
  String get interviews;

  /// No description provided for @offers.
  ///
  /// In en, this message translates to:
  /// **'Offers'**
  String get offers;

  /// No description provided for @examAssigned.
  ///
  /// In en, this message translates to:
  /// **'EXAMINATION ASSIGNED'**
  String get examAssigned;

  /// No description provided for @officialExamPortal.
  ///
  /// In en, this message translates to:
  /// **'Official Exam Portal'**
  String get officialExamPortal;

  /// No description provided for @startExam.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startExam;

  /// No description provided for @offerReceived.
  ///
  /// In en, this message translates to:
  /// **'OFFICIAL OFFER RECEIVED'**
  String get offerReceived;

  /// No description provided for @reviewOffer.
  ///
  /// In en, this message translates to:
  /// **'Review'**
  String get reviewOffer;

  /// No description provided for @interviewInvitation.
  ///
  /// In en, this message translates to:
  /// **'INTERVIEW INVITATION'**
  String get interviewInvitation;

  /// No description provided for @selectSlot.
  ///
  /// In en, this message translates to:
  /// **'Select Slot'**
  String get selectSlot;

  /// No description provided for @actionRequiredSlot.
  ///
  /// In en, this message translates to:
  /// **'Action required: Select time slot'**
  String get actionRequiredSlot;

  /// No description provided for @shareUpdateHint.
  ///
  /// In en, this message translates to:
  /// **'Share an update, insight, or advice...'**
  String get shareUpdateHint;

  /// No description provided for @photoAction.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get photoAction;

  /// No description provided for @insightAction.
  ///
  /// In en, this message translates to:
  /// **'Insight'**
  String get insightAction;

  /// No description provided for @questionAction.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get questionAction;

  /// No description provided for @topCompaniesHiring.
  ///
  /// In en, this message translates to:
  /// **'Top Companies Hiring'**
  String get topCompaniesHiring;

  /// No description provided for @explore.
  ///
  /// In en, this message translates to:
  /// **'Explore'**
  String get explore;

  /// No description provided for @allFeed.
  ///
  /// In en, this message translates to:
  /// **'🌟 All Feed'**
  String get allFeed;

  /// No description provided for @discussionsFeed.
  ///
  /// In en, this message translates to:
  /// **'💬 Discussions'**
  String get discussionsFeed;

  /// No description provided for @recommendedJobsFeed.
  ///
  /// In en, this message translates to:
  /// **'💼 Recommended Jobs'**
  String get recommendedJobsFeed;

  /// No description provided for @sponsoredJob.
  ///
  /// In en, this message translates to:
  /// **'Sponsored Job Recommendation'**
  String get sponsoredJob;

  /// No description provided for @viewJob.
  ///
  /// In en, this message translates to:
  /// **'View Job'**
  String get viewJob;

  /// No description provided for @skillMatch.
  ///
  /// In en, this message translates to:
  /// **'Skill Match'**
  String get skillMatch;

  /// No description provided for @likeAction.
  ///
  /// In en, this message translates to:
  /// **'Like'**
  String get likeAction;

  /// No description provided for @likedAction.
  ///
  /// In en, this message translates to:
  /// **'Liked'**
  String get likedAction;

  /// No description provided for @commentAction.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get commentAction;

  /// No description provided for @shareAction.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareAction;

  /// No description provided for @likesCount.
  ///
  /// In en, this message translates to:
  /// **'{count} likes'**
  String likesCount(int count);

  /// No description provided for @commentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} comments'**
  String commentsCount(int count);

  /// No description provided for @hiringBadge.
  ///
  /// In en, this message translates to:
  /// **'Hiring'**
  String get hiringBadge;

  /// No description provided for @editPost.
  ///
  /// In en, this message translates to:
  /// **'Edit Post'**
  String get editPost;

  /// No description provided for @deletePost.
  ///
  /// In en, this message translates to:
  /// **'Delete Post'**
  String get deletePost;

  /// No description provided for @postDeleted.
  ///
  /// In en, this message translates to:
  /// **'Post deleted'**
  String get postDeleted;

  /// No description provided for @postCopied.
  ///
  /// In en, this message translates to:
  /// **'Post copied to clipboard!'**
  String get postCopied;

  /// No description provided for @commentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get commentsTitle;

  /// No description provided for @noCommentsYet.
  ///
  /// In en, this message translates to:
  /// **'No comments yet. Start the conversation!'**
  String get noCommentsYet;

  /// No description provided for @addCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Add a thoughtful comment...'**
  String get addCommentHint;

  /// No description provided for @createPostTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Professional Post'**
  String get createPostTitle;

  /// No description provided for @editPostTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Post'**
  String get editPostTitle;

  /// No description provided for @selectTopics.
  ///
  /// In en, this message translates to:
  /// **'Select Topics:'**
  String get selectTopics;

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add Photo'**
  String get addPhoto;

  /// No description provided for @publish.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get publish;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @postContentHint.
  ///
  /// In en, this message translates to:
  /// **'What career insight, advice, or update do you want to share?'**
  String get postContentHint;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back!'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign In To Your Candidate Account'**
  String get loginSubtitle;

  /// No description provided for @candidatePortal.
  ///
  /// In en, this message translates to:
  /// **'Candidate Portal'**
  String get candidatePortal;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @emailHint.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailHint;

  /// No description provided for @passwordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordHint;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'LOG IN'**
  String get loginButton;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @orContinueWith.
  ///
  /// In en, this message translates to:
  /// **'or continue with'**
  String get orContinueWith;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Google'**
  String get signInWithGoogle;

  /// No description provided for @noAccountPrompt.
  ///
  /// In en, this message translates to:
  /// **'Don\'\'t have an account?'**
  String get noAccountPrompt;

  /// No description provided for @signUpAction.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUpAction;

  /// No description provided for @emailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get emailRequired;

  /// No description provided for @passwordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get passwordRequired;

  /// No description provided for @upcomingAssessments.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Assessments'**
  String get upcomingAssessments;

  /// No description provided for @recommendedForYou.
  ///
  /// In en, this message translates to:
  /// **'Recommended for You'**
  String get recommendedForYou;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAll;

  /// No description provided for @copyCode.
  ///
  /// In en, this message translates to:
  /// **'Copy Code'**
  String get copyCode;

  /// No description provided for @accessCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Access code copied!'**
  String get accessCodeCopied;

  /// No description provided for @officialExamWebsite.
  ///
  /// In en, this message translates to:
  /// **'Take Exam on Official Website'**
  String get officialExamWebsite;

  /// No description provided for @examinationsTab.
  ///
  /// In en, this message translates to:
  /// **'Examinations'**
  String get examinationsTab;

  /// No description provided for @assignmentsTab.
  ///
  /// In en, this message translates to:
  /// **'Assignments'**
  String get assignmentsTab;

  /// No description provided for @profileStrength.
  ///
  /// In en, this message translates to:
  /// **'Profile Strength'**
  String get profileStrength;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @jobsRecruitmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Jobs & Recruitment'**
  String get jobsRecruitmentTitle;

  /// No description provided for @filterAndSortTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter & Sort'**
  String get filterAndSortTooltip;

  /// No description provided for @communityFeedTitle.
  ///
  /// In en, this message translates to:
  /// **'Professional Community'**
  String get communityFeedTitle;

  /// No description provided for @createPostTooltip.
  ///
  /// In en, this message translates to:
  /// **'Create Post'**
  String get createPostTooltip;

  /// No description provided for @assessmentsHeader.
  ///
  /// In en, this message translates to:
  /// **'Assessments & Assignments'**
  String get assessmentsHeader;

  /// No description provided for @haveExamAccessCode.
  ///
  /// In en, this message translates to:
  /// **'Have an Examination Access Code?'**
  String get haveExamAccessCode;

  /// No description provided for @enterExamKeyHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your unique exam key to verify eligibility and launch your timed examination.'**
  String get enterExamKeyHint;

  /// No description provided for @verifyAndStart.
  ///
  /// In en, this message translates to:
  /// **'Verify & Start'**
  String get verifyAndStart;

  /// No description provided for @pasteExamAccessCode.
  ///
  /// In en, this message translates to:
  /// **'Paste exam access code...'**
  String get pasteExamAccessCode;

  /// No description provided for @noAssignedExamsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Assigned Examinations Yet'**
  String get noAssignedExamsTitle;

  /// No description provided for @noAssignedExamsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When employers assign online technical assessments for your job applications, they will appear here with your unique access code.'**
  String get noAssignedExamsSubtitle;

  /// No description provided for @profileScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Professional Profile'**
  String get profileScreenTitle;

  /// No description provided for @browseOpenJobs.
  ///
  /// In en, this message translates to:
  /// **'Browse Open Jobs'**
  String get browseOpenJobs;

  /// No description provided for @editPersonalInfo.
  ///
  /// In en, this message translates to:
  /// **'Edit Personal Info'**
  String get editPersonalInfo;

  /// No description provided for @metricSavedJobs.
  ///
  /// In en, this message translates to:
  /// **'Saved Jobs'**
  String get metricSavedJobs;

  /// No description provided for @metricApplications.
  ///
  /// In en, this message translates to:
  /// **'Applications'**
  String get metricApplications;

  /// No description provided for @metricAssessments.
  ///
  /// In en, this message translates to:
  /// **'Assessments'**
  String get metricAssessments;

  /// No description provided for @metricAssignments.
  ///
  /// In en, this message translates to:
  /// **'Assignments'**
  String get metricAssignments;

  /// No description provided for @headlinePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Add a professional headline...'**
  String get headlinePlaceholder;

  /// No description provided for @aboutMeTitle.
  ///
  /// In en, this message translates to:
  /// **'About Me'**
  String get aboutMeTitle;

  /// No description provided for @noAboutPrompt.
  ///
  /// In en, this message translates to:
  /// **'No about summary added yet. Tap edit to write a summary of your skills and experience.'**
  String get noAboutPrompt;

  /// No description provided for @skillsSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Skills'**
  String get skillsSectionTitle;

  /// No description provided for @noSkillsPrompt.
  ///
  /// In en, this message translates to:
  /// **'No skills added yet. Add at least 3 skills to qualify for jobs.'**
  String get noSkillsPrompt;

  /// No description provided for @workExperienceTitle.
  ///
  /// In en, this message translates to:
  /// **'Work Experience'**
  String get workExperienceTitle;

  /// No description provided for @noExperienceRecorded.
  ///
  /// In en, this message translates to:
  /// **'No work experience recorded.'**
  String get noExperienceRecorded;

  /// No description provided for @educationSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get educationSectionTitle;

  /// No description provided for @noEducationHistory.
  ///
  /// In en, this message translates to:
  /// **'No education history added yet.'**
  String get noEducationHistory;

  /// No description provided for @certificationsAndLanguages.
  ///
  /// In en, this message translates to:
  /// **'Certifications & Languages'**
  String get certificationsAndLanguages;

  /// No description provided for @certificationsCount.
  ///
  /// In en, this message translates to:
  /// **'Certifications: {count}'**
  String certificationsCount(int count);

  /// No description provided for @languagesList.
  ///
  /// In en, this message translates to:
  /// **'Languages: {list}'**
  String languagesList(String list);

  /// No description provided for @none.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// No description provided for @communityActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Community Activity'**
  String get communityActivityTitle;

  /// No description provided for @noCommunityPostsYet.
  ///
  /// In en, this message translates to:
  /// **'You have not published any community posts yet.'**
  String get noCommunityPostsYet;

  /// No description provided for @cvCardTitle.
  ///
  /// In en, this message translates to:
  /// **'Curriculum Vitae (CV)'**
  String get cvCardTitle;

  /// No description provided for @cvReadyForApplications.
  ///
  /// In en, this message translates to:
  /// **'Ready for job applications'**
  String get cvReadyForApplications;

  /// No description provided for @downloadResume.
  ///
  /// In en, this message translates to:
  /// **'Download CV'**
  String get downloadResume;

  /// No description provided for @replaceResume.
  ///
  /// In en, this message translates to:
  /// **'Replace CV'**
  String get replaceResume;

  /// No description provided for @uploadResume.
  ///
  /// In en, this message translates to:
  /// **'Upload Resume / CV'**
  String get uploadResume;

  /// No description provided for @uploadResumePrompt.
  ///
  /// In en, this message translates to:
  /// **'Upload your CV in PDF format (Max 10MB). Having an attached resume is required when applying for jobs.'**
  String get uploadResumePrompt;

  /// No description provided for @deleteResumeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete Resume'**
  String get deleteResumeTooltip;

  /// No description provided for @profileCompleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Great job! Your profile meets the requirements to apply for jobs and take examinations.'**
  String get profileCompleteSuccess;

  /// No description provided for @profileIncompletePrompt.
  ///
  /// In en, this message translates to:
  /// **'Complete required sections (CV, Skills, Education) to reach at least 70% profile completeness.'**
  String get profileIncompletePrompt;

  /// No description provided for @profilePicUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated!'**
  String get profilePicUpdated;

  /// No description provided for @profilePicUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Photo upload failed: {error}'**
  String profilePicUploadFailed(String error);

  /// No description provided for @resumeUploadedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Resume / CV uploaded successfully.'**
  String get resumeUploadedSuccess;

  /// No description provided for @searchJobsPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Search by job title, company, or skill...'**
  String get searchJobsPlaceholder;

  /// No description provided for @allJobsTab.
  ///
  /// In en, this message translates to:
  /// **'All Jobs'**
  String get allJobsTab;

  /// No description provided for @recommendedTab.
  ///
  /// In en, this message translates to:
  /// **'Recommended'**
  String get recommendedTab;

  /// No description provided for @savedTab.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedTab;

  /// No description provided for @appliedTab.
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get appliedTab;

  /// No description provided for @recentlyViewedTab.
  ///
  /// In en, this message translates to:
  /// **'Recently Viewed'**
  String get recentlyViewedTab;

  /// No description provided for @filterAndSortJobs.
  ///
  /// In en, this message translates to:
  /// **'Filter & Sort Jobs'**
  String get filterAndSortJobs;

  /// No description provided for @resetAll.
  ///
  /// In en, this message translates to:
  /// **'Reset All'**
  String get resetAll;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort By'**
  String get sortBy;

  /// No description provided for @workArrangement.
  ///
  /// In en, this message translates to:
  /// **'Work Arrangement'**
  String get workArrangement;

  /// No description provided for @employmentType.
  ///
  /// In en, this message translates to:
  /// **'Employment Type'**
  String get employmentType;

  /// No description provided for @experienceLevel.
  ///
  /// In en, this message translates to:
  /// **'Experience Level'**
  String get experienceLevel;

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get applyFilters;

  /// No description provided for @noSavedJobsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Saved Jobs Yet'**
  String get noSavedJobsTitle;

  /// No description provided for @noSavedJobsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bookmark job opportunities you are interested in to review and apply to them later.'**
  String get noSavedJobsSubtitle;

  /// No description provided for @noMatchingJobsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Matching Vacancies'**
  String get noMatchingJobsTitle;

  /// No description provided for @noMatchingJobsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try clearing your filters or searching with different keywords.'**
  String get noMatchingJobsSubtitle;

  /// No description provided for @clearAllFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear All Filters'**
  String get clearAllFilters;

  /// No description provided for @jobDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Job Details'**
  String get jobDetailsTitle;

  /// No description provided for @applyNow.
  ///
  /// In en, this message translates to:
  /// **'Apply Now'**
  String get applyNow;

  /// No description provided for @alreadyApplied.
  ///
  /// In en, this message translates to:
  /// **'Already Applied'**
  String get alreadyApplied;

  /// No description provided for @saveJob.
  ///
  /// In en, this message translates to:
  /// **'Save Job'**
  String get saveJob;

  /// No description provided for @savedJob.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get savedJob;

  /// No description provided for @jobDescription.
  ///
  /// In en, this message translates to:
  /// **'Job Description'**
  String get jobDescription;

  /// No description provided for @keyRequirements.
  ///
  /// In en, this message translates to:
  /// **'Key Requirements'**
  String get keyRequirements;

  /// No description provided for @responsibilities.
  ///
  /// In en, this message translates to:
  /// **'Responsibilities'**
  String get responsibilities;

  /// No description provided for @salary.
  ///
  /// In en, this message translates to:
  /// **'Salary'**
  String get salary;

  /// No description provided for @notSpecified.
  ///
  /// In en, this message translates to:
  /// **'Not specified'**
  String get notSpecified;

  /// No description provided for @completeProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Profile'**
  String get completeProfileTitle;

  /// No description provided for @completeProfileNotice.
  ///
  /// In en, this message translates to:
  /// **'Your profile completion is currently {percent}%. Test2Hire requires at least 70% completion before applying.'**
  String completeProfileNotice(int percent);

  /// No description provided for @goToProfile.
  ///
  /// In en, this message translates to:
  /// **'Go to Profile'**
  String get goToProfile;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @myApplicationsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Applications'**
  String get myApplicationsTitle;

  /// No description provided for @noApplicationsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Applications Submitted Yet'**
  String get noApplicationsTitle;

  /// No description provided for @noApplicationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Explore the Jobs section and apply to positions matching your skills.'**
  String get noApplicationsSubtitle;

  /// No description provided for @browseJobs.
  ///
  /// In en, this message translates to:
  /// **'Browse Jobs'**
  String get browseJobs;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Submitted / Pending'**
  String get statusPending;

  /// No description provided for @statusReviewed.
  ///
  /// In en, this message translates to:
  /// **'Reviewed'**
  String get statusReviewed;

  /// No description provided for @statusShortlisted.
  ///
  /// In en, this message translates to:
  /// **'Shortlisted'**
  String get statusShortlisted;

  /// No description provided for @statusExamAssigned.
  ///
  /// In en, this message translates to:
  /// **'Examination Assigned'**
  String get statusExamAssigned;

  /// No description provided for @statusInterviewScheduled.
  ///
  /// In en, this message translates to:
  /// **'Interview Scheduled'**
  String get statusInterviewScheduled;

  /// No description provided for @statusOffered.
  ///
  /// In en, this message translates to:
  /// **'Job Offer Received'**
  String get statusOffered;

  /// No description provided for @statusAccepted.
  ///
  /// In en, this message translates to:
  /// **'Offer Accepted'**
  String get statusAccepted;

  /// No description provided for @statusDeclined.
  ///
  /// In en, this message translates to:
  /// **'Offer Declined'**
  String get statusDeclined;

  /// No description provided for @statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Not Selected'**
  String get statusRejected;

  /// No description provided for @statusWithdrawn.
  ///
  /// In en, this message translates to:
  /// **'Withdrawn'**
  String get statusWithdrawn;

  /// No description provided for @viewApplicationDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewApplicationDetails;

  /// No description provided for @myInterviewsTitle.
  ///
  /// In en, this message translates to:
  /// **'My Interviews'**
  String get myInterviewsTitle;

  /// No description provided for @noInterviewsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Scheduled Interviews'**
  String get noInterviewsTitle;

  /// No description provided for @noInterviewsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When hiring teams invite you for technical or HR interviews, invitations will appear here.'**
  String get noInterviewsSubtitle;

  /// No description provided for @joinMeeting.
  ///
  /// In en, this message translates to:
  /// **'Join Meeting'**
  String get joinMeeting;

  /// No description provided for @confirmAttendance.
  ///
  /// In en, this message translates to:
  /// **'Confirm Attendance'**
  String get confirmAttendance;

  /// No description provided for @meetingLink.
  ///
  /// In en, this message translates to:
  /// **'Meeting Link'**
  String get meetingLink;

  /// No description provided for @interviewTime.
  ///
  /// In en, this message translates to:
  /// **'Interview Time'**
  String get interviewTime;

  /// No description provided for @interviewType.
  ///
  /// In en, this message translates to:
  /// **'Interview Type'**
  String get interviewType;

  /// No description provided for @myOffersTitle.
  ///
  /// In en, this message translates to:
  /// **'Job Offers'**
  String get myOffersTitle;

  /// No description provided for @noOffersTitle.
  ///
  /// In en, this message translates to:
  /// **'No Job Offers Yet'**
  String get noOffersTitle;

  /// No description provided for @noOffersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Formal employment offers extended by companies will be presented here for review.'**
  String get noOffersSubtitle;

  /// No description provided for @acceptOffer.
  ///
  /// In en, this message translates to:
  /// **'Accept Offer'**
  String get acceptOffer;

  /// No description provided for @declineOffer.
  ///
  /// In en, this message translates to:
  /// **'Decline Offer'**
  String get declineOffer;

  /// No description provided for @congratulationsOffer.
  ///
  /// In en, this message translates to:
  /// **'Congratulations on your offer!'**
  String get congratulationsOffer;

  /// No description provided for @proposedSalary.
  ///
  /// In en, this message translates to:
  /// **'Proposed Salary'**
  String get proposedSalary;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDate;

  /// No description provided for @takeHomeChallenges.
  ///
  /// In en, this message translates to:
  /// **'Take-Home Challenges'**
  String get takeHomeChallenges;

  /// No description provided for @noChallengesTitle.
  ///
  /// In en, this message translates to:
  /// **'No Challenges Assigned'**
  String get noChallengesTitle;

  /// No description provided for @noChallengesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Practical coding and engineering projects will appear here when assigned.'**
  String get noChallengesSubtitle;

  /// No description provided for @challengeInstructions.
  ///
  /// In en, this message translates to:
  /// **'Challenge Instructions'**
  String get challengeInstructions;

  /// No description provided for @submitChallenge.
  ///
  /// In en, this message translates to:
  /// **'Submit Solution'**
  String get submitChallenge;

  /// No description provided for @githubRepoUrl.
  ///
  /// In en, this message translates to:
  /// **'GitHub / Repository URL'**
  String get githubRepoUrl;

  /// No description provided for @notesOrComments.
  ///
  /// In en, this message translates to:
  /// **'Additional Notes'**
  String get notesOrComments;

  /// No description provided for @submittedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Submitted successfully!'**
  String get submittedSuccessfully;

  /// No description provided for @editPersonalInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Personal Information'**
  String get editPersonalInfoTitle;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @location.
  ///
  /// In en, this message translates to:
  /// **'Location (City, Country)'**
  String get location;

  /// No description provided for @headline.
  ///
  /// In en, this message translates to:
  /// **'Professional Headline'**
  String get headline;

  /// No description provided for @aboutMe.
  ///
  /// In en, this message translates to:
  /// **'About Summary'**
  String get aboutMe;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// No description provided for @changesSavedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Changes saved successfully!'**
  String get changesSavedSuccess;

  /// No description provided for @editExperienceTitle.
  ///
  /// In en, this message translates to:
  /// **'Work Experience'**
  String get editExperienceTitle;

  /// No description provided for @addExperience.
  ///
  /// In en, this message translates to:
  /// **'Add Experience'**
  String get addExperience;

  /// No description provided for @editEducationTitle.
  ///
  /// In en, this message translates to:
  /// **'Education History'**
  String get editEducationTitle;

  /// No description provided for @addEducation.
  ///
  /// In en, this message translates to:
  /// **'Add Education'**
  String get addEducation;

  /// No description provided for @manageSkillsTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage Skills'**
  String get manageSkillsTitle;

  /// No description provided for @addSkillHint.
  ///
  /// In en, this message translates to:
  /// **'Type a skill and press Enter...'**
  String get addSkillHint;

  /// No description provided for @editCertificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Certifications & Languages'**
  String get editCertificationsTitle;

  /// No description provided for @addCertification.
  ///
  /// In en, this message translates to:
  /// **'Add Certification'**
  String get addCertification;

  /// No description provided for @addLanguage.
  ///
  /// In en, this message translates to:
  /// **'Add Language'**
  String get addLanguage;

  /// No description provided for @notificationsTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsTitle;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get noNotifications;

  /// No description provided for @welcomeFeedMessage.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Test2Hire! Community posts and recommended jobs will appear here.'**
  String get welcomeFeedMessage;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
