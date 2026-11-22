"use client";

import React, { useEffect, useState, useMemo } from "react";
import Link from "next/link";
import { auth } from "@/lib/firebase";
import { onAuthStateChanged } from "firebase/auth";
import { useCompany } from "@/lib/i18n";
import { CURRENCY_OPTIONS } from "@/lib/formatters";
import {
  fetchCompanyJobs,
  listenCompanyJobs,
  listenCompanyApplicants,
  createCompanyJob,
  updateCompanyJob,
  deleteCompanyJob,
  fetchCompanyExams,
  CompanyJob,
  CompanyExam,
  CompanyApplicant,
} from "@/lib/company-portal-service";
import {
  Plus,
  Search,
  Users,
  MapPin,
  Trash2,
  Edit2,
  Loader2,
  X,
  Coins,
  AlertCircle,
} from "lucide-react";

export default function CompanyJobsPage() {
  const { t, isRTL, language, companyInfo } = useCompany();
  const isCompanyApproved =
    (companyInfo?.verificationStatus || "PENDING").toUpperCase() === "APPROVED";

  const [rawJobs, setRawJobs] = useState<CompanyJob[]>([]);
  const [applicants, setApplicants] = useState<CompanyApplicant[]>([]);
  const [exams, setExams] = useState<CompanyExam[]>([]);
  const [loading, setLoading] = useState(true);
  const [searchQuery, setSearchQuery] = useState("");
  const [statusFilter, setStatusFilter] = useState<string>("ALL");

  // Create / Edit Job Modal state
  const [isModalOpen, setIsModalOpen] = useState(false);
  const [editingJobId, setEditingJobId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [formTitle, setFormTitle] = useState("");
  const [formDescription, setFormDescription] = useState("");
  const [formJobType, setFormJobType] = useState("FULL_TIME");
  const [formWorkplaceType, setFormWorkplaceType] = useState("HYBRID");
  const [formExperienceLevel, setFormExperienceLevel] = useState("MID");
  const [formCity, setFormCity] = useState("Amman");
  const [formCountry, setFormCountry] = useState("Jordan");
  const [formSalaryMin, setFormSalaryMin] = useState("");
  const [formSalaryMax, setFormSalaryMax] = useState("");
  const [formCurrency, setFormCurrency] = useState("JOD");
  const [formSkills, setFormSkills] = useState("");
  const [formExamId, setFormExamId] = useState("");
  const [modalError, setModalError] = useState<string | null>(null);
  const [actionMessage, setActionMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);

  const loadData = async (uid?: string) => {
    const targetUid = uid || auth.currentUser?.uid;
    if (!targetUid) return;
    try {
      const examsData = await fetchCompanyExams(targetUid);
      setExams(examsData);
    } catch (err: any) {
      console.error("Failed to load company exams:", err);
    }
  };

  useEffect(() => {
    let unsubJobs: (() => void) | null = null;
    let unsubApps: (() => void) | null = null;

    const unsubAuth = onAuthStateChanged(auth, (user) => {
      if (unsubJobs) unsubJobs();
      if (unsubApps) unsubApps();

      if (user) {
        setLoading(true);
        loadData(user.uid);
        unsubJobs = listenCompanyJobs(
          user.uid,
          (jobsData) => {
            setRawJobs(jobsData);
            setLoading(false);
          },
          () => {
            setActionMessage({ type: "error", text: t("error") });
            setLoading(false);
          }
        );
        unsubApps = listenCompanyApplicants(user.uid, (appsData) => {
          setApplicants(appsData);
        });
      } else {
        setLoading(false);
      }
    });

    return () => {
      unsubAuth();
      if (unsubJobs) unsubJobs();
      if (unsubApps) unsubApps();
    };
  }, []);

  const jobs = useMemo(() => {
    const countsByJob: Record<string, number> = {};
    applicants.forEach((a) => {
      if (a.jobId && a.status !== "WITHDRAWN") {
        countsByJob[a.jobId] = (countsByJob[a.jobId] || 0) + 1;
      }
    });
    return rawJobs.map((j) => ({
      ...j,
      applicantsCount: countsByJob[j.id] ?? j.applicantsCount ?? 0,
    }));
  }, [rawJobs, applicants]);

  const filteredJobs = useMemo(() => {
    return jobs.filter((j) => {
      const q = searchQuery.toLowerCase();
      const matchSearch =
        j.title.toLowerCase().includes(q) ||
        j.requiredSkills.some((s) => s.toLowerCase().includes(q)) ||
        (j.location?.city || "").toLowerCase().includes(q);
      const matchStatus = statusFilter === "ALL" || j.status === statusFilter;
      return matchSearch && matchStatus;
    });
  }, [jobs, searchQuery, statusFilter]);

  const openCreateModal = () => {
    setEditingJobId(null);
    setModalError(null);
    resetForm();
    setIsModalOpen(true);
  };

  const openEditModal = (job: CompanyJob) => {
    setEditingJobId(job.id);
    setModalError(null);
    setFormTitle(job.title);
    setFormDescription(job.description);
    setFormJobType(job.jobType || "FULL_TIME");
    setFormWorkplaceType(job.workplaceType || "HYBRID");
    setFormExperienceLevel(job.experienceLevel || "MID");
    setFormCity(job.location?.city || "Amman");
    setFormCountry(job.location?.country || "Jordan");
    setFormSalaryMin(job.salaryRange?.min !== undefined && job.salaryRange?.min !== null ? String(job.salaryRange.min) : "");
    setFormSalaryMax(job.salaryRange?.max !== undefined && job.salaryRange?.max !== null ? String(job.salaryRange.max) : "");
    setFormCurrency(job.salaryRange?.currency || "JOD");
    setFormSkills((job.requiredSkills || []).join(", "));
    setFormExamId(job.examId || "");
    setIsModalOpen(true);
  };

  const handleSaveJob = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!auth.currentUser) return;
    setModalError(null);

    if (!formTitle.trim() || !formDescription.trim()) {
      setModalError(isRTL ? "يرجى إدخال مسمى الوظيفة ووصفها." : "Please provide both job title and description.");
      return;
    }

    const hasMin = formSalaryMin.trim() !== "";
    const hasMax = formSalaryMax.trim() !== "";
    const minNum = hasMin ? Number(formSalaryMin) : undefined;
    const maxNum = hasMax ? Number(formSalaryMax) : undefined;

    if ((minNum !== undefined && (Number.isNaN(minNum) || minNum < 0)) || (maxNum !== undefined && (Number.isNaN(maxNum) || maxNum < 0))) {
      setModalError(isRTL ? "يرجى إدخال قيم رواتب صحيحة غير سالبة." : "Please enter valid non-negative salary numbers.");
      return;
    }

    if (minNum !== undefined && maxNum !== undefined && maxNum < minNum) {
      setModalError(isRTL ? "الحد الأقصى للراتب يجب أن يكون أكبر من أو يساوي الحد الأدنى." : "Maximum salary must be greater than or equal to minimum salary.");
      return;
    }

    try {
      setSaving(true);
      const skillsArray = formSkills
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean);

      const resolvedSalaryRange =
        minNum !== undefined || maxNum !== undefined
          ? {
              min: minNum ?? maxNum,
              max: maxNum ?? minNum,
              currency: formCurrency || "JOD",
              isDisclosed: true,
            }
          : null;

      if (editingJobId) {
        await updateCompanyJob(editingJobId, {
          title: formTitle.trim(),
          description: formDescription.trim(),
          jobType: formJobType,
          workplaceType: formWorkplaceType,
          experienceLevel: formExperienceLevel,
          location: {
            city: formCity.trim(),
            country: formCountry.trim(),
          },
          salaryRange: resolvedSalaryRange,
          requiredSkills: skillsArray,
          examId: formExamId || null,
        });
        setActionMessage({ type: "success", text: t("success") });
      } else {
        const initialStatus = isCompanyApproved ? "PUBLISHED" : "DRAFT";
        await createCompanyJob({
          companyId: auth.currentUser.uid,
          companyName: companyInfo?.name || auth.currentUser.displayName || "Hiring Company",
          title: formTitle.trim(),
          description: formDescription.trim(),
          jobType: formJobType,
          workplaceType: formWorkplaceType,
          experienceLevel: formExperienceLevel,
          location: {
            city: formCity.trim(),
            country: formCountry.trim(),
          },
          salaryRange: resolvedSalaryRange || undefined,
          requiredSkills: skillsArray,
          status: initialStatus,
          applicantsCount: 0,
          examId: formExamId || undefined,
        });
        setActionMessage({
          type: "success",
          text: isCompanyApproved
            ? t("success")
            : isRTL
            ? "تم حفظ الوظيفة كمسودة لأن حساب الشركة بانتظار اعتماد الإدارة."
            : "Job saved as Draft while your company verification is pending admin approval.",
        });
      }

      setIsModalOpen(false);
      setEditingJobId(null);
      resetForm();
    } catch (err: any) {
      console.error("Error saving job:", err);
      setModalError(err.message || t("error"));
    } finally {
      setSaving(false);
    }
  };

  const handleStatusToggle = async (jobId: string, newStatus: any) => {
    if (newStatus === "PUBLISHED" && !isCompanyApproved) {
      setActionMessage({
        type: "error",
        text: isRTL
          ? "لا يمكن نشر الوظيفة قبل اعتماد حساب الشركة من إدارة المنصة."
          : "Jobs cannot be published until your company verification is approved by an administrator.",
      });
      return;
    }
    try {
      await updateCompanyJob(jobId, { status: newStatus });
      setRawJobs((prev) =>
        prev.map((j) => (j.id === jobId ? { ...j, status: newStatus } : j))
      );
      setActionMessage({ type: "success", text: t("success") });
    } catch (err: any) {
      console.error(err);
      setActionMessage({ type: "error", text: t("error") });
    }
  };

  const handleDeleteJob = async (jobId: string) => {
    if (!window.confirm(isRTL ? "هل أنت متأكد من رغبتك في حذف هذه الوظيفة نهائياً؟" : "Are you sure you want to delete this job posting?")) return;
    try {
      await deleteCompanyJob(jobId);
      setRawJobs((prev) => prev.filter((j) => j.id !== jobId));
      setActionMessage({ type: "success", text: t("success") });
    } catch (err) {
      console.error(err);
      setActionMessage({ type: "error", text: t("error") });
    }
  };

  const resetForm = () => {
    setFormTitle("");
    setFormDescription("");
    setFormJobType("FULL_TIME");
    setFormWorkplaceType("HYBRID");
    setFormExperienceLevel("MID");
    setFormCity("Amman");
    setFormCountry("Jordan");
    setFormSalaryMin("");
    setFormSalaryMax("");
    setFormCurrency("JOD");
    setFormSkills("");
    setFormExamId("");
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 dark:text-white tracking-tight">{t("jobsTitle")}</h1>
          <p className="text-sm text-slate-500 dark:text-slate-400 mt-1">{t("jobsSubtitle")}</p>
        </div>
        <button
          onClick={openCreateModal}
          className="inline-flex items-center gap-2 px-4 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold rounded-xl shadow-lg shadow-indigo-600/30 transition-all hover:scale-[1.02] cursor-pointer"
        >
          <Plus className="w-4 h-4" />
          <span>{t("postNewJob")}</span>
        </button>
      </div>

      {/* Action Notification */}
      {actionMessage && (
        <div
          className={`p-4 rounded-xl text-sm font-medium border flex items-center justify-between ${
            actionMessage.type === "success"
              ? "bg-emerald-50 dark:bg-emerald-950/60 text-emerald-800 dark:text-emerald-300 border-emerald-200 dark:border-emerald-800"
              : "bg-rose-50 dark:bg-rose-950/60 text-rose-800 dark:text-rose-300 border-rose-200 dark:border-rose-800"
          }`}
        >
          <span>{actionMessage.text}</span>
          <button
            onClick={() => setActionMessage(null)}
            className="text-xs uppercase font-bold hover:underline"
          >
            {t("close")}
          </button>
        </div>
      )}

      {/* Filters & Search */}
      <div className="bg-white dark:bg-slate-900 p-4 rounded-xl border border-slate-200/80 dark:border-slate-800 shadow-sm flex flex-col md:flex-row items-stretch md:items-center justify-between gap-4">
        <div className="flex flex-wrap items-center gap-2">
          {[
            { value: "ALL", label: t("allStatuses") },
            { value: "PUBLISHED", label: isRTL ? "منشورة" : "Published" },
            { value: "DRAFT", label: isRTL ? "مسودة" : "Draft" },
            { value: "CLOSED", label: isRTL ? "مغلقة" : "Closed" },
          ].map((st) => (
            <button
              key={st.value}
              onClick={() => setStatusFilter(st.value)}
              className={`px-3 py-1.5 text-xs font-semibold rounded-lg transition-colors cursor-pointer ${
                statusFilter === st.value
                  ? "bg-slate-900 dark:bg-indigo-600 text-white shadow-sm"
                  : "bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300 hover:bg-slate-200 dark:hover:bg-slate-700"
              }`}
            >
              {st.label}
            </button>
          ))}
        </div>

        <div className="w-full md:w-80 relative">
          <Search className={`w-4 h-4 absolute ${isRTL ? "right-3" : "left-3"} top-3 text-slate-400`} />
          <input
            type="text"
            placeholder={t("searchJobsPlaceholder")}
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className={`w-full ${isRTL ? "pr-9 pl-4" : "pl-9 pr-4"} py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-lg bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-indigo-500`}
          />
        </div>
      </div>

      {/* Jobs Table */}
      <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm overflow-hidden">
        {loading ? (
          <div className="py-24 flex flex-col items-center justify-center gap-3">
            <div className="w-8 h-8 border-4 border-indigo-600 dark:border-indigo-400 border-t-transparent rounded-full animate-spin"></div>
            <p className="text-sm text-slate-500 dark:text-slate-400">{t("loading")}</p>
          </div>
        ) : filteredJobs.length === 0 ? (
          <div className="py-20 text-center text-slate-500 dark:text-slate-400 text-sm">
            {t("noData")}
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse" dir={isRTL ? "rtl" : "ltr"}>
              <thead>
                <tr className="bg-slate-50 dark:bg-slate-800/60 border-b border-slate-200/80 dark:border-slate-800 text-slate-600 dark:text-slate-300 text-[11px] uppercase tracking-wider font-semibold">
                  <th className="py-3.5 px-4">{t("jobTitleCol")}</th>
                  <th className="py-3.5 px-4">{t("jobTypeCol")}</th>
                  <th className="py-3.5 px-4">{t("locationSalaryCol")}</th>
                  <th className="py-3.5 px-4 text-center">{t("applicantsCol")}</th>
                  <th className="py-3.5 px-4">{t("statusCol")}</th>
                  <th className={`py-3.5 px-4 ${isRTL ? "text-left" : "text-right"}`}>{t("actions")}</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-100 dark:divide-slate-800 text-sm">
                {filteredJobs.map((job) => (
                  <tr key={job.id} className="hover:bg-slate-50/70 dark:hover:bg-slate-800/40 transition-colors">
                    <td className="py-4 px-4">
                      <div className="font-bold text-slate-900 dark:text-white">{job.title}</div>
                      <div className="flex flex-wrap gap-1 mt-1">
                        {job.requiredSkills.slice(0, 4).map((sk) => (
                          <span key={sk} className="text-[10px] px-1.5 py-0.5 bg-indigo-50 dark:bg-indigo-950/60 text-indigo-700 dark:text-indigo-300 rounded border border-indigo-100 dark:border-indigo-800">
                            {sk}
                          </span>
                        ))}
                      </div>
                    </td>
                    <td className="py-4 px-4 whitespace-nowrap">
                      <div className="text-xs font-semibold text-slate-700 dark:text-slate-300">{job.jobType.replace("_", " ")}</div>
                      <div className="text-xs text-slate-500 dark:text-slate-400">{job.workplaceType} • {job.experienceLevel}</div>
                    </td>
                    <td className="py-4 px-4 whitespace-nowrap">
                      <div className="text-xs text-slate-700 dark:text-slate-300 flex items-center gap-1">
                        <MapPin className="w-3 h-3 text-slate-400" />
                        <span>{job.location?.city || "Remote"}{job.location?.country ? `, ${job.location.country}` : ""}</span>
                      </div>
                      {job.salaryRange?.min && (
                        <div className="text-xs text-emerald-600 dark:text-emerald-400 font-semibold mt-0.5">
                          {job.salaryRange.min.toLocaleString()} - {job.salaryRange.max?.toLocaleString()} {job.salaryRange.currency || "JOD"}
                        </div>
                      )}
                    </td>
                    <td className="py-4 px-4 text-center whitespace-nowrap">
                      <Link
                        href={`/company/applicants?jobId=${job.id}`}
                        className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-bold bg-indigo-50 dark:bg-indigo-950/60 text-indigo-700 dark:text-indigo-300 border border-indigo-200 dark:border-indigo-800 hover:bg-indigo-100 dark:hover:bg-indigo-900/60 transition-colors shadow-sm"
                      >
                        <Users className="w-3.5 h-3.5 text-indigo-500" />
                        <span>{job.applicantsCount} {t("applicantsCountBadge")}</span>
                      </Link>
                    </td>
                    <td className="py-4 px-4 whitespace-nowrap">
                      <span
                        className={`inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold ${
                          job.status === "PUBLISHED"
                            ? "bg-emerald-100 dark:bg-emerald-950/60 text-emerald-800 dark:text-emerald-300 border border-emerald-300 dark:border-emerald-800"
                            : job.status === "DRAFT"
                            ? "bg-amber-100 dark:bg-amber-950/60 text-amber-800 dark:text-amber-300 border border-amber-300 dark:border-amber-800"
                            : "bg-slate-200 dark:bg-slate-800 text-slate-700 dark:text-slate-300 border border-slate-300 dark:border-slate-700"
                        }`}
                      >
                        {job.status}
                      </span>
                    </td>
                    <td className={`py-4 px-4 ${isRTL ? "text-left" : "text-right"} whitespace-nowrap`}>
                      <div className="inline-flex items-center gap-1.5">
                        {job.status !== "PUBLISHED" && (
                          <button
                            onClick={() => handleStatusToggle(job.id, "PUBLISHED")}
                            className="px-2.5 py-1 text-xs font-semibold text-emerald-700 dark:text-emerald-300 bg-emerald-50 dark:bg-emerald-950/60 hover:bg-emerald-100 rounded-md transition-colors cursor-pointer"
                          >
                            {t("publishAction")}
                          </button>
                        )}
                        {job.status === "PUBLISHED" && (
                          <button
                            onClick={() => handleStatusToggle(job.id, "CLOSED")}
                            className="px-2.5 py-1 text-xs font-semibold text-amber-700 dark:text-amber-300 bg-amber-50 dark:bg-amber-950/60 hover:bg-amber-100 rounded-md transition-colors cursor-pointer"
                          >
                            {t("closeAction")}
                          </button>
                        )}
                        <button
                          onClick={() => openEditModal(job)}
                          className="p-1.5 text-slate-500 hover:text-indigo-600 hover:bg-indigo-50 dark:hover:bg-indigo-950/50 rounded-md transition-colors cursor-pointer"
                          title={t("edit")}
                        >
                          <Edit2 className="w-4 h-4" />
                        </button>
                        <button
                          onClick={() => handleDeleteJob(job.id)}
                          className="p-1.5 text-slate-400 hover:text-rose-600 hover:bg-rose-50 dark:hover:bg-rose-950/50 rounded-md transition-colors cursor-pointer"
                          title={t("delete")}
                        >
                          <Trash2 className="w-4 h-4" />
                        </button>
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Modal: Create / Edit Job */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 bg-slate-900/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white dark:bg-slate-900 rounded-2xl max-w-2xl w-full p-6 sm:p-8 shadow-2xl border border-slate-200 dark:border-slate-800 my-8">
            <div className="flex items-center justify-between pb-4 border-b border-slate-100 dark:border-slate-800 mb-6">
              <div>
                <h2 className="text-xl font-bold text-slate-900 dark:text-white">
                  {editingJobId
                    ? isRTL
                      ? "تعديل تفاصيل الوظيفة"
                      : "Edit Job Posting"
                    : t("newJobModalTitle")}
                </h2>
                <p className="text-xs text-slate-500 dark:text-slate-400">{t("newJobModalSub")}</p>
              </div>
              <button
                onClick={() => setIsModalOpen(false)}
                className="p-1 rounded-lg text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSaveJob} className="space-y-4">
              {modalError && (
                <div className="p-3 rounded-xl bg-rose-50 dark:bg-rose-950/60 border border-rose-200 dark:border-rose-800 text-rose-700 dark:text-rose-300 text-xs font-medium flex items-center gap-2">
                  <AlertCircle className="w-4 h-4 flex-shrink-0" />
                  <span>{modalError}</span>
                </div>
              )}

              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("jobTitleLabel")}</label>
                <input
                  type="text"
                  required
                  value={formTitle}
                  onChange={(e) => setFormTitle(e.target.value)}
                  placeholder="e.g. Senior Flutter & AI Engineer"
                  className="w-full px-3.5 py-2.5 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("jobDescLabel")}</label>
                <textarea
                  required
                  rows={4}
                  value={formDescription}
                  onChange={(e) => setFormDescription(e.target.value)}
                  placeholder="Job responsibilities, requirements, and tech stack..."
                  className="w-full px-3.5 py-2.5 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:ring-2 focus:ring-indigo-500 focus:outline-none"
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("employmentTypeLabel")}</label>
                  <select
                    value={formJobType}
                    onChange={(e) => setFormJobType(e.target.value)}
                    className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                  >
                    <option value="FULL_TIME">Full-Time</option>
                    <option value="PART_TIME">Part-Time</option>
                    <option value="CONTRACT">Contract</option>
                    <option value="INTERNSHIP">Internship</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("workplaceTypeLabel")}</label>
                  <select
                    value={formWorkplaceType}
                    onChange={(e) => setFormWorkplaceType(e.target.value)}
                    className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                  >
                    <option value="HYBRID">Hybrid</option>
                    <option value="REMOTE">Remote</option>
                    <option value="ON_SITE">On-Site</option>
                  </select>
                </div>

                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("experienceLevelLabel")}</label>
                  <select
                    value={formExperienceLevel}
                    onChange={(e) => setFormExperienceLevel(e.target.value)}
                    className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                  >
                    <option value="ENTRY">Entry Level</option>
                    <option value="MID">Mid Level</option>
                    <option value="SENIOR">Senior</option>
                    <option value="LEAD">Lead / Principal</option>
                  </select>
                </div>
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">
                    {isRTL ? "المدينة" : "City"}
                  </label>
                  <input
                    type="text"
                    value={formCity}
                    onChange={(e) => setFormCity(e.target.value)}
                    placeholder="Amman"
                    className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">
                    {isRTL ? "الدولة" : "Country"}
                  </label>
                  <input
                    type="text"
                    value={formCountry}
                    onChange={(e) => setFormCountry(e.target.value)}
                    placeholder="Jordan"
                    className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                  />
                </div>
              </div>

              <div>
                <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("skillsLabel")}</label>
                <input
                  type="text"
                  value={formSkills}
                  onChange={(e) => setFormSkills(e.target.value)}
                  placeholder="Flutter, Dart, Firebase, AI"
                  className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                />
              </div>

              <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("salaryMinLabel")}</label>
                  <input
                    type="number"
                    value={formSalaryMin}
                    onChange={(e) => setFormSalaryMin(e.target.value)}
                    placeholder="1000"
                    className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("salaryMaxLabel")}</label>
                  <input
                    type="number"
                    value={formSalaryMax}
                    onChange={(e) => setFormSalaryMax(e.target.value)}
                    placeholder="2500"
                    className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                  />
                </div>
                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("salaryCurrencyLabel")}</label>
                  <select
                    value={formCurrency}
                    onChange={(e) => setFormCurrency(e.target.value)}
                    className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white font-medium cursor-pointer"
                  >
                    {CURRENCY_OPTIONS.map((c) => (
                      <option key={c.code} value={c.code}>
                        {language === "ar" ? c.labelAr : c.labelEn}
                      </option>
                    ))}
                  </select>
                </div>
              </div>

              {exams.length > 0 && (
                <div>
                  <label className="block text-xs font-bold text-slate-700 dark:text-slate-300 mb-1">{t("linkExamLabel")}</label>
                  <select
                    value={formExamId}
                    onChange={(e) => setFormExamId(e.target.value)}
                    className="w-full px-3 py-2 text-xs border border-slate-300 dark:border-slate-700 rounded-xl bg-white dark:bg-slate-800 text-slate-900 dark:text-white"
                  >
                    <option value="">{t("noExamOption")}</option>
                    {exams.map((ex) => (
                      <option key={ex.id} value={ex.id}>
                        {ex.title} ({ex.durationMinutes} min - {ex.passingScore}%)
                      </option>
                    ))}
                  </select>
                </div>
              )}

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
                  disabled={saving}
                  className="px-5 py-2.5 bg-indigo-600 hover:bg-indigo-500 disabled:opacity-50 text-white text-xs font-semibold rounded-xl shadow-lg shadow-indigo-600/30 flex items-center gap-2"
                >
                  {saving && <Loader2 className="w-4 h-4 animate-spin" />}
                  <span>{editingJobId ? t("save") : t("postJobSubmit")}</span>
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
