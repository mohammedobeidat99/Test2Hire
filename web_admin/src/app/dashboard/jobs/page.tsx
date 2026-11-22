"use client";

import { useEffect, useState, useMemo } from "react";
import { formatTimestamp, sanitizeExternalUrl } from "@/lib/formatters";
import {
  fetchJobs,
  updateJobStatus,
  deleteJob,
  JobRecord,
  JobStatus,
} from "@/lib/job-service";
import {
  fetchJobApplicants,
  JobApplicant,
} from "@/lib/application-service";

export default function JobsPage() {
  const [jobs, setJobs] = useState<JobRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [statusFilter, setStatusFilter] = useState<JobStatus | "ALL">("ALL");
  const [searchQuery, setSearchQuery] = useState("");

  // Details Modal
  const [selectedJob, setSelectedJob] = useState<JobRecord | null>(null);

  // Applicants & CV Modal
  const [viewingApplicantsJob, setViewingApplicantsJob] = useState<JobRecord | null>(null);
  const [jobApplicants, setJobApplicants] = useState<JobApplicant[]>([]);
  const [loadingApplicants, setLoadingApplicants] = useState(false);
  const [applicantsError, setApplicantsError] = useState<string | null>(null);
  const [selectedApplicantInsights, setSelectedApplicantInsights] = useState<JobApplicant | null>(null);

  // Status Change / Action
  const [actionLoading, setActionLoading] = useState(false);
  const [actionMessage, setActionMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);

  const handleOpenApplicants = async (job: JobRecord) => {
    setViewingApplicantsJob(job);
    setLoadingApplicants(true);
    setApplicantsError(null);
    setSelectedApplicantInsights(null);
    try {
      const data = await fetchJobApplicants(job.id);
      setJobApplicants(data);
    } catch (err: any) {
      console.error("Failed to load applicants:", err);
      setApplicantsError(err.message || "Failed to load candidates");
    } finally {
      setLoadingApplicants(false);
    }
  };

  const loadData = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await fetchJobs(statusFilter);
      setJobs(data);
    } catch (err: any) {
      console.error(err);
      setError(err.message || "Failed to load job postings");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [statusFilter]);

  const filteredJobs = useMemo(() => {
    return jobs.filter((j) => {
      const q = searchQuery.toLowerCase();
      const matchTitle = j.title.toLowerCase().includes(q);
      const matchCompany = j.companyName.toLowerCase().includes(q);
      const matchSkill = j.requiredSkills.some((s) => s.toLowerCase().includes(q));
      const matchLocation =
        (j.location?.city?.toLowerCase().includes(q) || false) ||
        (j.location?.country?.toLowerCase().includes(q) || false);
      return matchTitle || matchCompany || matchSkill || matchLocation;
    });
  }, [jobs, searchQuery]);

  const handleStatusChange = async (jobId: string, newStatus: JobStatus) => {
    try {
      setActionLoading(true);
      setActionMessage(null);
      await updateJobStatus(jobId, newStatus);
      setActionMessage({
        type: "success",
        text: `Job status successfully updated to ${newStatus}.`,
      });
      setJobs((prev) =>
        prev.map((j) => (j.id === jobId ? { ...j, status: newStatus } : j))
      );
      if (selectedJob && selectedJob.id === jobId) {
        setSelectedJob({ ...selectedJob, status: newStatus });
      }
    } catch (err: any) {
      setActionMessage({
        type: "error",
        text: err.message || "Failed to update job status.",
      });
    } finally {
      setActionLoading(false);
    }
  };

  const handleDelete = async (jobId: string, title: string) => {
    if (!window.confirm(`Are you sure you want to permanently delete the job "${title}"?`)) {
      return;
    }
    try {
      setActionLoading(true);
      setActionMessage(null);
      await deleteJob(jobId);
      setActionMessage({
        type: "success",
        text: `Job "${title}" was permanently deleted.`,
      });
      setJobs((prev) => prev.filter((j) => j.id !== jobId));
      if (selectedJob?.id === jobId) {
        setSelectedJob(null);
      }
    } catch (err: any) {
      setActionMessage({
        type: "error",
        text: err.message || "Failed to delete job.",
      });
    } finally {
      setActionLoading(false);
    }
  };

  const getStatusBadge = (status: JobStatus) => {
    switch (status) {
      case "PUBLISHED":
        return (
          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-800 border border-emerald-300">
            Published
          </span>
        );
      case "DRAFT":
        return (
          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-amber-100 text-amber-800 border border-amber-300">
            Draft
          </span>
        );
      case "CLOSED":
        return (
          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-slate-200 text-slate-700 border border-slate-300">
            Closed
          </span>
        );
      case "ARCHIVED":
      default:
        return (
          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-rose-100 text-rose-800 border border-rose-300">
            Archived
          </span>
        );
    }
  };

  const stats = useMemo(() => {
    return {
      total: jobs.length,
      published: jobs.filter((j) => j.status === "PUBLISHED").length,
      draft: jobs.filter((j) => j.status === "DRAFT").length,
      closed: jobs.filter((j) => j.status === "CLOSED" || j.status === "ARCHIVED").length,
      totalApplicants: jobs.reduce((acc, j) => acc + (j.applicantsCount || 0), 0),
    };
  }, [jobs]);

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Job Postings Management</h1>
          <p className="text-sm text-slate-500 mt-1">
            Monitor, moderate, and manage all published and draft positions across the platform.
          </p>
        </div>
        <button
          onClick={loadData}
          disabled={loading}
          className="inline-flex items-center gap-2 px-4 py-2 bg-white border border-slate-300 text-slate-700 text-sm font-medium rounded-lg hover:bg-slate-50 shadow-sm transition-colors"
        >
          {loading ? "Refreshing..." : "Refresh Jobs"}
        </button>
      </div>

      {/* Action Notification Message (floating over modals) */}
      {actionMessage && (
        <div
          className={`fixed top-6 left-1/2 -translate-x-1/2 z-[99999] shadow-2xl max-w-lg w-[92%] sm:w-auto px-5 py-3.5 rounded-2xl text-sm font-semibold border flex items-center justify-between gap-3 ${
            actionMessage.type === "success"
              ? "bg-emerald-600 text-white border-emerald-500 shadow-emerald-500/25"
              : "bg-rose-600 text-white border-rose-500 shadow-rose-500/25"
          }`}
        >
          <span>{actionMessage.text}</span>
          <button
            type="button"
            onClick={() => setActionMessage(null)}
            className="text-xs uppercase tracking-wider font-bold ml-4 hover:underline cursor-pointer"
          >
            Dismiss
          </button>
        </div>
      )}

      {/* KPI Stats Bar */}
      <div className="grid grid-cols-2 md:grid-cols-5 gap-4">
        <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">
          <div className="text-xs font-medium text-slate-500 uppercase">Total Positions</div>
          <div className="text-2xl font-bold text-slate-900 mt-1">{stats.total}</div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">
          <div className="text-xs font-medium text-indigo-600 uppercase">Total Applicants</div>
          <div className="text-2xl font-bold text-indigo-700 mt-1">{stats.totalApplicants}</div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">
          <div className="text-xs font-medium text-emerald-600 uppercase">Live Published</div>
          <div className="text-2xl font-bold text-emerald-700 mt-1">{stats.published}</div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">
          <div className="text-xs font-medium text-amber-600 uppercase">Drafts Pending</div>
          <div className="text-2xl font-bold text-amber-700 mt-1">{stats.draft}</div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">
          <div className="text-xs font-medium text-slate-600 uppercase">Closed / Archived</div>
          <div className="text-2xl font-bold text-slate-700 mt-1">{stats.closed}</div>
        </div>
      </div>

      {/* Filters & Search */}
      <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm flex flex-col md:flex-row items-stretch md:items-center justify-between gap-4">
        <div className="flex flex-wrap items-center gap-2">
          {(["ALL", "PUBLISHED", "DRAFT", "CLOSED", "ARCHIVED"] as const).map((st) => (
            <button
              key={st}
              onClick={() => setStatusFilter(st)}
              className={`px-3 py-1.5 text-xs font-semibold rounded-lg transition-colors ${
                statusFilter === st
                  ? "bg-slate-900 text-white shadow-sm"
                  : "bg-slate-100 text-slate-600 hover:bg-slate-200"
              }`}
            >
              {st === "ALL" ? "All Statuses" : st}
            </button>
          ))}
        </div>

        <div className="w-full md:w-80">
          <input
            type="text"
            placeholder="Search by title, company, skills, location..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full px-3 py-2 text-sm border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
          />
        </div>
      </div>

      {/* Jobs Table */}
      <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
        {loading ? (
          <div className="py-20 flex flex-col items-center justify-center gap-3">
            <div className="w-8 h-8 border-4 border-indigo-600 border-t-transparent rounded-full animate-spin"></div>
            <p className="text-sm text-slate-500 font-medium">Loading jobs from Firebase Firestore...</p>
          </div>
        ) : error ? (
          <div className="py-16 text-center">
            <p className="text-rose-600 text-sm font-medium">{error}</p>
            <button
              onClick={loadData}
              className="mt-3 text-xs text-indigo-600 font-semibold hover:underline"
            >
              Try Again
            </button>
          </div>
        ) : filteredJobs.length === 0 ? (
          <div className="py-16 text-center text-slate-500 text-sm">
            No job postings found matching the selected filter criteria.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-slate-200 bg-slate-50/75 text-xs font-semibold text-slate-500 uppercase tracking-wider">
                  <th className="py-3.5 px-4">Role & Company</th>
                  <th className="py-3.5 px-4">Type / Workplace</th>
                  <th className="py-3.5 px-4">Applicants</th>
                  <th className="py-3.5 px-4">Status</th>
                  <th className="py-3.5 px-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200 text-sm">
                {filteredJobs.map((job) => (
                  <tr key={job.id} className="hover:bg-slate-50/60 transition-colors">
                    <td className="py-4 px-4">
                      <div className="font-semibold text-slate-900">{job.title}</div>
                      <div className="text-xs text-slate-500 flex items-center gap-2 mt-0.5">
                        <span className="font-medium text-slate-700">{job.companyName}</span>
                        {(job.location?.city || job.location?.country) && (
                          <span>• {[job.location.city, job.location.country].filter(Boolean).join(", ")}</span>
                        )}
                      </div>
                      {job.requiredSkills && job.requiredSkills.length > 0 && (
                        <div className="flex flex-wrap gap-1 mt-1.5">
                          {job.requiredSkills.slice(0, 3).map((skill, idx) => (
                            <span
                              key={idx}
                              className="px-1.5 py-0.5 bg-slate-100 text-slate-600 rounded text-[11px]"
                            >
                              {skill}
                            </span>
                          ))}
                          {job.requiredSkills.length > 3 && (
                            <span className="px-1.5 py-0.5 text-slate-400 text-[11px]">
                              +{job.requiredSkills.length - 3} more
                            </span>
                          )}
                        </div>
                      )}
                    </td>
                    <td className="py-4 px-4 whitespace-nowrap">
                      <div className="text-xs font-medium text-slate-700">{job.jobType.replace("_", " ")}</div>
                      <div className="text-xs text-slate-500">{job.workplaceType.replace("_", " ")} • {job.experienceLevel}</div>
                    </td>
                    <td className="py-4 px-4 whitespace-nowrap">
                      <button
                        onClick={() => handleOpenApplicants(job)}
                        className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-indigo-50 text-indigo-700 border border-indigo-200 hover:bg-indigo-100 hover:border-indigo-300 transition-colors cursor-pointer group"
                        title="Click to view all applicants and download CVs"
                      >
                        <svg className="w-3.5 h-3.5 text-indigo-500 group-hover:text-indigo-700" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
                        </svg>
                        <span>{job.applicantsCount} Applicants</span>
                      </button>
                    </td>
                    <td className="py-4 px-4 whitespace-nowrap">
                      {getStatusBadge(job.status)}
                    </td>
                    <td className="py-4 px-4 text-right whitespace-nowrap">
                      <div className="inline-flex items-center gap-2">
                        <button
                          onClick={() => setSelectedJob(job)}
                          className="px-2.5 py-1 text-xs font-medium text-indigo-600 bg-indigo-50 hover:bg-indigo-100 rounded-md transition-colors"
                        >
                          View Details
                        </button>

                        {job.status !== "PUBLISHED" && (
                          <button
                            disabled={actionLoading}
                            onClick={() => handleStatusChange(job.id, "PUBLISHED")}
                            className="px-2.5 py-1 text-xs font-medium text-emerald-700 bg-emerald-50 hover:bg-emerald-100 rounded-md transition-colors"
                          >
                            Publish
                          </button>
                        )}

                        {job.status === "PUBLISHED" && (
                          <button
                            disabled={actionLoading}
                            onClick={() => handleStatusChange(job.id, "CLOSED")}
                            className="px-2.5 py-1 text-xs font-medium text-amber-700 bg-amber-50 hover:bg-amber-100 rounded-md transition-colors"
                          >
                            Close
                          </button>
                        )}

                        {job.status !== "ARCHIVED" && (
                          <button
                            disabled={actionLoading}
                            onClick={() => handleStatusChange(job.id, "ARCHIVED")}
                            className="px-2.5 py-1 text-xs font-medium text-slate-600 bg-slate-100 hover:bg-slate-200 rounded-md transition-colors"
                          >
                            Archive
                          </button>
                        )}

                        <button
                          disabled={actionLoading}
                          onClick={() => handleDelete(job.id, job.title)}
                          className="px-2.5 py-1 text-xs font-medium text-rose-600 bg-rose-50 hover:bg-rose-100 rounded-md transition-colors"
                        >
                          Delete
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

      {/* Job Details Modal */}
      {selectedJob && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 backdrop-blur-sm p-4 overflow-y-auto">
          <div className="bg-white rounded-2xl max-w-2xl w-full max-h-[90vh] flex flex-col shadow-2xl overflow-hidden border border-slate-200 animate-in fade-in zoom-in-95 duration-150">
            <div className="p-6 border-b border-slate-200 flex items-start justify-between">
              <div>
                <div className="flex items-center gap-2">
                  <h3 className="text-xl font-bold text-slate-900">{selectedJob.title}</h3>
                  {getStatusBadge(selectedJob.status)}
                </div>
                <p className="text-sm text-slate-500 mt-1">
                  Posted by <span className="font-semibold text-slate-700">{selectedJob.companyName}</span>
                  {selectedJob.createdAt &&
                    ` on ${formatTimestamp(selectedJob.createdAt, "en-US")}`}
                </p>
              </div>
              <button
                onClick={() => setSelectedJob(null)}
                className="text-slate-400 hover:text-slate-600 text-xl font-bold p-1"
              >
                ✕
              </button>
            </div>

            <div className="p-6 overflow-y-auto space-y-6 text-sm text-slate-700">
              <div className="grid grid-cols-2 sm:grid-cols-3 gap-4 p-4 bg-slate-50 rounded-xl border border-slate-200">
                <div>
                  <span className="text-xs text-slate-400 block uppercase">Employment</span>
                  <span className="font-semibold text-slate-800">{selectedJob.jobType}</span>
                </div>
                <div>
                  <span className="text-xs text-slate-400 block uppercase">Workplace</span>
                  <span className="font-semibold text-slate-800">{selectedJob.workplaceType}</span>
                </div>
                <div>
                  <span className="text-xs text-slate-400 block uppercase">Experience</span>
                  <span className="font-semibold text-slate-800">{selectedJob.experienceLevel}</span>
                </div>
                <div>
                  <span className="text-xs text-slate-400 block uppercase">Applicants</span>
                  <span className="font-semibold text-slate-800">{selectedJob.applicantsCount}</span>
                </div>
                <div>
                  <span className="text-xs text-slate-400 block uppercase">Location</span>
                  <span className="font-semibold text-slate-800">
                    {[selectedJob.location?.city, selectedJob.location?.country].filter(Boolean).join(", ") || "Remote / Unspecified"}
                  </span>
                </div>
                {selectedJob.examId && (
                  <div>
                    <span className="text-xs text-slate-400 block uppercase">Linked Assessment</span>
                    <span className="font-semibold text-indigo-600">ID: {selectedJob.examId.slice(0, 8)}...</span>
                  </div>
                )}
              </div>

              <div>
                <h4 className="font-semibold text-slate-900 mb-2">Job Description</h4>
                <div className="whitespace-pre-line text-slate-600 bg-white p-4 rounded-xl border border-slate-200 leading-relaxed">
                  {selectedJob.description || "No description provided."}
                </div>
              </div>

              {selectedJob.requiredSkills && selectedJob.requiredSkills.length > 0 && (
                <div>
                  <h4 className="font-semibold text-slate-900 mb-2">Required Skills</h4>
                  <div className="flex flex-wrap gap-2">
                    {selectedJob.requiredSkills.map((skill, idx) => (
                      <span
                        key={idx}
                        className="px-2.5 py-1 bg-indigo-50 text-indigo-700 font-medium rounded-lg text-xs border border-indigo-100"
                      >
                        {skill}
                      </span>
                    ))}
                  </div>
                </div>
              )}
            </div>

            <div className="p-4 border-t border-slate-200 bg-slate-50 flex items-center justify-between">
              <button
                onClick={() => setSelectedJob(null)}
                className="px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-200 rounded-lg transition-colors"
              >
                Close
              </button>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => {
                    const job = selectedJob;
                    setSelectedJob(null);
                    handleOpenApplicants(job);
                  }}
                  className="px-4 py-2 text-sm font-semibold text-indigo-700 bg-indigo-50 hover:bg-indigo-100 rounded-lg transition-colors border border-indigo-200"
                >
                  View Applicants & Download CVs ({selectedJob.applicantsCount})
                </button>

                {selectedJob.status !== "PUBLISHED" && (
                  <button
                    onClick={() => handleStatusChange(selectedJob.id, "PUBLISHED")}
                    disabled={actionLoading}
                    className="px-4 py-2 text-sm font-medium text-white bg-emerald-600 hover:bg-emerald-700 rounded-lg shadow-sm transition-colors"
                  >
                    Publish Position
                  </button>
                )}
                {selectedJob.status === "PUBLISHED" && (
                  <button
                    onClick={() => handleStatusChange(selectedJob.id, "CLOSED")}
                    disabled={actionLoading}
                    className="px-4 py-2 text-sm font-medium text-white bg-amber-600 hover:bg-amber-700 rounded-lg shadow-sm transition-colors"
                  >
                    Close Position
                  </button>
                )}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Applicants & CV Download Modal */}
      {viewingApplicantsJob && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 backdrop-blur-sm p-4 overflow-y-auto">
          <div className="bg-white rounded-2xl max-w-4xl w-full max-h-[90vh] flex flex-col shadow-2xl overflow-hidden border border-slate-200 animate-in fade-in zoom-in-95 duration-150">
            {/* Header */}
            <div className="p-6 border-b border-slate-200 flex items-start justify-between bg-slate-50/50">
              <div>
                <div className="flex items-center gap-3">
                  <h3 className="text-xl font-bold text-slate-900">
                    Applicants for: {viewingApplicantsJob.title}
                  </h3>
                  <span className="px-2.5 py-0.5 rounded-full text-xs font-semibold bg-indigo-100 text-indigo-800">
                    {jobApplicants.length} Total
                  </span>
                </div>
                <p className="text-sm text-slate-500 mt-1">
                  Company: <span className="font-semibold text-slate-700">{viewingApplicantsJob.companyName}</span>
                </p>
              </div>
              <button
                onClick={() => setViewingApplicantsJob(null)}
                className="text-slate-400 hover:text-slate-600 text-xl font-bold p-1 rounded-lg"
              >
                ✕
              </button>
            </div>

            {/* Content */}
            <div className="p-6 overflow-y-auto space-y-4">
              {loadingApplicants ? (
                <div className="py-20 flex flex-col items-center justify-center gap-3">
                  <div className="w-8 h-8 border-4 border-indigo-600 border-t-transparent rounded-full animate-spin"></div>
                  <p className="text-sm text-slate-500 font-medium">Loading applicants from Firestore...</p>
                </div>
              ) : applicantsError ? (
                <div className="py-12 text-center text-rose-600 font-medium">
                  {applicantsError}
                </div>
              ) : jobApplicants.length === 0 ? (
                <div className="py-16 text-center text-slate-500 text-sm">
                  <div className="text-3xl mb-2">📋</div>
                  No candidates have applied to this vacancy yet.
                </div>
              ) : (
                <div className="divide-y divide-slate-200 border border-slate-200 rounded-xl overflow-hidden">
                  {jobApplicants.map((app) => (
                    <div key={app.id} className="p-4 bg-white hover:bg-slate-50/50 transition-colors">
                      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                        <div className="space-y-1">
                          <div className="flex items-center gap-2">
                            <span className="font-bold text-slate-900 text-base">{app.candidateName}</span>
                            <span className="px-2 py-0.5 text-[11px] font-semibold rounded-full bg-slate-100 text-slate-700">
                              {app.status}
                            </span>
                            {app.overallFitScore != null && (
                              <span className="px-2 py-0.5 text-[11px] font-bold rounded-full bg-emerald-100 text-emerald-800 flex items-center gap-1">
                                <span>✨ AI Fit: {app.overallFitScore}%</span>
                              </span>
                            )}
                          </div>
                          <div className="text-xs text-slate-500 flex flex-wrap items-center gap-x-3 gap-y-1">
                            <span>📧 {app.candidateEmail}</span>
                            {app.candidatePhone && <span>📞 {app.candidatePhone}</span>}
                            {app.candidateHeadline && <span>💼 {app.candidateHeadline}</span>}
                          </div>
                          {app.coverLetter && (
                            <p className="text-xs text-slate-600 italic bg-slate-50 p-2 rounded border border-slate-100 mt-1">
                              &ldquo;{app.coverLetter}&rdquo;
                            </p>
                          )}
                        </div>

                        {/* Actions */}
                        <div className="flex items-center gap-2 shrink-0">
                          {(() => {
                            const safeCvUrl = sanitizeExternalUrl(app.cvUrl);
                            return safeCvUrl ? (
                              <a
                                href={safeCvUrl}
                                target="_blank"
                                rel="noopener noreferrer"
                                download={app.cvFileName || "Resume.pdf"}
                                className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-bold text-white bg-indigo-600 hover:bg-indigo-700 rounded-lg shadow-sm transition-all"
                              >
                                <svg className="w-3.5 h-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                                </svg>
                                <span>Download CV</span>
                              </a>
                            ) : (
                              <span className="px-2.5 py-1 text-xs text-slate-400 bg-slate-100 rounded-lg">
                                No CV Attached
                              </span>
                            );
                          })()}

                          {app.aiParsedCv && (
                            <button
                              onClick={() =>
                                setSelectedApplicantInsights(
                                  selectedApplicantInsights?.id === app.id ? null : app
                                )
                              }
                              className="px-2.5 py-1.5 text-xs font-semibold text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-lg transition-colors flex items-center gap-1"
                            >
                              <span>✨ AI Insights</span>
                              <span>{selectedApplicantInsights?.id === app.id ? "▲" : "▼"}</span>
                            </button>
                          )}
                        </div>
                      </div>

                      {/* Expandable AI Insights */}
                      {selectedApplicantInsights?.id === app.id && app.aiParsedCv && (
                        <div className="mt-4 pt-3 border-t border-slate-100 bg-indigo-50/40 p-3 rounded-lg text-xs space-y-2 animate-in fade-in duration-150">
                          <div className="flex items-center justify-between font-semibold text-slate-800">
                            <span className="flex items-center gap-1 text-indigo-700">
                              <span>🤖 Gemini AI Analysis</span>
                              <span className="px-1.5 py-0.5 bg-indigo-100 text-indigo-800 rounded font-bold">
                                {app.aiParsedCv.aiRecommendation || "EVALUATED"}
                              </span>
                            </span>
                            <span>Exp: {app.aiParsedCv.yearsOfExperience || 0} yrs</span>
                          </div>

                          {app.aiParsedCv.aiRationale && (
                            <p className="text-slate-700 leading-relaxed font-medium">
                              {app.aiParsedCv.aiRationale}
                            </p>
                          )}

                          {app.aiParsedCv.matchedSkills && app.aiParsedCv.matchedSkills.length > 0 && (
                            <div className="flex flex-wrap items-center gap-1">
                              <span className="font-semibold text-emerald-700">Matched Skills:</span>
                              {app.aiParsedCv.matchedSkills.map((s, i) => (
                                <span key={i} className="px-1.5 py-0.5 bg-emerald-100 text-emerald-800 rounded">
                                  ✓ {s}
                                </span>
                              ))}
                            </div>
                          )}

                          {app.aiParsedCv.missingSkills && app.aiParsedCv.missingSkills.length > 0 && (
                            <div className="flex flex-wrap items-center gap-1">
                              <span className="font-semibold text-rose-700">Missing Gaps:</span>
                              {app.aiParsedCv.missingSkills.map((s, i) => (
                                <span key={i} className="px-1.5 py-0.5 bg-rose-100 text-rose-800 rounded">
                                  ✗ {s}
                                </span>
                              ))}
                            </div>
                          )}
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              )}
            </div>

            {/* Footer */}
            <div className="p-4 border-t border-slate-200 bg-slate-50 flex items-center justify-end">
              <button
                onClick={() => setViewingApplicantsJob(null)}
                className="px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-200 rounded-lg transition-colors"
              >
                Close
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
