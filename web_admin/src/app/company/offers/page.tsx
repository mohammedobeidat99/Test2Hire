"use client";

import React, { useEffect, useState } from "react";
import { auth } from "@/lib/firebase";
import { onAuthStateChanged } from "firebase/auth";
import { useCompany } from "@/lib/i18n";
import { CURRENCY_OPTIONS } from "@/lib/formatters";
import {
  listenCompanyOffers,
  listenCompanyApplicants,
  listenCompanyJobs,
  sendJobOffer,
  updateOfferStatus,
  CompanyOffer,
  CompanyApplicant,
  CompanyJob,
} from "@/lib/company-portal-service";
import {
  Plus,
  Loader2,
  X,
  XCircle,
  AlertCircle,
} from "lucide-react";

export default function CompanyOffersPage() {
  const { t, isRTL, language } = useCompany();

  const [offers, setOffers] = useState<CompanyOffer[]>([]);
  const [applicants, setApplicants] = useState<CompanyApplicant[]>([]);
  const [jobs, setJobs] = useState<CompanyJob[]>([]);
  const [loading, setLoading] = useState(true);

  // Send Offer Modal
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [sending, setSending] = useState(false);
  const [selectedApplicationId, setSelectedApplicationId] = useState("");
  const [salary, setSalary] = useState("");
  const [currency, setCurrency] = useState("JOD");
  const [salaryPeriod, setSalaryPeriod] = useState<"MONTHLY" | "ANNUAL">("MONTHLY");
  const [startDate, setStartDate] = useState("");
  const [expirationDate, setExpirationDate] = useState("");
  const [notes, setNotes] = useState("");
  const [modalError, setModalError] = useState<string | null>(null);
  const [feedback, setFeedback] = useState<{ type: "success" | "error"; text: string } | null>(null);

  useEffect(() => {
    let unsubOffers: (() => void) | null = null;
    let unsubApps: (() => void) | null = null;
    let unsubJobs: (() => void) | null = null;

    const unsubAuth = onAuthStateChanged(auth, (user) => {
      if (unsubOffers) unsubOffers();
      if (unsubApps) unsubApps();
      if (unsubJobs) unsubJobs();

      if (user) {
        setLoading(true);
        unsubOffers = listenCompanyOffers(
          user.uid,
          (offersData) => {
            setOffers(offersData);
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
      if (unsubOffers) unsubOffers();
      if (unsubApps) unsubApps();
      if (unsubJobs) unsubJobs();
    };
  }, []);

  const openOfferModal = () => {
    setModalError(null);
    setSelectedApplicationId((prev) =>
      prev && applicants.some((a) => a.id === prev) ? prev : applicants[0]?.id || ""
    );
    setSalary("");
    setCurrency("JOD");
    setSalaryPeriod("MONTHLY");
    setStartDate("");
    setExpirationDate("");
    setNotes("");
    setIsModalOpen(true);
  };

  const handleSendOffer = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!auth.currentUser) return;
    setModalError(null);

    const cand = applicants.find((a) => a.id === selectedApplicationId);
    if (!cand) {
      setModalError(isRTL ? "يرجى اختيار مرشح صالح." : "Please select a valid candidate.");
      return;
    }

    const salaryNum = Number(salary);
    if (Number.isNaN(salaryNum) || salaryNum <= 0) {
      setModalError(isRTL ? "يرجى إدخال قيمة راتب موجبة صحيحة." : "Please enter a valid positive salary amount.");
      return;
    }

    if (!startDate || !expirationDate) {
      setModalError(isRTL ? "يرجى تحديد تاريخ المباشرة وتاريخ انتهاء العرض." : "Please select both start date and offer expiration date.");
      return;
    }

    const job = jobs.find((j) => j.id === cand.jobId);

    try {
      setSending(true);
      await sendJobOffer({
        applicationId: cand.id,
        companyId: auth.currentUser.uid,
        candidateId: cand.candidateId,
        candidateName: cand.candidateName || "Candidate",
        candidateEmail: cand.candidateEmail || undefined,
        jobId: cand.jobId,
        jobTitle: cand.jobTitle || job?.title || "Position",
        salary: salaryNum,
        currency,
        salaryPeriod,
        startDate,
        expirationDate,
        notes: notes.trim(),
        status: "PENDING_CANDIDATE",
      });

      setIsModalOpen(false);
      setFeedback({ type: "success", text: t("success") });
    } catch (err: any) {
      console.error(err);
      setModalError(err?.message || t("error"));
    } finally {
      setSending(false);
    }
  };

  const handleWithdrawOffer = async (offerId: string) => {
    if (!window.confirm(isRTL ? "هل أنت متأكد من سحب هذا العرض الوظيفي؟" : "Are you sure you want to withdraw this job offer?")) return;
    try {
      await updateOfferStatus(offerId, "WITHDRAWN");
      setOffers((prev) =>
        prev.map((o) => (o.id === offerId ? { ...o, status: "WITHDRAWN" } : o))
      );
      setFeedback({ type: "success", text: t("success") });
    } catch (err: any) {
      console.error(err);
      setFeedback({ type: "error", text: err?.message || t("error") });
    }
  };

  const getOfferStatusLabel = (status: string) => {
    switch ((status || "").toUpperCase()) {
      case "ACCEPTED":
        return isRTL ? "مقبول" : "Accepted";
      case "DECLINED":
        return isRTL ? "مرفوض" : "Declined";
      case "WITHDRAWN":
        return isRTL ? "مسحوب" : "Withdrawn";
      case "EXPIRED":
        return isRTL ? "منتهي الصلاحية" : "Expired";
      default:
        return isRTL ? "بانتظار رد المرشح" : "Pending Candidate";
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 dark:text-white tracking-tight">{t("offersTitle")}</h1>
          <p className="text-sm text-slate-500 dark:text-slate-400 mt-1">{t("offersSubtitle")}</p>
        </div>
        <button
          onClick={openOfferModal}
          className="inline-flex items-center gap-2 px-4 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold rounded-xl shadow-lg shadow-indigo-600/30 transition-all hover:scale-[1.02] cursor-pointer"
        >
          <Plus className="w-4 h-4" />
          <span>{t("sendOfferBtn")}</span>
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

      {/* Offers Table */}
      <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm overflow-hidden">
        {loading ? (
          <div className="py-24 flex flex-col items-center justify-center gap-3">
            <div className="w-8 h-8 border-4 border-indigo-600 dark:border-indigo-400 border-t-transparent rounded-full animate-spin"></div>
            <p className="text-sm text-slate-500 dark:text-slate-400">{t("loading")}</p>
          </div>
        ) : offers.length === 0 ? (
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
                  <th className="py-3.5 px-4">{t("offerSalaryCol")}</th>
                  <th className="py-3.5 px-4">{t("offerStartDateCol")}</th>
                  <th className="py-3.5 px-4">{t("status")}</th>
                  <th className={`py-3.5 px-4 ${isRTL ? "text-left" : "text-right"}`}>{t("actions")}</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 dark:divide-slate-800 text-sm">
                {offers.map((offer) => (
                  <tr key={offer.id} className="hover:bg-slate-50/70 dark:hover:bg-slate-800/40 transition-colors">
                    <td className="py-4 px-4 font-bold text-slate-900 dark:text-white">
                      {offer.candidateName}
                      {offer.candidateEmail && (
                        <div className="text-xs font-normal text-slate-500 dark:text-slate-400">{offer.candidateEmail}</div>
                      )}
                    </td>
                    <td className="py-4 px-4 text-xs font-semibold text-slate-700 dark:text-slate-300">
                      {offer.jobTitle}
                    </td>
                    <td className="py-4 px-4 whitespace-nowrap text-xs font-bold text-emerald-700 dark:text-emerald-400">
                      {offer.salary.toLocaleString()} {offer.currency}{" "}
                      <span className="text-[10px] font-medium text-slate-500 dark:text-slate-400">
                        / {offer.salaryPeriod === "ANNUAL" ? (isRTL ? "سنوياً" : "Annual") : (isRTL ? "شهرياً" : "Monthly")}
                      </span>
                    </td>
                    <td className="py-4 px-4 whitespace-nowrap text-xs text-slate-600 dark:text-slate-300">
                      {offer.startDate || "-"}
                    </td>
                    <td className="py-4 px-4 whitespace-nowrap">
                      <span
                        className={`px-2.5 py-0.5 rounded-full text-xs font-semibold border ${
                          offer.status === "ACCEPTED"
                            ? "bg-emerald-100 dark:bg-emerald-950/60 text-emerald-800 dark:text-emerald-300 border-emerald-200 dark:border-emerald-800"
                            : offer.status === "DECLINED" || offer.status === "WITHDRAWN"
                            ? "bg-rose-100 dark:bg-rose-950/60 text-rose-800 dark:text-rose-300 border-rose-200 dark:border-rose-800"
                            : "bg-amber-100 dark:bg-amber-950/60 text-amber-800 dark:text-amber-300 border-amber-200 dark:border-amber-800"
                        }`}
                      >
                        {getOfferStatusLabel(offer.status)}
                      </span>
                    </td>
                    <td className={`py-4 px-4 ${isRTL ? "text-left" : "text-right"} whitespace-nowrap`}>
                      {(offer.status === "PENDING_CANDIDATE" || offer.status === "SENT") && (
                        <button
                          onClick={() => handleWithdrawOffer(offer.id)}
                          className="px-2.5 py-1 text-xs font-semibold text-rose-700 dark:text-rose-300 bg-rose-50 dark:bg-rose-950/60 hover:bg-rose-100 rounded-md transition-colors inline-flex items-center gap-1 cursor-pointer"
                        >
                          <XCircle className="w-3.5 h-3.5" />
                          <span>{isRTL ? "سحب العرض" : "Withdraw"}</span>
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Send Offer Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white dark:bg-slate-900 rounded-2xl max-w-lg w-full p-6 sm:p-8 shadow-2xl border border-slate-200 dark:border-slate-800 my-8">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100 dark:border-slate-800 mb-6">
              <div>
                <h2 className="text-xl font-bold text-slate-900 dark:text-white">{t("sendOfferBtn")}</h2>
                <p className="text-xs text-slate-500 dark:text-slate-400">{t("offersSubtitle")}</p>
              </div>
              <button
                onClick={() => setIsModalOpen(false)}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSendOffer} className="space-y-4">
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
                        {a.candidateName} - ({a.jobTitle})
                      </option>
                    ))
                  )}
                </select>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("offerSalaryLabel")}</label>
                  <input
                    type="number"
                    min="1"
                    required
                    value={salary}
                    onChange={(e) => setSalary(e.target.value)}
                    placeholder="1500"
                    className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("offerCurrencyLabel")}</label>
                  <select
                    value={currency}
                    onChange={(e) => setCurrency(e.target.value)}
                    className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                  >
                    {CURRENCY_OPTIONS.map((c) => (
                      <option key={c.code} value={c.code}>
                        {language === "ar" ? c.labelAr : c.labelEn}
                      </option>
                    ))}
                  </select>
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">
                    {isRTL ? "دورة الراتب" : "Salary Period"}
                  </label>
                  <select
                    value={salaryPeriod}
                    onChange={(e) => setSalaryPeriod(e.target.value as "MONTHLY" | "ANNUAL")}
                    className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                  >
                    <option value="MONTHLY">{isRTL ? "شهري (Monthly)" : "Monthly"}</option>
                    <option value="ANNUAL">{isRTL ? "سنوي (Annual)" : "Annual"}</option>
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("offerStartDateLabel")}</label>
                  <input
                    type="date"
                    required
                    value={startDate}
                    onChange={(e) => setStartDate(e.target.value)}
                    className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("offerExpireDateLabel")}</label>
                  <input
                    type="date"
                    required
                    value={expirationDate}
                    onChange={(e) => setExpirationDate(e.target.value)}
                    className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("offerNotesLabel")}</label>
                <textarea
                  rows={3}
                  value={notes}
                  onChange={(e) => setNotes(e.target.value)}
                  placeholder="Medical insurance, allowances, bonus structure..."
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
                  disabled={sending || applicants.length === 0}
                  className="px-5 py-2.5 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white text-xs font-semibold rounded-xl shadow-lg shadow-indigo-600/30 flex items-center gap-2 cursor-pointer"
                >
                  {sending && <Loader2 className="w-4 h-4 animate-spin" />}
                  <span>{t("sendOfferSubmit")}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
