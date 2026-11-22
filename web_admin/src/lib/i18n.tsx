"use client";

import React, { createContext, useContext, useState, useEffect, useCallback, useMemo } from "react";

export type Language = "ar" | "en";
export type Theme = "light" | "dark";

export const translations = {
  ar: {
    // Brand & Header
    portalTitle: "بوابة أصحاب الشركات",
    portalSubtitle: "إدارة التوظيف والكفاءات الذكية",
    signedInAs: "الحساب الحالي",
    verifiedCompany: "شركة معتمدة",
    signOut: "تسجيل الخروج",
    themeToggleLight: "الوضع الفاتح",
    themeToggleDark: "الوضع الليلي",
    langToggle: "English",

    // Navigation
    navDashboard: "لوحة التحكم",
    navJobs: "الوظائف والشواغر",
    navApplicants: "المرشحون",
    navExams: "الاختبارات والتقييمات",
    navInterviews: "المقابلات",
    navOffers: "عروض العمل",
    navProfile: "الملف التعريفي",

    // Common
    search: "بحث...",
    filter: "فلترة",
    all: "الكل",
    actions: "الإجراءات",
    save: "حفظ",
    cancel: "إلغاء",
    delete: "حذف",
    edit: "تعديل",
    view: "معاينة",
    status: "الحالة",
    close: "إغلاق",
    loading: "جاري التحميل...",
    noData: "لا توجد بيانات متاحة حالياً.",
    active: "نشط",
    success: "تم بنجاح!",
    error: "حدث خطأ ما",

    // Dashboard
    dashWelcomeBadge: "منصة التوظيف المدعومة بالذكاء الاصطناعي",
    dashTitle: "لوحة تحكم التوظيف وإدارة الكفاءات",
    dashSubtitle: "متابعة دقيقة وفورية لكافة الوظائف الشاغرة، طلبات المتقدمين، ونتائج التقييمات الآلية.",
    postNewJob: "نشر وظيفة جديدة",
    createAssessment: "إنشاء اختبار تقييم",
    kpiActiveJobs: "الوظائف النشطة",
    kpiActiveJobsSub: "وظائف معلنة وقابلة للتقديم",
    kpiTotalApplicants: "إجمالي المتقدمين",
    kpiTotalApplicantsSub: "مرشح مسجل عبر كافة الوظائف",
    kpiCompletedExams: "الاختبارات المنجزة",
    kpiCompletedExamsSub: "مرشح اجتاز التقييم التقني",
    kpiScheduledInterviews: "المقابلات المجدولة",
    kpiScheduledInterviewsSub: "مقابلة قيد الانتظار",
    recentApplicants: "أحدث المتقدمين",
    recentApplicantsSub: "المرشحون الذين تقدموا للوظائف مؤخراً",
    viewAllApplicants: "عرض كافة المتقدمين",
    activeJobsOverview: "الوظائف المعلنة",
    activeJobsOverviewSub: "حالة الوظائف وعدد المتقدمين لكل وظيفة",
    manageJobs: "إدارة الوظائف",
    applicantsCountBadge: "مرشح",

    // Jobs
    jobsTitle: "إدارة الوظائف والشواغر",
    jobsSubtitle: "إضافة وتعديل ومتابعة الوظائف المعلنة وعدد المتقدمين لكل وظيفة",
    searchJobsPlaceholder: "بحث بالمسمى، المهارات، المدينة...",
    jobTitleCol: "المسمى الوظيفي",
    jobTypeCol: "نوع العمل",
    locationSalaryCol: "الموقع والراتب",
    applicantsCol: "المتقدمون",
    statusCol: "الحالة",
    allStatuses: "جميع الحالات",
    published: "منشور (PUBLISHED)",
    draft: "مسودة (DRAFT)",
    closed: "مغلق (CLOSED)",
    publishAction: "نشر",
    closeAction: "إغلاق",
    newJobModalTitle: "نشر وظيفة جديدة",
    newJobModalSub: "أدخل تفاصيل الوظيفة والشروط المطلوبة",
    jobTitleLabel: "المسمى الوظيفي *",
    jobDescLabel: "الوصف الوظيفي والمسؤوليات *",
    employmentTypeLabel: "نوع التوظيف",
    workplaceTypeLabel: "مكان العمل",
    experienceLevelLabel: "مستوى الخبرة",
    cityCountryLabel: "المدينة والبلد",
    skillsLabel: "المهارات المطلوبة (مفصولة بفاصلة)",
    salaryMinLabel: "الحد الأدنى للراتب",
    salaryMaxLabel: "الحد الأقصى للراتب",
    salaryCurrencyLabel: "عملة الراتب",
    linkExamLabel: "ربط باختبار تقييم تقني (اختياري)",
    noExamOption: "بدون اختبار آلي",
    postJobSubmit: "نشر الوظيفة الآن",

    // Applicants
    applicantsTitle: "إدارة المتقدمين والمرشحين",
    applicantsSubtitle: "متابعة مراحل توظيف المرشحين، تقييم السير الذاتية (CVs)، ونتائج الاختبارات",
    candidateCol: "المرشح",
    appliedJobCol: "الوظيفة المتقدم لها",
    examScoreCol: "نتيجة الاختبار",
    cvCol: "السيرة الذاتية (CV)",
    stageCol: "المرحلة",
    downloadCv: "تحميل CV",
    viewCandidate: "معاينة وإدارة",
    allJobsOption: "جميع الوظائف",
    allStagesOption: "كافة المراحل",
    candidateDetailsTitle: "تفاصيل المرشح",
    contactInfo: "معلومات التواصل",
    technicalScore: "التقييم التقني",
    coverLetter: "رسالة التقديم (Cover Letter)",
    moveStageTitle: "تحديث مرحلة التوظيف (ATS Pipeline)",
    stageApplied: "طلب جديد (Applied)",
    stageExamAssigned: "تعيين اختبار (Exam Assigned)",
    stagePassed: "اجتياز التقييم (Passed)",
    stageInterview: "جدولة مقابلة (Interview)",
    stageOffer: "تقديم عرض عمل (Offer)",
    stageHired: "توظيف نهائي (Hired)",
    stageRejected: "رفض الطلب (Rejected)",
    aiSummaryTitle: "تحليل الذكاء الاصطناعي (AI Talent Synthesis)",
    aiGenerateSummaryBtn: "توليد ملخص وتوصية AI للمرشح",

    // Exams
    examsTitle: "الاختبارات والتقييمات التقنية",
    examsSubtitle: "إنشاء اختبارات تقنية واختيارية مؤتمتة وتعيينها للمرشحين والوظائف",
    newExamBtn: "إنشاء اختبار جديد",
    examTitleLabel: "عنوان الاختبار *",
    examDescLabel: "الوصف العام",
    examDurationLabel: "مدة الاختبار (بالدقائق)",
    examPassingScoreLabel: "نسبة النجاح المطلوبة (%)",
    questionsListTitle: "أسئلة الاختبار",
    addQuestionBtn: "إضافة سؤال",
    questionNumber: "السؤال #",
    questionTextPlaceholder: "اكتب نص السؤال هنا...",
    optionPlaceholder: "الخيار",
    correctAnswerNote: "الخيار المحدد بالدائرة هو الإجابة الصحيحة للتقييم الآلي.",
    saveExamBtn: "حفظ ونشر الاختبار",
    aiGenerateExamBtn: "توليد أسئلة الاختبار بالذكاء الاصطناعي (Gemini AI)",

    // Interviews
    interviewsTitle: "إدارة المقابلات",
    interviewsSubtitle: "جدولة وتنظيم المقابلات الشخصية والتقنية (عبر Google Meet أو الحضور الشخصي)",
    scheduleNewInterviewBtn: "جدولة مقابلة جديدة",
    interviewCandidateCol: "المرشح",
    interviewJobCol: "الوظيفة",
    interviewTimeCol: "موعد المقابلة",
    interviewTypeCol: "نوع المقابلة والرابط",
    interviewDateLabel: "التاريخ *",
    interviewTimeLabel: "الوقت *",
    interviewTypeLabel: "نوع المقابلة",
    meetingUrlLabel: "رابط المقابلة (Google Meet / Zoom)",
    meetingLocationLabel: "مقر المقابلة أو العنوان",
    interviewNotesLabel: "أجندة المقابلة والملاحظات",
    confirmScheduleBtn: "تأكيد وجدولة المقابلة",
    aiGenerateInterviewQuestionsBtn: "اقتراح أسئلة المقابلة بالذكاء الاصطناعي",

    // Offers
    offersTitle: "عروض العمل",
    offersSubtitle: "تقديم ومتابعة عروض التوظيف الرسمية والرواتب وتواريخ البدء للمرشحين المقبولين",
    sendOfferBtn: "تقديم عرض عمل جديد",
    offerSalaryCol: "الراتب الأساسي",
    offerStartDateCol: "تاريخ البدء المتوقع",
    offerCandidateLabel: "المرشح المقبول *",
    offerSalaryLabel: "الراتب الشهري *",
    offerCurrencyLabel: "العملة",
    offerStartDateLabel: "تاريخ مباشرة العمل",
    offerExpireDateLabel: "تاريخ انتهاء صلاحية العرض",
    offerNotesLabel: "مزايا إضافية أو شروط العرض",
    sendOfferSubmit: "إرسال العرض الرسمي",

    // Profile
    profileTitle: "الملف التعريفي للشركة",
    profileSubtitle: "إدارة الهوية المؤسسية، بيانات التواصل، ومعلومات التحقق والاعتماد",
    companyLogoLabel: "شعار الشركة (Company Logo)",
    companyLogoHint: "يدعم صيغ PNG, JPG, WebP أو رابط صورة مباشر",
    changeLogoBtn: "تغيير الشعار",
    uploadLogoBtn: "رفع صورة الشعار",
    companyNameLabel: "اسم الشركة / المؤسسة *",
    industryLabel: "قطاع العمل / المجال *",
    companySizeLabel: "حجم الشركة",
    websiteLabel: "الموقع الإلكتروني",
    aboutCompanyLabel: "نبذة عن الشركة",
    countryLabel: "الدولة",
    cityLabel: "المدينة",
    addressLabel: "العنوان والمقر",
    contactEmailLabel: "البريد الإلكتروني للتواصل",
    contactPhoneLabel: "رقم هاتف التواصل",
    taxNumberLabel: "الرقم الضريبي (Tax Number)",
    crNumberLabel: "السجل التجاري (CR Number)",
    saveProfileBtn: "حفظ بيانات الشركة",
    verifiedTitle: "شركة معتمدة رسمياً في Test2Hire",
    verifiedDesc: "يمكنك نشر الوظائف، تقييم المرشحين وإرسال عروض العمل بصلاحيات كاملة.",
    pendingTitle: "حساب الشركة قيد التدقيق",
    pendingDesc: "يتم فحص السجل التجاري والبيانات من قبل فريق الإشراف.",
  },
  en: {
    // Brand & Header
    portalTitle: "Employer Portal",
    portalSubtitle: "Smart Talent & Hiring Hub",
    signedInAs: "Signed in as",
    verifiedCompany: "Verified Employer",
    signOut: "Sign Out",
    themeToggleLight: "Light Mode",
    themeToggleDark: "Dark Mode",
    langToggle: "العربية",

    // Navigation
    navDashboard: "Dashboard",
    navJobs: "Jobs",
    navApplicants: "Applicants",
    navExams: "Assessments",
    navInterviews: "Interviews",
    navOffers: "Job Offers",
    navProfile: "Company Profile",

    // Common
    search: "Search...",
    filter: "Filter",
    all: "All",
    actions: "Actions",
    save: "Save",
    cancel: "Cancel",
    delete: "Delete",
    edit: "Edit",
    view: "View",
    status: "Status",
    close: "Close",
    loading: "Loading...",
    noData: "No data available at this time.",
    active: "Active",
    success: "Success!",
    error: "An error occurred",

    // Dashboard
    dashWelcomeBadge: "AI-Powered Recruitment Engine",
    dashTitle: "Talent Acquisition & Hiring Hub",
    dashSubtitle: "Live tracking of open positions, applicant pipelines, and automated technical assessments.",
    postNewJob: "Post New Job",
    createAssessment: "Create Assessment",
    kpiActiveJobs: "Active Jobs",
    kpiActiveJobsSub: "Open positions accepting candidates",
    kpiTotalApplicants: "Total Applicants",
    kpiTotalApplicantsSub: "Total registered candidates",
    kpiCompletedExams: "Exams Completed",
    kpiCompletedExamsSub: "Passed technical evaluations",
    kpiScheduledInterviews: "Interviews Scheduled",
    kpiScheduledInterviewsSub: "Upcoming interview sessions",
    recentApplicants: "Recent Applicants",
    recentApplicantsSub: "Candidates who applied recently",
    viewAllApplicants: "View All Applicants",
    activeJobsOverview: "Active Positions",
    activeJobsOverviewSub: "Status and applicant count per job",
    manageJobs: "Manage Jobs",
    applicantsCountBadge: "Applicants",

    // Jobs
    jobsTitle: "Job Postings Management",
    jobsSubtitle: "Create, moderate, and track open vacancies and applicants count",
    searchJobsPlaceholder: "Search by title, skills, location...",
    jobTitleCol: "Position Title",
    jobTypeCol: "Type & Level",
    locationSalaryCol: "Location & Salary",
    applicantsCol: "Applicants",
    statusCol: "Status",
    allStatuses: "All Statuses",
    published: "PUBLISHED",
    draft: "DRAFT",
    closed: "CLOSED",
    publishAction: "Publish",
    closeAction: "Close",
    newJobModalTitle: "Post New Job",
    newJobModalSub: "Fill in job requirements and credentials",
    jobTitleLabel: "Job Title *",
    jobDescLabel: "Job Description & Responsibilities *",
    employmentTypeLabel: "Job Type",
    workplaceTypeLabel: "Workplace Type",
    experienceLevelLabel: "Experience Level",
    cityCountryLabel: "City & Country",
    skillsLabel: "Required Skills (comma separated)",
    salaryMinLabel: "Min Salary",
    salaryMaxLabel: "Max Salary",
    salaryCurrencyLabel: "Salary Currency",
    linkExamLabel: "Attach Technical Assessment (Optional)",
    noExamOption: "No automated exam",
    postJobSubmit: "Publish Position Now",

    // Applicants
    applicantsTitle: "Candidate Pipeline & ATS",
    applicantsSubtitle: "Track hiring stages, inspect resumes (CVs), and evaluate test scores",
    candidateCol: "Candidate",
    appliedJobCol: "Target Position",
    examScoreCol: "Assessment Score",
    cvCol: "Resume / CV",
    stageCol: "Hiring Stage",
    downloadCv: "Download CV",
    viewCandidate: "View & Manage",
    allJobsOption: "All Positions",
    allStagesOption: "All Stages",
    candidateDetailsTitle: "Candidate Profile",
    contactInfo: "Contact Information",
    technicalScore: "Technical Assessment",
    coverLetter: "Cover Letter",
    moveStageTitle: "Update Pipeline Stage (ATS)",
    stageApplied: "Applied",
    stageExamAssigned: "Exam Assigned",
    stagePassed: "Passed Exam",
    stageInterview: "Interview",
    stageOffer: "Offer Extended",
    stageHired: "Hired",
    stageRejected: "Rejected",
    aiSummaryTitle: "AI Candidate Synthesis & Match",
    aiGenerateSummaryBtn: "Generate AI Synthesis & Recommendation",

    // Exams
    examsTitle: "Assessments & Technical Exams",
    examsSubtitle: "Design automated multiple-choice tests and assign them to roles",
    newExamBtn: "Create New Exam",
    examTitleLabel: "Exam Title *",
    examDescLabel: "General Description",
    examDurationLabel: "Duration (minutes)",
    examPassingScoreLabel: "Passing Score (%)",
    questionsListTitle: "Questions",
    addQuestionBtn: "Add Question",
    questionNumber: "Question #",
    questionTextPlaceholder: "Write the question prompt here...",
    optionPlaceholder: "Option",
    correctAnswerNote: "The selected radio option is evaluated as the correct answer automatically.",
    saveExamBtn: "Save & Publish Exam",
    aiGenerateExamBtn: "Generate Questions with Gemini AI",

    // Interviews
    interviewsTitle: "Candidate Interviews",
    interviewsSubtitle: "Schedule and manage video (Google Meet / Zoom) or in-person interview sessions",
    scheduleNewInterviewBtn: "Schedule New Interview",
    interviewCandidateCol: "Candidate",
    interviewJobCol: "Position",
    interviewTimeCol: "Scheduled Time",
    interviewTypeCol: "Type & Meeting Link",
    interviewDateLabel: "Date *",
    interviewTimeLabel: "Time *",
    interviewTypeLabel: "Meeting Type",
    meetingUrlLabel: "Meeting URL (Google Meet / Zoom)",
    meetingLocationLabel: "Office Address / Room",
    interviewNotesLabel: "Agenda & Notes",
    confirmScheduleBtn: "Confirm & Schedule Interview",
    aiGenerateInterviewQuestionsBtn: "Suggest Questions with AI",

    // Offers
    offersTitle: "Job Offers",
    offersSubtitle: "Extend and track formal job offers, compensation, and onboarding dates",
    sendOfferBtn: "Extend Job Offer",
    offerSalaryCol: "Base Compensation",
    offerStartDateCol: "Target Start Date",
    offerCandidateLabel: "Selected Candidate *",
    offerSalaryLabel: "Monthly Salary *",
    offerCurrencyLabel: "Currency",
    offerStartDateLabel: "Start Date",
    offerExpireDateLabel: "Offer Expiration Date",
    offerNotesLabel: "Benefits & Additional Terms",
    sendOfferSubmit: "Send Official Offer",

    // Profile
    profileTitle: "Company Profile",
    profileSubtitle: "Manage organizational identity, contact info, and verification credentials",
    companyLogoLabel: "Company Logo",
    companyLogoHint: "Supports PNG, JPG, WebP or direct image URL",
    changeLogoBtn: "Change Logo",
    uploadLogoBtn: "Upload Logo",
    companyNameLabel: "Company Name *",
    industryLabel: "Industry Domain *",
    companySizeLabel: "Company Size",
    websiteLabel: "Corporate Website",
    aboutCompanyLabel: "About Company",
    countryLabel: "Country",
    cityLabel: "City",
    addressLabel: "Headquarters Address",
    contactEmailLabel: "Official Contact Email",
    contactPhoneLabel: "Contact Phone Number",
    taxNumberLabel: "Tax Number",
    crNumberLabel: "Commercial Registration (CR)",
    saveProfileBtn: "Save Company Profile",
    verifiedTitle: "Officially Verified Employer on Test2Hire",
    verifiedDesc: "You have full access to publish positions, evaluate talent, and extend offers.",
    pendingTitle: "Verification Under Review",
    pendingDesc: "Your registration documents are being reviewed by platform administrators.",
  },
};

export interface CompanyBrandingInfo {
  name: string;
  logoUrl?: string;
  industry?: string;
  verificationStatus?: string;
}

interface CompanyContextType {
  language: Language;
  setLanguage: (lang: Language) => void;
  toggleLanguage: () => void;
  theme: Theme;
  toggleTheme: () => void;
  t: (key: keyof typeof translations.ar) => string;
  isRTL: boolean;
  companyInfo: CompanyBrandingInfo | null;
  setCompanyInfo: (info: CompanyBrandingInfo | null) => void;
}

const CompanyContext = createContext<CompanyContextType | undefined>(undefined);

export function CompanyProvider({ children }: { children: React.ReactNode }) {
  const [language, setLanguageState] = useState<Language>("ar");
  const [theme, setThemeState] = useState<Theme>("light");
  const [companyInfo, setCompanyInfo] = useState<CompanyBrandingInfo | null>(null);
  const [mounted, setMounted] = useState(false);

  useEffect(() => {
    // Load persisted preferences
    const savedLang = (localStorage.getItem("t2h_company_lang") as Language) || "ar";
    const savedTheme = (localStorage.getItem("t2h_company_theme") as Theme) || "light";

    setLanguageState(savedLang);
    setThemeState(savedTheme);

    // Apply HTML attributes
    document.documentElement.dir = savedLang === "ar" ? "rtl" : "ltr";
    document.documentElement.lang = savedLang;
    if (savedTheme === "dark") {
      document.documentElement.classList.add("dark");
    } else {
      document.documentElement.classList.remove("dark");
    }

    setMounted(true);
  }, []);

  const setLanguage = useCallback((lang: Language) => {
    setLanguageState(lang);
    localStorage.setItem("t2h_company_lang", lang);
    document.documentElement.dir = lang === "ar" ? "rtl" : "ltr";
    document.documentElement.lang = lang;
  }, []);

  const toggleLanguage = useCallback(() => {
    setLanguage(language === "ar" ? "en" : "ar");
  }, [language, setLanguage]);

  const toggleTheme = useCallback(() => {
    setThemeState((prev) => {
      const next = prev === "light" ? "dark" : "light";
      localStorage.setItem("t2h_company_theme", next);
      if (next === "dark") {
        document.documentElement.classList.add("dark");
      } else {
        document.documentElement.classList.remove("dark");
      }
      return next;
    });
  }, []);

  const t = useCallback(
    (key: keyof typeof translations.ar): string => {
      const dict = translations[language] || translations.ar;
      return (dict as any)[key] || key;
    },
    [language]
  );

  const isRTL = language === "ar";

  const contextValue = useMemo(
    () => ({
      language,
      setLanguage,
      toggleLanguage,
      theme,
      toggleTheme,
      t,
      isRTL,
      companyInfo,
      setCompanyInfo,
    }),
    [language, setLanguage, toggleLanguage, theme, toggleTheme, t, isRTL, companyInfo]
  );

  return (
    <CompanyContext.Provider value={contextValue}>
      <div className={theme === "dark" ? "dark" : ""}>
        {children}
      </div>
    </CompanyContext.Provider>
  );
}

export function useCompany() {
  const context = useContext(CompanyContext);
  if (!context) {
    throw new Error("useCompany must be used within a CompanyProvider");
  }
  return context;
}
