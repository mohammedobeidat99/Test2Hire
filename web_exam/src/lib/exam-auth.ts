import { auth, db, functions } from "./firebase";
import { httpsCallable } from "firebase/functions";
import { doc, updateDoc, serverTimestamp } from "firebase/firestore/lite";
import {
  CandidateAnswer,
  ExamSessionData,
  ExamSubmissionResult,
  ProctoringReport,
  SanitizedQuestion,
} from "../types/exam";

export type ExamErrorKind =
  | "ALREADY_COMPLETED"
  | "TERMINATED"
  | "EXPIRED"
  | "NOT_FOUND"
  | "INVALID_TOKEN"
  | "NETWORK"
  | "UNKNOWN";

export class ExamSessionError extends Error {
  public readonly kind: ExamErrorKind;

  constructor(kind: ExamErrorKind, message: string) {
    super(message);
    this.name = "ExamSessionError";
    this.kind = kind;
  }
}

// In-memory violation state and callable capability flag for the current browser session
let demoViolationCounter = 0;
let saveDraftCallableSupported: boolean | null = null;

const DEMO_CODING_STARTER =
  "function findMostFrequent(arr: number[]): number {\n  // Write your solution and explain Time Complexity\n  return arr[0];\n}";

export function isDemoOrTestToken(token: string): boolean {
  const t = token.trim().toLowerCase();
  return t === "demo" || t === "test";
}

/**
 * Extracts a clean assessment token whether the user pasted a raw token or a full exam URL.
 */
export function extractTokenInput(rawInput: string): string {
  const trimmed = rawInput.trim();
  if (!trimmed) return "";

  try {
    if (/^https?:\/\//i.test(trimmed) || trimmed.includes("/exam/")) {
      const url = /^https?:\/\//i.test(trimmed)
        ? new URL(trimmed)
        : new URL(trimmed, "https://test2here-72346.web.app");
      const queryToken = url.searchParams.get("token");
      const parts = url.pathname.split("/").filter(Boolean);
      const examIdx = parts.indexOf("exam");
      if (examIdx !== -1 && parts[examIdx + 1]) {
        const seg = decodeURIComponent(parts[examIdx + 1]).trim();
        if (seg.toLowerCase() === "default" && queryToken) {
          return queryToken.trim();
        }
        return seg;
      }
      if (queryToken) return queryToken.trim();
    }
  } catch {
    // Fall back to trimmed raw value
  }

  return trimmed;
}

function getDraftStorageKey(attemptId: string): string {
  return `t2h_exam_draft_${attemptId}`;
}

export function readLocalDraft(attemptId: string): Record<string, CandidateAnswer> {
  if (typeof window === "undefined" || !attemptId) return {};
  try {
    const raw =
      window.localStorage.getItem(getDraftStorageKey(attemptId)) ??
      window.sessionStorage.getItem(getDraftStorageKey(attemptId));
    if (!raw) return {};
    const parsed = JSON.parse(raw);
    return parsed && typeof parsed === "object" ? parsed : {};
  } catch {
    return {};
  }
}

export function writeLocalDraft(
  attemptId: string,
  answers: Record<string, CandidateAnswer>
): void {
  if (typeof window === "undefined" || !attemptId) return;
  try {
    const serialized = JSON.stringify(answers);
    window.localStorage.setItem(getDraftStorageKey(attemptId), serialized);
    window.sessionStorage.setItem(getDraftStorageKey(attemptId), serialized);
  } catch {
    // Ignore quota/storage errors
  }
}

export function clearLocalDraft(attemptId: string): void {
  if (typeof window === "undefined" || !attemptId) return;
  try {
    window.localStorage.removeItem(getDraftStorageKey(attemptId));
    window.sessionStorage.removeItem(getDraftStorageKey(attemptId));
  } catch {
    // Ignore storage errors
  }
}

/**
 * Classifies Firebase Functions / network errors into actionable session error kinds.
 */
export function classifyExamError(err: unknown): ExamSessionError {
  if (err instanceof ExamSessionError) return err;

  const anyErr = err as { code?: string; message?: string } | null;
  const code = String(anyErr?.code || "").toLowerCase();
  const message = String(anyErr?.message || "Unable to access the assessment session.");
  const lowerMsg = message.toLowerCase();

  if (
    code.includes("failed-precondition") ||
    lowerMsg.includes("already been completed") ||
    lowerMsg.includes("already submitted")
  ) {
    return new ExamSessionError("ALREADY_COMPLETED", message);
  }
  if (
    code.includes("permission-denied") ||
    lowerMsg.includes("terminated") ||
    lowerMsg.includes("violations")
  ) {
    return new ExamSessionError("TERMINATED", message);
  }
  if (code.includes("deadline-exceeded") || lowerMsg.includes("expired")) {
    return new ExamSessionError("EXPIRED", message);
  }
  if (code.includes("not-found") || lowerMsg.includes("not found")) {
    return new ExamSessionError("NOT_FOUND", message);
  }
  if (code.includes("invalid-argument") || lowerMsg.includes("valid assessment token")) {
    return new ExamSessionError("INVALID_TOKEN", message);
  }
  if (
    code.includes("unavailable") ||
    lowerMsg.includes("network") ||
    lowerMsg.includes("failed to fetch") ||
    lowerMsg.includes("offline")
  ) {
    return new ExamSessionError("NETWORK", message);
  }

  return new ExamSessionError("UNKNOWN", message);
}

/**
 * Returns a complete realistic Demo Exam Session covering all 5 question types.
 */
function getDemoSessionData(): ExamSessionData {
  demoViolationCounter = 0;
  clearLocalDraft("demo-attempt-001");

  return {
    attemptId: "demo-attempt-001",
    examId: "demo-exam-001",
    examTitle: "Full-Stack Software Engineering Assessment (Demo)",
    candidateName: "Guest Candidate",
    durationMinutes: 30,
    passingPercentage: 70,
    proctoringEnabled: true,
    totalQuestions: 5,
    totalPoints: 50,
    violationCount: 0,
    startedAt: new Date().toISOString(),
    serverNow: new Date().toISOString(),
    savedAnswers: {},
    questions: [
      {
        id: "q1",
        title: "ما هي الفائدة الأساسية من استخدام Virtual DOM في React؟",
        description:
          "اختر الإجابة الأدق والأصح فيما يلي حول كيفية إدارة التحديثات في واجهة المستخدم.",
        type: "SINGLE_CHOICE",
        difficulty: "MEDIUM",
        points: 10,
        options: [
          {
            id: "opt1",
            text: "تقليل عمليات إعادة الرسم المباشرة (Reflows & Repaints) في الـ DOM الحقيقي عن طريق خوارزمية المقارنة (Diffing)",
          },
          {
            id: "opt2",
            text: "تجاوز بروتوكول HTTP وإرسال البيانات مباشرة إلى الخادم دون شبكة",
          },
          {
            id: "opt3",
            text: "تشفير كود الجافاسكريبت تلقائياً داخل المتصفح",
          },
          {
            id: "opt4",
            text: "تسريع تحميل الصور والملفات الثابتة تلقائياً",
          },
        ],
      },
      {
        id: "q2",
        title: "أي من الخيارات التالية تُعتبر ممارسات أمنية موصى بها عند التعامل مع JWT؟",
        description: "حدد جميع الإجابات الصحيحة (اختيار متعدد):",
        type: "MULTIPLE_CHOICE",
        difficulty: "MEDIUM",
        points: 10,
        options: [
          {
            id: "opt1",
            text: "تخزين Refresh Token في HttpOnly SameSite Secure Cookie للوقاية من هجمات XSS",
          },
          {
            id: "opt2",
            text: "تحديد وقت صلاحية قصير (Short Expiration) للـ Access Token",
          },
          {
            id: "opt3",
            text: "وضع كلمات المرور والبيانات البنكية الحساسة غير المشفرة داخل Payload الـ JWT",
          },
          {
            id: "opt4",
            text: "التحقق من توقيع الـ Token (Signature Verification) على السيرفر في كل طلب محمي",
          },
        ],
      },
      {
        id: "q3",
        title: "في معمارية الخدمات المصغرة (Microservices)، هل يُفضل مبدأ Database-per-Service؟",
        description: "اختر صح أم خطأ:",
        type: "TRUE_FALSE",
        difficulty: "EASY",
        points: 10,
        options: [
          {
            id: "opt_t",
            text: "صح (True) - لضمان الاستقلالية وفك الارتباط التام (Loose Coupling)",
          },
          {
            id: "opt_f",
            text: "خطأ (False) - يجب دائماً إجبار جميع الخدمات على مشاركة نفس قاعدة البيانات المركزية",
          },
        ],
      },
      {
        id: "q4",
        title: "كتابة دالة خوارزمية للبحث عن العنصر الأكثر تكراراً (Most Frequent Element)",
        description:
          "اكتب دالة بلغة TypeScript / JavaScript لحساب العنصر الأكثر تكراراً في مصفوفة أرقام، واذكر التعقيد الزمني للحل (Time Complexity):",
        type: "CODING",
        difficulty: "HARD",
        points: 10,
        programmingLanguage: "typescript",
        sampleCodeSnippet: DEMO_CODING_STARTER,
        options: [],
      },
      {
        id: "q5",
        title: "اشرح الفرق بين التدرج الأفقي (Horizontal Scaling) والتدرج العمودي (Vertical Scaling)",
        description:
          "وضح باختصار متى تفضل استخدام كل أسلوب في الأنظمة السحابية ذات الحمل المرتفع.",
        type: "SHORT_ANSWER",
        difficulty: "MEDIUM",
        points: 10,
        options: [],
      },
    ],
  };
}

function normalizeQuestion(q: SanitizedQuestion): SanitizedQuestion {
  const normalizedType = String(q.type || "SINGLE_CHOICE").trim().toUpperCase();
  let options = Array.isArray(q.options)
    ? q.options
        .filter((opt) => opt && opt.id !== undefined)
        .map((opt) => ({
          id: String(opt.id),
          text: String(opt.text ?? ""),
        }))
    : [];

  // Ensure TRUE_FALSE questions always expose selectable options even if stored with empty options
  if (normalizedType === "TRUE_FALSE" && options.length === 0) {
    options = [
      { id: "true", text: "صح (True)" },
      { id: "false", text: "خطأ (False)" },
    ];
  }

  return {
    id: String(q.id),
    title: String(q.title || ""),
    description: String(q.description || ""),
    type: normalizedType,
    difficulty: String(q.difficulty || "MEDIUM").toUpperCase(),
    points: Number(q.points) > 0 ? Number(q.points) : 1,
    sampleCodeSnippet: q.sampleCodeSnippet ?? null,
    programmingLanguage: q.programmingLanguage ?? null,
    options,
  };
}

function normalizeSessionData(raw: ExamSessionData): ExamSessionData {
  const questions = Array.isArray(raw.questions)
    ? raw.questions.map(normalizeQuestion)
    : [];

  const serverAnswers =
    raw.savedAnswers && typeof raw.savedAnswers === "object" ? raw.savedAnswers : {};
  const localDraft = readLocalDraft(raw.attemptId);
  const mergedAnswers: Record<string, CandidateAnswer> = {
    ...serverAnswers,
    ...localDraft,
  };

  return {
    ...raw,
    examTitle: raw.examTitle || "Assessment",
    candidateName: raw.candidateName || "Candidate",
    durationMinutes: Number(raw.durationMinutes) > 0 ? Number(raw.durationMinutes) : 45,
    passingPercentage: Number(raw.passingPercentage) > 0 ? Number(raw.passingPercentage) : 70,
    proctoringEnabled: raw.proctoringEnabled ?? true,
    totalQuestions: questions.length,
    totalPoints:
      Number(raw.totalPoints) > 0
        ? Number(raw.totalPoints)
        : questions.reduce((sum, q) => sum + (Number(q.points) || 1), 0),
    questions,
    savedAnswers: mergedAnswers,
    violationCount: Number(raw.violationCount) || 0,
    startedAt: raw.startedAt || new Date().toISOString(),
    serverNow: raw.serverNow || null,
  };
}

/**
 * Fetches the active exam session and sanitized questions.
 * Connects to Firebase Cloud Functions, with built-in instant demo/test support.
 */
export async function loadExamSession(token: string): Promise<ExamSessionData> {
  const cleanToken = token.trim();
  if (!cleanToken) {
    throw new ExamSessionError("INVALID_TOKEN", "Valid assessment token is required.");
  }

  if (isDemoOrTestToken(cleanToken)) {
    return getDemoSessionData();
  }

  try {
    const getExamSessionFn = httpsCallable<{ token: string }, ExamSessionData>(
      functions,
      "getExamSession"
    );
    const result = await getExamSessionFn({ token: cleanToken });
    return normalizeSessionData(result.data);
  } catch (err) {
    throw classifyExamError(err);
  }
}

/**
 * Reports an anti-cheat proctoring violation to Cloud Functions.
 */
export async function reportViolation(
  token: string,
  violationType: string,
  details?: string,
  snapshotDataUrl?: string | null,
  proctoringSummary?: ProctoringReport
): Promise<{ success: boolean; violationCount: number; terminated: boolean }> {
  const cleanToken = token.trim();
  if (isDemoOrTestToken(cleanToken)) {
    demoViolationCounter += 1;
    const terminated = demoViolationCounter >= 3;
    return {
      success: true,
      violationCount: demoViolationCounter,
      terminated,
    };
  }

  const recordViolationFn = httpsCallable<
    {
      token: string;
      violationType: string;
      details?: string;
      snapshotDataUrl?: string;
      proctoringSummary?: ProctoringReport;
    },
    { success: boolean; violationCount?: number; terminated?: boolean }
  >(functions, "recordExamViolation");

  const result = await recordViolationFn({
    token: cleanToken,
    violationType,
    details,
    ...(snapshotDataUrl ? { snapshotDataUrl } : {}),
    ...(proctoringSummary ? { proctoringSummary } : {}),
  });

  return {
    success: Boolean(result.data?.success),
    violationCount: Number(result.data?.violationCount) || 0,
    terminated: Boolean(result.data?.terminated),
  };
}

/**
 * Syncs webcam/microphone proctoring snapshots & diagnostics periodically via saveExamDraft.
 */
export async function syncProctoringReport(
  token: string,
  proctoringReport: ProctoringReport
): Promise<void> {
  const cleanToken = token.trim();
  if (!cleanToken || isDemoOrTestToken(cleanToken)) return;
  try {
    const saveDraftFn = httpsCallable<
      { token: string; proctoringReport: ProctoringReport },
      { success: boolean }
    >(functions, "saveExamDraft");
    await saveDraftFn({ token: cleanToken, proctoringReport });
  } catch {
    // Non-blocking periodic sync
  }
}

/**
 * Submits the complete candidate answers payload to Cloud Functions for server-side grading.
 */
export async function submitCandidateExam(
  token: string,
  answers: Record<string, CandidateAnswer>,
  attemptId?: string,
  proctoringReport?: ProctoringReport
): Promise<ExamSubmissionResult> {
  const cleanToken = token.trim();

  if (isDemoOrTestToken(cleanToken)) {
    let earned = 0;

    // Q1: SINGLE_CHOICE -> opt1
    if (answers["q1"]?.selectedOptionIds?.includes("opt1")) {
      earned += 10;
    }

    // Q2: MULTIPLE_CHOICE -> opt1, opt2, opt4 (and NOT opt3)
    const q2Selected = answers["q2"]?.selectedOptionIds || [];
    if (
      q2Selected.length === 3 &&
      ["opt1", "opt2", "opt4"].every((id) => q2Selected.includes(id)) &&
      !q2Selected.includes("opt3")
    ) {
      earned += 10;
    }

    // Q3: TRUE_FALSE -> opt_t
    if (answers["q3"]?.selectedOptionIds?.includes("opt_t")) {
      earned += 10;
    }

    // Q4: CODING -> meaningful code response different from untouched stub
    const q4Text = answers["q4"]?.textAnswer?.trim() || "";
    if (q4Text.length >= 15 && q4Text !== DEMO_CODING_STARTER.trim()) {
      earned += 10;
    }

    // Q5: SHORT_ANSWER -> meaningful explanation
    const q5Text = answers["q5"]?.textAnswer?.trim() || "";
    if (q5Text.length >= 15) {
      earned += 10;
    }

    const total = 50;
    const scorePct = Math.round((earned / total) * 100);
    if (attemptId) clearLocalDraft(attemptId);

    return {
      success: true,
      score: scorePct,
      passed: scorePct >= 70,
      passingPercentage: 70,
      earnedPoints: earned,
      totalPointsPossible: total,
    };
  }

  // Sanitize payload shape so no undefined values are sent to Cloud Functions
  const sanitizedAnswers: Record<string, CandidateAnswer> = {};
  for (const [qId, ans] of Object.entries(answers)) {
    if (!ans) continue;
    const entry: CandidateAnswer = {};
    if (Array.isArray(ans.selectedOptionIds) && ans.selectedOptionIds.length > 0) {
      entry.selectedOptionIds = ans.selectedOptionIds.map(String);
    }
    if (typeof ans.textAnswer === "string" && ans.textAnswer.length > 0) {
      entry.textAnswer = ans.textAnswer;
    }
    if (entry.selectedOptionIds || entry.textAnswer) {
      sanitizedAnswers[qId] = entry;
    }
  }

  try {
    const submitExamFn = httpsCallable<
      {
        token: string;
        answers: Record<string, CandidateAnswer>;
        proctoringReport?: ProctoringReport;
      },
      ExamSubmissionResult
    >(functions, "submitExam");

    const result = await submitExamFn({
      token: cleanToken,
      answers: sanitizedAnswers,
      ...(proctoringReport ? { proctoringReport } : {}),
    });
    if (attemptId) clearLocalDraft(attemptId);
    return result.data;
  } catch (err) {
    const classified = classifyExamError(err);
    if (
      attemptId &&
      (classified.kind === "ALREADY_COMPLETED" || classified.kind === "TERMINATED")
    ) {
      clearLocalDraft(attemptId);
    }
    throw classified;
  }
}

/**
 * Persists candidate answer drafts locally and syncs remotely when supported.
 */
export async function saveAnswerDraft(
  attemptId: string,
  token: string,
  allAnswers: Record<string, CandidateAnswer>,
  questionId: string,
  answer: CandidateAnswer
): Promise<void> {
  writeLocalDraft(attemptId, allAnswers);

  if (!token || isDemoOrTestToken(token) || attemptId.startsWith("demo-")) {
    return;
  }

  // Prefer token-authenticated Cloud Function when available
  if (saveDraftCallableSupported !== false) {
    try {
      const saveDraftFn = httpsCallable<
        { token: string; questionId: string; answer: CandidateAnswer },
        { success: boolean }
      >(functions, "saveExamDraft");
      await saveDraftFn({ token: token.trim(), questionId, answer });
      saveDraftCallableSupported = true;
      return;
    } catch (err: unknown) {
      const code = String((err as { code?: string })?.code || "").toLowerCase();
      if (code.includes("not-found") || code.includes("unimplemented")) {
        saveDraftCallableSupported = false;
      }
    }
  }

  // Fallback direct Firestore update only when user has an active Firebase Auth session
  if (!auth.currentUser) {
    return;
  }

  try {
    const attemptRef = doc(db, "examAttempts", attemptId);
    await updateDoc(attemptRef, {
      [`answers.${questionId}`]: answer,
      lastHeartbeat: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });
  } catch (err) {
    console.warn("Failed to persist answer draft to Firestore:", err);
  }
}
