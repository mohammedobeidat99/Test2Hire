"use client";

import { useEffect, useState, useMemo } from "react";
import { sanitizeExternalUrl } from "@/lib/formatters";
import {
  fetchCompanies,
  reviewCompany,
  CompanyRecord,
  CompanyVerificationStatus,
} from "@/lib/company-service";

export default function CompaniesPage() {
  const [companies, setCompanies] = useState<CompanyRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [statusFilter, setStatusFilter] = useState<CompanyVerificationStatus | "ALL">("ALL");
  const [searchQuery, setSearchQuery] = useState("");
  
  // Review modal state
  const [selectedCompany, setSelectedCompany] = useState<CompanyRecord | null>(null);
  const [actionTargetStatus, setActionTargetStatus] = useState<CompanyVerificationStatus | null>(null);
  const [reviewNotes, setReviewNotes] = useState("");
  const [submittingAction, setSubmittingAction] = useState(false);
  const [modalError, setModalError] = useState<string | null>(null);
  const [actionMessage, setActionMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);

  const loadData = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await fetchCompanies(statusFilter);
      setCompanies(data);
    } catch (err: any) {
      console.error(err);
      setError(err.message || "Failed to load companies");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [statusFilter]);

  const filteredCompanies = useMemo(() => {
    return companies.filter((c) => {
      const matchSearch =
        c.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
        c.industry.toLowerCase().includes(searchQuery.toLowerCase()) ||
        c.contactEmail.toLowerCase().includes(searchQuery.toLowerCase());
      return matchSearch;
    });
  }, [companies, searchQuery]);

  const handleOpenReview = (company: CompanyRecord, status: CompanyVerificationStatus) => {
    setSelectedCompany(company);
    setActionTargetStatus(status);
    setReviewNotes(company.verificationNotes || "");
    setModalError(null);
  };

  const handleCloseModal = () => {
    setSelectedCompany(null);
    setActionTargetStatus(null);
    setReviewNotes("");
    setModalError(null);
  };

  const handleConfirmReview = async () => {
    if (!selectedCompany || !actionTargetStatus) return;

    try {
      setSubmittingAction(true);
      setActionMessage(null);
      setModalError(null);

      await reviewCompany({
        companyId: selectedCompany.id,
        status: actionTargetStatus,
        notes: reviewNotes.trim() || undefined,
      });

      setActionMessage({
        type: "success",
        text: `Successfully updated ${selectedCompany.name} to ${actionTargetStatus}.`,
      });

      // Optimistic update in list
      setCompanies((prev) =>
        prev.map((c) =>
          c.id === selectedCompany.id
            ? {
                ...c,
                verificationStatus: actionTargetStatus,
                verificationNotes: reviewNotes.trim(),
              }
            : c
        )
      );

      handleCloseModal();
    } catch (err: any) {
      console.error("Action failed:", err);
      const errMsg = err.message || "Failed to submit review decision.";
      setModalError(errMsg);
      setActionMessage({
        type: "error",
        text: errMsg,
      });
    } finally {
      setSubmittingAction(false);
    }
  };

  const getStatusBadge = (status: CompanyVerificationStatus) => {
    switch (status) {
      case "APPROVED":
        return (
          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-800 border border-emerald-300">
            Approved
          </span>
        );
      case "REJECTED":
        return (
          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-rose-100 text-rose-800 border border-rose-300">
            Rejected
          </span>
        );
      case "SUSPENDED":
        return (
          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-amber-100 text-amber-800 border border-amber-300">
            Suspended
          </span>
        );
      case "PENDING":
      default:
        return (
          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-blue-100 text-blue-800 border border-blue-300">
            Pending Review
          </span>
        );
    }
  };

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Company Moderation & Verification</h1>
          <p className="text-sm text-slate-500 mt-1">
            Review commercial legal documents, tax numbers, and approve or reject employer access.
          </p>
        </div>
        <button
          onClick={loadData}
          disabled={loading}
          className="inline-flex items-center gap-2 px-4 py-2 bg-white border border-slate-300 text-slate-700 text-sm font-medium rounded-lg hover:bg-slate-50 shadow-sm transition-colors"
        >
          {loading ? "Refreshing..." : "Refresh Records"}
        </button>
      </div>

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

      {/* Filters and Search Bar */}
      <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm flex flex-col md:flex-row items-stretch md:items-center justify-between gap-4">
        <div className="flex flex-wrap items-center gap-2">
          {(["ALL", "PENDING", "APPROVED", "REJECTED", "SUSPENDED"] as const).map((st) => (
            <button
              key={st}
              onClick={() => setStatusFilter(st)}
              className={`px-3 py-1.5 text-xs font-semibold rounded-lg transition-colors ${
                statusFilter === st
                  ? "bg-slate-900 text-white shadow-sm"
                  : "bg-slate-100 text-slate-600 hover:bg-slate-200"
              }`}
            >
              {st === "ALL" ? "All Companies" : st}
            </button>
          ))}
        </div>

        <div className="w-full md:w-72">
          <input
            type="text"
            placeholder="Search by name, industry, email..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full px-3 py-2 text-sm border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
          />
        </div>
      </div>

      {/* Table / List */}
      <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
        {loading ? (
          <div className="py-20 flex flex-col items-center justify-center gap-3">
            <div className="w-8 h-8 border-4 border-indigo-600 border-t-transparent rounded-full animate-spin"></div>
            <p className="text-sm text-slate-500 font-medium">Loading companies from directory...</p>
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
        ) : filteredCompanies.length === 0 ? (
          <div className="py-16 text-center text-slate-500 text-sm">
            No companies found matching the selected filter criteria.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-slate-200 bg-slate-50/75 text-xs font-semibold text-slate-500 uppercase tracking-wider">
                  <th className="py-3.5 px-4">Company</th>
                  <th className="py-3.5 px-4">Industry / Size</th>
                  <th className="py-3.5 px-4">Legal Registration</th>
                  <th className="py-3.5 px-4">Status</th>
                  <th className="py-3.5 px-4 text-right">Moderation Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200 text-sm">
                {filteredCompanies.map((company) => (
                  <tr key={company.id} className="hover:bg-slate-50/60 transition-colors">
                    <td className="py-4 px-4">
                      <div className="font-semibold text-slate-900">{company.name}</div>
                      <div className="text-xs text-slate-500 flex items-center gap-2 mt-0.5">
                        <span>{company.city ? `${company.city}, ${company.country}` : "Location not set"}</span>
                        {(() => {
                          const safeSite = sanitizeExternalUrl(company.website);
                          return safeSite ? (
                            <a
                              href={safeSite}
                              target="_blank"
                              rel="noopener noreferrer"
                              className="text-indigo-600 hover:underline inline-flex items-center"
                            >
                              Website &nearr;
                            </a>
                          ) : null;
                        })()}
                      </div>
                      <div className="text-xs text-slate-400 mt-0.5">{company.contactEmail}</div>
                    </td>

                    <td className="py-4 px-4">
                      <div className="text-slate-800 font-medium">{company.industry}</div>
                      <div className="text-xs text-slate-500">{company.size} employees</div>
                    </td>

                    <td className="py-4 px-4">
                      <div className="text-xs">
                        <span className="text-slate-500">Commercial Reg:</span>{" "}
                        <span className="font-mono font-medium text-slate-700">
                          {company.commercialRegister || "Not provided"}
                        </span>
                      </div>
                      <div className="text-xs mt-0.5">
                        <span className="text-slate-500">Tax Number:</span>{" "}
                        <span className="font-mono font-medium text-slate-700">
                          {company.taxNumber || "Not provided"}
                        </span>
                      </div>
                    </td>

                    <td className="py-4 px-4">
                      {getStatusBadge(company.verificationStatus)}
                      {company.verificationNotes && (
                        <p className="text-xs text-slate-500 mt-1 max-w-xs truncate" title={company.verificationNotes}>
                          Notes: {company.verificationNotes}
                        </p>
                      )}
                    </td>

                    <td className="py-4 px-4 text-right">
                      <div className="inline-flex items-center gap-1.5">
                        {company.verificationStatus !== "APPROVED" && (
                          <button
                            onClick={() => handleOpenReview(company, "APPROVED")}
                            className="px-2.5 py-1 text-xs font-semibold bg-emerald-600 hover:bg-emerald-700 text-white rounded-md transition-colors"
                          >
                            Approve
                          </button>
                        )}
                        {company.verificationStatus !== "REJECTED" && (
                          <button
                            onClick={() => handleOpenReview(company, "REJECTED")}
                            className="px-2.5 py-1 text-xs font-semibold bg-rose-600 hover:bg-rose-700 text-white rounded-md transition-colors"
                          >
                            Reject
                          </button>
                        )}
                        {company.verificationStatus === "APPROVED" && (
                          <button
                            onClick={() => handleOpenReview(company, "SUSPENDED")}
                            className="px-2.5 py-1 text-xs font-semibold bg-amber-600 hover:bg-amber-700 text-white rounded-md transition-colors"
                          >
                            Suspend
                          </button>
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

      {/* Review Modal Dialog */}
      {selectedCompany && actionTargetStatus && (
        <div className="fixed inset-0 z-50 bg-black/60 flex items-center justify-center p-4 backdrop-blur-sm overflow-y-auto">
          <div className="bg-white rounded-2xl max-w-lg w-full p-6 shadow-2xl border border-slate-200 my-8">
            <h3 className="text-lg font-bold text-slate-900 mb-1">
              Confirm Verification: {actionTargetStatus}
            </h3>
            <p className="text-sm text-slate-600 mb-4">
              You are setting the status for <span className="font-semibold text-slate-900">{selectedCompany.name}</span> to{" "}
              <span className="font-bold">{actionTargetStatus}</span>. This will update their authentication claims and notify their account.
            </p>

            {modalError && (
              <div className="mb-4 p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs font-semibold">
                {modalError}
              </div>
            )}

            <div className="space-y-3 mb-5 bg-slate-50 p-3.5 rounded-xl border border-slate-200 text-xs">
              <div><strong className="text-slate-700">Commercial Registration:</strong> {selectedCompany.commercialRegister || "None"}</div>
              <div><strong className="text-slate-700">Tax Number:</strong> {selectedCompany.taxNumber || "None"}</div>
              <div><strong className="text-slate-700">Email:</strong> {selectedCompany.contactEmail}</div>
              {selectedCompany.description && (
                <div><strong className="text-slate-700">About:</strong> {selectedCompany.description}</div>
              )}
            </div>

            <div className="space-y-2 mb-6">
              <label className="block text-xs font-semibold text-slate-700">
                Decision Notes / Reason {actionTargetStatus === "REJECTED" && <span className="text-rose-500">*</span>}
              </label>
              <textarea
                rows={3}
                value={reviewNotes}
                onChange={(e) => setReviewNotes(e.target.value)}
                placeholder="Add explanatory notes for the company (e.g. invalid commercial registration, missing tax certificate)..."
                className="w-full text-sm p-2.5 border border-slate-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
              />
            </div>

            <div className="flex items-center justify-end gap-3">
              <button
                type="button"
                onClick={handleCloseModal}
                disabled={submittingAction}
                className="px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-100 rounded-lg transition-colors"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleConfirmReview}
                disabled={submittingAction || (actionTargetStatus === "REJECTED" && !reviewNotes.trim())}
                className={`px-5 py-2 text-sm font-semibold text-white rounded-lg transition-colors ${
                  actionTargetStatus === "APPROVED"
                    ? "bg-emerald-600 hover:bg-emerald-700"
                    : actionTargetStatus === "REJECTED"
                    ? "bg-rose-600 hover:bg-rose-700"
                    : "bg-amber-600 hover:bg-amber-700"
                } ${submittingAction ? "opacity-60 cursor-not-allowed" : ""}`}
              >
                {submittingAction ? "Processing..." : `Confirm ${actionTargetStatus}`}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
