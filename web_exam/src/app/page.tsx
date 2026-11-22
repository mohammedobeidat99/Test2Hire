"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import {
  ArrowLeft,
  ArrowRight,
  Globe,
  KeyRound,
  Moon,
  ShieldAlert,
  Sparkles,
  Sun,
} from "lucide-react";
import { extractTokenInput } from "@/lib/exam-auth";
import { usePortalPreferences } from "@/lib/portal-preferences";

export default function Home() {
  const [token, setToken] = useState("");
  const [formError, setFormError] = useState<string | null>(null);
  const router = useRouter();
  const { isRTL, isDark, toggleLang, toggleTheme } = usePortalPreferences();

  const handleStartExam = (e: React.FormEvent) => {
    e.preventDefault();
    setFormError(null);
    const cleaned = extractTokenInput(token);
    if (!cleaned || cleaned.toLowerCase() === "default") {
      setFormError(
        isRTL
          ? "يرجى إدخال رمز جلسة اختبار صالح للمتابعة."
          : "Please enter a valid assessment token to continue."
      );
      return;
    }
    router.push(`/exam/${encodeURIComponent(cleaned)}`);
  };

  const handleStartDemo = () => {
    router.push("/exam/demo");
  };

  return (
    <main
      dir={isRTL ? "rtl" : "ltr"}
      className={`flex min-h-screen flex-col items-center justify-center p-4 sm:p-6 transition-colors ${
        isDark ? "bg-slate-950 text-slate-100" : "bg-slate-50 text-slate-900"
      }`}
    >
      {/* Top Preferences Bar */}
      <div className="w-full max-w-md flex items-center justify-end gap-2 mb-4">
        <button
          type="button"
          onClick={toggleLang}
          className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold border transition-colors cursor-pointer ${
            isDark
              ? "bg-slate-900 border-slate-800 text-slate-200 hover:bg-slate-800"
              : "bg-white border-slate-200 text-slate-700 hover:bg-slate-100"
          }`}
          aria-label={isRTL ? "Switch to English" : "التبديل إلى العربية"}
        >
          <Globe className="w-3.5 h-3.5" />
          <span>{isRTL ? "English" : "العربية"}</span>
        </button>

        <button
          type="button"
          onClick={toggleTheme}
          className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl text-xs font-semibold border transition-colors cursor-pointer ${
            isDark
              ? "bg-slate-900 border-slate-800 text-amber-300 hover:bg-slate-800"
              : "bg-white border-slate-200 text-slate-700 hover:bg-slate-100"
          }`}
          aria-label={isDark ? "Switch to Light Mode" : "Switch to Dark Mode"}
        >
          {isDark ? <Sun className="w-3.5 h-3.5" /> : <Moon className="w-3.5 h-3.5" />}
          <span>
            {isDark
              ? isRTL
                ? "وضع نهاري"
                : "Light"
              : isRTL
              ? "وضع ليلي"
              : "Dark"}
          </span>
        </button>
      </div>

      <div
        className={`max-w-md w-full p-6 sm:p-8 rounded-2xl shadow-lg border transition-colors ${
          isDark
            ? "bg-slate-900 border-slate-800 shadow-black/40"
            : "bg-white border-slate-200 shadow-slate-200/60"
        }`}
      >
        <div className="text-center">
          <div
            className={`w-16 h-16 rounded-full flex items-center justify-center mx-auto mb-4 font-bold text-2xl ${
              isDark
                ? "bg-indigo-500/20 text-indigo-300 border border-indigo-500/30"
                : "bg-indigo-50 text-indigo-700 border border-indigo-100"
            }`}
          >
            T2H
          </div>
          <h1
            className={`text-xl sm:text-2xl font-bold mb-2 ${
              isDark ? "text-white" : "text-slate-900"
            }`}
          >
            {isRTL ? "منصة اختبارات Test2Hire" : "Test2Hire Assessment Engine"}
          </h1>
          <p
            className={`text-sm mb-6 leading-relaxed ${
              isDark ? "text-slate-400" : "text-slate-600"
            }`}
          >
            {isRTL
              ? "أدخل رمز جلسة الاختبار الآمن أو الصق رابط الدعوة للمتابعة إلى واجهة الاختبار المباشرة:"
              : "Enter your secure Assessment Token or paste your invitation link to proceed to the live examination:"}
          </p>
        </div>

        <form onSubmit={handleStartExam} className="space-y-4 mb-4">
          <div>
            <label
              htmlFor="exam-token-input"
              className={`block text-xs font-semibold mb-1.5 ${
                isDark ? "text-slate-300" : "text-slate-700"
              }`}
            >
              {isRTL
                ? "رمز الدخول للاختبار (Assessment Token)"
                : "Assessment Access Token"}
            </label>
            <div className="relative" dir="ltr">
              <KeyRound className="w-4 h-4 text-slate-400 absolute left-3 top-3.5 pointer-events-none" />
              <input
                id="exam-token-input"
                type="text"
                value={token}
                onChange={(e) => {
                  setToken(e.target.value);
                  if (formError) setFormError(null);
                }}
                placeholder="Paste token or exam URL, e.g. a1b2c3d4..."
                className={`w-full pl-9 pr-3 py-2.5 text-sm border rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 transition-all font-mono ${
                  isDark
                    ? "bg-slate-950 border-slate-700 text-slate-100 placeholder-slate-500 focus:bg-slate-950"
                    : "bg-slate-50 border-slate-300 text-slate-900 placeholder-slate-400 focus:bg-white"
                }`}
              />
            </div>

            {formError && (
              <p className="text-xs text-rose-500 font-medium mt-1.5">{formError}</p>
            )}

            <div
              className={`text-[11px] mt-2 flex flex-wrap items-center gap-1.5 ${
                isDark ? "text-slate-400" : "text-slate-500"
              }`}
            >
              <span>{isRTL ? "رمز الاختبار التجريبي السريع:" : "Quick sandbox tokens:"}</span>
              <button
                type="button"
                onClick={() => {
                  setToken("test");
                  setFormError(null);
                }}
                className={`px-2 py-0.5 rounded font-mono font-bold text-[11px] border transition-colors cursor-pointer ${
                  isDark
                    ? "bg-indigo-950/60 hover:bg-indigo-900/60 text-indigo-300 border-indigo-800"
                    : "bg-indigo-50 hover:bg-indigo-100 text-indigo-700 border-indigo-200"
                }`}
              >
                test
              </button>
              <span>{isRTL ? "أو" : "or"}</span>
              <button
                type="button"
                onClick={() => {
                  setToken("demo");
                  setFormError(null);
                }}
                className={`px-2 py-0.5 rounded font-mono font-bold text-[11px] border transition-colors cursor-pointer ${
                  isDark
                    ? "bg-indigo-950/60 hover:bg-indigo-900/60 text-indigo-300 border-indigo-800"
                    : "bg-indigo-50 hover:bg-indigo-100 text-indigo-700 border-indigo-200"
                }`}
              >
                demo
              </button>
            </div>
          </div>

          <button
            type="submit"
            disabled={!token.trim()}
            className="w-full py-2.5 px-4 bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white font-medium text-sm rounded-lg flex items-center justify-center gap-2 transition-all cursor-pointer shadow-sm"
          >
            <span>{isRTL ? "بدء الاختبار بالرمز" : "Start Exam with Token"}</span>
            {isRTL ? (
              <ArrowLeft className="w-4 h-4" />
            ) : (
              <ArrowRight className="w-4 h-4" />
            )}
          </button>
        </form>

        <div className="relative flex py-2 items-center">
          <div
            className={`flex-grow border-t ${
              isDark ? "border-slate-800" : "border-slate-200"
            }`}
          />
          <span className="flex-shrink mx-3 text-xs text-slate-400 uppercase">
            {isRTL ? "أو للتجربة الفورية" : "Or try instantly"}
          </span>
          <div
            className={`flex-grow border-t ${
              isDark ? "border-slate-800" : "border-slate-200"
            }`}
          />
        </div>

        <button
          type="button"
          onClick={handleStartDemo}
          className={`w-full mt-2 py-2.5 px-4 border font-medium text-sm rounded-lg flex items-center justify-center gap-2 transition-all cursor-pointer shadow-sm ${
            isDark
              ? "bg-emerald-950/50 hover:bg-emerald-900/50 text-emerald-300 border-emerald-800"
              : "bg-emerald-50 hover:bg-emerald-100 text-emerald-800 border-emerald-200"
          }`}
        >
          <Sparkles className="w-4 h-4 text-emerald-500" />
          <span>
            {isRTL
              ? "تجربة اختبار توضيحي مباشر (Demo)"
              : "Launch Interactive Demo Exam"}
          </span>
        </button>

        <div
          className={`mt-6 border rounded-lg p-3.5 text-xs space-y-1.5 ${
            isDark
              ? "bg-slate-950/80 border-slate-800 text-slate-400"
              : "bg-slate-50 border-slate-200 text-slate-600"
          }`}
        >
          <div
            className={`flex items-center gap-1.5 font-semibold ${
              isDark ? "text-slate-200" : "text-slate-700"
            }`}
          >
            <ShieldAlert className="w-4 h-4 text-amber-500 flex-shrink-0" />
            <span>
              {isRTL
                ? "نظام المراقبة الذكي (Smart Proctoring)"
                : "Smart Proctoring Protocol"}
            </span>
          </div>
          <p className="leading-relaxed">
            {isRTL
              ? "تُدار الاختبارات المراقبة في وضع ملء الشاشة. يتم توثيق مغادرة النافذة أو تبديل التبويبات أو استخدام الحافظة لضمان نزاهة التقييم."
              : "Proctored assessments run in fullscreen mode. Tab switching, window blur, and clipboard shortcuts are monitored to guarantee evaluation integrity."}
          </p>
        </div>
      </div>
    </main>
  );
}
