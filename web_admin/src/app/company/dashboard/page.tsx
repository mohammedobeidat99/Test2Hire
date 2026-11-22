"use client";

import React, { useEffect, useState } from "react";
import Link from "next/link";
import { auth } from "@/lib/firebase";
import { onAuthStateChanged } from "firebase/auth";
import { useCompany } from "@/lib/i18n";
import { getApplicantStatusMeta } from "@/lib/formatters";
import {
  computeCompanyDashboardKPIs,
  listenCompanyJobs,
  listenCompanyApplicants,
  listenCompanyInterviews,
  CompanyJob,
  CompanyApplicant,
  CompanyInterview,
  CompanyDashboardKPIs,
} from "@/lib/company-portal-service";
import {
  Briefcase,
  Users,
  Award,
  Calendar,
  PlusCircle,
  ArrowUpRight,
  FileCheck,
  Sparkles,
  ArrowRight,
  ChevronRight,
} from "lucide-react";

export default function CompanyDashboardPage() {
  const { t, language } = useCompany();

  const [allJobs, setAllJobs] = useState<CompanyJob[]>([]);
  const [allApplicants, setAllApplicants] = useState<CompanyApplicant[]>([]);
  const [allInterviews, setAllInterviews] = useState<CompanyInterview[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    let unsubJobs: (() => void) | null = null;
    let unsubApps: (() => void) | null = null;
    let unsubInts: (() => void) | null = null;

    const unsubAuth = onAuthStateChanged(auth, (user) => {
      if (unsubJobs) unsubJobs();
      if (unsubApps) unsubApps();
      if (unsubInts) unsubInts();

      if (user) {
        setLoading(true);
        unsubJobs = listenCompanyJobs(user.uid, (jobs) => {
          setAllJobs(jobs);
          setLoading(false);
        });
        unsubApps = listenCompanyApplicants(user.uid, (apps) => {
          setAllApplicants(apps);
          setLoading(false);
        });
        unsubInts = listenCompanyInterviews(user.uid, (ints) => {
          setAllInterviews(ints);
        });
      } else {
        setLoading(false);
      }
    });

    return () => {
      unsubAuth();
      if (unsubJobs) unsubJobs();
      if (unsubApps) unsubApps();
      if (unsubInts) unsubInts();
    };
  }, []);

  // Dynamically compute real applicant counts per job and KPIs in memory
  const jobsWithCounts = React.useMemo(() => {
    const countsByJob: Record<string, number> = {};
    allApplicants.forEach((a) => {
      if (a.jobId && a.status !== "WITHDRAWN") {
        countsByJob[a.jobId] = (countsByJob[a.jobId] || 0) + 1;
      }
    });
    return allJobs.map((j) => ({
      ...j,
      applicantsCount: countsByJob[j.id] ?? j.applicantsCount ?? 0,
    }));
  }, [allJobs, allApplicants]);

  const kpis = React.useMemo<CompanyDashboardKPIs>(
    () => computeCompanyDashboardKPIs(jobsWithCounts, allApplicants, allInterviews),
    [jobsWithCounts, allApplicants, allInterviews]
  );

  const recentJobs = React.useMemo(() => jobsWithCounts.slice(0, 5), [jobsWithCounts]);
  const recentApplicants = React.useMemo(
    () => allApplicants.filter((a) => a.status !== "WITHDRAWN").slice(0, 6),
    [allApplicants]
  );

  const getStatusBadge = (status: string) => {
    const meta = getApplicantStatusMeta(status);
    return (
      <span className={`px-2.5 py-0.5 rounded-full text-xs font-semibold border ${meta.badgeClass}`}>
        {language === "ar" ? meta.labelAr : meta.labelEn}
      </span>
    );
  };

  if (loading) {
    return (
      <div className="py-24 flex flex-col items-center justify-center gap-3">
        <div className="w-10 h-10 border-4 border-indigo-600 dark:border-indigo-400 border-t-transparent rounded-full animate-spin"></div>
        <p className="text-sm font-medium text-slate-500 dark:text-slate-400">{t("loading")}</p>
      </div>
    );
  }

  return (
    <div className="space-y-8">
      {/* Welcome & Quick Action Header */}
      <div className="bg-white dark:bg-slate-900/90 rounded-3xl p-6 sm:p-8 text-slate-900 dark:text-white shadow-sm flex flex-col md:flex-row md:items-center md:justify-between gap-6 border border-slate-200/90 dark:border-slate-800 transition-colors">
        <div>
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-semibold bg-indigo-50 dark:bg-indigo-500/20 text-indigo-700 dark:text-indigo-300 border border-indigo-200 dark:border-indigo-500/30 mb-3">
            <Sparkles className="w-3.5 h-3.5" />
            <span>{t("dashWelcomeBadge")}</span>
          </div>
          <h1 className="text-2xl sm:text-3xl font-bold tracking-tight">
            {t("dashTitle")}
          </h1>
          <p className="text-slate-600 dark:text-slate-400 text-sm mt-1 max-w-xl leading-relaxed">
            {t("dashSubtitle")}
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-3">
          <Link
            href="/company/jobs"
            className="inline-flex items-center gap-2 px-4 py-2.5 bg-indigo-600 hover:bg-indigo-500 text-white text-xs font-semibold rounded-xl shadow-sm transition-all hover:scale-[1.02] cursor-pointer"
          >
            <PlusCircle className="w-4 h-4" />
            <span>{t("postNewJob")}</span>
          </Link>
          <Link
            href="/company/exams"
            className="inline-flex items-center gap-2 px-4 py-2.5 bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 text-xs font-semibold rounded-xl border border-slate-200 dark:border-slate-700 transition-all cursor-pointer"
          >
            <FileCheck className="w-4 h-4 text-indigo-600 dark:text-indigo-400" />
            <span>{t("createAssessment")}</span>
          </Link>
        </div>
      </div>

      {/* KPI Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4 sm:gap-6">
        {/* Active Jobs */}
        <div className="bg-white dark:bg-slate-900 p-5 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm hover:shadow-md transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
              {t("kpiActiveJobs")}
            </span>
            <div className="w-9 h-9 rounded-xl bg-emerald-50 dark:bg-emerald-950/50 text-emerald-600 dark:text-emerald-400 flex items-center justify-center">
              <Briefcase className="w-5 h-5" />
            </div>
          </div>
          <div className="text-3xl font-black text-slate-900 dark:text-white mt-2">{kpis.activeJobs}</div>
          <div className="text-xs text-emerald-600 dark:text-emerald-400 font-medium mt-1">
            {t("kpiActiveJobsSub")}
          </div>
        </div>

        {/* Total Applicants */}
        <div className="bg-white dark:bg-slate-900 p-5 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm hover:shadow-md transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
              {t("kpiTotalApplicants")}
            </span>
            <div className="w-9 h-9 rounded-xl bg-indigo-50 dark:bg-indigo-950/50 text-indigo-600 dark:text-indigo-400 flex items-center justify-center">
              <Users className="w-5 h-5" />
            </div>
          </div>
          <div className="text-3xl font-black text-indigo-600 dark:text-indigo-400 mt-2">{kpis.totalApplicants}</div>
          <div className="text-xs text-indigo-600 dark:text-indigo-400 font-medium mt-1">
            {t("kpiTotalApplicantsSub")}
          </div>
        </div>

        {/* Completed Exams */}
        <div className="bg-white dark:bg-slate-900 p-5 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm hover:shadow-md transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
              {t("kpiCompletedExams")}
            </span>
            <div className="w-9 h-9 rounded-xl bg-amber-50 dark:bg-amber-950/50 text-amber-600 dark:text-amber-400 flex items-center justify-center">
              <Award className="w-5 h-5" />
            </div>
          </div>
          <div className="text-3xl font-black text-amber-600 dark:text-amber-400 mt-2">{kpis.completedExams}</div>
          <div className="text-xs text-amber-600 dark:text-amber-400 font-medium mt-1">
            {t("kpiCompletedExamsSub")}
          </div>
        </div>

        {/* Scheduled Interviews */}
        <div className="bg-white dark:bg-slate-900 p-5 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm hover:shadow-md transition-all">
          <div className="flex items-center justify-between">
            <span className="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">
              {t("kpiScheduledInterviews")}
            </span>
            <div className="w-9 h-9 rounded-xl bg-purple-50 dark:bg-purple-950/50 text-purple-600 dark:text-purple-400 flex items-center justify-center">
              <Calendar className="w-5 h-5" />
            </div>
          </div>
          <div className="text-3xl font-black text-purple-600 dark:text-purple-400 mt-2">{kpis.scheduledInterviews}</div>
          <div className="text-xs text-purple-600 dark:text-purple-400 font-medium mt-1">
            {t("kpiScheduledInterviewsSub")}
          </div>
        </div>
      </div>

      {/* Main Grid: Recent Applicants Pipeline & Recent Jobs */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Recent Applicants */}
        <div className="lg:col-span-2 bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm overflow-hidden flex flex-col">
          <div className="p-5 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between">
            <div>
              <h2 className="text-base font-bold text-slate-900 dark:text-white">{t("recentApplicants")}</h2>
              <p className="text-xs text-slate-500 dark:text-slate-400">{t("recentApplicantsSub")}</p>
            </div>
            <Link
              href="/company/applicants"
              className="text-xs font-semibold text-indigo-600 dark:text-indigo-400 hover:text-indigo-700 flex items-center gap-1 cursor-pointer"
            >
              <span>{t("viewAllApplicants")} ({kpis.totalApplicants})</span>
              <ArrowUpRight className="w-3.5 h-3.5" />
            </Link>
          </div>

          <div className="divide-y divide-slate-100 dark:divide-slate-800 flex-1">
            {recentApplicants.length === 0 ? (
              <div className="p-12 text-center text-slate-400 text-sm">
                {t("noData")}
              </div>
            ) : (
              recentApplicants.map((app) => (
                <div
                  key={app.id}
                  className="p-4 flex items-center justify-between hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors"
                >
                  <div className="flex items-center gap-3">
                    <div className="w-10 h-10 rounded-xl bg-indigo-50 dark:bg-indigo-950/80 text-indigo-700 dark:text-indigo-300 font-bold flex items-center justify-center text-sm border border-indigo-200/60 dark:border-indigo-800/60">
                      {app.candidateName ? app.candidateName[0] : "C"}
                    </div>
                    <div>
                      <div className="text-sm font-bold text-slate-900 dark:text-white">{app.candidateName}</div>
                      <div className="text-xs text-slate-500 dark:text-slate-400">
                        {app.jobTitle} • {app.candidateEmail}
                      </div>
                    </div>
                  </div>

                  <div className="flex items-center gap-3">
                    {app.examScore !== undefined && (
                      <span className="text-xs font-bold text-indigo-600 dark:text-indigo-400 bg-indigo-50 dark:bg-indigo-950/60 px-2 py-0.5 rounded border border-indigo-200 dark:border-indigo-800">
                        {app.examScore}%
                      </span>
                    )}
                    {getStatusBadge(app.status)}
                    <Link
                      href="/company/applicants"
                      className="text-xs font-medium text-slate-600 dark:text-slate-300 hover:text-indigo-600 dark:hover:text-indigo-400 px-2.5 py-1 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 rounded-lg transition-colors cursor-pointer"
                    >
                      {t("actions")}
                    </Link>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>

        {/* Active Jobs Snapshot */}
        <div className="bg-white dark:bg-slate-900 rounded-2xl border border-slate-200/80 dark:border-slate-800 shadow-sm overflow-hidden flex flex-col">
          <div className="p-5 border-b border-slate-100 dark:border-slate-800 flex items-center justify-between">
            <div>
              <h2 className="text-base font-bold text-slate-900 dark:text-white">{t("activeJobsOverview")}</h2>
              <p className="text-xs text-slate-500 dark:text-slate-400">{t("activeJobsOverviewSub")}</p>
            </div>
            <Link
              href="/company/jobs"
              className="text-xs font-semibold text-indigo-600 dark:text-indigo-400 hover:text-indigo-700 flex items-center gap-1 cursor-pointer"
            >
              <span>{t("manageJobs")}</span>
              <ArrowUpRight className="w-3.5 h-3.5" />
            </Link>
          </div>

          <div className="divide-y divide-slate-100 dark:divide-slate-800 flex-1">
            {recentJobs.length === 0 ? (
              <div className="p-12 text-center text-slate-400 text-sm">
                {t("noData")}
              </div>
            ) : (
              recentJobs.map((job) => (
                <div key={job.id} className="p-4 hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors">
                  <div className="flex items-center justify-between mb-1">
                    <span className="text-sm font-bold text-slate-800 dark:text-slate-200 line-clamp-1">{job.title}</span>
                    <span className="text-xs font-bold px-2 py-0.5 rounded-full bg-indigo-50 dark:bg-indigo-950/60 text-indigo-700 dark:text-indigo-300 border border-indigo-200 dark:border-indigo-800">
                      {job.applicantsCount} {t("applicantsCountBadge")}
                    </span>
                  </div>
                  <div className="flex items-center justify-between text-xs text-slate-500 dark:text-slate-400">
                    <span>{job.jobType.replace("_", " ")} • {job.workplaceType.replace("_", " ")}</span>
                    <span className={job.status === "PUBLISHED" ? "text-emerald-600 dark:text-emerald-400 font-semibold" : "text-amber-600 dark:text-amber-400 font-semibold"}>
                      {job.status}
                    </span>
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
