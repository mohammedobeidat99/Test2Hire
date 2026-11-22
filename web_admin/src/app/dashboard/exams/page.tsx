"use client";

import { useEffect, useState, useMemo } from "react";
import { formatTimestamp } from "@/lib/formatters";
import {
  fetchExams,
  fetchExamAttempts,
  toggleExamArchive,
  deleteExam,
  ExamRecord,
  ExamAttemptRecord,
} from "@/lib/exam-service";

export default function ExamsPage() {
  const [exams, setExams] = useState<ExamRecord[]>([]);
  const [attempts, setAttempts] = useState<ExamAttemptRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<"TEMPLATES" | "ATTEMPTS">("TEMPLATES");
  const [searchQuery, setSearchQuery] = useState("");

  const [actionLoading, setActionLoading] = useState(false);
  const [actionMessage, setActionMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);

  const loadData = async () => {
    try {
      setLoading(true);
      setError(null);
      const [examsData, attemptsData] = await Promise.all([
        fetchExams(),
        fetchExamAttempts(),
      ]);
      setExams(examsData);
      setAttempts(attemptsData);
    } catch (err: any) {
      console.error(err);
      setError(err.message || "Failed to load exams");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  const filteredExams = useMemo(() => {
    return exams.filter((e) => {
      const q = searchQuery.toLowerCase();
      return (
        e.title.toLowerCase().includes(q) ||
        e.description.toLowerCase().includes(q) ||
        e.companyId.toLowerCase().includes(q)
      );
    });
  }, [exams, searchQuery]);

  const filteredAttempts = useMemo(() => {
    return attempts.filter((a) => {
      const q = searchQuery.toLowerCase();
      return (
        a.candidateId.toLowerCase().includes(q) ||
        a.examId.toLowerCase().includes(q) ||
        a.status.toLowerCase().includes(q)
      );
    });
  }, [attempts, searchQuery]);

  const handleToggleArchive = async (exam: ExamRecord) => {
    try {
      setActionLoading(true);
      setActionMessage(null);
      const newArchived = !exam.isArchived;
      await toggleExamArchive(exam.id, newArchived);
      setActionMessage({
        type: "success",
        text: `Exam "${exam.title}" was ${newArchived ? "archived" : "restored"}.`,
      });
      setExams((prev) =>
        prev.map((e) => (e.id === exam.id ? { ...e, isArchived: newArchived } : e))
      );
    } catch (err: any) {
      setActionMessage({
        type: "error",
        text: err.message || "Failed to update exam archive status.",
      });
    } finally {
      setActionLoading(false);
    }
  };

  const handleDeleteExam = async (exam: ExamRecord) => {
    if (!window.confirm(`Are you sure you want to permanently delete "${exam.title}"?`)) {
      return;
    }
    try {
      setActionLoading(true);
      setActionMessage(null);
      await deleteExam(exam.id);
      setActionMessage({
        type: "success",
        text: `Exam "${exam.title}" was permanently deleted.`,
      });
      setExams((prev) => prev.filter((e) => e.id !== exam.id));
    } catch (err: any) {
      setActionMessage({
        type: "error",
        text: err.message || "Failed to delete exam.",
      });
    } finally {
      setActionLoading(false);
    }
  };

  const stats = useMemo(() => {
    return {
      totalExams: exams.length,
      activeExams: exams.filter((e) => !e.isArchived).length,
      totalAttempts: attempts.length,
      flaggedAttempts: attempts.filter(
        (a) =>
          (a.violationsCount || 0) > 0 ||
          a.status === "TERMINATED_VIOLATION" ||
          a.status === "TERMINATED"
      ).length,
    };
  }, [exams, attempts]);

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Exam & Assessment Supervision</h1>
          <p className="text-sm text-slate-500 mt-1">
            Audit proctored exam templates, candidate attempt records, and anti-cheat violation telemetry.
          </p>
        </div>
        <button
          onClick={loadData}
          disabled={loading}
          className="inline-flex items-center gap-2 px-4 py-2 bg-white border border-slate-300 text-slate-700 text-sm font-medium rounded-lg hover:bg-slate-50 shadow-sm transition-colors"
        >
          {loading ? "Refreshing..." : "Refresh Exams"}
        </button>
      </div>

      {/* Action Notification Message */}
      {actionMessage && (
        <div
          className={`p-4 rounded-xl text-sm font-medium border flex items-center justify-between ${
            actionMessage.type === "success"
              ? "bg-emerald-50 text-emerald-800 border-emerald-200"
              : "bg-rose-50 text-rose-800 border-rose-200"
          }`}
        >
          <span>{actionMessage.text}</span>
          <button
            onClick={() => setActionMessage(null)}
            className="text-xs uppercase tracking-wider font-bold ml-4 hover:underline"
          >
            Dismiss
          </button>
        </div>
      )}

      {/* KPI Stats Bar */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">
          <div className="text-xs font-medium text-slate-500 uppercase">Exam Templates</div>
          <div className="text-2xl font-bold text-slate-900 mt-1">{stats.totalExams}</div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">
          <div className="text-xs font-medium text-emerald-600 uppercase">Active Templates</div>
          <div className="text-2xl font-bold text-emerald-700 mt-1">{stats.activeExams}</div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">
          <div className="text-xs font-medium text-indigo-600 uppercase">Total Sessions</div>
          <div className="text-2xl font-bold text-indigo-700 mt-1">{stats.totalAttempts}</div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">
          <div className="text-xs font-medium text-rose-600 uppercase">Flagged Violations</div>
          <div className="text-2xl font-bold text-rose-700 mt-1">{stats.flaggedAttempts}</div>
        </div>
      </div>

      {/* View Tabs & Search */}
      <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm flex flex-col md:flex-row items-stretch md:items-center justify-between gap-4">
        <div className="flex items-center gap-2 border-b md:border-b-0 pb-2 md:pb-0">
          <button
            onClick={() => setActiveTab("TEMPLATES")}
            className={`px-4 py-2 text-sm font-semibold rounded-lg transition-colors ${
              activeTab === "TEMPLATES"
                ? "bg-slate-900 text-white shadow-sm"
                : "bg-slate-100 text-slate-600 hover:bg-slate-200"
            }`}
          >
            Exam Templates ({exams.length})
          </button>
          <button
            onClick={() => setActiveTab("ATTEMPTS")}
            className={`px-4 py-2 text-sm font-semibold rounded-lg transition-colors ${
              activeTab === "ATTEMPTS"
                ? "bg-slate-900 text-white shadow-sm"
                : "bg-slate-100 text-slate-600 hover:bg-slate-200"
            }`}
          >
            Candidate Attempts ({attempts.length})
          </button>
        </div>

        <div className="w-full md:w-80">
          <input
            type="text"
            placeholder={
              activeTab === "TEMPLATES"
                ? "Search templates by title or company..."
                : "Search attempts by candidate, exam ID..."
            }
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full px-3 py-2 text-sm border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
          />
        </div>
      </div>

      {/* Content Section */}
      <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
        {loading ? (
          <div className="py-20 flex flex-col items-center justify-center gap-3">
            <div className="w-8 h-8 border-4 border-indigo-600 border-t-transparent rounded-full animate-spin"></div>
            <p className="text-sm text-slate-500 font-medium">Loading assessment records from Firebase Firestore...</p>
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
        ) : activeTab === "TEMPLATES" ? (
          filteredExams.length === 0 ? (
            <div className="py-16 text-center text-slate-500 text-sm">
              No exam templates found.
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="border-b border-slate-200 bg-slate-50/75 text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    <th className="py-3.5 px-4">Exam Title</th>
                    <th className="py-3.5 px-4">Duration & Passing</th>
                    <th className="py-3.5 px-4">Questions / Points</th>
                    <th className="py-3.5 px-4">Anti-Cheat</th>
                    <th className="py-3.5 px-4">Status</th>
                    <th className="py-3.5 px-4 text-right">Actions</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-200 text-sm">
                  {filteredExams.map((exam) => (
                    <tr key={exam.id} className="hover:bg-slate-50/60 transition-colors">
                      <td className="py-4 px-4">
                        <div className="font-semibold text-slate-900">{exam.title}</div>
                        <div className="text-xs text-slate-500 line-clamp-1 max-w-sm mt-0.5">
                          {exam.description || "No description provided."}
                        </div>
                        <div className="text-[11px] text-slate-400 mt-1 font-mono">
                          ID: {exam.id}
                        </div>
                      </td>
                      <td className="py-4 px-4 whitespace-nowrap">
                        <div className="text-xs font-medium text-slate-800">{exam.durationMinutes} mins</div>
                        <div className="text-xs text-slate-500">Pass mark: {exam.passingPercentage}%</div>
                      </td>
                      <td className="py-4 px-4 whitespace-nowrap">
                        <div className="text-xs font-medium text-slate-800">{exam.totalQuestions} Questions</div>
                        <div className="text-xs text-slate-500">{exam.totalPoints} Total Points</div>
                      </td>
                      <td className="py-4 px-4 whitespace-nowrap">
                        {exam.proctoringEnabled ? (
                          <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-emerald-50 text-emerald-700 border border-emerald-200">
                            Proctoring On
                          </span>
                        ) : (
                          <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-slate-100 text-slate-600">
                            Standard
                          </span>
                        )}
                      </td>
                      <td className="py-4 px-4 whitespace-nowrap">
                        {exam.isArchived ? (
                          <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold bg-rose-100 text-rose-800 border border-rose-200">
                            Archived
                          </span>
                        ) : (
                          <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-800 border border-emerald-200">
                            Active
                          </span>
                        )}
                      </td>
                      <td className="py-4 px-4 text-right whitespace-nowrap">
                        <div className="inline-flex items-center gap-2">
                          <button
                            disabled={actionLoading}
                            onClick={() => handleToggleArchive(exam)}
                            className="px-2.5 py-1 text-xs font-medium text-slate-700 bg-slate-100 hover:bg-slate-200 rounded-md transition-colors"
                          >
                            {exam.isArchived ? "Unarchive" : "Archive"}
                          </button>
                          <button
                            disabled={actionLoading}
                            onClick={() => handleDeleteExam(exam)}
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
          )
        ) : (
          filteredAttempts.length === 0 ? (
            <div className="py-16 text-center text-slate-500 text-sm">
              No candidate attempt sessions found.
            </div>
          ) : (
            <div className="overflow-x-auto">
              <table className="w-full text-left border-collapse">
                <thead>
                  <tr className="border-b border-slate-200 bg-slate-50/75 text-xs font-semibold text-slate-500 uppercase tracking-wider">
                    <th className="py-3.5 px-4">Attempt / Candidate UID</th>
                    <th className="py-3.5 px-4">Exam ID</th>
                    <th className="py-3.5 px-4">Status</th>
                    <th className="py-3.5 px-4">Score / Outcome</th>
                    <th className="py-3.5 px-4">Violations</th>
                    <th className="py-3.5 px-4">Date</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-200 text-sm">
                  {filteredAttempts.map((att) => (
                    <tr key={att.id} className="hover:bg-slate-50/60 transition-colors">
                      <td className="py-4 px-4">
                        <div className="font-mono text-xs font-medium text-slate-800">{att.candidateId || "Anonymous"}</div>
                        <div className="text-[11px] text-slate-400 font-mono mt-0.5">Attempt: {att.id.slice(0, 10)}...</div>
                      </td>
                      <td className="py-4 px-4 font-mono text-xs text-slate-600 whitespace-nowrap">
                        {att.examId.slice(0, 12)}...
                      </td>
                      <td className="py-4 px-4 whitespace-nowrap">
                        <span
                          className={`inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold ${
                            att.status === "COMPLETED"
                              ? "bg-emerald-100 text-emerald-800 border border-emerald-200"
                              : att.status === "IN_PROGRESS"
                              ? "bg-blue-100 text-blue-800 border border-blue-200"
                              : att.status === "TERMINATED_VIOLATION" || att.status === "TERMINATED"
                              ? "bg-rose-100 text-rose-800 border border-rose-200"
                              : "bg-slate-100 text-slate-700 border border-slate-200"
                          }`}
                        >
                          {att.status.replace(/_/g, " ")}
                        </span>
                      </td>
                      <td className="py-4 px-4 whitespace-nowrap">
                        {att.score !== undefined ? (
                          <div className="flex items-center gap-2">
                            <span className="font-bold text-slate-900">{att.score}%</span>
                            {att.passed !== undefined && (
                              <span
                                className={`text-[11px] font-semibold px-1.5 py-0.5 rounded ${
                                  att.passed
                                    ? "bg-emerald-50 text-emerald-700"
                                    : "bg-rose-50 text-rose-700"
                                }`}
                              >
                                {att.passed ? "PASSED" : "FAILED"}
                              </span>
                            )}
                          </div>
                        ) : (
                          <span className="text-xs text-slate-400">In Progress / Unscored</span>
                        )}
                      </td>
                      <td className="py-4 px-4 whitespace-nowrap">
                        {(att.violationsCount || 0) > 0 ? (
                          <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-bold bg-rose-100 text-rose-700 border border-rose-300">
                            ⚠ {att.violationsCount} Flagged
                          </span>
                        ) : (
                          <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-emerald-50 text-emerald-700">
                            Clean (0)
                          </span>
                        )}
                      </td>
                      <td className="py-4 px-4 whitespace-nowrap text-xs text-slate-500">
                        {formatTimestamp(att.createdAt, "en-US", {
                          dateStyle: "medium",
                          timeStyle: "short",
                        })}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )
        )}
      </div>
    </div>
  );
}
