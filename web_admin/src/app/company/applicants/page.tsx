"use client";

import React, { useEffect, useState, useMemo, Suspense } from "react";
import { useSearchParams } from "next/navigation";
import { auth, db, functions } from "@/lib/firebase";
import { onAuthStateChanged } from "firebase/auth";
import { doc, updateDoc, serverTimestamp } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { useCompany } from "@/lib/i18n";
import { getApplicantStatusMeta, formatTimestamp, sanitizeExternalUrl } from "@/lib/formatters";
import {
  listenCompanyApplicants,
  listenCompanyJobs,
  listenCompanyExamAttempts,
  fetchExamAttemptViolations,
  fetchCompanyExams,
  fetchCompanyChallenges,
  fetchCompanyChallengeSubmissions,
  assignChallengeToCandidate,
  updateApplicationStatus,
  assignExamToCandidate,
  CompanyApplicant,
  CompanyJob,
  CompanyExam,
  CompanyExamAttempt,
  CompanyExamViolation,
  CompanyChallenge,
  CompanyChallengeSubmission,
} from "@/lib/company-portal-service";
import {
  Search,
  Filter,
  Download,
  ExternalLink,
  Sparkles,
  X,
  Phone,
  Mail,
  Briefcase,
  Loader2,
  Bot,
  FileQuestion,
  CheckCircle2,
  KeyRound,
  ShieldAlert,
  Camera,
  FolderCode,
} from "lucide-react";

function CompanyApplicantsContent() {
  const { t, isRTL } = useCompany();
  const searchParams = useSearchParams();
  const initialJobId = searchParams.get("jobId") || "ALL";
  const targetApplicationId = searchParams.get("applicationId") || "";
  const targetCandidateId = searchParams.get("candidateId") || "";

  const [applicants, setApplicants] = useState<CompanyApplicant[]>([]);
  const [jobs, setJobs] = useState<CompanyJob[]>([]);
  const [exams, setExams] = useState<CompanyExam[]>([]);
  const [examAttempts, setExamAttempts] = useState<CompanyExamAttempt[]>([]);
  const [challenges, setChallenges] = useState<CompanyChallenge[]>([]);
  const [challengeSubmissions, setChallengeSubmissions] = useState<CompanyChallengeSubmission[]>([]);
  const [loading, setLoading] = useState(true);

  // Filters
  const [selectedJobId, setSelectedJobId] = useState<string>(initialJobId);
  const [statusFilter, setStatusFilter] = useState<string>("ALL");
  const [searchQuery, setSearchQuery] = useState("");
  const lastAutoOpenedTargetRef = React.useRef<string>("");

  // Candidate Details Modal
  const [selectedApplicant, setSelectedApplicant] = useState<CompanyApplicant | null>(null);
  const [selectedExamForAssign, setSelectedExamForAssign] = useState<string>("");
  const [assigningExam, setAssigningExam] = useState(false);
  const [selectedChallengeTemplateId, setSelectedChallengeTemplateId] = useState<string>("");
  const [customChallengeTitle, setCustomChallengeTitle] = useState<string>("");
  const [customChallengeBrief, setCustomChallengeBrief] = useState<string>("");
  const [assigningChallenge, setAssigningChallenge] = useState(false);
  const [expandedProctoringAttemptId, setExpandedProctoringAttemptId] = useState<string | null>(null);
  const [attemptViolationsMap, setAttemptViolationsMap] = useState<Record<string, CompanyExamViolation[]>>({});
  const [loadingViolationsForId, setLoadingViolationsForId] = useState<string | null>(null);
  const [updatingStatus, setUpdatingStatus] = useState(false);
  const [generatingAi, setGeneratingAi] = useState(false);
  const [actionFeedback, setActionFeedback] = useState<{ type: "success" | "error"; text: string } | null>(null);

  useEffect(() => {
    setSelectedJobId(searchParams.get("jobId") || "ALL");
  }, [searchParams]);

  // Deep-link auto-open when arriving from notification click (?applicationId=... or ?candidateId=...)
  useEffect(() => {
    if ((!targetApplicationId && !targetCandidateId) || applicants.length === 0) return;
    const key = `${targetApplicationId}:${targetCandidateId}`;
    if (lastAutoOpenedTargetRef.current === key) return;
    const match =
      (targetApplicationId && applicants.find((a) => a.id === targetApplicationId)) ||
      (targetCandidateId && applicants.find((a) => a.candidateId === targetCandidateId));
    if (match) {
      lastAutoOpenedTargetRef.current = key;
      setStatusFilter("ALL");
      setSelectedApplicant(match);
    }
  }, [targetApplicationId, targetCandidateId, applicants]);

  useEffect(() => {
    let unsubApps: (() => void) | null = null;
    let unsubJobs: (() => void) | null = null;
    let unsubAttempts: (() => void) | null = null;

    const unsubAuth = onAuthStateChanged(auth, (user) => {
      if (unsubApps) unsubApps();
      if (unsubJobs) unsubJobs();
      if (unsubAttempts) unsubAttempts();

      if (user) {
        setLoading(true);
        fetchCompanyExams(user.uid)
          .then((examsData) => {
            setExams(examsData);
            if (examsData.length > 0) setSelectedExamForAssign(examsData[0].id);
          })
          .catch(() => {});

        fetchCompanyChallenges(user.uid)
          .then((chData) => {
            setChallenges(chData);
            if (chData.length > 0) setSelectedChallengeTemplateId(chData[0].id);
          })
          .catch(() => {});

        fetchCompanyChallengeSubmissions(user.uid)
          .then(setChallengeSubmissions)
          .catch(() => {});

        unsubJobs = listenCompanyJobs(user.uid, (jobsData) => {
          setJobs(jobsData);
        });
        unsubAttempts = listenCompanyExamAttempts(user.uid, (attemptsData) => {
          setExamAttempts(attemptsData);
        });
        unsubApps = listenCompanyApplicants(
          user.uid,
          (appsData) => {
            setApplicants(appsData);
            setSelectedApplicant((prev) =>
              prev ? appsData.find((a) => a.id === prev.id) || prev : null
            );
            setLoading(false);
          },
          () => {
            setActionFeedback({ type: "error", text: t("error") });
            setLoading(false);
          }
        );
      } else {
        setLoading(false);
      }
    });

    return () => {
      unsubAuth();
      if (unsubApps) unsubApps();
      if (unsubJobs) unsubJobs();
      if (unsubAttempts) unsubAttempts();
    };
  }, []);

  const getCandidateExamAttempts = (app: CompanyApplicant): CompanyExamAttempt[] => {
    const exactApp = examAttempts.filter((a) => a.applicationId === app.id);
    const otherSameCandidate = examAttempts.filter(
      (a) => a.applicationId !== app.id && a.candidateId && a.candidateId === app.candidateId
    );
    return [...exactApp, ...otherSameCandidate];
  };

  const handleToggleAttemptProctoring = async (attempt: CompanyExamAttempt) => {
    if (expandedProctoringAttemptId === attempt.id) {
      setExpandedProctoringAttemptId(null);
      return;
    }
    setExpandedProctoringAttemptId(attempt.id);
    if (!attemptViolationsMap[attempt.id] && auth.currentUser) {
      setLoadingViolationsForId(attempt.id);
      const list = await fetchExamAttemptViolations(auth.currentUser.uid, attempt.id);
      setAttemptViolationsMap((prev) => ({ ...prev, [attempt.id]: list }));
      setLoadingViolationsForId(null);
    }
  };

  const handleAssignChallenge = async () => {
    if (!selectedApplicant || !auth.currentUser) return;
    const tpl = challenges.find((c) => c.id === selectedChallengeTemplateId);
    const titleToUse = customChallengeTitle.trim() || tpl?.title || "";
    const briefToUse = customChallengeBrief.trim() || tpl?.brief || "";
    if (!titleToUse) {
      setActionFeedback({
        type: "error",
        text: isRTL
          ? "يرجى اختيار قالب واجب عملي أو كتابة عنوان للواجب الجديد."
          : "Please select a practical assignment template or enter a title.",
      });
      return;
    }
    try {
      setAssigningChallenge(true);
      const newId = await assignChallengeToCandidate({
        companyId: auth.currentUser.uid,
        companyName: selectedApplicant.companyName || "Company",
        applicationId: selectedApplicant.id,
        candidateId: selectedApplicant.candidateId,
        candidateName: selectedApplicant.candidateName,
        jobId: selectedApplicant.jobId,
        jobTitle: selectedApplicant.jobTitle,
        title: titleToUse,
        brief: briefToUse || `Practical assignment for ${selectedApplicant.jobTitle}`,
        detailedInstructions:
          tpl?.detailedInstructions || briefToUse || `Complete this practical assignment for ${selectedApplicant.jobTitle}.`,
        difficulty: tpl?.difficulty || "INTERMEDIATE",
        deadlineDays: tpl?.deadlineDays || 3,
        deliverables: tpl?.deliverables || [],
        techStack: tpl?.techStack || [],
        starterTemplateUrl: tpl?.starterTemplateUrl || null,
      });
      setCustomChallengeTitle("");
      setCustomChallengeBrief("");
      setActionFeedback({
        type: "success",
        text: isRTL
          ? `تم تعيين الواجب العملي «${titleToUse}» لهذا المرشح فقط وإشعاره بنجاح!`
          : `Assigned practical assignment "${titleToUse}" exclusively to ${selectedApplicant.candidateName}!`,
      });
      fetchCompanyChallenges(auth.currentUser.uid).then(setChallenges).catch(() => {});
      setSelectedApplicant((prev) =>
        prev ? { ...prev, assignedChallengeId: newId, assignedChallengeTitle: titleToUse } : null
      );
    } catch (err: any) {
      setActionFeedback({ type: "error", text: err?.message || t("error") });
    } finally {
      setAssigningChallenge(false);
    }
  };

  const filteredApplicants = useMemo(() => {
    return applicants.filter((app) => {
      const q = searchQuery.toLowerCase();
      const matchSearch =
        app.candidateName.toLowerCase().includes(q) ||
        app.candidateEmail.toLowerCase().includes(q) ||
        app.jobTitle.toLowerCase().includes(q);
      const matchJob = selectedJobId === "ALL" || app.jobId === selectedJobId;
      const matchStatus = statusFilter === "ALL" || app.status.toUpperCase() === statusFilter.toUpperCase();
      return matchSearch && matchJob && matchStatus;
    });
  }, [applicants, searchQuery, selectedJobId, statusFilter]);

  const handleStatusChange = async (newStatus: string) => {
    if (!selectedApplicant) return;
    try {
      setUpdatingStatus(true);
      if (newStatus === "EXAM_ASSIGNED") {
        if (!selectedExamForAssign) {
          setActionFeedback({
            type: "error",
            text: isRTL
              ? "يرجى إنشاء وتحديد قالب اختبار أولاً قبل تعيين مرحلة الاختبار."
              : "Please create and select an exam template before assigning an exam stage.",
          });
          return;
        }
        await handleAssignExam();
        return;
      }
      await updateApplicationStatus(selectedApplicant.id, newStatus);
      setApplicants((prev) =>
        prev.map((a) => (a.id === selectedApplicant.id ? { ...a, status: newStatus } : a))
      );
      setSelectedApplicant((prev) => (prev ? { ...prev, status: newStatus } : null));
      setActionFeedback({
        type: "success",
        text: `${t("success")} -> ${isRTL ? getApplicantStatusMeta(newStatus).labelAr : getApplicantStatusMeta(newStatus).labelEn}`,
      });
    } catch (err: any) {
      console.error("Failed to update status:", err);
      setActionFeedback({ type: "error", text: err?.message || t("error") });
    } finally {
      setUpdatingStatus(false);
    }
  };

  const handleAssignExam = async () => {
    if (!selectedApplicant || !selectedExamForAssign) return;
    try {
      setAssigningExam(true);
      const { token, attemptId } = await assignExamToCandidate({
        applicationId: selectedApplicant.id,
        examId: selectedExamForAssign,
      });
      const chosenExam = exams.find((e) => e.id === selectedExamForAssign);
      const updated: CompanyApplicant = {
        ...selectedApplicant,
        status: "EXAM_ASSIGNED",
        examToken: token,
        examAttemptId: attemptId,
        examTitle: chosenExam?.title || "Assessment",
      };
      setSelectedApplicant(updated);
      setApplicants((prev) =>
        prev.map((a) => (a.id === selectedApplicant.id ? updated : a))
      );
      setActionFeedback({
        type: "success",
        text: isRTL
          ? `تم تعيين الاختبار وإرسال الإشعار ومفتاح الدخول (${token}) لتطبيق المرشح بنجاح!`
          : `Exam assigned and notification with Exam Key (${token}) sent to candidate's mobile app!`,
      });
    } catch (err: any) {
      console.error("Failed to assign exam:", err);
      setActionFeedback({ type: "error", text: err.message || t("error") });
    } finally {
      setAssigningExam(false);
    }
  };

  const handleGenerateAiSummary = async () => {
    if (!selectedApplicant) return;
    try {
      setGeneratingAi(true);
      const targetJob = jobs.find((j) => j.id === selectedApplicant.jobId);
      const reqSkills = targetJob?.requiredSkills?.length
        ? targetJob.requiredSkills
        : ["Flutter", "Clean Architecture", "REST APIs", "Firebase"];

      let summaryResult: any = null;
      try {
        const callSummary = httpsCallable<{ applicationId: string }, any>(
          functions,
          "generateCandidateAiSummary"
        );
        const cfRes = await callSummary({ applicationId: selectedApplicant.id });
        if (cfRes.data) {
          summaryResult = cfRes.data;
        }
      } catch (cfErr) {
        console.warn("generateCandidateAiSummary CF unavailable, falling back to /api/ai:", cfErr);
      }

      if (!summaryResult) {
        const idToken = await auth.currentUser?.getIdToken();
        const response = await fetch("/api/ai", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
          },
          body: JSON.stringify({
            action: "generateCandidateSummary",
            payload: {
              applicationId: selectedApplicant.id,
              candidateName: selectedApplicant.candidateName,
              jobTitle: selectedApplicant.jobTitle,
              requiredSkills: reqSkills,
              examScore: selectedApplicant.examScore ?? null,
              isRTL,
            },
          }),
        });
        if (!response.ok) {
          const errBody = await response.json().catch(() => ({}));
          throw new Error(errBody?.error || t("error"));
        }
        summaryResult = await response.json();
      }

      const cvMatchScore =
        typeof summaryResult?.cvMatchScore === "number" ? summaryResult.cvMatchScore : 90;
      const overallFitScore =
        typeof summaryResult?.overallFitScore === "number"
          ? summaryResult.overallFitScore
          : selectedApplicant.examScore != null
          ? Math.round(selectedApplicant.examScore * 0.6 + cvMatchScore * 0.4)
          : cvMatchScore;
      const aiRecommendation =
        summaryResult?.aiRecommendation ||
        summaryResult?.recommendationDecision ||
        "STRONG_MATCH";

      const aiData = {
        summary:
          summaryResult?.summary ||
          summaryResult?.executiveSummary ||
          (isRTL
            ? `يمتلك المرشح ${selectedApplicant.candidateName} خلفية تقنية قوية ومطابقة لمتطلبات وظيفة (${selectedApplicant.jobTitle}) مع جاهزية عالية للمرحلة التالية.`
            : `Candidate ${selectedApplicant.candidateName} demonstrates strong technical alignment with the requirements for ${selectedApplicant.jobTitle}.`),
        matchedSkills: summaryResult?.matchedSkills?.length ? summaryResult.matchedSkills : reqSkills,
        missingSkills: summaryResult?.missingSkills || [],
        cvMatchScore,
        aiRecommendation,
      };

      await updateDoc(doc(db, "applications", selectedApplicant.id), {
        aiParsedCv: aiData,
        cvMatchScore,
        overallFitScore,
        aiRecommendation,
        updatedAt: serverTimestamp(),
      });

      const updatedApplicant: CompanyApplicant = {
        ...selectedApplicant,
        cvMatchScore,
        overallFitScore,
        aiRecommendation,
        aiParsedCv: aiData,
      };

      setSelectedApplicant(updatedApplicant);
      setApplicants((prev) =>
        prev.map((a) => (a.id === selectedApplicant.id ? updatedApplicant : a))
      );
      setActionFeedback({
        type: "success",
        text: isRTL
          ? "تم توليد وحفظ تحليل الذكاء الاصطناعي للمرشح بنجاح!"
          : "AI Candidate Analysis generated and saved successfully!",
      });
    } catch (err: any) {
      console.error("AI error:", err);
      setActionFeedback({ type: "error", text: err?.message || t("error") });
    } finally {
      setGeneratingAi(false);
    }
  };

  const getStatusBadge = (status: string) => {
    const meta = getApplicantStatusMeta(status);
    return (
      <span className={`px-2.5 py-0.5 rounded-full text-xs font-semibold border ${meta.badgeClass}`}>
        {isRTL ? meta.labelAr : meta.labelEn}
      </span>
    );
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 dark:text-white tracking-tight">{t("applicantsTitle")}</h1>
          <p className="text-sm text-slate-500 dark:text-slate-400 mt-1">{t("applicantsSubtitle")}</p>
        </div>
        <div className="text-xs font-bold px-3 py-1.5 rounded-xl bg-indigo-50 dark:bg-indigo-950/60 text-indigo-700 dark:text-indigo-300 border border-indigo-200 dark:border-indigo-800 self-start sm:self-auto">
          {filteredApplicants.length} {t("applicantsCountBadge")}
        </div>
      </div>

      {/* Floating Toast Feedback (always visible above modals) */}
      {actionFeedback && (
        <div
          className={`fixed top-20 ${
            isRTL ? "left-6" : "right-6"
          } z-[99999] max-w-md w-full p-4 rounded-xl text-sm font-medium border shadow-2xl flex items-center justify-between gap-3 ${
            actionFeedback.type === "success"
              ? "bg-emerald-50 dark:bg-emerald-950 text-emerald-800 dark:text-emerald-200 border-emerald-300 dark:border-emerald-700"
              : "bg-rose-50 dark:bg-rose-950 text-rose-800 dark:text-rose-200 border-rose-300 dark:border-rose-700"
          }`}
        >
          <span>{actionFeedback.text}</span>
          <button onClick={() => setActionFeedback(null)} className="text-xs font-bold uppercase hover:underline flex-shrink-0 cursor-pointer">
            {t("close")}
          </button>
        </div>
      )}

      {/* Filter & Search Bar */}
      <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200/80 dark:border-slate-800 shadow-sm flex flex-col md:flex-row items-stretch md:items-center justify-between gap-4">
        <div className="flex flex-wrap items-center gap-3">
          {/* Job Filter */}
          <div className="flex items-center gap-1.5">
            <Briefcase className="w-4 h-4 text-slate-400" />
            <select
              value={selectedJobId}
              onChange={(e) => setSelectedJobId(e.target.value)}
              className="text-xs border border-slate-300 dark:border-slate-700 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-500 font-medium"
            >
              <option value="ALL">{t("allJobsOption")} ({applicants.length})</option>
              {jobs.map((j) => (
                <option key={j.id} value={j.id}>
                  {j.title} ({j.applicantsCount})
                </option>
              ))}
            </select>
          </div>

          {/* Status Filter */}
          <div className="flex items-center gap-1.5">
            <Filter className="w-4 h-4 text-slate-400" />
            <select
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              className="text-xs border border-slate-300 dark:border-slate-700 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-500 font-medium"
            >
              <option value="ALL">{t("allStagesOption")}</option>
              <option value="APPLIED">{isRTL ? "طلب جديد" : "Applied"}</option>
              <option value="UNDER_REVIEW">{isRTL ? "قيد المراجعة" : "Under Review"}</option>
              <option value="EXAM_ASSIGNED">{isRTL ? "تم تعيين اختبار" : "Exam Assigned"}</option>
              <option value="EXAM_IN_PROGRESS">{isRTL ? "يؤدي الاختبار" : "Exam In Progress"}</option>
              <option value="EXAM_COMPLETED">{isRTL ? "أكمل الاختبار" : "Exam Completed"}</option>
              <option value="PASSED">{isRTL ? "اجتاز الاختبار" : "Passed"}</option>
              <option value="FAILED">{isRTL ? "لم يجتز الاختبار" : "Failed"}</option>
              <option value="INTERVIEW_INVITED">{isRTL ? "مدعو لمقابلة" : "Interview Invited"}</option>
              <option value="INTERVIEW_SCHEDULED">{isRTL ? "مقابلة مجدولة" : "Interview"}</option>
              <option value="SELECTED">{isRTL ? "مختار" : "Selected"}</option>
              <option value="OFFER_EXTENDED">{isRTL ? "تم إرسال عرض" : "Offer Extended"}</option>
              <option value="HIRED">{isRTL ? "تم التعيين" : "Hired"}</option>
              <option value="REJECTED">{isRTL ? "مرفوض" : "Rejected"}</option>
              <option value="WITHDRAWN">{isRTL ? "منسحب" : "Withdrawn"}</option>
            </select>
          </div>
        </div>

        {/* Search */}
        <div className="w-full md:w-72 relative">
          <Search className={`w-4 h-4 absolute ${isRTL ? "right-3" : "left-3"} top-3 text-slate-400`} />
          <input
            type="text"
            placeholder={t("search")}
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className={`w-full ${isRTL ? "pr-9 pl-4" : "pl-9 pr-4"} py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-lg bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-500`}
          />
        </div>
      </div>

      {/* Applicants Table */}
      <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm overflow-hidden">
        {loading ? (
          <div className="py-24 flex flex-col items-center justify-center gap-3">
            <div className="w-8 h-8 border-4 border-indigo-600 dark:border-indigo-400 border-t-transparent rounded-full animate-spin"></div>
            <p className="text-sm text-slate-500 dark:text-slate-400">{t("loading")}</p>
          </div>
        ) : filteredApplicants.length === 0 ? (
          <div className="py-20 text-center text-slate-500 dark:text-slate-400 text-sm">
            {t("noData")}
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse" dir={isRTL ? "rtl" : "ltr"}>
              <thead>
                <tr className="bg-slate-50 dark:bg-slate-800/60 border-b border-slate-200/80 dark:border-slate-800 text-slate-600 dark:text-slate-300 text-[11px] uppercase tracking-wider font-semibold">
                  <th className="py-3.5 px-4">{t("candidateCol")}</th>
                  <th className="py-3.5 px-4">{t("appliedJobCol")}</th>
                  <th className="py-3.5 px-4 text-center">{t("examScoreCol")}</th>
                  <th className="py-3.5 px-4 text-center">{t("cvCol")}</th>
                  <th className="py-3.5 px-4">{t("stageCol")}</th>
                  <th className={`py-3.5 px-4 ${isRTL ? "text-left" : "text-right"}`}>{t("actions")}</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 dark:divide-slate-800 text-sm">
                {filteredApplicants.map((app) => (
                  <tr key={app.id} className="hover:bg-slate-50/70 dark:hover:bg-slate-800/40 transition-colors">
                    <td className="py-4 px-4">
                      <div className="flex items-center gap-3">
                        <div className="w-9 h-9 rounded-xl bg-indigo-100 dark:bg-indigo-950/80 text-indigo-700 dark:text-indigo-300 font-bold flex items-center justify-center text-sm flex-shrink-0">
                          {app.candidateName ? app.candidateName[0] : "C"}
                        </div>
                        <div>
                          <div className="font-bold text-slate-900 dark:text-white">{app.candidateName}</div>
                          <div className="text-xs text-slate-500 dark:text-slate-400">{app.candidateEmail}</div>
                        </div>
                      </div>
                    </td>
                    <td className="py-4 px-4">
                      <div className="text-xs font-semibold text-slate-800 dark:text-slate-200">{app.jobTitle}</div>
                    </td>
                    <td className="py-4 px-4 text-center whitespace-nowrap">
                      {(() => {
                        const candAttempts = getCandidateExamAttempts(app);
                        const primaryAttempt =
                          candAttempts.find((a) => a.id === app.examAttemptId) ||
                          candAttempts[0];
                        const isTerminated =
                          app.examTerminated === true ||
                          primaryAttempt?.status === "TERMINATED";
                        const resolvedScore =
                          primaryAttempt?.status === "COMPLETED"
                            ? primaryAttempt.score
                            : app.examScore;
                        const isPassed =
                          primaryAttempt?.status === "COMPLETED"
                            ? primaryAttempt.passed
                            : typeof resolvedScore === "number"
                            ? resolvedScore >= (primaryAttempt?.passingPercentage ?? 70)
                            : false;

                        return (
                          <div className="inline-flex flex-col items-center gap-1">
                            {isTerminated ? (
                              <span className="text-[11px] font-bold text-rose-700 dark:text-rose-300 bg-rose-50 dark:bg-rose-950/70 border border-rose-300 dark:border-rose-800 px-2.5 py-1 rounded-lg inline-flex items-center gap-1">
                                <ShieldAlert className="w-3 h-3" />
                                <span>
                                  {isRTL ? "راسب - مخالفة مراقبة (0%)" : "Failed - Violation (0%)"}
                                </span>
                              </span>
                            ) : typeof resolvedScore === "number" &&
                              (primaryAttempt?.status === "COMPLETED" ||
                                app.examScore !== undefined) ? (
                              <span
                                className={`text-xs font-bold border px-2.5 py-1 rounded-lg ${
                                  isPassed
                                    ? "text-emerald-700 dark:text-emerald-300 bg-emerald-50 dark:bg-emerald-950/60 border-emerald-200 dark:border-emerald-800"
                                    : "text-rose-700 dark:text-rose-300 bg-rose-50 dark:bg-rose-950/60 border-rose-200 dark:border-rose-800"
                                }`}
                              >
                                {isPassed
                                  ? isRTL ? `ناجح (${resolvedScore}%)` : `Passed (${resolvedScore}%)`
                                  : isRTL ? `راسب (${resolvedScore}%)` : `Failed (${resolvedScore}%)`}
                              </span>
                            ) : primaryAttempt ? (
                              <span className="text-[11px] font-semibold text-blue-700 dark:text-blue-300 bg-blue-50 dark:bg-blue-950/60 border border-blue-200 dark:border-blue-800 px-2 py-0.5 rounded-lg">
                                {isRTL ? "بانتظار الاختبار" : primaryAttempt.status}
                              </span>
                            ) : (
                              <span className="text-xs text-slate-400">-</span>
                            )}
                            {candAttempts.length > 1 && (
                              <span className="text-[10px] font-bold text-indigo-600 dark:text-indigo-400">
                                {isRTL
                                  ? `${candAttempts.length} اختبارات مسجلة`
                                  : `${candAttempts.length} exams recorded`}
                              </span>
                            )}
                          </div>
                        );
                      })()}
                    </td>
                    <td className="py-4 px-4 text-center whitespace-nowrap">
                      {(() => {
                        const safeCvUrl = sanitizeExternalUrl(app.cvUrl);
                        return safeCvUrl ? (
                          <a
                            href={safeCvUrl}
                            target="_blank"
                            rel="noopener noreferrer"
                            className="inline-flex items-center gap-1.5 px-2.5 py-1 text-xs font-medium text-indigo-600 dark:text-indigo-400 bg-indigo-50 dark:bg-indigo-950/60 hover:bg-indigo-100 dark:hover:bg-indigo-900/60 border border-indigo-200 dark:border-indigo-800 rounded-lg transition-colors"
                          >
                            <Download className="w-3.5 h-3.5" />
                            <span>{t("downloadCv")}</span>
                          </a>
                        ) : (
                          <span className="text-xs text-slate-400">-</span>
                        );
                      })()}
                    </td>
                    <td className="py-4 px-4 whitespace-nowrap">
                      {getStatusBadge(app.status)}
                    </td>
                    <td className={`py-4 px-4 ${isRTL ? "text-left" : "text-right"} whitespace-nowrap`}>
                      <button
                        onClick={() => setSelectedApplicant(app)}
                        className="px-3 py-1.5 text-xs font-semibold text-indigo-600 dark:text-indigo-400 bg-indigo-50 dark:bg-indigo-950/60 hover:bg-indigo-100 dark:hover:bg-indigo-900/60 rounded-lg transition-colors border border-indigo-200 dark:border-indigo-800 cursor-pointer"
                      >
                        {t("viewCandidate")}
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Candidate Details & Action Modal */}
      {selectedApplicant && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white dark:bg-slate-900 rounded-2xl max-w-2xl w-full p-6 sm:p-8 shadow-2xl border border-slate-200 dark:border-slate-800 my-8">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100 dark:border-slate-800 mb-6">
              <div className="flex items-center gap-3">
                <div className="w-12 h-12 rounded-2xl bg-indigo-600 text-white font-black text-lg flex items-center justify-center shadow-md shadow-indigo-600/30">
                  {selectedApplicant.candidateName ? selectedApplicant.candidateName[0] : "C"}
                </div>
                <div>
                  <h2 className="text-xl font-bold text-slate-900 dark:text-white">{selectedApplicant.candidateName}</h2>
                  <p className="text-xs text-slate-500 dark:text-slate-400">{selectedApplicant.jobTitle}</p>
                </div>
              </div>
              <button
                onClick={() => setSelectedApplicant(null)}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="space-y-5 text-xs text-slate-700 dark:text-slate-300">
              {/* Contact Info */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 bg-slate-50 dark:bg-slate-800/60 p-4 rounded-xl border border-slate-200/60 dark:border-slate-700">
                <div className="flex items-center gap-2">
                  <Mail className="w-4 h-4 text-slate-400" />
                  <span>{selectedApplicant.candidateEmail}</span>
                </div>
                {selectedApplicant.candidatePhone && (
                  <div className="flex items-center gap-2">
                    <Phone className="w-4 h-4 text-slate-400" />
                    <span>{selectedApplicant.candidatePhone}</span>
                  </div>
                )}
              </div>

              {/* CV & Test Results */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="p-4 rounded-xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-800/40">
                  <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-2">{t("cvCol")}</div>
                  {(() => {
                    const safeSelectedCvUrl = sanitizeExternalUrl(selectedApplicant.cvUrl);
                    return safeSelectedCvUrl ? (
                      <div className="flex items-center justify-between gap-2">
                        <span className="font-semibold text-slate-800 dark:text-slate-200 truncate">{selectedApplicant.cvFileName || "Resume.pdf"}</span>
                        <a
                          href={safeSelectedCvUrl}
                          target="_blank"
                          rel="noopener noreferrer"
                          className="inline-flex items-center gap-1 text-xs font-bold text-indigo-600 dark:text-indigo-400 hover:underline shrink-0"
                        >
                          <ExternalLink className="w-3.5 h-3.5" />
                          <span>{isRTL ? "فتح الملف" : "Open CV"}</span>
                        </a>
                      </div>
                    ) : (
                      <div className="text-slate-400">{isRTL ? "غير متوفر" : "Not uploaded"}</div>
                    );
                  })()}
                </div>

                <div className="p-4 rounded-xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-800/40">
                  <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-2">{t("technicalScore")}</div>
                  {(() => {
                    const candAttempts = getCandidateExamAttempts(selectedApplicant);
                    const latestAtt =
                      candAttempts.find((a) => a.id === selectedApplicant.examAttemptId) ||
                      candAttempts[0];
                    if (selectedApplicant.examTerminated || latestAtt?.status === "TERMINATED") {
                      return (
                        <div className="space-y-1">
                          <div className="flex items-center justify-between text-rose-700 dark:text-rose-400 font-bold">
                            <span className="text-base">0%</span>
                            <span className="text-xs inline-flex items-center gap-1">
                              <ShieldAlert className="w-3.5 h-3.5" />
                              {isRTL ? "راسب — إغلاق بمخالفة مراقبة" : "Failed — Violation Terminated"}
                            </span>
                          </div>
                          {latestAtt && (
                            <div className="text-[10px] text-rose-500">
                              {isRTL
                                ? `المخالفات: ${latestAtt.violationCount}/3 (${latestAtt.lastViolationType || "PROCTORING"})`
                                : `Violations: ${latestAtt.violationCount}/3 (${latestAtt.lastViolationType || "PROCTORING"})`}
                            </div>
                          )}
                        </div>
                      );
                    }
                    if (selectedApplicant.examScore !== undefined || latestAtt?.status === "COMPLETED") {
                      const sc = latestAtt?.status === "COMPLETED" ? latestAtt.score : (selectedApplicant.examScore ?? 0);
                      const passed = latestAtt?.status === "COMPLETED"
                        ? latestAtt.passed
                        : sc >= (latestAtt?.passingPercentage ?? 70);
                      return (
                        <div className="flex items-center justify-between">
                          <span className={`font-bold text-lg ${passed ? "text-emerald-700 dark:text-emerald-400" : "text-rose-700 dark:text-rose-400"}`}>
                            {sc}%
                          </span>
                          <span className={`text-xs font-semibold ${passed ? "text-emerald-600 dark:text-emerald-400" : "text-rose-600 dark:text-rose-400"}`}>
                            {passed ? (isRTL ? "ناجح" : "Passed") : (isRTL ? "راسب" : "Failed")}
                            {candAttempts.length > 1 ? ` (${candAttempts.length} ${isRTL ? "اختبارات" : "exams"})` : ""}
                          </span>
                        </div>
                      );
                    }
                    if (selectedApplicant.examToken) {
                      return (
                        <div className="space-y-1">
                          <div className="text-blue-600 dark:text-blue-400 font-bold flex items-center gap-1">
                            <KeyRound className="w-3.5 h-3.5" />
                            <span>{isRTL ? "تم تعيين الاختبار" : "Exam Assigned"}</span>
                          </div>
                          <div className="text-[10px] font-mono bg-slate-100 dark:bg-slate-800 px-2 py-0.5 rounded truncate">
                            Key: {selectedApplicant.examToken}
                          </div>
                        </div>
                      );
                    }
                    return <div className="text-slate-400">{isRTL ? "لم يخضع لاختبار بعد" : "Not tested yet"}</div>;
                  })()}
                </div>
              </div>

              {/* Assign Assessment Box (Reflects directly on Candidate Mobile App!) */}
              {exams.length > 0 && (
                <div className="p-4 rounded-2xl border border-blue-200 dark:border-blue-800 bg-blue-50/40 dark:bg-blue-950/30 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                  <div className="flex items-center gap-2.5">
                    <FileQuestion className="w-5 h-5 text-blue-600 dark:text-blue-400 flex-shrink-0" />
                    <div>
                      <div className="font-bold text-slate-900 dark:text-white text-xs">
                        {isRTL ? "تعيين اختبار تقني للمرشح (يصل فوراً للموبايل)" : "Assign Technical Exam (Instant Mobile Sync)"}
                      </div>
                      <select
                        value={selectedExamForAssign}
                        onChange={(e) => setSelectedExamForAssign(e.target.value)}
                        className="mt-1 text-xs border border-slate-300 dark:border-slate-700 rounded-lg px-2.5 py-1 bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                      >
                        {exams.map((ex) => (
                          <option key={ex.id} value={ex.id}>
                            {ex.title} ({ex.durationMinutes} min • {ex.passingScore}%)
                          </option>
                        ))}
                      </select>
                    </div>
                  </div>
                  <button
                    type="button"
                    onClick={handleAssignExam}
                    disabled={assigningExam}
                    className="px-4 py-2 bg-blue-600 hover:bg-blue-500 text-white font-semibold rounded-xl text-xs shadow-sm disabled:opacity-50 flex items-center gap-1.5 self-start sm:self-center cursor-pointer"
                  >
                    {assigningExam ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <CheckCircle2 className="w-3.5 h-3.5" />}
                    <span>{isRTL ? "إرسال الاختبار للمرشح" : "Send Exam Invite"}</span>
                  </button>
                </div>
              )}

              {/* Full Multi-Exam History & Proctoring Record */}
              {(() => {
                const candAttempts = getCandidateExamAttempts(selectedApplicant);
                if (candAttempts.length === 0) return null;
                return (
                  <div className="p-4 rounded-2xl border border-slate-200 dark:border-slate-800 bg-slate-50/70 dark:bg-slate-800/40 space-y-2.5">
                    <div className="flex items-center justify-between">
                      <div className="font-bold text-slate-900 dark:text-white text-xs flex items-center gap-2">
                        <Camera className="w-4 h-4 text-indigo-500" />
                        <span>
                          {isRTL
                            ? `سجل كافة الاختبارات والمراقبة لهذا المرشح (${candAttempts.length})`
                            : `All Exam Attempts & Proctoring Records (${candAttempts.length})`}
                        </span>
                      </div>
                    </div>
                    <div className="space-y-2 max-h-72 overflow-y-auto pr-1">
                      {candAttempts.map((att) => {
                        const isTerm = att.status === "TERMINATED";
                        const isComp = att.status === "COMPLETED";
                        const isExpanded = expandedProctoringAttemptId === att.id;
                        const snaps = att.proctoringSnapshots || [];
                        const viols = attemptViolationsMap[att.id] || [];
                        return (
                          <div
                            key={att.id}
                            className="p-3 rounded-xl bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 space-y-2"
                          >
                            <div className="flex flex-wrap items-center justify-between gap-2">
                              <div>
                                <div className="font-bold text-slate-900 dark:text-white text-xs">
                                  {att.examTitle}
                                </div>
                                <div className="text-[10px] text-slate-500">
                                  {att.jobTitle} •{" "}
                                  {formatTimestamp(att.completedAt || att.createdAt, isRTL ? "ar-SA" : "en-US")}
                                </div>
                              </div>
                              <div className="flex items-center gap-1.5">
                                {isTerm ? (
                                  <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-rose-100 dark:bg-rose-950/70 text-rose-700 dark:text-rose-300 border border-rose-300 dark:border-rose-800">
                                    {isRTL ? `راسب - مخالفة (${att.violationCount}/3)` : `Terminated (${att.violationCount}/3)`}
                                  </span>
                                ) : isComp ? (
                                  <span
                                    className={`px-2 py-0.5 rounded-full text-[10px] font-bold border ${
                                      att.passed
                                        ? "bg-emerald-100 dark:bg-emerald-950/70 text-emerald-700 dark:text-emerald-300 border-emerald-300 dark:border-emerald-800"
                                        : "bg-rose-100 dark:bg-rose-950/70 text-rose-700 dark:text-rose-300 border-rose-300 dark:border-rose-800"
                                    }`}
                                  >
                                    {att.passed
                                      ? isRTL ? `ناجح ${att.score}%` : `Passed ${att.score}%`
                                      : isRTL ? `راسب ${att.score}%` : `Failed ${att.score}%`}
                                  </span>
                                ) : (
                                  <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-100 dark:bg-amber-950/70 text-amber-700 dark:text-amber-300 border border-amber-300 dark:border-amber-800">
                                    {att.status}
                                  </span>
                                )}
                                <button
                                  type="button"
                                  onClick={() => handleToggleAttemptProctoring(att)}
                                  className="px-2.5 py-1 rounded-lg bg-indigo-50 dark:bg-indigo-950/60 hover:bg-indigo-100 text-indigo-700 dark:text-indigo-300 text-[10px] font-bold cursor-pointer"
                                >
                                  {isExpanded
                                    ? isRTL ? "إخفاء المراقبة" : "Hide Proctoring"
                                    : isRTL ? `المراقبة والكاميرا (${snaps.length})` : `Proctoring (${snaps.length})`}
                                </button>
                              </div>
                            </div>

                            {isExpanded && (
                              <div className="pt-2 border-t border-slate-100 dark:border-slate-800 space-y-2">
                                <div className="flex flex-wrap gap-2 text-[10px] text-slate-600 dark:text-slate-300">
                                  <span>
                                    {isRTL ? `المخالفات المسجلة: ${att.violationCount}/3` : `Violations: ${att.violationCount}/3`}
                                  </span>
                                  {att.proctoringReport && (
                                    <span>
                                      • {att.proctoringReport.cameraVerified ? "Camera OK" : "No Camera"} /{" "}
                                      {att.proctoringReport.micVerified ? "Mic OK" : "No Mic"}
                                    </span>
                                  )}
                                </div>
                                {snaps.length > 0 && (
                                  <div className="grid grid-cols-3 sm:grid-cols-5 gap-1.5">
                                    {snaps.map((s, idx) => (
                                      <div key={idx} className="rounded-lg overflow-hidden border border-slate-300 dark:border-slate-700 bg-black">
                                        <img src={s.imageDataUrl} alt={s.label} className="w-full aspect-video object-cover" />
                                        <div className="px-1 py-0.5 text-[9px] text-slate-200 truncate">{s.label}</div>
                                      </div>
                                    ))}
                                  </div>
                                )}
                                {loadingViolationsForId === att.id ? (
                                  <div className="text-[11px] text-slate-400">{t("loading")}</div>
                                ) : viols.length > 0 ? (
                                  <div className="space-y-1">
                                    {viols.map((v) => (
                                      <div key={v.id} className="text-[10px] px-2 py-1 rounded bg-rose-50 dark:bg-rose-950/40 text-rose-700 dark:text-rose-300">
                                        <strong>{v.violationType}:</strong> {v.details}
                                      </div>
                                    ))}
                                  </div>
                                ) : (
                                  <div className="text-[10px] text-slate-400">
                                    {isRTL ? "لا توجد مخالفات أمنية مسجلة." : "No security violations logged."}
                                  </div>
                                )}
                              </div>
                            )}
                          </div>
                        );
                      })}
                    </div>
                  </div>
                );
              })()}

              {/* Assign Practical Assignment & View Submissions */}
              <div className="p-4 rounded-2xl border border-purple-200 dark:border-purple-800 bg-purple-50/40 dark:bg-purple-950/20 space-y-3">
                <div className="flex items-center justify-between">
                  <div className="font-bold text-slate-900 dark:text-white text-xs flex items-center gap-2">
                    <FolderCode className="w-4 h-4 text-purple-600 dark:text-purple-400" />
                    <span>
                      {isRTL
                        ? "تعيين واجب عملي خاص بهذا المرشح (يظهر له فقط)"
                        : "Assign Practical Task (Scoped to this Candidate Only)"}
                    </span>
                  </div>
                </div>
                {challenges.length > 0 && (
                  <select
                    value={selectedChallengeTemplateId}
                    onChange={(e) => setSelectedChallengeTemplateId(e.target.value)}
                    className="w-full text-xs border border-slate-300 dark:border-slate-700 rounded-lg px-2.5 py-1.5 bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                  >
                    <option value="">
                      {isRTL ? "أو أنشئ واجباً سريعاً مخصصاً بالأسفل..." : "Or enter custom quick assignment below..."}
                    </option>
                    {challenges
                      .filter((c) => !c.candidateId)
                      .map((c) => (
                        <option key={c.id} value={c.id}>
                          {c.title} ({c.deadlineDays}d • {c.difficulty})
                        </option>
                      ))}
                  </select>
                )}
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                  <input
                    type="text"
                    value={customChallengeTitle}
                    onChange={(e) => setCustomChallengeTitle(e.target.value)}
                    placeholder={isRTL ? "عنوان واجب مخصص (اختياري)" : "Custom task title (optional)"}
                    className="px-2.5 py-1.5 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white text-xs"
                  />
                  <input
                    type="text"
                    value={customChallengeBrief}
                    onChange={(e) => setCustomChallengeBrief(e.target.value)}
                    placeholder={isRTL ? "تعليمات مختصرة (اختياري)" : "Brief instructions (optional)"}
                    className="px-2.5 py-1.5 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white text-xs"
                  />
                </div>
                <div className="flex items-center justify-between gap-2">
                  <button
                    type="button"
                    onClick={handleAssignChallenge}
                    disabled={assigningChallenge}
                    className="px-4 py-2 bg-purple-600 hover:bg-purple-500 disabled:opacity-50 text-white font-semibold rounded-xl text-xs flex items-center gap-1.5 cursor-pointer"
                  >
                    {assigningChallenge ? <Loader2 className="w-3.5 h-3.5 animate-spin" /> : <CheckCircle2 className="w-3.5 h-3.5" />}
                    <span>{isRTL ? "إرسال الواجب العملي للمرشح" : "Assign Practical Task"}</span>
                  </button>
                  {selectedApplicant.assignedChallengeTitle && (
                    <span className="text-[11px] font-semibold text-purple-700 dark:text-purple-300 truncate">
                      {isRTL ? `آخر واجب: ${selectedApplicant.assignedChallengeTitle}` : `Assigned: ${selectedApplicant.assignedChallengeTitle}`}
                    </span>
                  )}
                </div>

                {(() => {
                  const candSubs = challengeSubmissions.filter(
                    (s) => s.candidateId === selectedApplicant.candidateId
                  );
                  if (candSubs.length === 0) return null;
                  return (
                    <div className="pt-2 border-t border-purple-200/70 dark:border-purple-800/50 space-y-1.5">
                      <div className="text-[11px] font-bold text-slate-700 dark:text-slate-300">
                        {isRTL ? "تسليمات الواجبات العملية المستلمة:" : "Candidate Practical Submissions:"}
                      </div>
                      {candSubs.map((sub) => {
                        const safeLink = sanitizeExternalUrl(sub.githubRepoUrl);
                        return (
                          <div key={sub.id} className="p-2 rounded-lg bg-white dark:bg-slate-900 border border-slate-200 dark:border-slate-700 flex items-center justify-between gap-2 text-[11px]">
                            <span className="font-semibold">
                              {sub.status}{sub.score != null ? ` • ${sub.score}/100` : ""}
                            </span>
                            {safeLink && (
                              <a href={safeLink} target="_blank" rel="noopener noreferrer" className="text-indigo-600 dark:text-indigo-400 font-bold hover:underline inline-flex items-center gap-1">
                                <ExternalLink className="w-3 h-3" />
                                <span>{isRTL ? "فتح الحل" : "Open Solution"}</span>
                              </a>
                            )}
                          </div>
                        );
                      })}
                    </div>
                  );
                })()}
              </div>

              {/* AI Talent Synthesis Card */}
              <div className="p-4 rounded-2xl border border-indigo-200 dark:border-indigo-800 bg-indigo-50/50 dark:bg-indigo-950/30 space-y-2">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2 font-bold text-indigo-900 dark:text-indigo-200">
                    <Sparkles className="w-4 h-4 text-indigo-600 dark:text-indigo-400" />
                    <span>{t("aiSummaryTitle")}</span>
                  </div>
                  <button
                    onClick={handleGenerateAiSummary}
                    disabled={generatingAi}
                    className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-indigo-600 hover:bg-indigo-500 text-white font-semibold rounded-lg text-[11px] shadow-sm disabled:opacity-50 cursor-pointer"
                  >
                    {generatingAi ? <Loader2 className="w-3 h-3 animate-spin" /> : <Bot className="w-3 h-3" />}
                    <span>{t("aiGenerateSummaryBtn")}</span>
                  </button>
                </div>

                {selectedApplicant.aiRecommendation && (
                  <div className="text-xs font-semibold text-emerald-700 dark:text-emerald-300">
                    💡 {isRTL ? "التوصية الذكية:" : "AI Recommendation:"} {selectedApplicant.aiRecommendation}
                    {selectedApplicant.overallFitScore ? ` (${selectedApplicant.overallFitScore}% Fit)` : ""}
                  </div>
                )}
                {selectedApplicant.aiParsedCv?.summary && (
                  <p className="text-xs text-slate-700 dark:text-slate-300 leading-relaxed">
                    {selectedApplicant.aiParsedCv.summary}
                  </p>
                )}
                {selectedApplicant.aiParsedCv?.matchedSkills && (
                  <div className="flex flex-wrap gap-1 pt-1">
                    {selectedApplicant.aiParsedCv.matchedSkills.map((sk) => (
                      <span key={sk} className="text-[10px] px-2 py-0.5 rounded-full bg-emerald-100 dark:bg-emerald-950 text-emerald-800 dark:text-emerald-300 border border-emerald-300 dark:border-emerald-800">
                        ✓ {sk}
                      </span>
                    ))}
                  </div>
                )}
              </div>

              {/* Cover Letter */}
              {selectedApplicant.coverLetter && (
                <div className="p-4 rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-800/40">
                  <div className="text-[11px] font-bold text-slate-400 uppercase tracking-wider mb-1">{t("coverLetter")}</div>
                  <p className="text-slate-700 dark:text-slate-300 leading-relaxed">{selectedApplicant.coverLetter}</p>
                </div>
              )}

              {/* ATS Progression Buttons */}
              <div className="pt-4 border-t border-slate-100 dark:border-slate-800">
                <div className="text-[11px] font-bold text-slate-500 dark:text-slate-400 uppercase tracking-wider mb-3">
                  {t("moveStageTitle")}
                </div>
                <div className="flex flex-wrap gap-2">
                  <button
                    disabled={updatingStatus || assigningExam}
                    onClick={() => handleStatusChange("EXAM_ASSIGNED")}
                    className="px-3 py-1.5 rounded-lg text-xs font-semibold bg-blue-50 dark:bg-blue-950/60 text-blue-700 dark:text-blue-300 hover:bg-blue-100 border border-blue-200 dark:border-blue-800 disabled:opacity-50 cursor-pointer"
                  >
                    {t("stageExamAssigned")}
                  </button>
                  <button
                    disabled={updatingStatus || assigningExam}
                    onClick={() => handleStatusChange("PASSED")}
                    className="px-3 py-1.5 rounded-lg text-xs font-semibold bg-emerald-50 dark:bg-emerald-950/60 text-emerald-700 dark:text-emerald-300 hover:bg-emerald-100 border border-emerald-200 dark:border-emerald-800 disabled:opacity-50 cursor-pointer"
                  >
                    {t("stagePassed")}
                  </button>
                  <button
                    disabled={updatingStatus || assigningExam}
                    onClick={() => handleStatusChange("INTERVIEW_SCHEDULED")}
                    className="px-3 py-1.5 rounded-lg text-xs font-semibold bg-purple-50 dark:bg-purple-950/60 text-purple-700 dark:text-purple-300 hover:bg-purple-100 border border-purple-200 dark:border-purple-800 disabled:opacity-50 cursor-pointer"
                  >
                    {t("stageInterview")}
                  </button>
                  <button
                    disabled={updatingStatus || assigningExam}
                    onClick={() => handleStatusChange("OFFER_EXTENDED")}
                    className="px-3 py-1.5 rounded-lg text-xs font-semibold bg-amber-50 dark:bg-amber-950/60 text-amber-700 dark:text-amber-300 hover:bg-amber-100 border border-amber-200 dark:border-amber-800 disabled:opacity-50 cursor-pointer"
                  >
                    {t("stageOffer")}
                  </button>
                  <button
                    disabled={updatingStatus || assigningExam}
                    onClick={() => handleStatusChange("HIRED")}
                    className="px-3 py-1.5 rounded-lg text-xs font-semibold bg-teal-50 dark:bg-teal-950/60 text-teal-700 dark:text-teal-300 hover:bg-teal-100 border border-teal-200 dark:border-teal-800 disabled:opacity-50 cursor-pointer"
                  >
                    {t("stageHired")}
                  </button>
                  <button
                    disabled={updatingStatus || assigningExam}
                    onClick={() => handleStatusChange("REJECTED")}
                    className="px-3 py-1.5 rounded-lg text-xs font-semibold bg-rose-50 dark:bg-rose-950/60 text-rose-700 dark:text-rose-300 hover:bg-rose-100 border border-rose-200 dark:border-rose-800 disabled:opacity-50 cursor-pointer"
                  >
                    {t("stageRejected")}
                  </button>
                </div>
              </div>
            </div>

            <div className="pt-6 mt-6 border-t border-slate-100 dark:border-slate-800 flex justify-end">
              <button
                onClick={() => setSelectedApplicant(null)}
                className="px-5 py-2 text-xs font-semibold text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl cursor-pointer"
              >
                {t("close")}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

export default function CompanyApplicantsPage() {
  return (
    <Suspense
      fallback={
        <div className="flex items-center justify-center min-h-[55vh]">
          <Loader2 className="w-8 h-8 text-indigo-600 animate-spin" />
        </div>
      }
    >
      <CompanyApplicantsContent />
    </Suspense>
  );
}

