"use client";

import { useEffect, useState, useMemo } from "react";
import { formatTimestamp } from "@/lib/formatters";
import {
  fetchAuditLogs,
  AuditLogRecord,
} from "@/lib/audit-service";

export default function AuditLogsPage() {
  const [logs, setLogs] = useState<AuditLogRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [targetTypeFilter, setTargetTypeFilter] = useState<string>("ALL");
  const [searchQuery, setSearchQuery] = useState("");
  const [selectedLog, setSelectedLog] = useState<AuditLogRecord | null>(null);

  const loadData = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await fetchAuditLogs({ targetType: targetTypeFilter });
      setLogs(data);
    } catch (err: any) {
      console.error(err);
      setError(err.message || "Failed to load audit logs");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [targetTypeFilter]);

  const filteredLogs = useMemo(() => {
    return logs.filter((l) => {
      const q = searchQuery.toLowerCase();
      const matchAction = l.action.toLowerCase().includes(q);
      const matchActor = l.actorId.toLowerCase().includes(q);
      const matchTarget = (l.targetId?.toLowerCase() || "").includes(q);
      const matchMeta = JSON.stringify(l.metadata || {}).toLowerCase().includes(q);
      return matchAction || matchActor || matchTarget || matchMeta;
    });
  }, [logs, searchQuery]);

  const getActionBadge = (action: string) => {
    if (action.includes("APPROVED") || action.includes("PUBLISHED")) {
      return (
        <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-800 border border-emerald-300">
          {action}
        </span>
      );
    }
    if (action.includes("REJECTED") || action.includes("DELETED") || action.includes("TERMINATED")) {
      return (
        <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold bg-rose-100 text-rose-800 border border-rose-300">
          {action}
        </span>
      );
    }
    if (action.includes("ROLE") || action.includes("UPDATE")) {
      return (
        <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold bg-indigo-100 text-indigo-800 border border-indigo-300">
          {action}
        </span>
      );
    }
    return (
      <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-semibold bg-slate-100 text-slate-700 border border-slate-300">
        {action}
      </span>
    );
  };

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 tracking-tight">Platform Audit & Security Logs</h1>
          <p className="text-sm text-slate-500 mt-1">
            Immutable, append-only records of all critical administrative actions and system events.
          </p>
        </div>
        <button
          onClick={loadData}
          disabled={loading}
          className="inline-flex items-center gap-2 px-4 py-2 bg-white border border-slate-300 text-slate-700 text-sm font-medium rounded-lg hover:bg-slate-50 shadow-sm transition-colors"
        >
          {loading ? "Refreshing..." : "Refresh Audit Trail"}
        </button>
      </div>

      {/* Filter & Search */}
      <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm flex flex-col md:flex-row items-stretch md:items-center justify-between gap-4">
        <div className="flex flex-wrap items-center gap-2">
          {["ALL", "COMPANY", "USER", "JOB", "EXAM", "SYSTEM"].map((t) => (
            <button
              key={t}
              onClick={() => setTargetTypeFilter(t)}
              className={`px-3 py-1.5 text-xs font-semibold rounded-lg transition-colors ${
                targetTypeFilter === t
                  ? "bg-slate-900 text-white shadow-sm"
                  : "bg-slate-100 text-slate-600 hover:bg-slate-200"
              }`}
            >
              {t === "ALL" ? "All Targets" : t}
            </button>
          ))}
        </div>

        <div className="w-full md:w-80">
          <input
            type="text"
            placeholder="Search by action, actor, target ID..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full px-3 py-2 text-sm border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
          />
        </div>
      </div>

      {/* Audit Logs Table */}
      <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
        {loading ? (
          <div className="py-20 flex flex-col items-center justify-center gap-3">
            <div className="w-8 h-8 border-4 border-indigo-600 border-t-transparent rounded-full animate-spin"></div>
            <p className="text-sm text-slate-500 font-medium">Loading audit records from Firebase Firestore...</p>
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
        ) : filteredLogs.length === 0 ? (
          <div className="py-16 text-center text-slate-500 text-sm">
            No audit logs found matching the selected filter criteria.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-slate-200 bg-slate-50/75 text-xs font-semibold text-slate-500 uppercase tracking-wider">
                  <th className="py-3.5 px-4">Timestamp</th>
                  <th className="py-3.5 px-4">Action</th>
                  <th className="py-3.5 px-4">Actor</th>
                  <th className="py-3.5 px-4">Target Type & ID</th>
                  <th className="py-3.5 px-4">Details / Metadata</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200 text-sm">
                {filteredLogs.map((log) => (
                  <tr key={log.id} className="hover:bg-slate-50/60 transition-colors">
                    <td className="py-4 px-4 whitespace-nowrap text-xs text-slate-500 font-mono">
                      {formatTimestamp(
                        log.timestamp,
                        "en-US",
                        { dateStyle: "medium", timeStyle: "short" },
                        "Just now"
                      )}
                    </td>
                    <td className="py-4 px-4 whitespace-nowrap">
                      {getActionBadge(log.action)}
                    </td>
                    <td className="py-4 px-4 whitespace-nowrap">
                      <div className="flex items-center gap-1.5">
                        <span className="px-1.5 py-0.5 rounded text-[11px] font-bold bg-slate-200 text-slate-700">
                          {log.actorRole}
                        </span>
                        <span className="text-xs text-slate-500 font-mono">
                          {log.actorId.slice(0, 10)}...
                        </span>
                      </div>
                    </td>
                    <td className="py-4 px-4 whitespace-nowrap">
                      <div className="text-xs font-medium text-slate-800">{log.targetType}</div>
                      {log.targetId && (
                        <div className="text-[11px] text-slate-400 font-mono">{log.targetId.slice(0, 16)}...</div>
                      )}
                    </td>
                    <td className="py-4 px-4">
                      {log.metadata && Object.keys(log.metadata).length > 0 ? (
                        <button
                          onClick={() => setSelectedLog(log)}
                          className="px-2 py-1 text-xs font-mono text-indigo-600 bg-indigo-50 hover:bg-indigo-100 rounded transition-colors"
                        >
                          View Meta ({Object.keys(log.metadata).length} fields)
                        </button>
                      ) : (
                        <span className="text-xs text-slate-400">None</span>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>

      {/* Metadata Detail Modal */}
      {selectedLog && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 backdrop-blur-sm p-4 overflow-y-auto">
          <div className="bg-white rounded-2xl max-w-lg w-full shadow-2xl overflow-hidden border border-slate-200 animate-in fade-in zoom-in-95 duration-150 my-8">
            <div className="p-6 border-b border-slate-200 flex items-start justify-between">
              <div>
                <h3 className="text-lg font-bold text-slate-900">Audit Log Event Payload</h3>
                <p className="text-xs text-slate-500 mt-1">
                  Action: <span className="font-semibold text-slate-700">{selectedLog.action}</span>
                </p>
              </div>
              <button
                onClick={() => setSelectedLog(null)}
                className="text-slate-400 hover:text-slate-600 text-xl font-bold p-1"
              >
                ✕
              </button>
            </div>

            <div className="p-6 space-y-3">
              <div className="bg-slate-900 text-slate-100 p-4 rounded-xl font-mono text-xs overflow-x-auto max-h-80">
                <pre>{JSON.stringify(selectedLog.metadata, null, 2)}</pre>
              </div>
            </div>

            <div className="p-4 border-t border-slate-200 bg-slate-50 flex items-center justify-end">
              <button
                onClick={() => setSelectedLog(null)}
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
