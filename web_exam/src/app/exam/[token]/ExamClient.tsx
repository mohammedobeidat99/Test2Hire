"use client";

import { memo, useEffect, useState, useCallback, useMemo, useRef } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import {
  loadExamSession,
  reportViolation,
  submitCandidateExam,
  saveAnswerDraft,
  writeLocalDraft,
  isDemoOrTestToken,
  ExamSessionError,
} from "@/lib/exam-auth";
import { usePortalPreferences } from "@/lib/portal-preferences";
import {
  CandidateAnswer,
  ExamSessionData,
  SanitizedQuestion,
  ExamSubmissionResult,
  ProctoringReport,
  ProctoringViolationEvent,
} from "@/types/exam";
import {
  AlertTriangle,
  Clock,
  CheckCircle2,
  XCircle,
  ShieldAlert,
  ShieldCheck,
  ChevronRight,
  ChevronLeft,
  Maximize,
  Send,
  Lock,
  AlertOctagon,
  Globe,
  Moon,
  Sun,
  RefreshCw,
  Code2,
  FileText,
} from "lucide-react";

function isQuestionAnswered(ans?: CandidateAnswer): boolean {
  if (!ans) return false;
  const hasOption = Array.isArray(ans.selectedOptionIds) && ans.selectedOptionIds.length > 0;
  const hasText = typeof ans.textAnswer === "string" && ans.textAnswer.trim().length > 0;
  return hasOption || hasText;
}

function getQuestionTypeLabel(type: string, isRTL: boolean): string {
  switch (type.toUpperCase()) {
    case "SINGLE_CHOICE":
      return isRTL ? "اختيار واحد" : "SINGLE CHOICE";
    case "MULTIPLE_CHOICE":
      return isRTL ? "اختيار متعدد" : "MULTIPLE CHOICE";
    case "TRUE_FALSE":
      return isRTL ? "صح أو خطأ" : "TRUE / FALSE";
    case "CODING":
      return isRTL ? "تحدي برمجي" : "CODING";
    case "SHORT_ANSWER":
      return isRTL ? "إجابة مقالية" : "SHORT ANSWER";
    case "MIXED":
      return isRTL ? "سؤال متنوع" : "MIXED";
    default:
      return type.replace(/_/g, " ");
  }
}

function getDifficultyLabel(difficulty: string, isRTL: boolean): string {
  switch (difficulty.toUpperCase()) {
    case "EASY":
      return isRTL ? "سهل" : "EASY";
    case "MEDIUM":
      return isRTL ? "متوسط" : "MEDIUM";
    case "HARD":
      return isRTL ? "صعب" : "HARD";
    default:
      return difficulty;
  }
}

function resolveInitialToken(paramToken: unknown): string {
  if (typeof window !== "undefined") {
    const searchToken = new URLSearchParams(window.location.search).get("token")?.trim();
    const parts = window.location.pathname.split("/").filter(Boolean);
    const idx = parts.indexOf("exam");
    if (idx !== -1 && parts[idx + 1]) {
      try {
        const pathToken = decodeURIComponent(parts[idx + 1]).trim();
        if (pathToken.toLowerCase() === "default" && searchToken) {
          return searchToken;
        }
        return pathToken;
      } catch {
        return parts[idx + 1].trim();
      }
    }
    if (searchToken) return searchToken;
  }
  return typeof paramToken === "string" ? paramToken.trim() : "";
}

const WATERMARK_INDICES = Array.from({ length: 48 }, (_, i) => i);

function formatCountdownTime(seconds: number): string {
  const safeSeconds = Number.isFinite(seconds) ? Math.max(0, Math.floor(seconds)) : 0;
  const mins = Math.floor(safeSeconds / 60);
  const secs = safeSeconds % 60;
  return `${mins.toString().padStart(2, "0")}:${secs.toString().padStart(2, "0")}`;
}

const WatermarkOverlay = memo(function WatermarkOverlay({
  candidateName,
  attemptId,
  isDark,
}: {
  candidateName: string;
  attemptId: string;
  isDark: boolean;
}) {
  const [watermarkTime, setWatermarkTime] = useState(() => {
    if (typeof window === "undefined") return "";
    const now = new Date();
    return now.toLocaleTimeString() + " • " + now.toLocaleDateString();
  });

  useEffect(() => {
    const updateTime = () => {
      const now = new Date();
      setWatermarkTime(now.toLocaleTimeString() + " • " + now.toLocaleDateString());
    };
    updateTime();
    const interval = setInterval(updateTime, 1000);
    return () => clearInterval(interval);
  }, []);

  return (
    <div
      className="fixed inset-0 pointer-events-none z-20 opacity-[0.045] flex flex-wrap gap-12 p-8 select-none overflow-hidden"
      style={{ transform: "rotate(-18deg) scale(1.4)" }}
    >
      {WATERMARK_INDICES.map((i) => (
        <div
          key={i}
          className={`text-xs font-mono font-bold tracking-widest whitespace-nowrap ${
            isDark ? "text-white" : "text-slate-900"
          }`}
        >
          {candidateName} • {attemptId} • {watermarkTime} • TEST2HIRE SECURE
        </div>
      ))}
    </div>
  );
});

const ExamCountdownTimer = memo(function ExamCountdownTimer({
  endTimeMs,
  initialSeconds,
  isDark,
  onExpire,
}: {
  endTimeMs: number | null;
  initialSeconds: number;
  isDark: boolean;
  onExpire: () => void;
}) {
  const [timeLeftSeconds, setTimeLeftSeconds] = useState<number>(initialSeconds);
  const onExpireRef = useRef(onExpire);
  const hasFiredExpireRef = useRef(false);

  useEffect(() => {
    onExpireRef.current = onExpire;
  }, [onExpire]);

  useEffect(() => {
    if (endTimeMs === null) {
      hasFiredExpireRef.current = false;
      setTimeLeftSeconds(initialSeconds);
      return;
    }

    hasFiredExpireRef.current = false;
    const syncRemaining = () => {
      const nextRemaining = Math.max(0, Math.ceil((endTimeMs - Date.now()) / 1000));
      setTimeLeftSeconds(nextRemaining);
      if (nextRemaining <= 0 && !hasFiredExpireRef.current) {
        hasFiredExpireRef.current = true;
        onExpireRef.current();
      }
      return nextRemaining;
    };

    if (syncRemaining() <= 0) {
      return;
    }

    const timer = setInterval(() => {
      if (syncRemaining() <= 0) {
        clearInterval(timer);
      }
    }, 500);

    return () => clearInterval(timer);
  }, [endTimeMs, initialSeconds]);

  return (
    <div
      dir="ltr"
      className={`flex items-center gap-1.5 px-3 py-1.5 rounded-xl font-mono font-bold text-xs sm:text-sm border ${
        timeLeftSeconds < 300
          ? "bg-red-500/20 text-red-500 border-red-500/40 animate-pulse"
          : isDark
          ? "bg-slate-800/80 text-slate-200 border-slate-700"
          : "bg-slate-100 text-slate-800 border-slate-300"
      }`}
    >
      <Clock className="w-4 h-4" />
      <span>{formatCountdownTime(timeLeftSeconds)}</span>
    </div>
  );
});

export default function ExamClient() {
  const params = useParams();
  const { isRTL, isDark, toggleLang, toggleTheme } = usePortalPreferences();

  const [token, setToken] = useState<string>(() => resolveInitialToken(params?.token));
  const [reloadNonce, setReloadNonce] = useState(0);

  useEffect(() => {
    const resolved = resolveInitialToken(params?.token);
    setToken((prev) => (prev === resolved ? prev : resolved));
  }, [params]);

  // Base State
  const [session, setSession] = useState<ExamSessionData | null>(null);
  const [isLoading, setIsLoading] = useState(true);
  const [sessionError, setSessionError] = useState<ExamSessionError | null>(null);
  const [submitError, setSubmitError] = useState<string | null>(null);

  // Security Gate State
  const [hasPassedSecurityCheck, setHasPassedSecurityCheck] = useState(false);
  const [isStartingGate, setIsStartingGate] = useState(false);
  const violationEventsRef = useRef<ProctoringViolationEvent[]>([]);

  // Exam Progress State
  const [currentIndex, setCurrentIndex] = useState(0);
  const [answers, setAnswers] = useState<Record<string, CandidateAnswer>>({});
  const [draftSaveState, setDraftSaveState] = useState<"idle" | "saving" | "saved">("idle");
  const [initialTimerSeconds, setInitialTimerSeconds] = useState<number>(0);
  const [timerEndTimeMs, setTimerEndTimeMs] = useState<number | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [showSubmitConfirm, setShowSubmitConfirm] = useState(false);
  const [submissionResult, setSubmissionResult] = useState<ExamSubmissionResult | null>(null);

  // Anti-Cheat & Proctoring State
  const [isFullscreen, setIsFullscreen] = useState(false);
  const [violations, setViolations] = useState(0);
  const [isTerminated, setIsTerminated] = useState(false);
  const [warningMessage, setWarningMessage] = useState<string | null>(null);
  const [showFullscreenWarning, setShowFullscreenWarning] = useState(false);
  const [fullscreenGracePeriod, setFullscreenGracePeriod] = useState(10);

  // Refs for stable callbacks, timers, and race guards
  const hasStartedRef = useRef(false);
  const isSubmittingRef = useRef(false);
  const hasAutoSubmittedRef = useRef(false);
  const initialRemainingRef = useRef<number>(0);
  const isResumedSessionRef = useRef(false);
  const graceTimerRef = useRef<ReturnType<typeof setInterval> | null>(null);
  const draftDebounceRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const draftSavedTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const answersRef = useRef<Record<string, CandidateAnswer>>({});
  const lastViolationAtRef = useRef<number>(0);
  const violationInFlightRef = useRef<boolean>(false);
  const proctoringReadyAtRef = useRef<number>(0);
  const audioCtxRef = useRef<AudioContext | null>(null);
  const handleViolationRef = useRef<(type: string, details: string) => Promise<void>>(
    async () => {}
  );
  const handleSubmitRef = useRef<(autoSubmitReason?: string) => Promise<void>>(
    async () => {}
  );

  useEffect(() => {
    answersRef.current = answers;
  }, [answers]);

  // Sound generator for violation beep using a single reused Web Audio API context
  const playAlertSound = useCallback(() => {
    try {
      const AudioContextClass =
        window.AudioContext ||
        (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
      if (!AudioContextClass) return;

      if (!audioCtxRef.current || audioCtxRef.current.state === "closed") {
        audioCtxRef.current = new AudioContextClass();
      }
      const audioCtx = audioCtxRef.current;
      if (audioCtx.state === "suspended") {
        audioCtx.resume().catch(() => {});
      }

      const osc = audioCtx.createOscillator();
      const gain = audioCtx.createGain();
      osc.type = "sawtooth";
      osc.frequency.setValueAtTime(440, audioCtx.currentTime);
      osc.frequency.exponentialRampToValueAtTime(880, audioCtx.currentTime + 0.3);
      gain.gain.setValueAtTime(0.18, audioCtx.currentTime);
      gain.gain.exponentialRampToValueAtTime(0.01, audioCtx.currentTime + 0.3);
      osc.connect(gain);
      gain.connect(audioCtx.destination);
      osc.start();
      osc.stop(audioCtx.currentTime + 0.3);
    } catch {
      // Ignore audio errors when autoplay is blocked
    }
  }, []);

  const buildProctoringReport = useCallback((): ProctoringReport => {
    return {
      cameraVerified: false,
      micVerified: false,
      audioPeakLevel: 0,
      snapshots: [],
      violationEvents: violationEventsRef.current.slice(-20),
    };
  }, []);

  // Clean up audio context and pending timers on unmount
  useEffect(() => {
    return () => {
      if (graceTimerRef.current) {
        clearInterval(graceTimerRef.current);
      }
      if (draftDebounceRef.current) {
        clearTimeout(draftDebounceRef.current);
      }
      if (draftSavedTimerRef.current) {
        clearTimeout(draftSavedTimerRef.current);
      }
      if (audioCtxRef.current && audioCtxRef.current.state !== "closed") {
        audioCtxRef.current.close().catch(() => {});
      }
    };
  }, []);

  // 2. Load Exam Session
  useEffect(() => {
    const cleanToken = token.trim();
    if (!cleanToken || cleanToken.toLowerCase() === "default") {
      setIsLoading(false);
      setSession(null);
      setSessionError(
        new ExamSessionError(
          "INVALID_TOKEN",
          isRTL
            ? "لم يتم تحديد رمز اختبار صالح في الرابط. يرجى إدخال رمز الدعوة من الصفحة الرئيسية."
            : "No valid assessment token was provided in the link. Please enter your invitation token on the home page."
        )
      );
      return;
    }

    let isMounted = true;

    async function initSession() {
      setIsLoading(true);
      setSessionError(null);
      setSubmitError(null);
      hasAutoSubmittedRef.current = false;

      try {
        const data = await loadExamSession(cleanToken);
        if (!isMounted) return;

        setSession(data);
        setAnswers(data.savedAnswers || {});
        answersRef.current = data.savedAnswers || {};
        setViolations(data.violationCount || 0);
        setCurrentIndex(0);

        const totalDurationSeconds = Math.max(60, data.durationMinutes * 60);
        const startedMs = new Date(data.startedAt).getTime();
        const serverNowMs = data.serverNow
          ? new Date(data.serverNow).getTime()
          : Date.now();
        const referenceNowMs = !Number.isNaN(serverNowMs) ? serverNowMs : Date.now();

        let remaining = totalDurationSeconds;
        let resumed = false;

        if (!isDemoOrTestToken(cleanToken) && !Number.isNaN(startedMs)) {
          const elapsed = Math.max(0, Math.floor((referenceNowMs - startedMs) / 1000));
          remaining = Math.min(totalDurationSeconds, Math.max(0, totalDurationSeconds - elapsed));
          resumed = elapsed >= 15;
        }

        if (data.expiresAt) {
          const expiresMs = new Date(data.expiresAt).getTime();
          if (!Number.isNaN(expiresMs)) {
            const windowLeft = Math.max(0, Math.floor((expiresMs - referenceNowMs) / 1000));
            remaining = Math.min(remaining, windowLeft);
          }
        }

        isResumedSessionRef.current = resumed;
        initialRemainingRef.current = remaining;
        setInitialTimerSeconds(remaining);
        setTimerEndTimeMs(null);
      } catch (err) {
        if (!isMounted) return;
        const classified =
          err instanceof ExamSessionError
            ? err
            : new ExamSessionError(
                "UNKNOWN",
                (err as { message?: string })?.message ||
                  "Unable to access the assessment session."
              );
        if (classified.kind === "TERMINATED") {
          setIsTerminated(true);
        } else {
          setSessionError(classified);
        }
      } finally {
        if (isMounted) setIsLoading(false);
      }
    }

    initSession();

    return () => {
      isMounted = false;
    };
  }, [token, reloadNonce, isRTL]);

  // 3. Submit Handler (Synchronous lock prevents duplicate submissions)
  const handleSubmit = useCallback(
    async (autoSubmitReason?: string) => {
      if (isSubmittingRef.current || submissionResult || isTerminated) return;

      isSubmittingRef.current = true;
      setIsSubmitting(true);
      setShowSubmitConfirm(false);
      setSubmitError(null);

      if (graceTimerRef.current) {
        clearInterval(graceTimerRef.current);
        graceTimerRef.current = null;
      }
      if (draftDebounceRef.current) {
        clearTimeout(draftDebounceRef.current);
        draftDebounceRef.current = null;
      }

      try {
        const proctoringReport = session?.proctoringEnabled
          ? buildProctoringReport()
          : undefined;
        const result = await submitCandidateExam(
          token,
          answersRef.current,
          session?.attemptId,
          proctoringReport
        );
        setSubmissionResult(result);
        if (typeof document !== "undefined" && document.fullscreenElement) {
          document.exitFullscreen().catch(() => {});
        }
      } catch (err) {
        const classified =
          err instanceof ExamSessionError
            ? err
            : new ExamSessionError(
                "UNKNOWN",
                (err as { message?: string })?.message ||
                  "Failed to submit examination."
              );

        if (classified.kind === "TERMINATED") {
          setIsTerminated(true);
        } else if (classified.kind === "ALREADY_COMPLETED") {
          setSessionError(classified);
        } else {
          setSubmitError(
            autoSubmitReason
              ? isRTL
                ? `تعذر الإرسال التلقائي (${autoSubmitReason}): ${classified.message}. يرجى المحاولة يدوياً.`
                : `Auto-submit failed (${autoSubmitReason}): ${classified.message}. Please retry manually.`
              : classified.message ||
                  (isRTL
                    ? "فشل تسليم الاختبار. يرجى التحقق من اتصالك والمحاولة مجدداً."
                    : "Failed to submit examination. Please check your connection and retry.")
          );
        }
      } finally {
        isSubmittingRef.current = false;
        setIsSubmitting(false);
      }
    },
    [
      token,
      session?.attemptId,
      session?.proctoringEnabled,
      submissionResult,
      isTerminated,
      isRTL,
      buildProctoringReport,
    ]
  );

  useEffect(() => {
    handleSubmitRef.current = handleSubmit;
  }, [handleSubmit]);

  // 4. Drift-Free Countdown Deadline (Isolated in <ExamCountdownTimer /> to avoid 1Hz parent re-renders)
  useEffect(() => {
    if (
      isLoading ||
      !session ||
      submissionResult ||
      isTerminated ||
      !hasPassedSecurityCheck
    ) {
      setTimerEndTimeMs(null);
      return;
    }

    const activeSeconds =
      isResumedSessionRef.current || isDemoOrTestToken(token)
        ? initialRemainingRef.current
        : Math.max(60, session.durationMinutes * 60);

    setInitialTimerSeconds(activeSeconds);
    setTimerEndTimeMs(Date.now() + activeSeconds * 1000);
  }, [isLoading, session, submissionResult, isTerminated, hasPassedSecurityCheck, token]);

  const handleTimeExpired = useCallback(() => {
    if (!hasAutoSubmittedRef.current) {
      hasAutoSubmittedRef.current = true;
      void handleSubmitRef.current("Time Expired");
    }
  }, []);

  // 5. Anti-Cheat Security Violation Reporter (With burst cooldown deduplication)
  const handleViolation = useCallback(
    async (type: string, details: string) => {
      if (
        !session?.proctoringEnabled ||
        submissionResult ||
        isTerminated ||
        !hasStartedRef.current
      ) {
        return;
      }

      const now = Date.now();
      if (now < proctoringReadyAtRef.current) return;

      // Cooldown prevents simultaneous blur + visibilitychange + fullscreenchange from triple-counting 1 action
      if (violationInFlightRef.current || now - lastViolationAtRef.current < 2000) {
        return;
      }

      lastViolationAtRef.current = now;
      violationInFlightRef.current = true;
      playAlertSound();

      try {
        violationEventsRef.current = [
          ...violationEventsRef.current,
          { type, details, timestamp: new Date().toISOString() },
        ].slice(-20);
        const summary = buildProctoringReport();

        const res = await reportViolation(token, type, details, null, summary);
        setViolations(res.violationCount);

        if (res.terminated) {
          setIsTerminated(true);
          if (graceTimerRef.current) {
            clearInterval(graceTimerRef.current);
            graceTimerRef.current = null;
          }
          if (typeof document !== "undefined" && document.fullscreenElement) {
            document.exitFullscreen().catch(() => {});
          }
        } else {
          setWarningMessage(
            isRTL
              ? `تحذير مراقبة (${res.violationCount}/3): ${details}. تجاوز 3 مخالفات يؤدي إلى إنهاء الاختبار تلقائياً.`
              : `Proctoring Warning (${res.violationCount}/3): ${details}. Reaching 3 violations will terminate the exam.`
          );
        }
      } catch (err) {
        console.error("Failed to log proctoring violation:", err);
      } finally {
        violationInFlightRef.current = false;
      }
    },
    [
      session?.proctoringEnabled,
      submissionResult,
      isTerminated,
      token,
      playAlertSound,
      isRTL,
      buildProctoringReport,
    ]
  );

  useEffect(() => {
    handleViolationRef.current = handleViolation;
  }, [handleViolation]);

  // 6. Strict Event Shield Listeners (Keyboard, Visibility, Blur, Fullscreen)
  useEffect(() => {
    if (
      !session?.proctoringEnabled ||
      submissionResult ||
      isTerminated ||
      !hasPassedSecurityCheck
    ) {
      return;
    }

    const handleVisibilityChange = () => {
      if (document.hidden) {
        handleViolation(
          "TAB_SWITCH",
          isRTL
            ? "تم رصد تبديل تبويب المتصفح أو تصغير النافذة"
            : "Candidate switched browser tabs or minimized window"
        );
      }
    };

    const handleWindowBlur = () => {
      handleViolation(
        "WINDOW_BLUR",
        isRTL
          ? "فقدت نافذة الاختبار التركيز"
          : "Exam window lost focus"
      );
    };

    const handleFullscreenChange = () => {
      const inFullscreen = !!document.fullscreenElement;
      setIsFullscreen(inFullscreen);

      if (!inFullscreen && hasStartedRef.current) {
        setShowFullscreenWarning(true);
        setFullscreenGracePeriod(10);

        if (graceTimerRef.current) clearInterval(graceTimerRef.current);
        graceTimerRef.current = setInterval(() => {
          setFullscreenGracePeriod((prev) => {
            if (prev <= 1) {
              if (graceTimerRef.current) {
                clearInterval(graceTimerRef.current);
                graceTimerRef.current = null;
              }
              handleViolationRef.current(
                "FULLSCREEN_TIMEOUT",
                "Failed to return to fullscreen mode within grace period"
              );
              return 0;
            }
            return prev - 1;
          });
        }, 1000);

        handleViolation(
          "FULLSCREEN_EXIT",
          isRTL
            ? "تم الخروج من وضع ملء الشاشة الإلزامي"
            : "Exited required full-screen examination mode"
        );
      } else if (inFullscreen) {
        setShowFullscreenWarning(false);
        if (graceTimerRef.current) {
          clearInterval(graceTimerRef.current);
          graceTimerRef.current = null;
        }
      }
    };

    const handleKeyDown = (e: KeyboardEvent) => {
      const target = e.target as HTMLElement | null;
      const isTextInput =
        target?.tagName === "TEXTAREA" || target?.tagName === "INPUT";
      const modKey = e.ctrlKey || e.metaKey;

      if (e.key === "F12") {
        e.preventDefault();
        e.stopPropagation();
        handleViolation("DEVTOOLS_ATTEMPT", "Developer Tools shortcut (F12) blocked");
        return;
      }

      if (modKey && e.shiftKey && ["i", "j", "c"].includes(e.key.toLowerCase())) {
        e.preventDefault();
        e.stopPropagation();
        handleViolation("DEVTOOLS_ATTEMPT", "Inspect element combination blocked");
        return;
      }

      if (modKey && e.key.toLowerCase() === "u") {
        e.preventDefault();
        e.stopPropagation();
        handleViolation("VIEW_SOURCE_ATTEMPT", "View Page Source shortcut blocked");
        return;
      }

      if (e.key === "PrintScreen") {
        e.preventDefault();
        e.stopPropagation();
        handleViolation("SCREENSHOT_ATTEMPT", "Screen capture key detected");
        return;
      }

      if (modKey && e.key.toLowerCase() === "p") {
        e.preventDefault();
        e.stopPropagation();
        handleViolation("PRINT_ATTEMPT", "Print shortcut blocked");
        return;
      }

      if (modKey && e.key.toLowerCase() === "s") {
        e.preventDefault();
        e.stopPropagation();
        return;
      }

      if ((modKey && e.key.toLowerCase() === "r") || e.key === "F5") {
        e.preventDefault();
        e.stopPropagation();
        handleViolation("RELOAD_ATTEMPT", "Page reload attempt blocked");
        return;
      }

      // Allow Select All inside candidate's own answer textarea, block copy/paste/cut & global select-all
      if (modKey && ["c", "v", "x", "a"].includes(e.key.toLowerCase())) {
        if (e.key.toLowerCase() === "a" && isTextInput) {
          return;
        }
        e.preventDefault();
        e.stopPropagation();
        return;
      }

      if ((e.altKey && e.key === "Tab") || (e.key === "Meta" && !isTextInput)) {
        e.preventDefault();
        handleViolation("SYSTEM_KEY_ATTEMPT", "System application switcher detected");
      }
    };

    const preventClipboard = (e: ClipboardEvent) => {
      e.preventDefault();
      e.stopPropagation();
    };

    const preventContextMenu = (e: MouseEvent) => {
      e.preventDefault();
    };

    const preventDragDrop = (e: DragEvent) => {
      e.preventDefault();
      e.stopPropagation();
    };

    document.addEventListener("visibilitychange", handleVisibilityChange);
    window.addEventListener("blur", handleWindowBlur);
    document.addEventListener("fullscreenchange", handleFullscreenChange);
    window.addEventListener("keydown", handleKeyDown, true);
    document.addEventListener("copy", preventClipboard);
    document.addEventListener("cut", preventClipboard);
    document.addEventListener("paste", preventClipboard);
    document.addEventListener("contextmenu", preventContextMenu);
    document.addEventListener("dragstart", preventDragDrop);
    document.addEventListener("drop", preventDragDrop);

    return () => {
      document.removeEventListener("visibilitychange", handleVisibilityChange);
      window.removeEventListener("blur", handleWindowBlur);
      document.removeEventListener("fullscreenchange", handleFullscreenChange);
      window.removeEventListener("keydown", handleKeyDown, true);
      document.removeEventListener("copy", preventClipboard);
      document.removeEventListener("cut", preventClipboard);
      document.removeEventListener("paste", preventClipboard);
      document.removeEventListener("contextmenu", preventContextMenu);
      document.removeEventListener("dragstart", preventDragDrop);
      document.removeEventListener("drop", preventDragDrop);
      if (graceTimerRef.current) {
        clearInterval(graceTimerRef.current);
        graceTimerRef.current = null;
      }
    };
  }, [
    session?.proctoringEnabled,
    submissionResult,
    isTerminated,
    hasPassedSecurityCheck,
    handleViolation,
    isRTL,
  ]);

  // Request Fullscreen
  const requestFullscreen = async () => {
    try {
      if (typeof document !== "undefined" && !document.fullscreenElement) {
        if (document.documentElement.requestFullscreen) {
          await document.documentElement.requestFullscreen();
          setIsFullscreen(true);
          setShowFullscreenWarning(false);
        }
      }
    } catch (err) {
      console.warn("Fullscreen request error:", err);
    }
  };

  // Complete Security Gate Check & Start Exam
  const handleCompleteSecurityGate = async () => {
    if (isStartingGate) return;
    setIsStartingGate(true);
    try {
      if (session?.proctoringEnabled) {
        proctoringReadyAtRef.current = Date.now() + 800;
        await requestFullscreen();
      }
      setHasPassedSecurityCheck(true);
      hasStartedRef.current = true;
    } finally {
      setIsStartingGate(false);
    }
  };

  const persistDraftWithIndicator = useCallback(
    async (
      attemptId: string,
      allAnswers: Record<string, CandidateAnswer>,
      questionId: string,
      entry: CandidateAnswer
    ) => {
      setDraftSaveState("saving");
      try {
        await saveAnswerDraft(attemptId, token, allAnswers, questionId, entry);
        setDraftSaveState("saved");
        if (draftSavedTimerRef.current) clearTimeout(draftSavedTimerRef.current);
        draftSavedTimerRef.current = setTimeout(() => {
          setDraftSaveState((cur) => (cur === "saved" ? "idle" : cur));
        }, 2200);
      } catch {
        setDraftSaveState("idle");
      }
    },
    [token]
  );

  // Answer selection (persists immediately)
  const handleSelectOption = (questionId: string, optionId: string, isMulti: boolean) => {
    setAnswers((prev) => {
      const existing = prev[questionId]?.selectedOptionIds || [];
      let nextOptions: string[];

      if (isMulti) {
        nextOptions = existing.includes(optionId)
          ? existing.filter((id) => id !== optionId)
          : [...existing, optionId];
      } else {
        nextOptions = [optionId];
      }

      const nextEntry: CandidateAnswer = {
        ...prev[questionId],
        selectedOptionIds: nextOptions,
      };
      const updated = {
        ...prev,
        [questionId]: nextEntry,
      };
      answersRef.current = updated;

      if (session) {
        void persistDraftWithIndicator(session.attemptId, updated, questionId, nextEntry);
      }
      return updated;
    });
  };

  // Text / Coding answer change (synchronous localStorage persistence, debounced remote sync)
  const handleTextAnswerChange = (questionId: string, text: string) => {
    setAnswers((prev) => {
      const nextEntry: CandidateAnswer = {
        ...prev[questionId],
        textAnswer: text,
      };
      const updated = {
        ...prev,
        [questionId]: nextEntry,
      };
      answersRef.current = updated;

      if (session) {
        writeLocalDraft(session.attemptId, updated);
        setDraftSaveState("saving");
        if (draftDebounceRef.current) clearTimeout(draftDebounceRef.current);
        const attemptId = session.attemptId;
        draftDebounceRef.current = setTimeout(() => {
          void persistDraftWithIndicator(attemptId, updated, questionId, nextEntry);
        }, 700);
      }
      return updated;
    });
  };

  const questions = useMemo(() => session?.questions ?? [], [session]);
  const answeredCount = useMemo(
    () =>
      questions.reduce(
        (count, q) => count + (isQuestionAnswered(answers[q.id]) ? 1 : 0),
        0
      ),
    [questions, answers]
  );
  const unansweredCount = questions.length - answeredCount;
  const currentQ: SanitizedQuestion | undefined = questions[currentIndex];
  const isLastQuestion =
    questions.length > 0 && currentIndex === questions.length - 1;

  const renderPreferenceButtons = () => (
    <div className="flex items-center gap-2">
      <button
        type="button"
        onClick={toggleLang}
        className={`inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl text-xs font-semibold border transition-colors cursor-pointer ${
          isDark
            ? "bg-slate-800/90 border-slate-700 text-slate-200 hover:bg-slate-700"
            : "bg-white border-slate-300 text-slate-700 hover:bg-slate-100"
        }`}
        aria-label={isRTL ? "Switch to English" : "التبديل إلى العربية"}
      >
        <Globe className="w-3.5 h-3.5" />
        <span>{isRTL ? "EN" : "العربية"}</span>
      </button>

      <button
        type="button"
        onClick={toggleTheme}
        className={`inline-flex items-center gap-1.5 px-2.5 py-1.5 rounded-xl text-xs font-semibold border transition-colors cursor-pointer ${
          isDark
            ? "bg-slate-800/90 border-slate-700 text-amber-300 hover:bg-slate-700"
            : "bg-white border-slate-300 text-slate-700 hover:bg-slate-100"
        }`}
        aria-label={isDark ? "Light mode" : "Dark mode"}
      >
        {isDark ? <Sun className="w-3.5 h-3.5" /> : <Moon className="w-3.5 h-3.5" />}
      </button>
    </div>
  );

  // ==================== RENDERING STATES ====================

  if (isLoading) {
    return (
      <div
        dir={isRTL ? "rtl" : "ltr"}
        className={`min-h-screen flex flex-col items-center justify-center p-4 transition-colors ${
          isDark ? "bg-slate-950 text-white" : "bg-slate-50 text-slate-900"
        }`}
      >
        <div className="w-12 h-12 border-4 border-indigo-500 border-t-transparent rounded-full animate-spin mb-4" />
        <p className={`font-medium text-center ${isDark ? "text-slate-300" : "text-slate-700"}`}>
          {isRTL
            ? "جاري تهيئة بيئة الاختبار وفحص جلسة التقييم..."
            : "Initializing secure assessment environment..."}
        </p>
        <span className="text-xs text-slate-500 mt-2">
          Test2Hire Secure Assessment Portal
        </span>
      </div>
    );
  }

  if (sessionError && !session) {
    const isCompletedErr = sessionError.kind === "ALREADY_COMPLETED";
    const isExpiredErr = sessionError.kind === "EXPIRED";
    const isRetryable =
      sessionError.kind === "NETWORK" || sessionError.kind === "UNKNOWN";

    return (
      <div
        dir={isRTL ? "rtl" : "ltr"}
        className={`min-h-screen flex flex-col items-center justify-center p-4 transition-colors ${
          isDark ? "bg-slate-950 text-slate-100" : "bg-slate-50 text-slate-900"
        }`}
      >
        <div className="max-w-md w-full flex justify-end mb-3">
          {renderPreferenceButtons()}
        </div>

        <div
          className={`max-w-md w-full p-6 sm:p-8 rounded-3xl shadow-xl border text-center ${
            isDark ? "bg-slate-900" : "bg-white"
          } ${
            isCompletedErr
              ? "border-emerald-500/40"
              : isExpiredErr
              ? "border-amber-500/40"
              : "border-red-500/30"
          }`}
        >
          <div
            className={`w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-4 border ${
              isCompletedErr
                ? "bg-emerald-500/10 text-emerald-500 border-emerald-500/20"
                : isExpiredErr
                ? "bg-amber-500/10 text-amber-500 border-amber-500/20"
                : "bg-red-500/10 text-red-500 border-red-500/20"
            }`}
          >
            {isCompletedErr ? (
              <CheckCircle2 className="w-8 h-8" />
            ) : isExpiredErr ? (
              <Clock className="w-8 h-8" />
            ) : (
              <XCircle className="w-8 h-8" />
            )}
          </div>

          <h2 className={`text-xl font-bold mb-2 ${isDark ? "text-white" : "text-slate-900"}`}>
            {isCompletedErr
              ? isRTL
                ? "تم تسليم هذا الاختبار مسبقاً"
                : "Assessment Already Submitted"
              : isExpiredErr
              ? isRTL
                ? "انتهت صلاحية نافذة الاختبار"
                : "Assessment Window Expired"
              : isRTL
              ? "تعذر الوصول للاختبار"
              : "Unable to Access Assessment"}
          </h2>

          <p className={`text-sm mb-6 leading-relaxed ${isDark ? "text-slate-400" : "text-slate-600"}`}>
            {sessionError.message}
          </p>

          <div className="space-y-3">
            {isRetryable && (
              <button
                type="button"
                onClick={() => setReloadNonce((n) => n + 1)}
                className="w-full py-3 px-4 bg-emerald-600 hover:bg-emerald-500 text-white font-semibold text-sm rounded-xl transition-all flex items-center justify-center gap-2 cursor-pointer"
              >
                <RefreshCw className="w-4 h-4" />
                <span>{isRTL ? "إعادة المحاولة" : "Retry Loading Session"}</span>
              </button>
            )}
            <Link
              href="/"
              className={`block w-full py-3 px-4 font-semibold text-sm rounded-xl transition-all ${
                isDark
                  ? "bg-slate-800 hover:bg-slate-700 text-slate-200"
                  : "bg-slate-100 hover:bg-slate-200 text-slate-800"
              }`}
            >
              {isRTL ? "العودة للرئيسية" : "Back to Home"}
            </Link>
            <Link
              href="/exam/demo"
              className="block w-full py-3 px-4 bg-indigo-600 hover:bg-indigo-500 text-white font-semibold text-sm rounded-xl shadow-lg shadow-indigo-600/25 transition-all"
            >
              {isRTL ? "تجربة اختبار توضيحي (Demo)" : "Try Demo Exam"}
            </Link>
          </div>
        </div>
      </div>
    );
  }

  if (isTerminated) {
    return (
      <div
        dir={isRTL ? "rtl" : "ltr"}
        className={`min-h-screen flex flex-col items-center justify-center p-4 transition-colors ${
          isDark ? "bg-slate-950 text-white" : "bg-slate-50 text-slate-900"
        }`}
      >
        <div className="max-w-md w-full flex justify-end mb-3">
          {renderPreferenceButtons()}
        </div>

        <div
          className={`max-w-md w-full p-6 sm:p-8 rounded-3xl shadow-2xl border border-red-600 text-center ${
            isDark ? "bg-slate-900" : "bg-white"
          }`}
        >
          <div className="w-20 h-20 bg-red-600/20 text-red-500 rounded-full flex items-center justify-center mx-auto mb-5 animate-pulse border border-red-600/40">
            <AlertOctagon className="w-10 h-10" />
          </div>
          <h2 className="text-2xl font-black text-red-500 mb-2">
            {isRTL ? "تم إنهاء الاختبار فورياً" : "Assessment Terminated"}
          </h2>
          <p className={`text-sm mb-6 leading-relaxed ${isDark ? "text-slate-300" : "text-slate-600"}`}>
            {isRTL
              ? "تم إلغاء وإقفال هذا الاختبار تلقائياً بعد رصد 3 مخالفات أمنية لمعايير النزاهة ومنع الغش."
              : "This assessment was automatically terminated after 3 anti-cheat policy violations."}
          </p>
          <div
            className={`text-xs p-4 rounded-2xl border mb-6 leading-relaxed ${
              isDark
                ? "bg-red-950/60 text-red-200 border-red-800/60"
                : "bg-red-50 text-red-800 border-red-200"
            }`}
          >
            {isRTL
              ? "تم توثيق كافة المخالفات في سجل التدقيق الأمني وإرسال التقرير إلى جهة التوظيف."
              : "All detected policy violations have been logged and reported to the hiring organization."}
          </div>
          <Link
            href="/"
            className={`inline-block py-2.5 px-6 font-medium text-xs rounded-xl transition-colors ${
              isDark
                ? "bg-slate-800 hover:bg-slate-700 text-slate-300"
                : "bg-slate-100 hover:bg-slate-200 text-slate-700"
            }`}
          >
            {isRTL ? "إغلاق الجلسة" : "Close Session"}
          </Link>
        </div>
      </div>
    );
  }

  if (submissionResult) {
    return (
      <div
        dir={isRTL ? "rtl" : "ltr"}
        className={`min-h-screen flex flex-col items-center justify-center p-4 transition-colors ${
          isDark ? "bg-slate-950 text-white" : "bg-slate-50 text-slate-900"
        }`}
      >
        <div className="max-w-lg w-full flex justify-end mb-3">
          {renderPreferenceButtons()}
        </div>

        <div
          className={`max-w-lg w-full p-6 sm:p-8 rounded-3xl shadow-2xl border text-center ${
            isDark ? "bg-slate-900 border-slate-800" : "bg-white border-slate-200"
          }`}
        >
          <div
            className={`w-16 h-16 rounded-2xl flex items-center justify-center mx-auto mb-4 border ${
              submissionResult.passed
                ? "bg-emerald-500/10 text-emerald-500 border-emerald-500/30"
                : "bg-amber-500/10 text-amber-500 border-amber-500/30"
            }`}
          >
            <CheckCircle2 className="w-9 h-9" />
          </div>

          <h2 className="text-2xl font-bold mb-1">
            {isRTL ? "تم تسليم الاختبار بنجاح" : "Assessment Submitted Successfully"}
          </h2>
          <p className={`text-sm mb-6 ${isDark ? "text-slate-400" : "text-slate-600"}`}>
            {isRTL
              ? `شكراً لك، ${session?.candidateName}. تم حفظ وتقييم إجاباتك بنجاح.`
              : `Thank you, ${session?.candidateName}. Your responses have been recorded and evaluated.`}
          </p>

          <div
            className={`border rounded-2xl p-6 mb-6 ${
              isDark ? "bg-slate-950 border-slate-800" : "bg-slate-50 border-slate-200"
            }`}
          >
            <div className="text-5xl font-black mb-2 tracking-tight">
              {submissionResult.score}%
            </div>
            <div className={`text-xs font-semibold mb-4 ${isDark ? "text-slate-400" : "text-slate-600"}`}>
              {isRTL
                ? `النقاط المكتسبة: ${submissionResult.earnedPoints} / ${submissionResult.totalPointsPossible} • علامة الاجتياز: ${submissionResult.passingPercentage}%`
                : `Earned: ${submissionResult.earnedPoints} / ${submissionResult.totalPointsPossible} pts • Passing: ${submissionResult.passingPercentage}%`}
            </div>

            <div className="inline-flex items-center gap-1.5 px-4 py-1.5 rounded-full text-xs font-bold tracking-wide">
              {submissionResult.passed ? (
                <span className="bg-emerald-500/20 text-emerald-500 border border-emerald-500/30 px-4 py-1 rounded-full">
                  {isRTL ? "اجتياز الاختبار (Passed)" : "Passed Benchmark"}
                </span>
              ) : (
                <span className="bg-amber-500/20 text-amber-500 border border-amber-500/30 px-4 py-1 rounded-full">
                  {isRTL ? "دون علامة الاجتياز (Below Benchmark)" : "Below Benchmark"}
                </span>
              )}
            </div>
          </div>

          <div className="flex flex-col sm:flex-row items-center justify-center gap-3">
            <Link
              href="/"
              className={`w-full sm:w-auto py-2.5 px-5 rounded-xl text-xs font-semibold transition-colors ${
                isDark
                  ? "bg-slate-800 hover:bg-slate-700 text-slate-200"
                  : "bg-slate-100 hover:bg-slate-200 text-slate-800"
              }`}
            >
              {isRTL ? "العودة للرئيسية" : "Back to Home"}
            </Link>
          </div>
          <p className="text-xs text-slate-500 mt-4">
            {isRTL
              ? "يمكنك الآن إغلاق هذه الصفحة بأمان. ستتزامن نتائجك تلقائياً مع ملف طلبك."
              : "You may close this page safely. Your results are synced with your application."}
          </p>
        </div>
      </div>
    );
  }

  // Empty questions defensive state
  if (session && session.questions.length === 0) {
    return (
      <div
        dir={isRTL ? "rtl" : "ltr"}
        className={`min-h-screen flex flex-col items-center justify-center p-4 ${
          isDark ? "bg-slate-950 text-white" : "bg-slate-50 text-slate-900"
        }`}
      >
        <div
          className={`max-w-md w-full p-8 rounded-3xl border text-center ${
            isDark ? "bg-slate-900 border-slate-800" : "bg-white border-slate-200"
          }`}
        >
          <AlertTriangle className="w-12 h-12 text-amber-500 mx-auto mb-4" />
          <h2 className="text-lg font-bold mb-2">
            {isRTL ? "لا توجد أسئلة في هذا الاختبار" : "No Questions Configured"}
          </h2>
          <p className={`text-sm mb-6 ${isDark ? "text-slate-400" : "text-slate-600"}`}>
            {isRTL
              ? "يبدو أن قالب الاختبار لا يحتوي على أي أسئلة حالياً. يرجى التواصل مع جهة التوظيف."
              : "This exam template currently has no questions. Please contact the hiring company."}
          </p>
          <Link
            href="/"
            className="inline-block py-2.5 px-6 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-semibold"
          >
            {isRTL ? "العودة للرئيسية" : "Back to Home"}
          </Link>
        </div>
      </div>
    );
  }

  // Pre-Exam Security / Briefing Gate
  if (!hasPassedSecurityCheck) {
    const proctored = Boolean(session?.proctoringEnabled);
    const isDemo = isDemoOrTestToken(token);

    return (
      <div
        dir={isRTL ? "rtl" : "ltr"}
        className={`min-h-screen flex flex-col justify-center items-center p-4 py-8 overflow-y-auto transition-colors ${
          isDark ? "bg-slate-950 text-white" : "bg-slate-50 text-slate-900"
        }`}
      >
        <div className="max-w-xl w-full flex justify-between items-center mb-4">
          <Link
            href="/"
            className={`text-xs font-semibold hover:underline ${
              isDark ? "text-slate-400" : "text-slate-600"
            }`}
          >
            {isRTL ? "← الرئيسية" : "← Home"}
          </Link>
          {renderPreferenceButtons()}
        </div>

        <div
          className={`max-w-xl w-full border rounded-3xl p-6 sm:p-8 shadow-2xl relative my-auto ${
            isDark ? "bg-slate-900 border-slate-800" : "bg-white border-slate-200"
          }`}
        >
          <div className="flex items-center gap-3 mb-6 pb-4 border-b border-slate-800/40">
            <div className="w-12 h-12 bg-indigo-500/20 text-indigo-500 rounded-2xl flex items-center justify-center border border-indigo-500/30 flex-shrink-0">
              <ShieldCheck className="w-6 h-6" />
            </div>
            <div className="min-w-0">
              <h2 className="text-lg sm:text-xl font-bold truncate">
                {proctored
                  ? isRTL
                    ? "بوابة الأمان والتحقق من النزاهة"
                    : "Security & Proctoring Verification"
                  : isRTL
                  ? "معلومات الاختبار والاستعداد للبدء"
                  : "Assessment Briefing & Start"}
              </h2>
              <p className="text-xs text-slate-400 truncate">
                {session?.examTitle}
              </p>
            </div>
          </div>

          {proctored ? (
            <div className="space-y-3.5 mb-6 text-sm">
              <div
                className={`p-4 rounded-2xl border flex items-start gap-3 ${
                  isDark
                    ? "bg-slate-950/80 border-slate-800 text-slate-300"
                    : "bg-slate-50 border-slate-200 text-slate-700"
                }`}
              >
                <Maximize className="w-5 h-5 text-indigo-500 flex-shrink-0 mt-0.5" />
                <div>
                  <div className={`font-semibold ${isDark ? "text-white" : "text-slate-900"}`}>
                    {isRTL
                      ? "وضع ملء الشاشة الإلزامي (Full Screen)"
                      : "Mandatory Full-Screen Mode"}
                  </div>
                  <div className="text-xs text-slate-400 mt-1 leading-relaxed">
                    {isRTL
                      ? "مغادرة ملء الشاشة أو التبديل بين التبويبات يُسجل كمخالفة فورية، والحد الأقصى 3 مخالفات قبل إنهاء الاختبار تلقائياً."
                      : "Exiting fullscreen or switching tabs logs a violation. Reaching 3 strikes automatically terminates the session."}
                  </div>
                </div>
              </div>

              <div
                className={`p-4 rounded-2xl border flex items-start gap-3 ${
                  isDark
                    ? "bg-slate-950/80 border-slate-800 text-slate-300"
                    : "bg-slate-50 border-slate-200 text-slate-700"
                }`}
              >
                <Lock className="w-5 h-5 text-indigo-500 flex-shrink-0 mt-0.5" />
                <div>
                  <div className={`font-semibold ${isDark ? "text-white" : "text-slate-900"}`}>
                    {isRTL
                      ? "حظر النسخ، اللصق، وأدوات المطور"
                      : "Clipboard & DevTools Shield"}
                  </div>
                  <div className="text-xs text-slate-400 mt-1 leading-relaxed">
                    {isRTL
                      ? "تم تعطيل النقر الأيمن واختصارات اللصق والنسخ وأدوات المطور مع علامة مائية أمنية ديناميكية."
                      : "Right-click, clipboard copy/paste, and developer shortcuts are restricted with a forensic watermark overlay."}
                  </div>
                </div>
              </div>
            </div>
          ) : (
            <div
              className={`p-4 rounded-2xl border mb-6 text-sm ${
                isDark
                  ? "bg-slate-950/80 border-slate-800 text-slate-300"
                  : "bg-slate-50 border-slate-200 text-slate-700"
              }`}
            >
              <p className="leading-relaxed">
                {isRTL
                  ? "هذا التقييم قياسي (لا يتطلب وضع ملء الشاشة). تأكد من استقرار اتصالك بالإنترنت قبل البدء."
                  : "This is a standard assessment (no fullscreen lock required). Ensure a stable internet connection before starting."}
              </p>
            </div>
          )}

          <div
            className={`border p-4 rounded-2xl mb-6 space-y-2 text-xs ${
              isDark
                ? "bg-indigo-950/40 border-indigo-500/20"
                : "bg-indigo-50 border-indigo-200"
            }`}
          >
            <div className="flex flex-wrap items-center justify-between gap-2">
              <span>
                {isRTL ? "المرشح: " : "Candidate: "}
                <strong>{session?.candidateName}</strong>
              </span>
              <span>
                {isRTL ? "المدة: " : "Duration: "}
                <strong>
                  {session?.durationMinutes} {isRTL ? "دقيقة" : "mins"}
                </strong>
                {" • "}
                {session?.totalQuestions} {isRTL ? "أسئلة" : "Questions"}
              </span>
            </div>
            <div className="pt-2 border-t border-indigo-500/20 flex flex-wrap items-center justify-between gap-2">
              <span className="text-emerald-500 font-semibold flex items-center gap-1.5">
                <span className="w-2 h-2 rounded-full bg-emerald-500 animate-pulse" />
                {isRTL ? "جاهز للبدء فوراً" : "Available Now"}
              </span>
              <span className="text-amber-500 font-medium">
                {isRTL ? "الموعد النهائي: " : "Deadline: "}
                <strong>
                  {session?.expiresAt
                    ? new Date(session.expiresAt).toLocaleDateString(
                        isRTL ? "ar-EG" : "en-US",
                        {
                          year: "numeric",
                          month: "short",
                          day: "numeric",
                          hour: "2-digit",
                          minute: "2-digit",
                        }
                      )
                    : isRTL
                    ? "خلال 7 أيام من الدعوة"
                    : "Within 7 days"}
                </strong>
              </span>
            </div>
          </div>

          <button
            type="button"
            disabled={isStartingGate}
            onClick={handleCompleteSecurityGate}
            className="w-full py-4 px-6 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-60 disabled:cursor-not-allowed text-white font-bold text-sm rounded-2xl shadow-xl shadow-indigo-600/30 flex items-center justify-center gap-2 transition-all transform active:scale-[0.98] cursor-pointer"
          >
            {isStartingGate ? (
              <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
            ) : (
              <ShieldCheck className="w-5 h-5" />
            )}
            <span>
              {isStartingGate
                ? isRTL
                  ? "جاري تهيئة بيئة الاختبار..."
                  : "Initializing Assessment..."
                : proctored
                ? isRTL
                  ? "بدء الاختبار المحمي الآن"
                  : "Start Proctored Exam"
                : isRTL
                ? "بدء الاختبار الآن"
                : "Start Assessment Now"}
            </span>
          </button>
        </div>
      </div>
    );
  }

  const normalizedType = (currentQ?.type || "SINGLE_CHOICE").toUpperCase();
  const isMultiChoice = normalizedType === "MULTIPLE_CHOICE";
  const hasOptions = Boolean(currentQ?.options && currentQ.options.length > 0);
  const showDistinctDescription = Boolean(
    currentQ?.description &&
      currentQ.description.trim().length > 0 &&
      currentQ.description.trim() !== currentQ.title.trim()
  );

  return (
    <div
      dir={isRTL ? "rtl" : "ltr"}
      className={`min-h-screen flex flex-col relative overflow-x-hidden font-sans transition-colors ${
        session?.proctoringEnabled ? "proctoring-shield" : ""
      } ${isDark ? "bg-slate-900 text-slate-100" : "bg-slate-100 text-slate-900"}`}
    >
      {/* 1. Dynamic Forensic Watermark Overlay (Proctoring Only) */}
      {session?.proctoringEnabled && (
        <WatermarkOverlay
          candidateName={session.candidateName}
          attemptId={session.attemptId || token}
          isDark={isDark}
        />
      )}

      {/* 2. Fullscreen Exit Critical Emergency Modal */}
      {showFullscreenWarning && (
        <div className="fixed inset-0 bg-red-950/95 z-50 flex items-center justify-center p-4 sm:p-6 text-center backdrop-blur-md">
          <div className="max-w-md w-full bg-red-900/50 border-2 border-red-500 p-6 sm:p-8 rounded-3xl text-white shadow-2xl">
            <AlertOctagon className="w-14 h-14 text-red-400 mx-auto mb-4 animate-bounce" />
            <h3 className="text-xl sm:text-2xl font-black mb-2">
              {isRTL ? "تحذير أمني عاجل!" : "CRITICAL SECURITY ALERT!"}
            </h3>
            <p className="text-red-100 text-sm mb-6 leading-relaxed">
              {isRTL
                ? "لقد قمت بمغادرة وضع ملء الشاشة. يجب العودة فوراً قبل انتهاء المهلة، وإلا سيتم تسجيل مخالفة إضافية."
                : "You exited fullscreen mode. Return immediately before the countdown ends to avoid another strike."}
            </p>
            <div className="text-3xl sm:text-4xl font-black font-mono text-yellow-300 mb-6">
              {fullscreenGracePeriod} {isRTL ? "ثوانٍ متبقية" : "sec left"}
            </div>
            <button
              type="button"
              onClick={requestFullscreen}
              className="w-full py-3.5 px-6 bg-yellow-400 hover:bg-yellow-300 text-slate-950 font-black text-sm rounded-2xl shadow-lg transition-all cursor-pointer"
            >
              {isRTL ? "العودة لوضع ملء الشاشة فوراً" : "Return to Fullscreen Immediately"}
            </button>
          </div>
        </div>
      )}

      {/* 3. Submit Confirmation Modal */}
      {showSubmitConfirm && (
        <div className="fixed inset-0 bg-black/70 z-50 flex items-center justify-center p-4 backdrop-blur-sm">
          <div
            className={`max-w-md w-full rounded-3xl p-6 sm:p-7 border shadow-2xl ${
              isDark
                ? "bg-slate-900 border-slate-700 text-white"
                : "bg-white border-slate-200 text-slate-900"
            }`}
          >
            <h3 className="text-lg font-bold mb-2">
              {isRTL ? "تأكيد تسليم الاختبار" : "Confirm Final Submission"}
            </h3>
            <p className={`text-sm mb-4 leading-relaxed ${isDark ? "text-slate-300" : "text-slate-600"}`}>
              {unansweredCount > 0
                ? isRTL
                  ? `لقد أجبت على ${answeredCount} من أصل ${questions.length} أسئلة. لا يزال لديك ${unansweredCount} سؤال بدون إجابة. هل تريد التسليم الآن؟`
                  : `You have answered ${answeredCount} of ${questions.length} questions (${unansweredCount} unanswered). Are you sure you want to submit now?`
                : isRTL
                ? `لقد أجبت على جميع الأسئلة (${answeredCount}/${questions.length}). لن تتمكن من تعديل إجاباتك بعد التسليم.`
                : `You have answered all ${questions.length} questions. You cannot modify answers after submission.`}
            </p>
            <div className="flex flex-col-reverse sm:flex-row justify-end gap-2.5 pt-2">
              <button
                type="button"
                onClick={() => setShowSubmitConfirm(false)}
                className={`px-4 py-2.5 rounded-xl text-xs font-semibold border cursor-pointer ${
                  isDark
                    ? "border-slate-700 text-slate-300 hover:bg-slate-800"
                    : "border-slate-300 text-slate-700 hover:bg-slate-100"
                }`}
              >
                {isRTL ? "مراجعة الأسئلة" : "Review Answers"}
              </button>
              <button
                type="button"
                disabled={isSubmitting}
                onClick={() => handleSubmit()}
                className="px-5 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-bold shadow-lg flex items-center justify-center gap-2 cursor-pointer disabled:opacity-50"
              >
                <Send className="w-3.5 h-3.5" />
                <span>{isRTL ? "تأكيد التسليم النهائي" : "Submit Final Exam"}</span>
              </button>
            </div>
          </div>
        </div>
      )}

      {/* 4. Unified Sticky Top Bar (Warning Banner + Header) */}
      <div className="sticky top-0 z-30">
        {warningMessage && (
          <div className="bg-amber-600 text-white px-4 sm:px-6 py-2.5 text-xs font-semibold flex items-center justify-between gap-3 shadow-md border-b border-amber-500">
            <div className="flex items-center gap-2 min-w-0">
              <AlertTriangle className="w-4 h-4 flex-shrink-0 animate-pulse" />
              <span className="break-words">{warningMessage}</span>
            </div>
            <button
              type="button"
              onClick={() => setWarningMessage(null)}
              className="text-white hover:text-amber-200 font-bold underline flex-shrink-0 cursor-pointer"
            >
              {isRTL ? "إغلاق" : "Dismiss"}
            </button>
          </div>
        )}

        <header
          className={`backdrop-blur-md border-b px-4 sm:px-6 py-3 flex flex-wrap items-center justify-between gap-3 shadow-sm ${
            isDark
              ? "bg-slate-950/90 border-slate-800"
              : "bg-white/95 border-slate-200"
          }`}
        >
          <div className="min-w-0">
            <h1 className="font-bold text-sm sm:text-base flex flex-wrap items-center gap-2">
              <span className="truncate max-w-[220px] sm:max-w-md">{session?.examTitle}</span>
              <span
                className={`text-xs px-2.5 py-0.5 rounded-full font-semibold border ${
                  isDark
                    ? "bg-indigo-500/10 text-indigo-300 border-indigo-500/20"
                    : "bg-indigo-50 text-indigo-700 border-indigo-200"
                }`}
              >
                {session?.candidateName}
              </span>
            </h1>
            <p className={`text-xs mt-0.5 font-mono flex flex-wrap items-center gap-2 ${isDark ? "text-slate-400" : "text-slate-600"}`}>
              <span>
                {isRTL
                  ? `السؤال ${currentIndex + 1} من ${questions.length} • تمت إجابة ${answeredCount}`
                  : `Question ${currentIndex + 1} of ${questions.length} • Answered ${answeredCount}`}
              </span>
              {draftSaveState === "saving" && (
                <span className="text-indigo-500 font-semibold">
                  {isRTL ? "• جاري الحفظ..." : "• Saving..."}
                </span>
              )}
              {draftSaveState === "saved" && (
                <span className="text-emerald-500 font-semibold">
                  {isRTL ? "• تم حفظ المسودة" : "• Draft saved"}
                </span>
              )}
            </p>
          </div>

          <div className="flex flex-wrap items-center gap-2 sm:gap-3">
            {/* Timer Display (Isolated component to avoid 1Hz parent re-renders) */}
            <ExamCountdownTimer
              endTimeMs={timerEndTimeMs}
              initialSeconds={initialTimerSeconds}
              isDark={isDark}
              onExpire={handleTimeExpired}
            />

            {session?.proctoringEnabled && !isFullscreen && (
              <button
                type="button"
                onClick={requestFullscreen}
                className="flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold bg-indigo-600 hover:bg-indigo-500 text-white transition-colors cursor-pointer"
              >
                <Maximize className="w-3.5 h-3.5" />
                <span className="hidden sm:inline">
                  {isRTL ? "ملء الشاشة" : "Fullscreen"}
                </span>
              </button>
            )}

            {session?.proctoringEnabled && (
              <div
                className={`flex items-center gap-1.5 text-xs px-2.5 sm:px-3 py-1.5 rounded-xl border font-mono font-bold ${
                  isDark ? "bg-slate-800 border-slate-700" : "bg-slate-100 border-slate-300"
                }`}
              >
                <ShieldAlert
                  className={`w-4 h-4 ${
                    violations > 0 ? "text-red-500 animate-pulse" : "text-emerald-500"
                  }`}
                />
                <span className={violations > 1 ? "text-red-500" : ""}>
                  {isRTL ? `المخالفات: ${violations}/3` : `Strikes: ${violations}/3`}
                </span>
              </div>
            )}

            {renderPreferenceButtons()}
          </div>
        </header>
      </div>

      {/* 5. Main Examination Area */}
      <main className="flex-1 max-w-4xl w-full mx-auto p-3 sm:p-6 pb-8 flex flex-col z-10">
        {/* Visible Submit Error Banner */}
        {submitError && (
          <div
            className={`mb-4 p-4 rounded-2xl border flex flex-wrap items-center justify-between gap-3 text-xs sm:text-sm ${
              isDark
                ? "bg-red-950/70 border-red-700 text-red-200"
                : "bg-red-50 border-red-300 text-red-800"
            }`}
          >
            <div className="flex items-center gap-2 min-w-0">
              <AlertTriangle className="w-5 h-5 text-red-500 flex-shrink-0" />
              <span className="break-words">{submitError}</span>
            </div>
            <div className="flex items-center gap-2">
              <button
                type="button"
                onClick={() => handleSubmit()}
                disabled={isSubmitting}
                className="px-3 py-1.5 rounded-lg bg-red-600 hover:bg-red-500 text-white font-semibold text-xs cursor-pointer"
              >
                {isRTL ? "إعادة الإرسال" : "Retry Submit"}
              </button>
              <button
                type="button"
                onClick={() => setSubmitError(null)}
                className="px-2 py-1 text-xs underline cursor-pointer"
              >
                {isRTL ? "إخفاء" : "Dismiss"}
              </button>
            </div>
          </div>
        )}

        {currentQ ? (
          <div
            className={`backdrop-blur-md rounded-3xl shadow-xl border p-4 sm:p-8 flex-1 flex flex-col justify-between ${
              isDark
                ? "bg-slate-950/80 border-slate-800"
                : "bg-white border-slate-200"
            }`}
          >
            <div>
              {/* Question Header Badges */}
              <div
                className={`flex flex-wrap items-center justify-between gap-2 pb-4 border-b mb-6 ${
                  isDark ? "border-slate-800" : "border-slate-200"
                }`}
              >
                <div className="flex flex-wrap items-center gap-2">
                  <span
                    className={`text-xs font-bold uppercase tracking-wider px-3 py-1 rounded-lg border ${
                      isDark
                        ? "bg-slate-800 text-indigo-300 border-slate-700"
                        : "bg-indigo-50 text-indigo-700 border-indigo-200"
                    }`}
                  >
                    {getQuestionTypeLabel(normalizedType, isRTL)}
                  </span>
                  <span
                    className={`text-xs font-medium px-2.5 py-1 rounded-lg border ${
                      isDark
                        ? "bg-slate-800/80 text-slate-400 border-slate-800"
                        : "bg-slate-100 text-slate-600 border-slate-200"
                    }`}
                  >
                    {getDifficultyLabel(currentQ.difficulty, isRTL)}
                  </span>
                  {currentQ.programmingLanguage && (
                    <span
                      dir="ltr"
                      className={`text-xs font-mono px-2.5 py-1 rounded-lg border inline-flex items-center gap-1 ${
                        isDark
                          ? "bg-emerald-950/50 text-emerald-300 border-emerald-800"
                          : "bg-emerald-50 text-emerald-700 border-emerald-200"
                      }`}
                    >
                      <Code2 className="w-3.5 h-3.5" />
                      {currentQ.programmingLanguage}
                    </span>
                  )}
                </div>
                <span
                  className={`text-xs font-bold font-mono px-3 py-1 rounded-lg border ${
                    isDark
                      ? "text-indigo-400 bg-indigo-500/10 border-indigo-500/20"
                      : "text-indigo-700 bg-indigo-50 border-indigo-200"
                  }`}
                >
                  {currentQ.points}{" "}
                  {isRTL ? (currentQ.points === 1 ? "نقطة" : "نقاط") : "pts"}
                </span>
              </div>

              {/* Title & Description */}
              <h2
                className={`text-base sm:text-xl font-bold mb-3 leading-snug ${
                  isDark ? "text-white" : "text-slate-900"
                }`}
              >
                {currentQ.title}
              </h2>

              {showDistinctDescription && (
                <p
                  className={`text-sm mb-6 whitespace-pre-wrap leading-relaxed ${
                    isDark ? "text-slate-300" : "text-slate-700"
                  }`}
                >
                  {currentQ.description}
                </p>
              )}

              {/* Sample Code Snippet (Always LTR for code readability) */}
              {currentQ.sampleCodeSnippet && (
                <div className="mb-6">
                  <div className="flex items-center justify-between mb-1.5">
                    <span className="text-[11px] font-semibold text-slate-400 flex items-center gap-1">
                      <FileText className="w-3.5 h-3.5" />
                      {isRTL ? "نموذج كود مرجعي / مبدئي" : "Code Context / Starter Template"}
                    </span>
                    {!hasOptions && normalizedType === "CODING" && (
                      <button
                        type="button"
                        onClick={() => {
                          if (!answers[currentQ.id]?.textAnswer?.trim()) {
                            handleTextAnswerChange(
                              currentQ.id,
                              currentQ.sampleCodeSnippet || ""
                            );
                          }
                        }}
                        className="text-[11px] font-semibold text-indigo-400 hover:text-indigo-300 underline cursor-pointer"
                      >
                        {isRTL ? "نسخ القالب لمحرر الحل" : "Load Starter into Editor"}
                      </button>
                    )}
                  </div>
                  <div
                    dir="ltr"
                    className={`rounded-2xl overflow-hidden border p-4 font-mono text-xs overflow-x-auto shadow-inner text-left ${
                      isDark
                        ? "border-slate-800 bg-slate-950 text-slate-200"
                        : "border-slate-300 bg-slate-900 text-slate-100"
                    }`}
                  >
                    <pre className="select-text">{currentQ.sampleCodeSnippet}</pre>
                  </div>
                </div>
              )}

              {/* Question Input Area: Options (SINGLE_CHOICE, MULTIPLE_CHOICE, TRUE_FALSE, option-based CODING/SHORT_ANSWER/MIXED) vs Textarea */}
              {hasOptions ? (
                <div className="space-y-3 mt-4">
                  <p className={`text-xs font-medium ${isDark ? "text-slate-400" : "text-slate-600"}`}>
                    {isMultiChoice
                      ? isRTL
                        ? "يمكنك اختيار أكثر من إجابة واحدة:"
                        : "Select all options that apply:"
                      : isRTL
                      ? "اختر إجابة واحدة:"
                      : "Select one answer:"}
                  </p>
                  {currentQ.options.map((opt) => {
                    const isSelected = (
                      answers[currentQ.id]?.selectedOptionIds || []
                    ).includes(opt.id);

                    return (
                      <button
                        key={opt.id}
                        type="button"
                        role={isMultiChoice ? "checkbox" : "radio"}
                        aria-checked={isSelected}
                        onClick={() =>
                          handleSelectOption(currentQ.id, opt.id, isMultiChoice)
                        }
                        className={`w-full text-start p-4 rounded-2xl border text-sm font-medium cursor-pointer transition-all flex items-center gap-3.5 ${
                          isSelected
                            ? isDark
                              ? "bg-indigo-600/20 border-indigo-500 text-white shadow-lg shadow-indigo-500/10"
                              : "bg-indigo-50 border-indigo-500 text-indigo-950 shadow-sm"
                            : isDark
                            ? "bg-slate-900/60 border-slate-800 text-slate-300 hover:bg-slate-800/60 hover:border-slate-700"
                            : "bg-slate-50 border-slate-200 text-slate-800 hover:bg-slate-100 hover:border-slate-300"
                        }`}
                      >
                        <span
                          className={`w-5 h-5 border flex items-center justify-center flex-shrink-0 transition-colors ${
                            isMultiChoice ? "rounded-md" : "rounded-full"
                          } ${
                            isSelected
                              ? "bg-indigo-600 border-indigo-500 text-white"
                              : isDark
                              ? "border-slate-700 bg-slate-800"
                              : "border-slate-300 bg-white"
                          }`}
                        >
                          {isSelected && <span className="text-[10px] font-bold">✓</span>}
                        </span>
                        <span className="flex-1 leading-relaxed">{opt.text}</span>
                      </button>
                    );
                  })}
                </div>
              ) : (
                <div className="mt-4 space-y-2">
                  <div className="flex items-center justify-between text-xs text-slate-400">
                    <span>
                      {normalizedType === "CODING"
                        ? isRTL
                          ? "اكتب الكود البرمجي والتعقيد الزمني (يدعم مفتاح Tab للمسافات):"
                          : "Write your code solution and complexity analysis (Tab inserts 2 spaces):"
                        : isRTL
                        ? "اكتب إجابتك التوضيحية أدناه:"
                        : "Write your detailed answer below:"}
                    </span>
                    <span className="font-mono">
                      {(answers[currentQ.id]?.textAnswer || "").length}{" "}
                      {isRTL ? "حرف" : "chars"}
                    </span>
                  </div>
                  <textarea
                    rows={normalizedType === "CODING" ? 9 : 6}
                    dir={normalizedType === "CODING" ? "ltr" : "auto"}
                    value={answers[currentQ.id]?.textAnswer || ""}
                    onChange={(e) =>
                      handleTextAnswerChange(currentQ.id, e.target.value)
                    }
                    onKeyDown={(e) => {
                      if (normalizedType === "CODING" && e.key === "Tab") {
                        e.preventDefault();
                        const el = e.currentTarget;
                        const start = el.selectionStart;
                        const end = el.selectionEnd;
                        const val = el.value;
                        const nextVal = val.substring(0, start) + "  " + val.substring(end);
                        handleTextAnswerChange(currentQ.id, nextVal);
                        requestAnimationFrame(() => {
                          el.selectionStart = el.selectionEnd = start + 2;
                        });
                      }
                    }}
                    placeholder={
                      normalizedType === "CODING"
                        ? "// Write your solution here..."
                        : isRTL
                        ? "اكتب إجابتك النموذجية هنا بشكل واضح ومفصل..."
                        : "Write your detailed answer here..."
                    }
                    className={`w-full p-4 rounded-2xl border text-sm focus:outline-none focus:ring-2 focus:ring-indigo-500 shadow-inner select-text ${
                      normalizedType === "CODING" ? "font-mono text-left" : ""
                    } ${
                      isDark
                        ? "border-slate-800 bg-slate-950 text-slate-100 placeholder-slate-600"
                        : "border-slate-300 bg-slate-50 text-slate-900 placeholder-slate-400 focus:bg-white"
                    }`}
                  />
                </div>
              )}
            </div>

            {/* Navigation Buttons Footer */}
            <div
              className={`flex flex-col sm:flex-row items-stretch sm:items-center justify-between gap-4 pt-6 border-t mt-8 ${
                isDark ? "border-slate-800" : "border-slate-200"
              }`}
            >
              {/* Question Index Pills */}
              <div className="flex flex-wrap items-center justify-center gap-1.5 pb-1 sm:order-2 max-w-full">
                {questions.map((q, idx) => {
                  const isCurrent = idx === currentIndex;
                  const isAnswered = isQuestionAnswered(answers[q.id]);

                  return (
                    <button
                      key={q.id}
                      type="button"
                      onClick={() => setCurrentIndex(idx)}
                      aria-label={`Question ${idx + 1}`}
                      className={`w-8 h-8 flex-shrink-0 rounded-lg text-xs font-bold transition-all cursor-pointer ${
                        isCurrent
                          ? "bg-indigo-600 text-white ring-2 ring-indigo-400/50"
                          : isAnswered
                          ? isDark
                            ? "bg-indigo-950/80 text-indigo-300 border border-indigo-700/50"
                            : "bg-indigo-100 text-indigo-700 border border-indigo-300"
                          : isDark
                          ? "bg-slate-800/80 text-slate-400 hover:bg-slate-700"
                          : "bg-slate-100 text-slate-600 hover:bg-slate-200"
                      }`}
                    >
                      {idx + 1}
                    </button>
                  );
                })}
              </div>

              <div className="flex items-center justify-between sm:contents gap-3">
                <button
                  type="button"
                  disabled={currentIndex === 0}
                  onClick={() => setCurrentIndex((prev) => Math.max(0, prev - 1))}
                  className={`sm:order-1 flex items-center justify-center gap-1.5 px-4 py-2.5 rounded-xl border text-sm font-semibold disabled:opacity-30 disabled:pointer-events-none transition-colors cursor-pointer ${
                    isDark
                      ? "border-slate-800 text-slate-300 hover:bg-slate-800"
                      : "border-slate-300 text-slate-700 hover:bg-slate-100"
                  }`}
                >
                  {isRTL ? (
                    <ChevronRight className="w-4 h-4" />
                  ) : (
                    <ChevronLeft className="w-4 h-4" />
                  )}
                  <span>{isRTL ? "السابق" : "Previous"}</span>
                </button>

                {isLastQuestion ? (
                  <button
                    type="button"
                    onClick={() => setShowSubmitConfirm(true)}
                    disabled={isSubmitting}
                    className="sm:order-3 flex items-center justify-center gap-2 px-5 sm:px-6 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-500 text-white text-sm font-bold shadow-lg shadow-emerald-600/20 disabled:opacity-50 transition-all cursor-pointer"
                  >
                    {isSubmitting ? (
                      <div className="w-4 h-4 border-2 border-white border-t-transparent rounded-full animate-spin" />
                    ) : (
                      <Send className="w-4 h-4" />
                    )}
                    <span>
                      {isRTL ? "تسليم الامتحان النهائي" : "Submit Final Exam"}
                    </span>
                  </button>
                ) : (
                  <button
                    type="button"
                    onClick={() =>
                      setCurrentIndex((prev) =>
                        Math.min(questions.length - 1, prev + 1)
                      )
                    }
                    className="sm:order-3 flex items-center justify-center gap-1.5 px-5 py-2.5 rounded-xl bg-indigo-600 hover:bg-indigo-500 text-white text-sm font-bold shadow-lg shadow-indigo-600/20 transition-all cursor-pointer"
                  >
                    <span>{isRTL ? "التالي" : "Next"}</span>
                    {isRTL ? (
                      <ChevronLeft className="w-4 h-4" />
                    ) : (
                      <ChevronRight className="w-4 h-4" />
                    )}
                  </button>
                )}
              </div>
            </div>
          </div>
        ) : null}
      </main>
    </div>
  );
}
