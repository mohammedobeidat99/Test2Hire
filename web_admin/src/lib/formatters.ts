export interface CurrencyOption {
  code: string;
  labelAr: string;
  labelEn: string;
}

export const CURRENCY_OPTIONS: CurrencyOption[] = [
  { code: "JOD", labelAr: "د.أ - دينار أردني (JOD)", labelEn: "JOD - Jordanian Dinar" },
  { code: "SAR", labelAr: "ر.س - ريال سعودي (SAR)", labelEn: "SAR - Saudi Riyal" },
  { code: "AED", labelAr: "د.إ - درهم إماراتي (AED)", labelEn: "AED - UAE Dirham" },
  { code: "USD", labelAr: "$ - دولار أمريكي (USD)", labelEn: "USD - US Dollar" },
  { code: "EUR", labelAr: "€ - يورو (EUR)", labelEn: "EUR - Euro" },
  { code: "GBP", labelAr: "£ - جنيه إسترليني (GBP)", labelEn: "GBP - British Pound" },
  { code: "KWD", labelAr: "د.ك - دينار كويتي (KWD)", labelEn: "KWD - Kuwaiti Dinar" },
  { code: "QAR", labelAr: "ر.ق - ريال قطري (QAR)", labelEn: "QAR - Qatari Riyal" },
  { code: "BHD", labelAr: "د.ب - دينار بحريني (BHD)", labelEn: "BHD - Bahraini Dinar" },
  { code: "OMR", labelAr: "ر.ع - ريال عماني (OMR)", labelEn: "OMR - Omani Rial" },
  { code: "EGP", labelAr: "ج.م - جنيه مصري (EGP)", labelEn: "EGP - Egyptian Pound" },
  { code: "IQD", labelAr: "د.ع - دينار عراقي (IQD)", labelEn: "IQD - Iraqi Dinar" },
  { code: "SYP", labelAr: "ل.س - ليرة سورية (SYP)", labelEn: "SYP - Syrian Pound" },
];

/**
 * Safely convert any Firestore Timestamp, serialized timestamp object, Date, or string to epoch milliseconds.
 */
export function timestampToMillis(ts: unknown): number {
  if (!ts) return 0;
  if (typeof ts === "number") return Number.isFinite(ts) ? ts : 0;
  if (ts instanceof Date) {
    const ms = ts.getTime();
    return Number.isNaN(ms) ? 0 : ms;
  }
  if (typeof ts === "string") {
    const ms = Date.parse(ts);
    return Number.isNaN(ms) ? 0 : ms;
  }
  if (typeof ts === "object") {
    const obj = ts as Record<string, unknown>;
    if (typeof obj.toMillis === "function") {
      try {
        return Number((obj.toMillis as () => number)()) || 0;
      } catch {
        return 0;
      }
    }
    if (typeof obj.toDate === "function") {
      try {
        const d = (obj.toDate as () => Date)();
        const ms = d?.getTime?.();
        return Number.isNaN(ms) ? 0 : ms;
      } catch {
        return 0;
      }
    }
    const seconds = typeof obj.seconds === "number" ? obj.seconds : typeof obj._seconds === "number" ? obj._seconds : null;
    if (seconds !== null) {
      const nanos = typeof obj.nanoseconds === "number" ? obj.nanoseconds : typeof obj._nanoseconds === "number" ? obj._nanoseconds : 0;
      return seconds * 1000 + Math.floor(nanos / 1_000_000);
    }
  }
  return 0;
}

/**
 * Safely convert a timestamp-like value into a valid Date, or null if missing/invalid.
 */
export function timestampToDate(ts: unknown): Date | null {
  const ms = timestampToMillis(ts);
  if (!ms) return null;
  const d = new Date(ms);
  return Number.isNaN(d.getTime()) ? null : d;
}

/**
 * Safely format any timestamp-like value without throwing on non-Timestamp types.
 */
export function formatTimestamp(
  ts: unknown,
  locale = "en-US",
  options?: Intl.DateTimeFormatOptions,
  fallback = "N/A"
): string {
  const d = timestampToDate(ts);
  if (!d) return fallback;
  return options ? d.toLocaleString(locale, options) : d.toLocaleDateString(locale);
}

/**
 * Comparator for descending chronological sorting.
 */
export function compareTimestampsDesc(a: unknown, b: unknown): number {
  return timestampToMillis(b) - timestampToMillis(a);
}

export interface ApplicantStatusMeta {
  labelAr: string;
  labelEn: string;
  badgeClass: string;
}

export function getApplicantStatusMeta(status: string): ApplicantStatusMeta {
  switch ((status || "APPLIED").toUpperCase()) {
    case "PASSED":
    case "EXAM_COMPLETED":
      return {
        labelAr: status.toUpperCase() === "EXAM_COMPLETED" ? "أكمل الاختبار" : "اجتاز الاختبار",
        labelEn: status.toUpperCase() === "EXAM_COMPLETED" ? "Exam Completed" : "Passed Exam",
        badgeClass:
          "bg-emerald-100 dark:bg-emerald-950/70 text-emerald-800 dark:text-emerald-300 border-emerald-200 dark:border-emerald-800",
      };
    case "FAILED":
      return {
        labelAr: "لم يجتز الاختبار",
        labelEn: "Failed Exam",
        badgeClass:
          "bg-rose-100 dark:bg-rose-950/70 text-rose-800 dark:text-rose-300 border-rose-200 dark:border-rose-800",
      };
    case "EXAM_ASSIGNED":
    case "EXAM_PENDING":
    case "EXAM_IN_PROGRESS":
      return {
        labelAr: status.toUpperCase() === "EXAM_IN_PROGRESS" ? "يؤدي الاختبار" : "تم تعيين اختبار",
        labelEn: status.toUpperCase() === "EXAM_IN_PROGRESS" ? "Exam In Progress" : "Exam Assigned",
        badgeClass:
          "bg-blue-100 dark:bg-blue-950/70 text-blue-800 dark:text-blue-300 border-blue-200 dark:border-blue-800",
      };
    case "INTERVIEW_SCHEDULED":
    case "INTERVIEW_INVITED":
      return {
        labelAr: status.toUpperCase() === "INTERVIEW_INVITED" ? "مدعو لمقابلة" : "مقابلة مجدولة",
        labelEn: status.toUpperCase() === "INTERVIEW_INVITED" ? "Interview Invited" : "Interview",
        badgeClass:
          "bg-purple-100 dark:bg-purple-950/70 text-purple-800 dark:text-purple-300 border-purple-200 dark:border-purple-800",
      };
    case "OFFER_EXTENDED":
    case "SELECTED":
      return {
        labelAr: status.toUpperCase() === "SELECTED" ? "مختار / عرض عمل" : "تم إرسال عرض",
        labelEn: status.toUpperCase() === "SELECTED" ? "Selected / Offer" : "Offer Sent",
        badgeClass:
          "bg-amber-100 dark:bg-amber-950/70 text-amber-800 dark:text-amber-300 border-amber-200 dark:border-amber-800",
      };
    case "HIRED":
      return {
        labelAr: "تم التعيين",
        labelEn: "Hired",
        badgeClass:
          "bg-teal-100 dark:bg-teal-950/70 text-teal-800 dark:text-teal-300 border-teal-200 dark:border-teal-800",
      };
    case "UNDER_REVIEW":
    case "SHORTLISTED":
      return {
        labelAr: status.toUpperCase() === "SHORTLISTED" ? "قائمة مختصرة" : "قيد المراجعة",
        labelEn: status.toUpperCase() === "SHORTLISTED" ? "Shortlisted" : "Under Review",
        badgeClass:
          "bg-indigo-100 dark:bg-indigo-950/70 text-indigo-800 dark:text-indigo-300 border-indigo-200 dark:border-indigo-800",
      };
    case "REJECTED":
      return {
        labelAr: "مرفوض",
        labelEn: "Rejected",
        badgeClass:
          "bg-rose-100 dark:bg-rose-950/70 text-rose-800 dark:text-rose-300 border-rose-200 dark:border-rose-800",
      };
    case "WITHDRAWN":
      return {
        labelAr: "منسحب",
        labelEn: "Withdrawn",
        badgeClass:
          "bg-slate-200 dark:bg-slate-800 text-slate-600 dark:text-slate-400 border-slate-300 dark:border-slate-700",
      };
    default:
      return {
        labelAr: "طلب جديد",
        labelEn: "Applied",
        badgeClass:
          "bg-slate-100 dark:bg-slate-800 text-slate-700 dark:text-slate-300 border-slate-200 dark:border-slate-700",
      };
  }
}

export const ALLOWED_RASTER_IMAGE_TYPES = [
  "image/jpeg",
  "image/jpg",
  "image/png",
  "image/webp",
  "image/gif",
] as const;

export function isAllowedRasterImage(file: File): boolean {
  const mime = (file.type || "").toLowerCase();
  if ((ALLOWED_RASTER_IMAGE_TYPES as readonly string[]).includes(mime)) return true;
  if (!mime && /\.(jpe?g|png|webp|gif)$/i.test(file.name || "")) return true;
  return false;
}

/**
 * Validate and normalize external links to http:/https: only (blocks javascript:, data:, etc.).
 */
export function sanitizeExternalUrl(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const trimmed = raw.trim();
  if (!trimmed || trimmed.startsWith("//")) return null;
  const hasScheme = /^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(trimmed);
  const candidate = hasScheme ? trimmed : `https://${trimmed}`;
  try {
    const parsed = new URL(candidate);
    if (parsed.protocol !== "http:" && parsed.protocol !== "https:") {
      return null;
    }
    return parsed.toString();
  } catch {
    return null;
  }
}

/**
 * Validate image URLs, allowing https:/http: URLs or raster data:image/* base64 payloads (never SVG).
 */
export function sanitizeImageUrl(raw: unknown): string | null {
  if (typeof raw !== "string") return null;
  const trimmed = raw.trim();
  if (!trimmed) return "";
  if (/^data:image\/(jpeg|jpg|png|webp|gif);base64,[A-Za-z0-9+/=]+$/i.test(trimmed)) {
    return trimmed;
  }
  return sanitizeExternalUrl(trimmed);
}

