"use client";

import React, { useEffect, useState } from "react";
import { auth } from "@/lib/firebase";
import { onAuthStateChanged } from "firebase/auth";
import { useCompany } from "@/lib/i18n";
import { sanitizeExternalUrl } from "@/lib/formatters";
import {
  listenCompanyInterviews,
  listenCompanyApplicants,
  listenCompanyJobs,
  scheduleInterview,
  updateInterviewStatus,
  CompanyInterview,
  CompanyApplicant,
  CompanyJob,
} from "@/lib/company-portal-service";
import {
  Plus,
  Video,
  MapPin,
  Clock,
  ExternalLink,
  Loader2,
  X,
  Bot,
  CheckCircle2,
  XCircle,
  AlertCircle,
} from "lucide-react";

export default function CompanyInterviewsPage() {
  const { t, isRTL } = useCompany();

  const [interviews, setInterviews] = useState<CompanyInterview[]>([]);
  const [applicants, setApplicants] = useState<CompanyApplicant[]>([]);
  const [jobs, setJobs] = useState<CompanyJob[]>([]);
  const [loading, setLoading] = useState(true);

  // Schedule Modal
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [saving, setSaving] = useState(false);
  const [generatingAi, setGeneratingAi] = useState(false);
  const [selectedApplicationId, setSelectedApplicationId] = useState("");
  const [scheduledDate, setScheduledDate] = useState("");
  const [scheduledTime, setScheduledTime] = useState("");
  const [meetingType, setMeetingType] = useState<"ONLINE" | "IN_PERSON">("ONLINE");
  const [meetingUrl, setMeetingUrl] = useState("");
  const [location, setLocation] = useState("");
  const [notes, setNotes] = useState("");
  const [modalError, setModalError] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<{ type: "success" | "error"; text: string } | null>(null);

  useEffect(() => {
    let unsubInts: (() => void) | null = null;
    let unsubApps: (() => void) | null = null;
    let unsubJobs: (() => void) | null = null;

    const unsubAuth = onAuthStateChanged(auth, (user) => {
      if (unsubInts) unsubInts();
      if (unsubApps) unsubApps();
      if (unsubJobs) unsubJobs();

      if (user) {
        setLoading(true);
        unsubInts = listenCompanyInterviews(
          user.uid,
          (interviewsData) => {
            setInterviews(interviewsData);
            setLoading(false);
          },
          () => {
            setFeedback({ type: "error", text: t("error") });
            setLoading(false);
          }
        );
        unsubApps = listenCompanyApplicants(user.uid, (appsData) => {
          setApplicants(appsData);
          setSelectedApplicationId((prev) =>
            prev && appsData.some((a) => a.id === prev) ? prev : appsData[0]?.id || ""
          );
        });
        unsubJobs = listenCompanyJobs(user.uid, (jobsData) => {
          setJobs(jobsData);
        });
      } else {
        setLoading(false);
      }
    });

    return () => {
      unsubAuth();
      if (unsubInts) unsubInts();
      if (unsubApps) unsubApps();
      if (unsubJobs) unsubJobs();
    };
  }, []);

  const openScheduleModal = () => {
    setModalError(null);
    setSelectedApplicationId((prev) =>
      prev && applicants.some((a) => a.id === prev) ? prev : applicants[0]?.id || ""
    );
    setScheduledDate("");
    setScheduledTime("");
    setMeetingType("ONLINE");
    setMeetingUrl("");
    setLocation("");
    setNotes("");
    setIsModalOpen(true);
  };

  const handleGenerateAiQuestions = async () => {
    const cand = applicants.find((a) => a.id === selectedApplicationId) || applicants[0];
    const job = jobs.find((j) => j.id === cand?.jobId) || jobs[0];

    try {
      setGeneratingAi(true);
      setModalError(null);
      const idToken = await auth.currentUser?.getIdToken();
      const response = await fetch("/api/ai", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
        },
        body: JSON.stringify({
          action: "generateInterviewQuestions",
          payload: {
            applicationId: cand?.id,
            candidateName: cand?.candidateName || "Candidate",
            jobTitle: cand?.jobTitle || job?.title || "Software Engineer",
            candidateSkills: cand?.aiParsedCv?.matchedSkills || job?.requiredSkills || [],
            missingSkills: cand?.aiParsedCv?.missingSkills || [],
          },
        }),
      });
      if (!response.ok) {
        const errBody = await response.json().catch(() => ({}));
        throw new Error(errBody?.error || t("error"));
      }
      const resData = await response.json();

      const qList = resData?.interviewQuestions || resData?.questions;
      if (qList && Array.isArray(qList)) {
        const text = qList
          .map((q: any, i: number) => `${i + 1}. [${q.category || "TECH"}] ${q.question || q}`)
          .join("\n\n");
        setNotes((prev) => (prev ? `${prev}\n\n--- AI Suggested Questions ---\n${text}` : text));
        setFeedback({
          type: "success",
          text: isRTL
            ? "تم توليد وتضمين أسئلة المقابلة بالذكاء الاصطناعي بنجاح!"
            : "AI Interview Questions generated and added!",
        });
      } else {
        throw new Error(isRTL ? "تعذر توليد الأسئلة من الخادم." : "No interview questions returned.");
      }
    } catch (err: any) {
      console.error("AI error:", err);
      setModalError(err.message || t("error"));
    } finally {
      setGeneratingAi(false);
    }
  };

  const handleSchedule = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!auth.currentUser) return;
    setModalError(null);

    const cand = applicants.find((a) => a.id === selectedApplicationId);
    if (!cand) {
      setModalError(isRTL ? "يرجى اختيار مرشح صالح للمقابلة." : "Please select a valid applicant.");
      return;
    }
    if (!scheduledDate || !scheduledTime) {
      setModalError(isRTL ? "يرجى تحديد تاريخ ووقت المقابلة." : "Please select interview date and time.");
      return;
    }
    if (meetingType === "IN_PERSON" && !location.trim()) {
      setModalError(isRTL ? "يرجى إدخال عنوان مكان المقابلة الحضورية." : "Please enter the on-site interview location.");
      return;
    }

    const cleanMeetingUrl =
      meetingType === "ONLINE" && meetingUrl.trim() ? sanitizeExternalUrl(meetingUrl) : undefined;
    if (meetingType === "ONLINE" && meetingUrl.trim() && !cleanMeetingUrl) {
      setModalError(
        isRTL
          ? "رابط الاجتماع غير صالح (يجب أن يبدأ بـ http أو https)."
          : "Please enter a valid http(s) meeting link."
      );
      return;
    }

    const job = jobs.find((j) => j.id === cand.jobId);

    try {
      setSaving(true);
      await scheduleInterview({
        applicationId: cand.id,
        companyId: auth.currentUser.uid,
        candidateId: cand.candidateId,
        candidateName: cand.candidateName || "Candidate",
        candidateEmail: cand.candidateEmail || undefined,
        jobId: cand.jobId,
        jobTitle: cand.jobTitle || job?.title || "Position",
        scheduledAt: `${scheduledDate} ${scheduledTime}`,
        meetingType: meetingType,
        meetingUrl: cleanMeetingUrl || undefined,
        location: meetingType === "IN_PERSON" ? location.trim() : undefined,
        notes: notes.trim(),
        status: "CONFIRMED",
      });

      setIsModalOpen(false);
      setFeedback({ type: "success", text: t("success") });
    } catch (err: any) {
      console.error(err);
      setModalError(err?.message || t("error"));
    } finally {
      setSaving(false);
    }
  };

  const handleUpdateStatus = async (interviewId: string, newStatus: string) => {
    if (
      newStatus === "CANCELLED" &&
      !window.confirm(isRTL ? "هل أنت متأكد من إلغاء هذه المقابلة؟" : "Are you sure you want to cancel this interview?")
    ) {
      return;
    }
    try {
      await updateInterviewStatus(interviewId, newStatus);
      setInterviews((prev) =>
        prev.map((i) => (i.id === interviewId ? { ...i, status: newStatus as any } : i))
      );
      setFeedback({ type: "success", text: t("success") });
    } catch (err: any) {
      console.error(err);
      setFeedback({ type: "error", text: err?.message || t("error") });
    }
  };

  const getInterviewStatusLabel = (status: string) => {
    switch ((status || "").toUpperCase()) {
      case "COMPLETED":
        return isRTL ? "مكتملة" : "Completed";
      case "CANCELLED":
        return isRTL ? "ملغاة" : "Cancelled";
      case "DECLINED":
        return isRTL ? "مرفوضة من المرشح" : "Declined";
      case "PENDING_CANDIDATE":
        return isRTL ? "بانتظار تأكيد المرشح" : "Pending Candidate";
      case "SCHEDULED":
        return isRTL ? "مجدولة" : "Scheduled";
      default:
        return isRTL ? "مؤكدة" : "Confirmed";
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 dark:text-white tracking-tight">{t("interviewsTitle")}</h1>
          <p className="text-sm text-slate-500 dark:text-slate-400 mt-1">{t("interviewsSubtitle")}</p>
        </div>
        <button
          onClick={openScheduleModal}
          className="inline-flex items-center gap-2 px-4 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold rounded-xl shadow-lg shadow-indigo-600/30 transition-all hover:scale-[1.02] cursor-pointer"
        >
          <Plus className="w-4 h-4" />
          <span>{t("scheduleNewInterviewBtn")}</span>
        </button>
      </div>

      {/* Floating Action Toast */}
      {feedback && (
        <div
          className={`fixed top-20 ${
            isRTL ? "left-6" : "right-6"
          } z-[99999] max-w-md w-full p-4 rounded-xl text-sm font-medium border shadow-2xl flex items-center justify-between gap-3 ${
            feedback.type === "success"
              ? "bg-emerald-50 dark:bg-emerald-950 text-emerald-800 dark:text-emerald-200 border-emerald-300 dark:border-emerald-700"
              : "bg-rose-50 dark:bg-rose-950 text-rose-800 dark:text-rose-200 border-rose-300 dark:border-rose-700"
          }`}
        >
          <span>{feedback.text}</span>
          <button onClick={() => setFeedback(null)} className="text-xs font-bold uppercase hover:underline flex-shrink-0 cursor-pointer">
            {t("close")}
          </button>
        </div>
      )}

      {/* Interviews Table */}
      <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm overflow-hidden">
        {loading ? (
          <div className="py-24 flex flex-col items-center justify-center gap-3">
            <div className="w-8 h-8 border-4 border-indigo-600 dark:border-indigo-400 border-t-transparent rounded-full animate-spin"></div>
            <p className="text-sm text-slate-500 dark:text-slate-400">{t("loading")}</p>
          </div>
        ) : interviews.length === 0 ? (
          <div className="py-20 text-center text-slate-500 dark:text-slate-400 text-sm">
            {t("noData")}
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse" dir={isRTL ? "rtl" : "ltr"}>
              <thead>
                <tr className="bg-slate-50 dark:bg-slate-800/60 border-b border-slate-200/80 dark:border-slate-800 text-slate-600 dark:text-slate-300 text-[11px] uppercase tracking-wider font-semibold">
                  <th className="py-3.5 px-4">{t("interviewCandidateCol")}</th>
                  <th className="py-3.5 px-4">{t("interviewJobCol")}</th>
                  <th className="py-3.5 px-4">{t("interviewTimeCol")}</th>
                  <th className="py-3.5 px-4">{t("interviewTypeCol")}</th>
                  <th className="py-3.5 px-4">{t("status")}</th>
                  <th className={`py-3.5 px-4 ${isRTL ? "text-left" : "text-right"}`}>{t("actions")}</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 dark:divide-slate-800 text-sm">
                {interviews.map((item) => (
                  <tr key={item.id} className="hover:bg-slate-50/70 dark:hover:bg-slate-800/40 transition-colors">
                    <td className="py-4 px-4 font-bold text-slate-900 dark:text-white">
                      {item.candidateName}
                      {item.candidateEmail && (
                        <div className="text-xs font-normal text-slate-500 dark:text-slate-400">{item.candidateEmail}</div>
                      )}
                    </td>
                    <td className="py-4 px-4 text-xs font-semibold text-slate-700 dark:text-slate-300">
                      {item.jobTitle}
                    </td>
                    <td className="py-4 px-4 whitespace-nowrap text-xs text-slate-700 dark:text-slate-300">
                      <div className="flex items-center gap-1.5 font-semibold">
                        <Clock className="w-3.5 h-3.5 text-slate-400" />
                        <span>{item.scheduledAt}</span>
                      </div>
                    </td>
                    <td className="py-4 px-4 whitespace-nowrap text-xs">
                      {item.meetingType === "ONLINE" ? (
                        <div className="flex items-center gap-2 text-indigo-600 dark:text-indigo-400">
                          <Video className="w-4 h-4 text-indigo-500" />
                          {(() => {
                            const safeMeetingUrl = sanitizeExternalUrl(item.meetingUrl);
                            return safeMeetingUrl ? (
                              <a
                                href={safeMeetingUrl}
                                target="_blank"
                                rel="noopener noreferrer"
                                className="font-semibold hover:underline inline-flex items-center gap-1"
                              >
                                <span>{isRTL ? "رابط الاجتماع" : "Join Meeting"}</span>
                                <ExternalLink className="w-3 h-3" />
                              </a>
                            ) : (
                              <span>Online</span>
                            );
                          })()}
                        </div>
                      ) : (
                        <div className="flex items-center gap-1 text-slate-700 dark:text-slate-300">
                          <MapPin className="w-3.5 h-3.5 text-slate-400" />
                          <span>{item.location || "On-site"}</span>
                        </div>
                      )}
                    </td>
                    <td className="py-4 px-4 whitespace-nowrap">
                      <span
                        className={`px-2.5 py-0.5 rounded-full text-xs font-semibold border ${
                          item.status === "COMPLETED"
                            ? "bg-emerald-100 dark:bg-emerald-950/60 text-emerald-800 dark:text-emerald-300 border-emerald-200 dark:border-emerald-800"
                            : item.status === "CANCELLED" || item.status === "DECLINED"
                            ? "bg-rose-100 dark:bg-rose-950/60 text-rose-800 dark:text-rose-300 border-rose-200 dark:border-rose-800"
                            : "bg-purple-100 dark:bg-purple-950/60 text-purple-800 dark:text-purple-300 border-purple-200 dark:border-purple-800"
                        }`}
                      >
                        {getInterviewStatusLabel(item.status)}
                      </span>
                    </td>
                    <td className={`py-4 px-4 ${isRTL ? "text-left" : "text-right"} whitespace-nowrap`}>
                      <div className="inline-flex items-center gap-1.5">
                        {item.status !== "COMPLETED" && item.status !== "CANCELLED" && item.status !== "DECLINED" && (
                          <>
                            <button
                              onClick={() => handleUpdateStatus(item.id, "COMPLETED")}
                              className="px-2.5 py-1 text-xs font-semibold text-emerald-700 dark:text-emerald-300 bg-emerald-50 dark:bg-emerald-950/60 hover:bg-emerald-100 rounded-md transition-colors inline-flex items-center gap-1 cursor-pointer"
                            >
                              <CheckCircle2 className="w-3.5 h-3.5" />
                              <span>{isRTL ? "مكتملة" : "Complete"}</span>
                            </button>
                            <button
                              onClick={() => handleUpdateStatus(item.id, "CANCELLED")}
                              className="px-2.5 py-1 text-xs font-semibold text-rose-700 dark:text-rose-300 bg-rose-50 dark:bg-rose-950/60 hover:bg-rose-100 rounded-md transition-colors inline-flex items-center gap-1 cursor-pointer"
                            >
                              <XCircle className="w-3.5 h-3.5" />
                              <span>{isRTL ? "إلغاء" : "Cancel"}</span>
                            </button>
                          </>
                        )}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Schedule Interview Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white dark:bg-slate-900 rounded-2xl max-w-lg w-full p-6 sm:p-8 shadow-2xl border border-slate-200 dark:border-slate-800 my-8">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100 dark:border-slate-800 mb-6">
              <div>
                <h2 className="text-xl font-bold text-slate-900 dark:text-white">{t("scheduleNewInterviewBtn")}</h2>
                <p className="text-xs text-slate-500 dark:text-slate-400">{t("interviewsSubtitle")}</p>
              </div>
              <button
                onClick={() => setIsModalOpen(false)}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSchedule} className="space-y-4">
              {modalError && (
                <div className="p-3 rounded-xl bg-rose-50 dark:bg-rose-950/60 border border-rose-200 dark:border-rose-800 text-rose-700 dark:text-rose-300 text-xs font-medium flex items-center gap-2">
                  <AlertCircle className="w-4 h-4 flex-shrink-0" />
                  <span>{modalError}</span>
                </div>
              )}

              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("offerCandidateLabel")}</label>
                <select
                  required
                  value={selectedApplicationId}
                  onChange={(e) => setSelectedApplicationId(e.target.value)}
                  className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                >
                  {applicants.length === 0 ? (
                    <option value="">{t("noData")}</option>
                  ) : (
                    applicants.map((a) => (
                      <option key={a.id} value={a.id}>
                        {a.candidateName} ({a.jobTitle})
                      </option>
                    ))
                  )}
                </select>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("interviewDateLabel")}</label>
                  <input
                    type="date"
                    required
                    value={scheduledDate}
                    onChange={(e) => setScheduledDate(e.target.value)}
                    className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("interviewTimeLabel")}</label>
                  <input
                    type="time"
                    required
                    value={scheduledTime}
                    onChange={(e) => setScheduledTime(e.target.value)}
                    className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("interviewTypeLabel")}</label>
                <select
                  value={meetingType}
                  onChange={(e) => setMeetingType(e.target.value as any)}
                  className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                >
                  <option value="ONLINE">{isRTL ? "مقابلة فيديو عبر الإنترنت (Jitsi / Zoom)" : "Video Call (Online)"}</option>
                  <option value="IN_PERSON">{isRTL ? "مقابلة حضورية في مقر الشركة" : "In-Person (On-site)"}</option>
                </select>
              </div>

              {meetingType === "ONLINE" ? (
                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("meetingUrlLabel")}</label>
                  <input
                    type="url"
                    value={meetingUrl}
                    onChange={(e) => setMeetingUrl(e.target.value)}
                    placeholder={isRTL ? "اختياري — يُنشأ رابط غرفة تلقائياً إذا تُرك فارغاً" : "Optional — auto-generated room if blank"}
                    className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                  />
                </div>
              ) : (
                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("meetingLocationLabel")}</label>
                  <input
                    type="text"
                    required={meetingType === "IN_PERSON"}
                    value={location}
                    onChange={(e) => setLocation(e.target.value)}
                    placeholder="Company HQ - Floor 3 - Meeting Room A"
                    className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                  />
                </div>
              )}

              <div>
                <div className="flex items-center justify-between mb-1">
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300">{t("interviewNotesLabel")}</label>
                  <button
                    type="button"
                    onClick={handleGenerateAiQuestions}
                    disabled={generatingAi || applicants.length === 0}
                    className="text-[11px] font-semibold text-indigo-600 dark:text-indigo-400 hover:underline flex items-center gap-1 disabled:opacity-50 cursor-pointer"
                  >
                    {generatingAi ? <Loader2 className="w-3 h-3 animate-spin" /> : <Bot className="w-3 h-3" />}
                    <span>{t("aiGenerateInterviewQuestionsBtn")}</span>
                  </button>
                </div>
                <textarea
                  rows={3}
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="Interview agenda, key topics to discuss, or AI suggested questions..."
                  className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                />
              </div>

              <div className="pt-4 flex items-center justify-end gap-3 border-t border-slate-100 dark:border-slate-800">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2 text-xs font-semibold text-slate-600 dark:text-slate-300 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-xl"
                >
                  {t("cancel")}
                </button>
                <button
                  type="submit"
                  disabled={saving || applicants.length === 0}
                  className="px-5 py-2.5 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white text-xs font-semibold rounded-xl shadow-lg shadow-indigo-600/30 flex items-center gap-2 cursor-pointer"
                >
                  {saving && <Loader2 className="w-4 h-4 animate-spin" />}
                  <span>{t("confirmScheduleBtn")}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
