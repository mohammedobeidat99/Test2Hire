"use client";

import React, { useEffect, useState, Suspense } from "react";
import { useSearchParams } from "next/navigation";
import { auth } from "@/lib/firebase";
import { onAuthStateChanged } from "firebase/auth";
import { useCompany } from "@/lib/i18n";
import { formatTimestamp, sanitizeExternalUrl } from "@/lib/formatters";
import {
  fetchCompanyExams,
  fetchCompanyExamQuestions,
  createCompanyExam,
  updateCompanyExam,
  deleteCompanyExam,
  listenCompanyExamAttempts,
  fetchExamAttemptViolations,
  listenCompanyJobs,
  fetchCompanyChallenges,
  createCompanyChallenge,
  updateCompanyChallenge,
  deleteCompanyChallenge,
  fetchCompanyChallengeSubmissions,
  gradeChallengeSubmission,
  CompanyExam,
  CompanyExamAttempt,
  CompanyExamViolation,
  CompanyJob,
  CompanyChallenge,
  CompanyChallengeSubmission,
} from "@/lib/company-portal-service";
import {
  FileQuestion,
  Plus,
  Clock,
  Award,
  CheckCircle2,
  AlertCircle,
  Trash2,
  Eye,
  X,
  Loader2,
  Sparkles,
  Pencil,
  ShieldAlert,
  Camera,
  Mic,
  FolderCode,
  ExternalLink,
  Users,
} from "lucide-react";

interface QuestionDraft {
  text: string;
  options: string[];
  correctIndex: number;
  correctIndices?: number[];
  points: number;
  type?: string;
}

function CompanyExamsContent() {
  const { t, isRTL } = useCompany();
  const searchParams = useSearchParams();

  const [activeTab, setActiveTab] = useState<"EXAMS" | "CHALLENGES">(() =>
    searchParams.get("tab") === "challenges" ? "CHALLENGES" : "EXAMS"
  );

  const [exams, setExams] = useState<CompanyExam[]>([]);
  const [examAttempts, setExamAttempts] = useState<CompanyExamAttempt[]>([]);
  const [jobs, setJobs] = useState<CompanyJob[]>([]);
  const [challenges, setChallenges] = useState<CompanyChallenge[]>([]);
  const [submissions, setSubmissions] = useState<CompanyChallengeSubmission[]>([]);

  const [loading, setLoading] = useState(true);
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);
  const [editingExamId, setEditingExamId] = useState<string | null>(null);
  const [loadingEditExam, setLoadingEditExam] = useState(false);

  const [previewExam, setPreviewExam] = useState<CompanyExam | null>(null);
  const [recordsExam, setRecordsExam] = useState<CompanyExam | null>(null);
  const [selectedAttemptViolations, setSelectedAttemptViolations] = useState<{
    attempt: CompanyExamAttempt;
    violations: CompanyExamViolation[];
    loading: boolean;
  } | null>(null);

  const [creating, setCreating] = useState(false);
  const [generatingAi, setGeneratingAi] = useState(false);
  const [loadingPreview, setLoadingPreview] = useState(false);
  const [actionFeedback, setActionFeedback] = useState<{ type: "success" | "error"; text: string } | null>(null);

  // Challenge Modal & Grading State
  const [isChallengeModalOpen, setIsChallengeModalOpen] = useState(false);
  const [editingChallengeId, setEditingChallengeId] = useState<string | null>(null);
  const [savingChallenge, setSavingChallenge] = useState(false);
  const [chTitle, setChTitle] = useState("");
  const [chBrief, setChBrief] = useState("");
  const [chInstructions, setChInstructions] = useState("");
  const [chDifficulty, setChDifficulty] = useState<"BEGINNER" | "INTERMEDIATE" | "ADVANCED" | "EXPERT">("INTERMEDIATE");
  const [chDeadlineDays, setChDeadlineDays] = useState(3);
  const [chJobId, setChJobId] = useState("");
  const [chTechStack, setChTechStack] = useState("");
  const [chDeliverables, setChDeliverables] = useState("");
  const [chStarterUrl, setChStarterUrl] = useState("");
  const [activeSubmissionsChallenge, setActiveSubmissionsChallenge] = useState<CompanyChallenge | null>(null);
  const [gradingDrafts, setGradingDrafts] = useState<Record<string, { score: string; feedback: string; status: "APPROVED" | "REJECTED" | "UNDER_REVIEW"; saving?: boolean }>>({});

  // AI Generator Parameters
  const [aiQuestionCount, setAiQuestionCount] = useState<number>(5);
  const [aiQuestionType, setAiQuestionType] = useState<string>("SINGLE_CHOICE");
  const [aiDifficulty, setAiDifficulty] = useState<string>("MID");

  // Exam Form State
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [durationMinutes, setDurationMinutes] = useState(30);
  const [passingScore, setPassingScore] = useState(70);
  const [questions, setQuestions] = useState<QuestionDraft[]>([
    {
      text: "",
      options: ["", "", "", ""],
      correctIndex: 0,
      points: 10,
    },
  ]);

  useEffect(() => {
    if (searchParams.get("tab") === "challenges") {
      setActiveTab("CHALLENGES");
    }
  }, [searchParams]);

  const loadExams = async (uid?: string) => {
    const targetUid = uid || auth.currentUser?.uid;
    if (!targetUid) return;
    try {
      setLoading(true);
      const [examsData, chData, subData] = await Promise.all([
        fetchCompanyExams(targetUid),
        fetchCompanyChallenges(targetUid),
        fetchCompanyChallengeSubmissions(targetUid),
      ]);
      setExams(examsData);
      setChallenges(chData);
      setSubmissions(subData);
    } catch (err: any) {
      console.error("Failed to load exams:", err);
      setActionFeedback({ type: "error", text: t("error") });
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    let unsubAttempts: (() => void) | null = null;
    let unsubJobs: (() => void) | null = null;

    const unsub = onAuthStateChanged(auth, (user) => {
      if (unsubAttempts) unsubAttempts();
      if (unsubJobs) unsubJobs();
      if (user) {
        loadExams(user.uid);
        unsubAttempts = listenCompanyExamAttempts(user.uid, setExamAttempts);
        unsubJobs = listenCompanyJobs(user.uid, setJobs);
      } else {
        setLoading(false);
      }
    });
    return () => {
      unsub();
      if (unsubAttempts) unsubAttempts();
      if (unsubJobs) unsubJobs();
    };
  }, []);

  // Auto-dismiss notification after 6 seconds
  useEffect(() => {
    if (!actionFeedback) return;
    const timer = setTimeout(() => {
      setActionFeedback(null);
    }, 6000);
    return () => clearTimeout(timer);
  }, [actionFeedback]);

  const handleAddQuestion = () => {
    if (aiQuestionType === "TRUE_FALSE") {
      setQuestions((prev) => [
        ...prev,
        {
          text: "",
          type: "TRUE_FALSE",
          options: isRTL ? ["صح", "خطأ"] : ["True", "False"],
          correctIndex: 0,
          points: 10,
        },
      ]);
    } else {
      setQuestions((prev) => [
        ...prev,
        {
          text: "",
          type: aiQuestionType,
          options: ["", "", "", ""],
          correctIndex: 0,
          correctIndices: aiQuestionType === "MULTIPLE_CHOICE" ? [0] : undefined,
          points: 10,
        },
      ]);
    }
  };

  const handleQuestionTypeChange = (qIndex: number, newType: string) => {
    setQuestions((prev) =>
      prev.map((q, idx) => {
        if (idx !== qIndex) return q;
        if (newType === "TRUE_FALSE") {
          return {
            ...q,
            type: newType,
            options: isRTL ? ["صح", "خطأ"] : ["True", "False"],
            correctIndex: q.correctIndex > 1 ? 0 : q.correctIndex,
            correctIndices: undefined,
          };
        }
        const nextOptions =
          q.options.length < 4
            ? [
                q.options[0] || (isRTL ? "الخيار الأول" : "Option 1"),
                q.options[1] || (isRTL ? "الخيار الثاني" : "Option 2"),
                isRTL ? "الخيار الثالث" : "Option 3",
                isRTL ? "الخيار الرابع" : "Option 4",
              ]
            : q.options;
        return {
          ...q,
          type: newType,
          options: nextOptions,
          correctIndices:
            newType === "MULTIPLE_CHOICE"
              ? q.correctIndices?.length
                ? q.correctIndices
                : [q.correctIndex || 0]
              : undefined,
        };
      })
    );
  };

  const handleRemoveQuestion = (index: number) => {
    if (questions.length <= 1) return;
    setQuestions((prev) => prev.filter((_, i) => i !== index));
  };

  const handleOptionChange = (qIndex: number, optIndex: number, val: string) => {
    setQuestions((prev) =>
      prev.map((q, idx) =>
        idx === qIndex
          ? { ...q, options: q.options.map((opt, oi) => (oi === optIndex ? val : opt)) }
          : q
      )
    );
  };

  const handleDeleteExam = async (examId: string) => {
    if (!window.confirm(isRTL ? "هل أنت متأكد من حذف هذا الاختبار؟" : "Are you sure you want to delete this assessment?")) return;
    try {
      await deleteCompanyExam(examId);
      setExams((prev) => prev.filter((ex) => ex.id !== examId));
      setActionFeedback({ type: "success", text: t("success") });
    } catch (err) {
      console.error(err);
      setActionFeedback({ type: "error", text: t("error") });
    }
  };

  const handleGenerateQuestionsWithAi = async () => {
    if (!title.trim()) {
      setActionFeedback({
        type: "error",
        text: isRTL ? "يرجى كتابة عنوان الاختبار أولاً (مثل: Flutter & Cloud Engineer) لتوليد الأسئلة المناسبة." : "Please enter the Exam Title first to generate relevant questions.",
      });
      return;
    }

    try {
      setGeneratingAi(true);
      const idToken = await auth.currentUser?.getIdToken();
      const response = await fetch("/api/ai", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
        },
        body: JSON.stringify({
          action: "generateExamQuestions",
          payload: {
            jobTitle: title.trim(),
            difficulty: aiDifficulty,
            questionCount: aiQuestionCount,
            questionType: aiQuestionType,
            language: isRTL ? "ar" : "en",
          },
        }),
      });
      if (!response.ok) {
        const errBody = await response.json().catch(() => ({}));
        throw new Error(errBody?.error || t("error"));
      }
      const resData = await response.json();

      if (resData?.questions && Array.isArray(resData.questions)) {
        const mapped = resData.questions.map((q: any) => {
          const type = q.type || (q.options?.length === 2 ? "TRUE_FALSE" : aiQuestionType);
          let options = q.options || ["A", "B", "C", "D"];
          if (type === "TRUE_FALSE" && options.length !== 2) {
            options = isRTL ? ["صح", "خطأ"] : ["True", "False"];
          }
          const idx = typeof q.correctAnswerIndex === "number" ? q.correctAnswerIndex : 0;
          return {
            text: q.question,
            type: type,
            options: options,
            correctIndex: idx,
            correctIndices:
              type === "MULTIPLE_CHOICE"
                ? Array.isArray(q.correctAnswerIndices) && q.correctAnswerIndices.length > 0
                  ? q.correctAnswerIndices
                  : [idx]
                : undefined,
            points: q.points || 10,
          };
        });
        setQuestions(mapped);
        setActionFeedback({
          type: "success",
          text: isRTL
            ? `تم توليد وتعبئة ${mapped.length} أسئلة بنجاح بالذكاء الاصطناعي (${aiQuestionType === "TRUE_FALSE" ? "صح أو خطأ" : aiQuestionType === "CODING" ? "أكواد برمجية" : aiQuestionType === "SHORT_ANSWER" ? "مفاهيم وشرح" : aiQuestionType === "MULTIPLE_CHOICE" ? "اختيار متعدد الإجابات" : "اختيار من متعدد"})!`
            : `Generated ${mapped.length} questions successfully with AI!`,
        });
      } else {
        throw new Error(isRTL ? "لم يتم إرجاع أسئلة صالحة من الخادم." : "No valid questions returned.");
      }
    } catch (err: any) {
      console.error("AI error:", err);
      setActionFeedback({
        type: "error",
        text: err.message || t("error"),
      });
    } finally {
      setGeneratingAi(false);
    }
  };

  const resetForm = () => {
    setEditingExamId(null);
    setTitle("");
    setDescription("");
    setDurationMinutes(30);
    setPassingScore(70);
    setQuestions([
      {
        text: "",
        options: ["", "", "", ""],
        correctIndex: 0,
        points: 10,
      },
    ]);
  };

  const handleOpenCreateExam = () => {
    resetForm();
    setIsCreateModalOpen(true);
  };

  const handleOpenEditExam = async (exam: CompanyExam) => {
    setPreviewExam(null);
    setEditingExamId(exam.id);
    setTitle(exam.title || "");
    setDescription(exam.description || "");
    setDurationMinutes(Number(exam.durationMinutes) || 30);
    setPassingScore(Number(exam.passingScore) || 70);
    setIsCreateModalOpen(true);

    if (exam.questions && exam.questions.length > 0) {
      setQuestions(
        exam.questions.map((q) => ({
          text: q.text,
          type: q.type || "SINGLE_CHOICE",
          options: q.options?.length ? q.options : ["", "", "", ""],
          correctIndex: q.correctIndex ?? 0,
          correctIndices: q.correctIndices,
          points: q.points || 10,
        }))
      );
      return;
    }

    if (exam.questionIds && exam.questionIds.length > 0) {
      try {
        setLoadingEditExam(true);
        const hydrated = await fetchCompanyExamQuestions(
          exam.companyId || auth.currentUser?.uid || "",
          exam.questionIds
        );
        if (hydrated.length > 0) {
          setQuestions(
            hydrated.map((q) => ({
              text: q.text,
              type: q.type || "SINGLE_CHOICE",
              options: q.options?.length ? q.options : ["", "", "", ""],
              correctIndex: q.correctIndex ?? 0,
              correctIndices: q.correctIndices,
              points: q.points || 10,
            }))
          );
        }
      } catch (err) {
        console.error("Failed to load exam questions for edit:", err);
        setActionFeedback({ type: "error", text: t("error") });
      } finally {
        setLoadingEditExam(false);
      }
    }
  };

  const handleOpenAttemptDetails = async (attempt: CompanyExamAttempt) => {
    setSelectedAttemptViolations({ attempt, violations: [], loading: true });
    const companyId = auth.currentUser?.uid || attempt.companyId;
    const violations = await fetchExamAttemptViolations(companyId, attempt.id);
    setSelectedAttemptViolations({ attempt, violations, loading: false });
  };

  const openCreateChallengeModal = (existing?: CompanyChallenge) => {
    if (existing) {
      setEditingChallengeId(existing.id);
      setChTitle(existing.title);
      setChBrief(existing.brief);
      setChInstructions(existing.detailedInstructions);
      setChDifficulty(existing.difficulty || "INTERMEDIATE");
      setChDeadlineDays(existing.deadlineDays || 3);
      setChJobId(existing.jobId || "");
      setChTechStack((existing.techStack || []).join(", "));
      setChDeliverables((existing.deliverables || []).join("\n"));
      setChStarterUrl(existing.starterTemplateUrl || "");
    } else {
      setEditingChallengeId(null);
      setChTitle("");
      setChBrief("");
      setChInstructions("");
      setChDifficulty("INTERMEDIATE");
      setChDeadlineDays(3);
      setChJobId(jobs[0]?.id || "");
      setChTechStack("");
      setChDeliverables("");
      setChStarterUrl("");
    }
    setIsChallengeModalOpen(true);
  };

  const handleSaveChallenge = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!auth.currentUser) return;
    if (!chTitle.trim() || !chBrief.trim() || !chInstructions.trim()) {
      setActionFeedback({
        type: "error",
        text: isRTL ? "يرجى إكمال العنوان والملخص والتعليمات للواجب العملي." : "Title, brief, and instructions are required.",
      });
      return;
    }
    const cleanStarter = chStarterUrl.trim() ? sanitizeExternalUrl(chStarterUrl) : null;
    if (chStarterUrl.trim() && !cleanStarter) {
      setActionFeedback({
        type: "error",
        text: isRTL ? "رابط الملف المرجعي غير صالح (يجب أن يبدأ بـ http أو https)." : "Invalid reference URL.",
      });
      return;
    }

    const linkedJob = jobs.find((j) => j.id === chJobId);
    const techArr = chTechStack
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);
    const delivArr = chDeliverables
      .split("\n")
      .map((s) => s.trim())
      .filter(Boolean);

    try {
      setSavingChallenge(true);
      if (editingChallengeId) {
        await updateCompanyChallenge(editingChallengeId, {
          jobId: linkedJob?.id || null,
          jobTitle: linkedJob?.title || null,
          title: chTitle.trim(),
          brief: chBrief.trim(),
          detailedInstructions: chInstructions.trim(),
          difficulty: chDifficulty,
          deadlineDays: Number(chDeadlineDays) || 3,
          techStack: techArr,
          deliverables: delivArr,
          starterTemplateUrl: cleanStarter,
        });
      } else {
        await createCompanyChallenge({
          companyId: auth.currentUser.uid,
          companyName: linkedJob?.companyName || "Company",
          jobId: linkedJob?.id || null,
          jobTitle: linkedJob?.title || null,
          candidateId: null,
          candidateName: null,
          applicationId: null,
          title: chTitle.trim(),
          brief: chBrief.trim(),
          detailedInstructions: chInstructions.trim(),
          difficulty: chDifficulty,
          deadlineDays: Number(chDeadlineDays) || 3,
          techStack: techArr,
          deliverables: delivArr,
          starterTemplateUrl: cleanStarter,
        });
      }
      setIsChallengeModalOpen(false);
      setActionFeedback({ type: "success", text: t("success") });
      loadExams(auth.currentUser.uid);
    } catch (err: any) {
      setActionFeedback({ type: "error", text: err?.message || t("error") });
    } finally {
      setSavingChallenge(false);
    }
  };

  const handleDeleteChallenge = async (challengeId: string) => {
    if (!window.confirm(isRTL ? "هل أنت متأكد من حذف هذا الواجب العملي؟" : "Delete this practical assignment?")) {
      return;
    }
    try {
      await deleteCompanyChallenge(challengeId);
      setChallenges((prev) => prev.filter((c) => c.id !== challengeId));
      setActionFeedback({ type: "success", text: t("success") });
    } catch (err: any) {
      setActionFeedback({ type: "error", text: err?.message || t("error") });
    }
  };

  const handleGradeSubmission = async (sub: CompanyChallengeSubmission, challengeTitle: string) => {
    const draft = gradingDrafts[sub.id];
    const scoreVal = Number(draft?.score ?? sub.score ?? 80);
    const feedbackVal = draft?.feedback ?? sub.reviewerFeedback ?? "";
    const statusVal = draft?.status ?? "APPROVED";
    if (!Number.isFinite(scoreVal) || scoreVal < 0 || scoreVal > 100) {
      setActionFeedback({
        type: "error",
        text: isRTL ? "يجب أن تكون الدرجة بين 0 و 100." : "Score must be between 0 and 100.",
      });
      return;
    }

    setGradingDrafts((prev) => ({
      ...prev,
      [sub.id]: { score: String(scoreVal), feedback: feedbackVal, status: statusVal, saving: true },
    }));
    try {
      await gradeChallengeSubmission({
        submissionId: sub.id,
        score: scoreVal,
        reviewerFeedback: feedbackVal,
        status: statusVal,
        candidateId: sub.candidateId,
        challengeTitle,
        challengeId: sub.challengeId,
      });
      setSubmissions((prev) =>
        prev.map((s) =>
          s.id === sub.id
            ? { ...s, score: scoreVal, reviewerFeedback: feedbackVal, status: statusVal }
            : s
        )
      );
      setActionFeedback({
        type: "success",
        text: isRTL ? "تم حفظ تقييم الواجب العملي وإشعار المرشح!" : "Submission graded and candidate notified!",
      });
    } catch (err: any) {
      setActionFeedback({ type: "error", text: err?.message || t("error") });
    } finally {
      setGradingDrafts((prev) => ({
        ...prev,
        [sub.id]: { ...prev[sub.id], saving: false },
      }));
    }
  };

  const handleCreateExam = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!auth.currentUser) return;

    const dur = Number(durationMinutes);
    const pass = Number(passingScore);
    if (!title.trim()) {
      setActionFeedback({
        type: "error",
        text: isRTL ? "يرجى إدخال عنوان الاختبار." : "Please enter an exam title.",
      });
      return;
    }
    if (Number.isNaN(dur) || dur < 5 || dur > 240) {
      setActionFeedback({
        type: "error",
        text: isRTL ? "يجب أن تتراوح مدة الاختبار بين 5 و 240 دقيقة." : "Exam duration must be between 5 and 240 minutes.",
      });
      return;
    }
    if (Number.isNaN(pass) || pass < 1 || pass > 100) {
      setActionFeedback({
        type: "error",
        text: isRTL ? "يجب أن تكون نسبة النجاح بين 1% و 100%." : "Passing score must be between 1% and 100%.",
      });
      return;
    }

    for (let i = 0; i < questions.length; i++) {
      if (!questions[i].text.trim()) {
        setActionFeedback({
          type: "error",
          text: `${t("questionNumber")} ${i + 1} - ${isRTL ? "يرجى إدخال نص السؤال" : "Please enter question text"}`,
        });
        return;
      }
      if (questions[i].options.some((o) => !o.trim())) {
        setActionFeedback({
          type: "error",
          text: `${t("questionNumber")} ${i + 1} - ${isRTL ? "يرجى إكمال جميع خيارات الإجابة" : "Please fill in all answer options"}`,
        });
        return;
      }
      if (
        questions[i].type === "MULTIPLE_CHOICE" &&
        (!questions[i].correctIndices || questions[i].correctIndices!.length === 0)
      ) {
        setActionFeedback({
          type: "error",
          text: `${t("questionNumber")} ${i + 1} - ${isRTL ? "يرجى تحديد إجابة صحيحة واحدة على الأقل" : "Please select at least one correct answer"}`,
        });
        return;
      }
    }

    try {
      setCreating(true);
      const payload = {
        companyId: auth.currentUser.uid,
        title: title.trim(),
        description: description.trim(),
        durationMinutes: Number(durationMinutes),
        passingScore: Number(passingScore),
        questionsCount: questions.length,
        questions: questions,
      };
      if (editingExamId) {
        await updateCompanyExam(editingExamId, payload);
      } else {
        await createCompanyExam(payload);
      }

      setIsCreateModalOpen(false);
      resetForm();
      setActionFeedback({ type: "success", text: t("success") });
      loadExams();
    } catch (err: any) {
      console.error("Error saving exam:", err);
      setActionFeedback({ type: "error", text: err.message || t("error") });
    } finally {
      setCreating(false);
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 dark:text-white tracking-tight">{t("examsTitle")}</h1>
          <p className="text-sm text-slate-500 dark:text-slate-400 mt-1">{t("examsSubtitle")}</p>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          {activeTab === "EXAMS" ? (
            <button
              onClick={handleOpenCreateExam}
              className="inline-flex items-center gap-2 px-4 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold rounded-xl shadow-lg shadow-indigo-600/30 transition-all hover:scale-[1.02] cursor-pointer"
            >
              <Plus className="w-4 h-4" />
              <span>{t("newExamBtn")}</span>
            </button>
          ) : (
            <button
              onClick={() => openCreateChallengeModal()}
              className="inline-flex items-center gap-2 px-4 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold rounded-xl shadow-lg shadow-indigo-600/30 transition-all hover:scale-[1.02] cursor-pointer"
            >
              <Plus className="w-4 h-4" />
              <span>{isRTL ? "إضافة واجب عملي جديد" : "New Practical Assignment"}</span>
            </button>
          )}
        </div>
      </div>

      {/* Mode Switcher: Technical Exams vs Practical Assignments */}
      <div className="inline-flex p-1 rounded-2xl bg-slate-100 dark:bg-slate-900 border border-slate-200 dark:border-slate-800">
        <button
          type="button"
          onClick={() => setActiveTab("EXAMS")}
          className={`inline-flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer ${
            activeTab === "EXAMS"
              ? "bg-white dark:bg-slate-800 text-indigo-700 dark:text-indigo-300 shadow-sm"
              : "text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white"
          }`}
        >
          <FileQuestion className="w-4 h-4" />
          <span>{isRTL ? `الاختبارات التقنية (${exams.length})` : `Technical Exams (${exams.length})`}</span>
        </button>
        <button
          type="button"
          onClick={() => setActiveTab("CHALLENGES")}
          className={`inline-flex items-center gap-2 px-4 py-2 rounded-xl text-xs font-bold transition-all cursor-pointer ${
            activeTab === "CHALLENGES"
              ? "bg-white dark:bg-slate-800 text-indigo-700 dark:text-indigo-300 shadow-sm"
              : "text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white"
          }`}
        >
          <FolderCode className="w-4 h-4" />
          <span>{isRTL ? `الواجبات العملية (${challenges.length})` : `Practical Assignments (${challenges.length})`}</span>
        </button>
      </div>

      {/* Action Notification Toast (Floating on top of everything, including modals) */}
      {actionFeedback && (
        <div
          className={`fixed top-6 left-1/2 -translate-x-1/2 z-[99999] shadow-2xl max-w-lg w-[92%] sm:w-auto px-5 py-3.5 rounded-2xl text-xs sm:text-sm font-semibold border flex items-center gap-3 backdrop-blur-md transition-all animate-in fade-in slide-in-from-top-4 duration-200 ${
            actionFeedback.type === "success"
              ? "bg-emerald-600 text-white border-emerald-500 shadow-emerald-500/25"
              : "bg-rose-600 text-white border-rose-500 shadow-rose-500/25"
          }`}
        >
          {actionFeedback.type === "success" ? (
            <CheckCircle2 className="w-5 h-5 shrink-0 text-white" />
          ) : (
            <AlertCircle className="w-5 h-5 shrink-0 text-white" />
          )}
          <span className="flex-1 leading-snug">{actionFeedback.text}</span>
          <button
            onClick={() => setActionFeedback(null)}
            className="p-1 rounded-lg text-white/80 hover:text-white hover:bg-white/10 cursor-pointer"
          >
            <X className="w-4 h-4" />
          </button>
        </div>
      )}

      {loading ? (
        <div className="py-24 flex flex-col items-center justify-center gap-3">
          <div className="w-8 h-8 border-4 border-indigo-600 dark:border-indigo-400 border-t-transparent rounded-full animate-spin"></div>
          <p className="text-sm text-slate-500 dark:text-slate-400">{t("loading")}</p>
        </div>
      ) : activeTab === "CHALLENGES" ? (
        challenges.length === 0 ? (
          <div className="bg-white dark:bg-slate-900 p-16 rounded-2xl border border-slate-200 dark:border-slate-800 text-center">
            <FolderCode className="w-12 h-12 text-slate-300 dark:text-slate-600 mx-auto mb-3" />
            <h3 className="text-base font-bold text-slate-800 dark:text-slate-200">
              {isRTL ? "لا توجد واجبات عملية بعد" : "No Practical Assignments Yet"}
            </h3>
            <p className="text-xs text-slate-500 dark:text-slate-400 max-w-md mx-auto mt-1 mb-6">
              {isRTL
                ? "أنشئ واجبات ومشاريع عملية وربطها بوظيفة معينة أو تعيينها لمرشح محدد من صفحة المتقدمين لتقييم تسليماتهم."
                : "Create practical take-home tasks tied to specific jobs or assign them directly to individual candidates."}
            </p>
            <button
              onClick={() => openCreateChallengeModal()}
              className="inline-flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white text-xs font-semibold rounded-xl cursor-pointer"
            >
              <Plus className="w-4 h-4" />
              <span>{isRTL ? "إنشاء واجب عملي" : "Create Practical Assignment"}</span>
            </button>
          </div>
        ) : (
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {challenges.map((ch) => {
              const chSubs = submissions.filter((s) => s.challengeId === ch.id);
              return (
                <div
                  key={ch.id}
                  className="bg-white dark:bg-slate-900 p-6 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-4"
                >
                  <div>
                    <div className="flex items-center justify-between mb-3">
                      <span className="text-[11px] font-bold px-2.5 py-0.5 rounded-full bg-indigo-50 dark:bg-indigo-950/60 text-indigo-700 dark:text-indigo-300 border border-indigo-200 dark:border-indigo-800">
                        {ch.difficulty}
                      </span>
                      <div className="flex items-center gap-1">
                        <button
                          onClick={() => openCreateChallengeModal(ch)}
                          className="p-1.5 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 dark:hover:bg-indigo-950/50 rounded-lg cursor-pointer"
                          title={isRTL ? "تعديل الواجب" : "Edit Assignment"}
                        >
                          <Pencil className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => handleDeleteChallenge(ch.id)}
                          className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 dark:hover:bg-rose-950/50 rounded-lg cursor-pointer"
                          title={t("delete")}
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </div>
                    <h3 className="font-bold text-slate-900 dark:text-white text-base">{ch.title}</h3>
                    <p className="text-xs text-slate-500 dark:text-slate-400 mt-1 line-clamp-2">{ch.brief}</p>
                    <div className="mt-3 flex flex-wrap gap-1.5 text-[11px]">
                      {ch.candidateName ? (
                        <span className="px-2 py-0.5 rounded-md bg-purple-50 dark:bg-purple-950/50 text-purple-700 dark:text-purple-300 border border-purple-200 dark:border-purple-800 font-semibold">
                          {isRTL ? `مخصص لـ: ${ch.candidateName}` : `Candidate: ${ch.candidateName}`}
                        </span>
                      ) : ch.jobTitle ? (
                        <span className="px-2 py-0.5 rounded-md bg-blue-50 dark:bg-blue-950/50 text-blue-700 dark:text-blue-300 border border-blue-200 dark:border-blue-800 font-semibold">
                          {isRTL ? `لوظيفة: ${ch.jobTitle}` : `Job: ${ch.jobTitle}`}
                        </span>
                      ) : (
                        <span className="px-2 py-0.5 rounded-md bg-amber-50 dark:bg-amber-950/50 text-amber-700 dark:text-amber-300 border border-amber-200 dark:border-amber-800 font-semibold">
                          {isRTL ? "غير مربوط بمرشح/وظيفة" : "Unscoped Draft"}
                        </span>
                      )}
                      <span className="px-2 py-0.5 rounded-md bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 font-semibold">
                        {ch.deadlineDays} {isRTL ? "أيام" : "days"}
                      </span>
                    </div>
                  </div>
                  <div className="pt-3 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between">
                    <span className="text-xs font-semibold text-slate-600 dark:text-slate-300">
                      {chSubs.length} {isRTL ? "تسليمات" : "Submissions"}
                    </span>
                    <button
                      type="button"
                      onClick={() => setActiveSubmissionsChallenge(ch)}
                      className="px-3 py-1.5 rounded-xl bg-indigo-50 dark:bg-indigo-950/60 hover:bg-indigo-100 text-indigo-700 dark:text-indigo-300 text-xs font-bold cursor-pointer"
                    >
                      {isRTL ? "مراجعة التسليمات" : "Review Submissions"}
                    </button>
                  </div>
                </div>
              );
            })}
          </div>
        )
      ) : exams.length === 0 ? (
        <div className="bg-white dark:bg-slate-900 p-16 rounded-2xl border border-slate-200 dark:border-slate-800 text-center">
          <FileQuestion className="w-12 h-12 text-slate-300 dark:text-slate-600 mx-auto mb-3" />
          <h3 className="text-base font-bold text-slate-800 dark:text-slate-200">{t("noData")}</h3>
          <p className="text-xs text-slate-500 dark:text-slate-400 max-w-sm mx-auto mt-1 mb-6">
            {isRTL
              ? "قم بإنشاء اختبارات تقنية بأسئلة اختيار من متعدد لتقييم المتقدمين تلقائياً."
              : "Create technical MCQ assessments to evaluate candidates automatically."}
          </p>
          <button
            onClick={handleOpenCreateExam}
            className="inline-flex items-center gap-2 px-4 py-2 bg-indigo-600 text-white text-xs font-semibold rounded-xl cursor-pointer"
          >
            <Plus className="w-4 h-4" />
            <span>{t("newExamBtn")}</span>
          </button>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {exams.map((exam) => {
            const attemptsForExam = examAttempts.filter((a) => a.examId === exam.id);
            const terminatedCount = attemptsForExam.filter((a) => a.status === "TERMINATED").length;
            return (
              <div
                key={exam.id}
                className="bg-white dark:bg-slate-900 p-6 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm hover:shadow-md transition-shadow flex flex-col justify-between"
              >
                <div>
                  <div className="flex items-center justify-between mb-3">
                    <span className="w-10 h-10 rounded-xl bg-indigo-50 dark:bg-indigo-950/60 text-indigo-600 dark:text-indigo-400 flex items-center justify-center font-bold">
                      <FileQuestion className="w-5 h-5" />
                    </span>
                    <div className="flex items-center gap-1">
                      <span className="text-[11px] font-bold px-2 py-0.5 rounded-full bg-emerald-50 dark:bg-emerald-950/60 text-emerald-700 dark:text-emerald-300 border border-emerald-200 dark:border-emerald-800">
                        {t("active")}
                      </span>
                      <button
                        onClick={() => handleOpenEditExam(exam)}
                        className="p-1.5 text-slate-400 hover:text-amber-600 hover:bg-amber-50 dark:hover:bg-amber-950/50 rounded-lg transition-colors cursor-pointer"
                        title={isRTL ? "تعديل الاختبار والأسئلة" : "Edit Exam & Questions"}
                      >
                        <Pencil className="w-4 h-4" />
                      </button>
                      <button
                        onClick={async () => {
                          setPreviewExam(exam);
                          if ((!exam.questions || exam.questions.length === 0) && exam.questionIds?.length) {
                            try {
                              setLoadingPreview(true);
                              const hydrated = await fetchCompanyExamQuestions(
                                exam.companyId || auth.currentUser?.uid || "",
                                exam.questionIds
                              );
                              setPreviewExam((prev) =>
                                prev && prev.id === exam.id ? { ...prev, questions: hydrated } : prev
                              );
                            } catch (err) {
                              console.error("Failed to load exam questions:", err);
                              setActionFeedback({ type: "error", text: t("error") });
                            } finally {
                              setLoadingPreview(false);
                            }
                          }
                        }}
                        className="p-1.5 text-slate-400 hover:text-indigo-600 hover:bg-indigo-50 dark:hover:bg-indigo-950/50 rounded-lg transition-colors cursor-pointer"
                        title={t("view")}
                      >
                        <Eye className="w-4 h-4" />
                      </button>
                      <button
                        onClick={() => handleDeleteExam(exam.id)}
                        className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 dark:hover:bg-rose-950/50 rounded-lg transition-colors cursor-pointer"
                        title={t("delete")}
                      >
                        <Trash2 className="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                  <h3 className="font-bold text-slate-900 dark:text-white text-base">{exam.title}</h3>
                  <p className="text-xs text-slate-500 dark:text-slate-400 mt-1 line-clamp-2">{exam.description || "Technical assessment exam"}</p>
                </div>

                <div className="space-y-3 mt-4 pt-4 border-t border-slate-100 dark:border-slate-800">
                  <div className="flex items-center justify-between text-xs text-slate-600 dark:text-slate-300">
                    <div className="flex items-center gap-1">
                      <Clock className="w-3.5 h-3.5 text-slate-400" />
                      <span>{exam.durationMinutes} min</span>
                    </div>
                    <div className="flex items-center gap-1 font-semibold text-emerald-700 dark:text-emerald-400">
                      <Award className="w-3.5 h-3.5" />
                      <span>{exam.passingScore}% Pass</span>
                    </div>
                    <div className="text-slate-500 dark:text-slate-400 font-medium">
                      {exam.questionsCount || (exam.questions ? exam.questions.length : 0)} Qs
                    </div>
                  </div>

                  <button
                    type="button"
                    onClick={() => setRecordsExam(exam)}
                    className="w-full py-2 px-3 rounded-xl bg-slate-50 dark:bg-slate-800/80 hover:bg-indigo-50 dark:hover:bg-indigo-950/50 border border-slate-200 dark:border-slate-700 text-xs font-bold text-slate-700 dark:text-slate-200 flex items-center justify-between cursor-pointer transition-colors"
                  >
                    <span className="flex items-center gap-1.5">
                      <Users className="w-3.5 h-3.5 text-indigo-500" />
                      <span>
                        {isRTL
                          ? `سجل المتقدمين والمراقبة (${attemptsForExam.length})`
                          : `Candidate Records & Proctoring (${attemptsForExam.length})`}
                      </span>
                    </span>
                    {terminatedCount > 0 && (
                      <span className="px-1.5 py-0.5 rounded-md bg-rose-100 dark:bg-rose-950 text-rose-700 dark:text-rose-300 text-[10px] font-bold">
                        {terminatedCount} {isRTL ? "مخالف" : "Violations"}
                      </span>
                    )}
                  </button>
                </div>
              </div>
            );
          })}
        </div>
      )}

      {/* Preview Exam Modal */}
      {previewExam && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white dark:bg-slate-900 rounded-2xl max-w-2xl w-full p-6 sm:p-8 shadow-2xl border border-slate-200 dark:border-slate-800 my-8">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100 dark:border-slate-800 mb-4">
              <div>
                <h2 className="text-lg font-bold text-slate-900 dark:text-white">{previewExam.title}</h2>
                <p className="text-xs text-slate-500 dark:text-slate-400">
                  {previewExam.durationMinutes} min • {previewExam.passingScore}% Pass
                </p>
              </div>
              <button
                onClick={() => setPreviewExam(null)}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <div className="space-y-3 max-h-[400px] overflow-y-auto">
              {loadingPreview ? (
                <div className="py-10 flex items-center justify-center gap-2 text-xs text-slate-500">
                  <Loader2 className="w-4 h-4 animate-spin text-indigo-600" />
                  <span>{t("loading")}</span>
                </div>
              ) : previewExam.questions && previewExam.questions.length > 0 ? (
                previewExam.questions.map((q, idx) => (
                  <div key={idx} className="p-4 rounded-xl bg-slate-50 dark:bg-slate-800/60 border border-slate-200 dark:border-slate-700 space-y-2 text-xs">
                    <div className="font-bold text-slate-900 dark:text-white">
                      {idx + 1}. {q.text}
                    </div>
                    <div className="grid grid-cols-1 sm:grid-cols-2 gap-1.5">
                      {q.options?.map((opt, oIdx) => {
                        const isCorrect =
                          q.type === "MULTIPLE_CHOICE" && Array.isArray(q.correctIndices) && q.correctIndices.length > 0
                            ? q.correctIndices.includes(oIdx)
                            : q.correctIndex === oIdx;
                        return (
                          <div
                            key={oIdx}
                            className={`px-2.5 py-1.5 rounded-lg border ${
                              isCorrect
                                ? "bg-emerald-50 dark:bg-emerald-950/60 border-emerald-300 dark:border-emerald-700 text-emerald-800 dark:text-emerald-300 font-semibold"
                                : "bg-white dark:bg-slate-800 border-slate-200 dark:border-slate-700 text-slate-600 dark:text-slate-300"
                            }`}
                          >
                            {isCorrect ? "✓ " : ""}{opt}
                          </div>
                        );
                      })}
                    </div>
                  </div>
                ))
              ) : (
                <div className="text-xs text-slate-500 dark:text-slate-400 py-8 text-center">
                  {isRTL
                    ? `يحتوي هذا الاختبار على ${previewExam.questionsCount || 0} سؤال مرتبط ببنك الأسئلة.`
                    : `This assessment contains ${previewExam.questionsCount || 0} questions linked in the question bank.`}
                </div>
              )}
            </div>

            <div className="pt-4 mt-4 border-t border-slate-100 dark:border-slate-800 flex items-center justify-end gap-2">
              <button
                type="button"
                onClick={() => handleOpenEditExam(previewExam)}
                className="px-4 py-2 text-xs font-bold text-indigo-700 dark:text-indigo-300 bg-indigo-50 dark:bg-indigo-950/60 hover:bg-indigo-100 rounded-xl inline-flex items-center gap-1.5 cursor-pointer"
              >
                <Pencil className="w-3.5 h-3.5" />
                <span>{isRTL ? "تعديل الاختبار والأسئلة" : "Edit Exam & Questions"}</span>
              </button>
              <button
                onClick={() => setPreviewExam(null)}
                className="px-4 py-2 text-xs font-semibold text-slate-700 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl cursor-pointer"
              >
                {t("close")}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Create / Edit Exam Modal */}
      {isCreateModalOpen && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white dark:bg-slate-900 rounded-2xl max-w-3xl w-full p-6 sm:p-8 shadow-2xl border border-slate-200 dark:border-slate-800 my-8">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100 dark:border-slate-800 mb-6">
              <div>
                <h2 className="text-xl font-bold text-slate-900 dark:text-white">
                  {editingExamId
                    ? isRTL
                      ? "تعديل الاختبار والأسئلة"
                      : "Edit Exam & Questions"
                    : t("newExamBtn")}
                </h2>
                <p className="text-xs text-slate-500 dark:text-slate-400">
                  {editingExamId
                    ? isRTL
                      ? "قم بتحديث الإعدادات أو تعديل/إضافة/حذف الأسئلة مباشرة"
                      : "Update exam settings or edit, add, and remove questions"
                    : isRTL
                    ? "حدد بيانات الاختبار أو استخدم الذكاء الاصطناعي"
                    : "Configure exam details or generate with AI"}
                </p>
              </div>
              <button
                onClick={() => {
                  setIsCreateModalOpen(false);
                  resetForm();
                }}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {loadingEditExam ? (
              <div className="py-16 flex flex-col items-center justify-center gap-3">
                <Loader2 className="w-8 h-8 animate-spin text-indigo-600" />
                <span className="text-xs text-slate-500">{isRTL ? "جاري تحميل أسئلة الاختبار للتعديل..." : "Loading exam questions..."}</span>
              </div>
            ) : (
            <form onSubmit={handleCreateExam} className="space-y-6">
              {/* In-Dialog Error / Feedback Banner */}
              {actionFeedback && (
                <div
                  className={`p-3.5 rounded-xl border flex items-center justify-between gap-3 text-xs font-semibold ${
                    actionFeedback.type === "success"
                      ? "bg-emerald-50 dark:bg-emerald-950/60 text-emerald-800 dark:text-emerald-200 border-emerald-200 dark:border-emerald-800"
                      : "bg-rose-50 dark:bg-rose-950/60 text-rose-800 dark:text-rose-200 border-rose-200 dark:border-rose-800"
                  }`}
                >
                  <div className="flex items-center gap-2">
                    {actionFeedback.type === "success" ? (
                      <CheckCircle2 className="w-4 h-4 text-emerald-600 dark:text-emerald-400 shrink-0" />
                    ) : (
                      <AlertCircle className="w-4 h-4 text-rose-600 dark:text-rose-400 shrink-0" />
                    )}
                    <span>{actionFeedback.text}</span>
                  </div>
                  <button
                    type="button"
                    onClick={() => setActionFeedback(null)}
                    className="text-[11px] font-bold hover:underline shrink-0"
                  >
                    {t("close")}
                  </button>
                </div>
              )}

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("examTitleLabel")}</label>
                  <input
                    type="text"
                    required
                    value={title}
                    onChange={(e) => setTitle(e.target.value)}
                    placeholder="e.g. Flutter & Mobile Architecture Assessment"
                    className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("examDescLabel")}</label>
                  <input
                    type="text"
                    value={description}
                    onChange={(e) => setDescription(e.target.value)}
                    placeholder="Brief description of the assessment scope"
                    className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                  />
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("examDurationLabel")}</label>
                  <input
                    type="number"
                    min={5}
                    max={180}
                    value={durationMinutes}
                    onChange={(e) => setDurationMinutes(Number(e.target.value))}
                    className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("examPassingScoreLabel")}</label>
                  <input
                    type="number"
                    min={10}
                    max={100}
                    value={passingScore}
                    onChange={(e) => setPassingScore(Number(e.target.value))}
                    className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                  />
                </div>
              </div>

              {/* AI Auto-Generator Panel */}
              <div className="p-5 rounded-2xl border border-indigo-200 dark:border-indigo-800 bg-gradient-to-br from-indigo-50/80 via-white to-purple-50/60 dark:from-indigo-950/40 dark:via-slate-900/60 dark:to-purple-950/30 shadow-sm space-y-4">
                <div className="flex items-start justify-between gap-3">
                  <div className="flex items-center gap-2.5">
                    <div className="p-2 rounded-xl bg-indigo-600 text-white shadow-sm shadow-indigo-600/30">
                      <Sparkles className="w-5 h-5" />
                    </div>
                    <div>
                      <h4 className="text-sm font-bold text-slate-900 dark:text-white flex items-center gap-2">
                        {isRTL ? "توليد الأسئلة بالذكاء الاصطناعي (Gemini AI)" : "AI Assessment Question Generator"}
                        <span className="text-[10px] font-semibold px-2 py-0.5 rounded-full bg-indigo-100 text-indigo-700 dark:bg-indigo-900/50 dark:text-indigo-300">
                          Smart Architect
                        </span>
                      </h4>
                      <p className="text-xs text-slate-500 dark:text-slate-400 mt-0.5">
                        {isRTL
                          ? "حدد عدد الأسئلة ونوعها ومستوى الصعوبة ليقوم الذكاء الاصطناعي بصياغتها فوراً للاختبار."
                          : "Specify the number of questions, question type, and difficulty level to generate."}
                      </p>
                    </div>
                  </div>
                </div>

                {/* Controls Grid */}
                <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 pt-1">
                  {/* Question Count */}
                  <div>
                    <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5">
                      {isRTL ? "عدد الأسئلة المطلوب:" : "Number of Questions:"}
                    </label>
                    <div className="flex items-center gap-1.5">
                      {[3, 5, 10, 15].map((cnt) => (
                        <button
                          key={cnt}
                          type="button"
                          onClick={() => setAiQuestionCount(cnt)}
                          className={`flex-1 py-1.5 text-xs font-bold rounded-lg border transition-all cursor-pointer ${
                            aiQuestionCount === cnt
                              ? "bg-indigo-600 text-white border-indigo-600 shadow-sm shadow-indigo-600/20"
                              : "bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-300 border-slate-200 dark:border-slate-700 hover:border-indigo-300"
                          }`}
                        >
                          {cnt}
                        </button>
                      ))}
                      <input
                        type="number"
                        min="1"
                        max="30"
                        value={aiQuestionCount}
                        onChange={(e) => setAiQuestionCount(Math.min(Math.max(Number(e.target.value) || 1, 1), 30))}
                        className="w-14 px-2 py-1.5 text-xs font-bold text-center rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                        title={isRTL ? "أو أدخل رقماً مخصصاً" : "Or enter custom count"}
                      />
                    </div>
                  </div>

                  {/* Question Type */}
                  <div>
                    <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5">
                      {isRTL ? "نوع وصيغة الأسئلة:" : "Question Type:"}
                    </label>
                    <select
                      value={aiQuestionType}
                      onChange={(e) => setAiQuestionType(e.target.value)}
                      className="w-full px-3 py-1.5 text-xs font-medium rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 cursor-pointer"
                    >
                      <option value="SINGLE_CHOICE">
                        {isRTL ? "اختيار واحد من متعدد (Single Choice)" : "Single Choice (4 options)"}
                      </option>
                      <option value="MULTIPLE_CHOICE">
                        {isRTL ? "اختيار متعدد الإجابات (Multiple Choice)" : "Multiple Choice (Multi-select)"}
                      </option>
                      <option value="TRUE_FALSE">
                        {isRTL ? "صح أو خطأ (True / False)" : "True / False"}
                      </option>
                      <option value="CODING">
                        {isRTL ? "أكواد برمجية وتحدي عملي (Coding)" : "Coding & Practical"}
                      </option>
                      <option value="SHORT_ANSWER">
                        {isRTL ? "مفاهيم هندسية وتطبيقية (Conceptual)" : "Conceptual & Architecture"}
                      </option>
                      <option value="MIXED">
                        {isRTL ? "شامل ومتنوع (تشكيلة مختلطة)" : "Mixed & Comprehensive"}
                      </option>
                    </select>
                  </div>

                  {/* Difficulty */}
                  <div>
                    <label className="block text-xs font-semibold text-slate-700 dark:text-slate-300 mb-1.5">
                      {isRTL ? "مستوى الصعوبة:" : "Difficulty Level:"}
                    </label>
                    <div className="grid grid-cols-3 gap-1">
                      {[
                        { key: "JUNIOR", ar: "مبتدئ", en: "Junior" },
                        { key: "MID", ar: "متوسط", en: "Mid" },
                        { key: "SENIOR", ar: "متقدم", en: "Senior" },
                      ].map((d) => (
                        <button
                          key={d.key}
                          type="button"
                          onClick={() => setAiDifficulty(d.key)}
                          className={`py-1.5 text-xs font-semibold rounded-lg border transition-all cursor-pointer ${
                            aiDifficulty === d.key
                              ? "bg-indigo-600 text-white border-indigo-600 shadow-sm"
                              : "bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-300 border-slate-200 dark:border-slate-700 hover:border-indigo-300"
                          }`}
                        >
                          {isRTL ? d.ar : d.en}
                        </button>
                      ))}
                    </div>
                  </div>
                </div>

                {/* Generate Action Button */}
                <div className="flex items-center justify-end pt-2 border-t border-indigo-100 dark:border-indigo-900/40">
                  <button
                    type="button"
                    onClick={handleGenerateQuestionsWithAi}
                    disabled={generatingAi}
                    className="w-full sm:w-auto px-5 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white rounded-xl text-xs font-bold flex items-center justify-center gap-2 shadow-md shadow-indigo-600/30 disabled:opacity-50 transition-all cursor-pointer"
                  >
                    {generatingAi ? (
                      <Loader2 className="w-4 h-4 animate-spin" />
                    ) : (
                      <Sparkles className="w-4 h-4 text-amber-300" />
                    )}
                    <span>
                      {generatingAi
                        ? isRTL
                          ? "جاري توليد الأسئلة بواسطة Gemini..."
                          : "Generating with Gemini..."
                        : isRTL
                        ? `توليد ${aiQuestionCount} أسئلة بالذكاء الاصطناعي الآن ✨`
                        : `Generate ${aiQuestionCount} Questions with AI ✨`}
                    </span>
                  </button>
                </div>
              </div>

              {/* Questions Builder */}
              <div className="space-y-4 pt-2">
                <div className="flex items-center justify-between">
                  <h3 className="text-sm font-bold text-slate-900 dark:text-white">
                    {t("questionsListTitle")} ({questions.length})
                  </h3>
                  <button
                    type="button"
                    onClick={handleAddQuestion}
                    className="inline-flex items-center gap-1.5 px-3 py-1.5 bg-indigo-50 dark:bg-indigo-950/60 text-indigo-700 dark:text-indigo-300 hover:bg-indigo-100 text-xs font-semibold rounded-lg transition-colors border border-indigo-200 dark:border-indigo-800 cursor-pointer"
                  >
                    <Plus className="w-3.5 h-3.5" />
                    <span>{t("addQuestionBtn")}</span>
                  </button>
                </div>

                <div className="space-y-4 max-h-[350px] overflow-y-auto pr-1">
                  {questions.map((q, qIndex) => (
                    <div key={qIndex} className="p-4 bg-slate-50 dark:bg-slate-800/60 border border-slate-200/80 dark:border-slate-700 rounded-xl space-y-3">
                      <div className="flex items-center justify-between gap-2 flex-wrap">
                        <div className="flex items-center gap-2">
                          <span className="text-xs font-bold text-indigo-700 dark:text-indigo-400">
                            {t("questionNumber")} {qIndex + 1}
                          </span>
                          {/* Question Type selector */}
                          <select
                            value={q.type || "SINGLE_CHOICE"}
                            onChange={(e) => handleQuestionTypeChange(qIndex, e.target.value)}
                            className="text-[11px] font-semibold px-2 py-0.5 rounded-lg border border-indigo-200 dark:border-indigo-800 bg-white dark:bg-slate-800 text-indigo-700 dark:text-indigo-300 focus:outline-none focus:ring-1 focus:ring-indigo-500 cursor-pointer"
                          >
                            <option value="SINGLE_CHOICE">{isRTL ? "اختيار واحد (Single Choice)" : "Single Choice"}</option>
                            <option value="MULTIPLE_CHOICE">{isRTL ? "اختيار متعدد الإجابات (Multi)" : "Multiple Choice"}</option>
                            <option value="TRUE_FALSE">{isRTL ? "صح أو خطأ (True/False)" : "True / False"}</option>
                            <option value="CODING">{isRTL ? "تحدي كود (Coding)" : "Coding Challenge"}</option>
                            <option value="SHORT_ANSWER">{isRTL ? "مفاهيم وشرح (Concepts)" : "Conceptual"}</option>
                          </select>
                        </div>
                        {questions.length > 1 && (
                          <button
                            type="button"
                            onClick={() => handleRemoveQuestion(qIndex)}
                            className="text-xs text-rose-600 hover:underline flex items-center gap-1 cursor-pointer"
                          >
                            <Trash2 className="w-3.5 h-3.5" />
                            <span>{t("delete")}</span>
                          </button>
                        )}
                      </div>

                      <input
                        type="text"
                        required
                        value={q.text}
                        onChange={(e) =>
                          setQuestions((prev) =>
                            prev.map((item, idx) =>
                              idx === qIndex ? { ...item, text: e.target.value } : item
                            )
                          )
                        }
                        placeholder={t("questionTextPlaceholder")}
                        className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-lg bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                      />

                      {/* Options rendering depending on type */}
                      {q.type === "TRUE_FALSE" ? (
                        <div className="space-y-1.5 pt-1">
                          <label className="block text-[11px] font-bold text-slate-600 dark:text-slate-400">
                            {isRTL ? "حدد الإجابة الصحيحة:" : "Select the Correct Answer:"}
                          </label>
                          <div className="grid grid-cols-2 gap-3">
                            {q.options.slice(0, 2).map((opt, optIdx) => {
                              const isSelected = q.correctIndex === optIdx;
                              return (
                                <button
                                  key={optIdx}
                                  type="button"
                                  onClick={() =>
                                    setQuestions((prev) =>
                                      prev.map((item, idx) =>
                                        idx === qIndex ? { ...item, correctIndex: optIdx } : item
                                      )
                                    )
                                  }
                                  className={`p-3 rounded-xl border text-xs font-bold flex items-center justify-between transition-all cursor-pointer ${
                                    isSelected
                                      ? optIdx === 0
                                        ? "bg-emerald-600 text-white border-emerald-600 shadow-md shadow-emerald-600/20"
                                        : "bg-rose-600 text-white border-rose-600 shadow-md shadow-rose-600/20"
                                      : "bg-white dark:bg-slate-800 text-slate-700 dark:text-slate-300 border-slate-200 dark:border-slate-700 hover:border-indigo-400"
                                  }`}
                                >
                                  <span className="text-sm font-bold">{opt}</span>
                                  {isSelected ? (
                                    <span className="inline-flex items-center gap-1 text-[11px] font-bold bg-white/20 px-2 py-0.5 rounded-full">
                                      <CheckCircle2 className="w-3.5 h-3.5 text-white" />
                                      {isRTL ? "الإجابة الصحيحة" : "Correct"}
                                    </span>
                                  ) : (
                                    <span className="text-[10px] font-normal opacity-70">
                                      {isRTL ? "انقر للاختيار" : "Select"}
                                    </span>
                                  )}
                                </button>
                              );
                            })}
                          </div>
                        </div>
                      ) : (
                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-2">
                          {q.options.map((opt, optIdx) => {
                            const isMulti = q.type === "MULTIPLE_CHOICE";
                            const selectedIndices = q.correctIndices || [q.correctIndex];
                            const isOptChecked = isMulti
                              ? selectedIndices.includes(optIdx)
                              : q.correctIndex === optIdx;

                            return (
                              <div key={optIdx} className="flex items-center gap-2">
                                <input
                                  type={isMulti ? "checkbox" : "radio"}
                                  name={isMulti ? undefined : `correct_${qIndex}`}
                                  checked={isOptChecked}
                                  onChange={() =>
                                    setQuestions((prev) =>
                                      prev.map((item, idx) => {
                                        if (idx !== qIndex) return item;
                                        if (isMulti) {
                                          const current = item.correctIndices || [item.correctIndex];
                                          const next = current.includes(optIdx)
                                            ? current.filter((x) => x !== optIdx)
                                            : [...current, optIdx];
                                          return {
                                            ...item,
                                            correctIndices: next,
                                            correctIndex: next[0] ?? 0,
                                          };
                                        }
                                        return { ...item, correctIndex: optIdx };
                                      })
                                    )
                                  }
                                  className="text-indigo-600 focus:ring-indigo-500 cursor-pointer"
                                />
                                <input
                                  type="text"
                                  required
                                  value={opt}
                                  onChange={(e) => handleOptionChange(qIndex, optIdx, e.target.value)}
                                  placeholder={`${t("optionPlaceholder")} ${optIdx + 1}`}
                                  className={`w-full px-2.5 py-1.5 text-xs border rounded-lg bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 ${
                                    isOptChecked
                                      ? "border-emerald-500 ring-1 ring-emerald-500"
                                      : "border-slate-300 dark:border-slate-700"
                                  }`}
                                />
                              </div>
                            );
                          })}
                        </div>
                      )}
                      <div className="text-[11px] text-slate-500 dark:text-slate-400 flex items-center gap-1">
                        <CheckCircle2 className="w-3.5 h-3.5 text-emerald-600 dark:text-emerald-400" />
                        <span>{t("correctAnswerNote")}</span>
                      </div>
                    </div>
                  ))}
                </div>
              </div>

              <div className="pt-4 flex items-center justify-end gap-3 border-t border-slate-100 dark:border-slate-800">
                <button
                  type="button"
                  onClick={() => {
                    setIsCreateModalOpen(false);
                    resetForm();
                  }}
                  className="px-4 py-2 text-xs font-semibold text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl cursor-pointer"
                >
                  {t("cancel")}
                </button>
                <button
                  type="submit"
                  disabled={creating}
                  className="px-5 py-2.5 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white text-xs font-semibold rounded-xl shadow-lg shadow-indigo-600/30 flex items-center gap-2 cursor-pointer"
                >
                  {creating && <Loader2 className="w-4 h-4 animate-spin" />}
                  <span>
                    {editingExamId
                      ? isRTL
                        ? "حفظ التعديلات على الاختبار"
                        : "Update Exam & Questions"
                      : t("saveExamBtn")}
                  </span>
                </button>
              </div>
            </form>
            )}
          </div>
        </div>
      )}

      {/* Candidates & Proctoring Records Modal */}
      {recordsExam && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white dark:bg-slate-900 rounded-2xl max-w-3xl w-full p-6 sm:p-8 shadow-2xl border border-slate-200 dark:border-slate-800 my-8">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100 dark:border-slate-800 mb-5">
              <div>
                <h2 className="text-lg font-bold text-slate-900 dark:text-white">
                  {isRTL ? `سجل المتقدمين والمراقبة: ${recordsExam.title}` : `Exam Records & Proctoring: ${recordsExam.title}`}
                </h2>
                <p className="text-xs text-slate-500 dark:text-slate-400">
                  {isRTL
                    ? "يعرض كافة المتقدمين (الناجحين، الراسبين، والمغلق اختبارهم بسبب المخالفات) مع صور الكاميرا وسجل المراقبة."
                    : "All candidates including terminated proctoring attempts, scores, and captured webcam verification snapshots."}
                </p>
              </div>
              <button
                onClick={() => {
                  setRecordsExam(null);
                  setSelectedAttemptViolations(null);
                }}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {(() => {
              const attemptsForExam = examAttempts.filter((a) => a.examId === recordsExam.id);
              if (attemptsForExam.length === 0) {
                return (
                  <div className="py-12 text-center text-xs text-slate-500 dark:text-slate-400">
                    {isRTL ? "لم يتقدم أي مرشح لهذا الاختبار حتى الآن." : "No candidate attempts recorded for this exam yet."}
                  </div>
                );
              }
              return (
                <div className="space-y-3 max-h-[450px] overflow-y-auto pr-1">
                  {attemptsForExam.map((att) => {
                    const isTerminated = att.status === "TERMINATED";
                    const isCompleted = att.status === "COMPLETED";
                    return (
                      <div
                        key={att.id}
                        className="p-4 rounded-2xl border border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-slate-800/50 space-y-3"
                      >
                        <div className="flex flex-wrap items-center justify-between gap-2">
                          <div>
                            <div className="font-bold text-sm text-slate-900 dark:text-white">
                              {att.candidateName}
                            </div>
                            <div className="text-[11px] text-slate-500 dark:text-slate-400">
                              {att.candidateEmail} • {att.jobTitle}
                            </div>
                          </div>
                          <div className="flex items-center gap-2">
                            {isTerminated ? (
                              <span className="px-2.5 py-1 rounded-full text-xs font-bold bg-rose-100 dark:bg-rose-950/70 text-rose-700 dark:text-rose-300 border border-rose-300 dark:border-rose-800 inline-flex items-center gap-1">
                                <ShieldAlert className="w-3.5 h-3.5" />
                                {isRTL ? "راسب - إنهاء بمخالفة (0%)" : "Failed - Violation Limit (0%)"}
                              </span>
                            ) : isCompleted ? (
                              <span
                                className={`px-2.5 py-1 rounded-full text-xs font-bold border ${
                                  att.passed
                                    ? "bg-emerald-100 dark:bg-emerald-950/70 text-emerald-700 dark:text-emerald-300 border-emerald-300 dark:border-emerald-800"
                                    : "bg-rose-100 dark:bg-rose-950/70 text-rose-700 dark:text-rose-300 border-rose-300 dark:border-rose-800"
                                }`}
                              >
                                {att.passed
                                  ? isRTL ? `ناجح (${att.score}%)` : `Passed (${att.score}%)`
                                  : isRTL ? `راسب (${att.score}%)` : `Failed (${att.score}%)`}
                              </span>
                            ) : (
                              <span className="px-2.5 py-1 rounded-full text-xs font-bold bg-amber-100 dark:bg-amber-950/70 text-amber-700 dark:text-amber-300 border border-amber-300 dark:border-amber-800">
                                {att.status}
                              </span>
                            )}
                            <button
                              type="button"
                              onClick={() => handleOpenAttemptDetails(att)}
                              className="px-3 py-1.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-[11px] font-bold cursor-pointer"
                            >
                              {isRTL ? "تفاصيل الكاميرا والمخالفات" : "Proctoring Details"}
                            </button>
                          </div>
                        </div>

                        <div className="flex flex-wrap items-center gap-3 text-[11px] text-slate-600 dark:text-slate-300">
                          <span className="inline-flex items-center gap-1">
                            <ShieldAlert className="w-3.5 h-3.5 text-amber-500" />
                            {isRTL ? `المخالفات: ${att.violationCount}/3` : `Violations: ${att.violationCount}/3`}
                          </span>
                          {att.proctoringReport && (
                            <>
                              <span className="inline-flex items-center gap-1">
                                <Camera className="w-3.5 h-3.5 text-indigo-500" />
                                {att.proctoringReport.cameraVerified
                                  ? isRTL ? "كاميرا مفعلة" : "Camera Verified"
                                  : isRTL ? "كاميرا غير مؤكدة" : "No Camera"}
                              </span>
                              <span className="inline-flex items-center gap-1">
                                <Mic className="w-3.5 h-3.5 text-emerald-500" />
                                {att.proctoringReport.micVerified
                                  ? isRTL ? "مايك مفعل" : "Mic Verified"
                                  : isRTL ? "مايك غير مؤكد" : "No Mic"}
                              </span>
                            </>
                          )}
                          <span>
                            {formatTimestamp(att.completedAt || att.createdAt, isRTL ? "ar-SA" : "en-US")}
                          </span>
                        </div>
                      </div>
                    );
                  })}
                </div>
              );
            })()}
          </div>
        </div>
      )}

      {/* Attempt Proctoring Details Modal (Snapshots + Violation Log) */}
      {selectedAttemptViolations && (
        <div className="fixed inset-0 z-[60] bg-slate-900/70 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white dark:bg-slate-900 rounded-2xl max-w-2xl w-full p-6 shadow-2xl border border-slate-200 dark:border-slate-800 my-8 space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-slate-800">
              <div>
                <h3 className="text-base font-bold text-slate-900 dark:text-white">
                  {selectedAttemptViolations.attempt.candidateName} — {selectedAttemptViolations.attempt.examTitle}
                </h3>
                <p className="text-xs text-slate-500">
                  {isRTL ? `المخالفات: ${selectedAttemptViolations.attempt.violationCount}/3` : `Violations: ${selectedAttemptViolations.attempt.violationCount}/3`}
                </p>
              </div>
              <button
                onClick={() => setSelectedAttemptViolations(null)}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-600 cursor-pointer"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {(() => {
              const snaps = selectedAttemptViolations.attempt.proctoringSnapshots || [];
              if (snaps.length === 0) {
                return (
                  <div className="p-4 rounded-xl bg-slate-50 dark:bg-slate-800/50 text-xs text-slate-500 text-center">
                    {isRTL ? "لا توجد لقطات كاميرا محفوظة لهذه المحاولة." : "No webcam verification snapshots recorded for this attempt."}
                  </div>
                );
              }
              return (
                <div className="space-y-2">
                  <div className="text-xs font-bold text-slate-700 dark:text-slate-300">
                    {isRTL ? `لقطات الكاميرا الموثقة (${snaps.length})` : `Captured Webcam Snapshots (${snaps.length})`}
                  </div>
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 max-h-56 overflow-y-auto">
                    {snaps.map((s, idx) => (
                      <div key={idx} className="rounded-xl overflow-hidden border border-slate-200 dark:border-slate-700 bg-black">
                        <img src={s.imageDataUrl} alt={s.label} className="w-full aspect-video object-cover" />
                        <div className="px-2 py-1 bg-slate-900 text-[10px] text-slate-200 truncate">
                          {s.label}
                        </div>
                      </div>
                    ))}
                  </div>
                </div>
              );
            })()}

            <div className="space-y-2">
              <div className="text-xs font-bold text-slate-700 dark:text-slate-300">
                {isRTL ? "سجل المخالفات التفصيلي" : "Detailed Violation Log"}
              </div>
              {selectedAttemptViolations.loading ? (
                <div className="py-4 flex justify-center">
                  <Loader2 className="w-5 h-5 animate-spin text-indigo-600" />
                </div>
              ) : selectedAttemptViolations.violations.length === 0 ? (
                <p className="text-xs text-slate-500">{isRTL ? "لا توجد مخالفات مسجلة." : "No violations recorded."}</p>
              ) : (
                <div className="space-y-2 max-h-48 overflow-y-auto">
                  {selectedAttemptViolations.violations.map((v) => (
                    <div key={v.id} className="p-2.5 rounded-xl bg-rose-50/70 dark:bg-rose-950/30 border border-rose-200 dark:border-rose-800 text-xs flex items-center justify-between gap-2">
                      <div>
                        <span className="font-bold text-rose-700 dark:text-rose-300">{v.violationType}</span>
                        <p className="text-slate-600 dark:text-slate-300">{v.details}</p>
                      </div>
                      <span className="text-[10px] text-slate-400 shrink-0">
                        {formatTimestamp(v.timestamp, isRTL ? "ar-SA" : "en-US")}
                      </span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* Create / Edit Practical Assignment Modal */}
      {isChallengeModalOpen && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white dark:bg-slate-900 rounded-2xl max-w-2xl w-full p-6 sm:p-8 shadow-2xl border border-slate-200 dark:border-slate-800 my-8">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100 dark:border-slate-800 mb-5">
              <h2 className="text-lg font-bold text-slate-900 dark:text-white">
                {editingChallengeId
                  ? isRTL ? "تعديل الواجب العملي" : "Edit Practical Assignment"
                  : isRTL ? "إنشاء واجب عملي جديد" : "Create Practical Assignment"}
              </h2>
              <button onClick={() => setIsChallengeModalOpen(false)} className="p-1 text-slate-400 hover:text-slate-600 cursor-pointer">
                <X className="w-5 h-5" />
              </button>
            </div>
            <form onSubmit={handleSaveChallenge} className="space-y-4 text-xs">
              <div>
                <label className="block font-bold mb-1 text-slate-700 dark:text-slate-300">
                  {isRTL ? "عنوان الواجب / المشروع *" : "Assignment Title *"}
                </label>
                <input
                  type="text"
                  required
                  value={chTitle}
                  onChange={(e) => setChTitle(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                  placeholder="e.g. Build REST API Microservice"
                />
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label className="block font-bold mb-1 text-slate-700 dark:text-slate-300">
                    {isRTL ? "ربط بوظيفة" : "Linked Job"}
                  </label>
                  <select
                    value={chJobId}
                    onChange={(e) => setChJobId(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                  >
                    <option value="">{isRTL ? "عام (بدون وظيفة محددة)" : "Unassigned / Template"}</option>
                    {jobs.map((j) => (
                      <option key={j.id} value={j.id}>{j.title}</option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block font-bold mb-1 text-slate-700 dark:text-slate-300">
                    {isRTL ? "الصعوبة" : "Difficulty"}
                  </label>
                  <select
                    value={chDifficulty}
                    onChange={(e) => setChDifficulty(e.target.value as any)}
                    className="w-full px-3 py-2 rounded-xl border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                  >
                    <option value="BEGINNER">BEGINNER</option>
                    <option value="INTERMEDIATE">INTERMEDIATE</option>
                    <option value="ADVANCED">ADVANCED</option>
                    <option value="EXPERT">EXPERT</option>
                  </select>
                </div>
                <div>
                  <label className="block font-bold mb-1 text-slate-700 dark:text-slate-300">
                    {isRTL ? "المهلة (أيام)" : "Deadline (Days)"}
                  </label>
                  <input
                    type="number"
                    min={1}
                    max={30}
                    value={chDeadlineDays}
                    onChange={(e) => setChDeadlineDays(Number(e.target.value) || 3)}
                    className="w-full px-3 py-2 rounded-xl border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                  />
                </div>
              </div>
              <div>
                <label className="block font-bold mb-1 text-slate-700 dark:text-slate-300">
                  {isRTL ? "ملخص الواجب *" : "Short Brief *"}
                </label>
                <input
                  type="text"
                  required
                  value={chBrief}
                  onChange={(e) => setChBrief(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                />
              </div>
              <div>
                <label className="block font-bold mb-1 text-slate-700 dark:text-slate-300">
                  {isRTL ? "التعليمات والمتطلبات التفصيلية *" : "Detailed Instructions *"}
                </label>
                <textarea
                  required
                  rows={3}
                  value={chInstructions}
                  onChange={(e) => setChInstructions(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                />
              </div>
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block font-bold mb-1 text-slate-700 dark:text-slate-300">
                    {isRTL ? "التقنيات (مفصولة بفاصلة)" : "Tech Stack (comma separated)"}
                  </label>
                  <input
                    type="text"
                    value={chTechStack}
                    onChange={(e) => setChTechStack(e.target.value)}
                    placeholder="Node.js, TypeScript, Firebase"
                    className="w-full px-3 py-2 rounded-xl border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                  />
                </div>
                <div>
                  <label className="block font-bold mb-1 text-slate-700 dark:text-slate-300">
                    {isRTL ? "رابط ملف مبدئي (اختياري)" : "Starter Template URL (optional)"}
                  </label>
                  <input
                    type="url"
                    value={chStarterUrl}
                    onChange={(e) => setChStarterUrl(e.target.value)}
                    placeholder="https://github.com/..."
                    className="w-full px-3 py-2 rounded-xl border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                  />
                </div>
              </div>
              <div>
                <label className="block font-bold mb-1 text-slate-700 dark:text-slate-300">
                  {isRTL ? "المخرجات المطلوبة (سطر لكل متطلب)" : "Deliverables (one per line)"}
                </label>
                <textarea
                  rows={2}
                  value={chDeliverables}
                  onChange={(e) => setChDeliverables(e.target.value)}
                  placeholder="GitHub repository link&#10;README setup guide"
                  className="w-full px-3 py-2 rounded-xl border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                />
              </div>
              <div className="flex justify-end gap-2 pt-3 border-t border-slate-100 dark:border-slate-800">
                <button
                  type="button"
                  onClick={() => setIsChallengeModalOpen(false)}
                  className="px-4 py-2 rounded-xl font-semibold text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 cursor-pointer"
                >
                  {t("cancel")}
                </button>
                <button
                  type="submit"
                  disabled={savingChallenge}
                  className="px-5 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white font-bold flex items-center gap-2 cursor-pointer"
                >
                  {savingChallenge && <Loader2 className="w-4 h-4 animate-spin" />}
                  <span>{isRTL ? "حفظ الواجب العملي" : "Save Assignment"}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Practical Assignment Submissions & Grading Modal */}
      {activeSubmissionsChallenge && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white dark:bg-slate-900 rounded-2xl max-w-2xl w-full p-6 shadow-2xl border border-slate-200 dark:border-slate-800 my-8 space-y-4">
            <div className="flex items-center justify-between pb-3 border-b border-slate-100 dark:border-slate-800">
              <div>
                <h2 className="text-lg font-bold text-slate-900 dark:text-white">
                  {isRTL ? `تسليمات: ${activeSubmissionsChallenge.title}` : `Submissions: ${activeSubmissionsChallenge.title}`}
                </h2>
              </div>
              <button onClick={() => setActiveSubmissionsChallenge(null)} className="p-1 text-slate-400 hover:text-slate-600 cursor-pointer">
                <X className="w-5 h-5" />
              </button>
            </div>
            {(() => {
              const chSubs = submissions.filter((s) => s.challengeId === activeSubmissionsChallenge.id);
              if (chSubs.length === 0) {
                return (
                  <div className="py-10 text-center text-xs text-slate-500">
                    {isRTL ? "لا توجد تسليمات من المرشحين لهذا الواجب حتى الآن." : "No submissions yet for this assignment."}
                  </div>
                );
              }
              return (
                <div className="space-y-4 max-h-[450px] overflow-y-auto pr-1">
                  {chSubs.map((sub) => {
                    const safeRepo = sanitizeExternalUrl(sub.githubRepoUrl);
                    const safeDemo = sanitizeExternalUrl(sub.liveDemoUrl || undefined);
                    const draft = gradingDrafts[sub.id] || {
                      score: String(sub.score ?? 80),
                      feedback: sub.reviewerFeedback || "",
                      status: (sub.status === "REJECTED" ? "REJECTED" : "APPROVED") as "APPROVED" | "REJECTED" | "UNDER_REVIEW",
                    };
                    return (
                      <div key={sub.id} className="p-4 rounded-2xl border border-slate-200 dark:border-slate-700 bg-slate-50 dark:bg-slate-800/40 space-y-3 text-xs">
                        <div className="flex flex-wrap items-center justify-between gap-2">
                          <div>
                            <div className="font-bold text-sm text-slate-900 dark:text-white">{sub.candidateName}</div>
                            <div className="text-slate-500">{sub.candidateEmail}</div>
                          </div>
                          <span className="px-2.5 py-0.5 rounded-full font-bold bg-indigo-100 dark:bg-indigo-950 text-indigo-700 dark:text-indigo-300">
                            {sub.status}{sub.score != null ? ` • ${sub.score}/100` : ""}
                          </span>
                        </div>
                        <div className="flex flex-wrap gap-2">
                          {safeRepo && (
                            <a href={safeRepo} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-700 text-indigo-600 dark:text-indigo-400 font-semibold hover:underline">
                              <ExternalLink className="w-3.5 h-3.5" />
                              <span>{isRTL ? "فتح ملف/رابط الحل" : "Open Solution / Repo"}</span>
                            </a>
                          )}
                          {safeDemo && (
                            <a href={safeDemo} target="_blank" rel="noopener noreferrer" className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-white dark:bg-slate-800 border border-slate-300 dark:border-slate-700 text-emerald-600 dark:text-emerald-400 font-semibold hover:underline">
                              <ExternalLink className="w-3.5 h-3.5" />
                              <span>{isRTL ? "النسخة المباشرة" : "Live Demo"}</span>
                            </a>
                          )}
                        </div>
                        {sub.candidateNotes && (
                          <p className="text-slate-600 dark:text-slate-300 whitespace-pre-line">{sub.candidateNotes}</p>
                        )}
                        <div className="grid grid-cols-1 sm:grid-cols-3 gap-2 pt-2 border-t border-slate-200 dark:border-slate-700">
                          <input
                            type="number"
                            min={0}
                            max={100}
                            value={draft.score}
                            onChange={(e) => setGradingDrafts((p) => ({ ...p, [sub.id]: { ...draft, score: e.target.value } }))}
                            placeholder="Score (0-100)"
                            className="px-2.5 py-1.5 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900 text-slate-900 dark:text-white"
                          />
                          <select
                            value={draft.status}
                            onChange={(e) => setGradingDrafts((p) => ({ ...p, [sub.id]: { ...draft, status: e.target.value as any } }))}
                            className="px-2.5 py-1.5 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900 text-slate-900 dark:text-white"
                          >
                            <option value="APPROVED">{isRTL ? "مقبول (Approved)" : "Approved"}</option>
                            <option value="UNDER_REVIEW">{isRTL ? "قيد المراجعة" : "Under Review"}</option>
                            <option value="REJECTED">{isRTL ? "غير متوافق (Rejected)" : "Rejected"}</option>
                          </select>
                          <button
                            type="button"
                            disabled={Boolean(draft.saving)}
                            onClick={() => handleGradeSubmission(sub, activeSubmissionsChallenge.title)}
                            className="px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-500 text-white font-bold cursor-pointer disabled:opacity-50"
                          >
                            {isRTL ? "اعتماد التقييم" : "Save Grade"}
                          </button>
                        </div>
                        <input
                          type="text"
                          value={draft.feedback}
                          onChange={(e) => setGradingDrafts((p) => ({ ...p, [sub.id]: { ...draft, feedback: e.target.value } }))}
                          placeholder={isRTL ? "ملاحظات المقيّم للمرشح..." : "Reviewer feedback..."}
                          className="w-full px-2.5 py-1.5 rounded-lg border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900 text-slate-900 dark:text-white"
                        />
                      </div>
                    );
                  })}
                </div>
              );
            })()}
          </div>
        </div>
      )}
    </div>
  );
}

export default function CompanyExamsPage() {
  return (
    <Suspense
      fallback={
        <div className="py-24 flex justify-center">
          <div className="w-8 h-8 border-4 border-indigo-600 border-t-transparent rounded-full animate-spin"></div>
        </div>
      }
    >
      <CompanyExamsContent />
    </Suspense>
  );
}
