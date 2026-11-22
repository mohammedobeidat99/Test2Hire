"use client";

import { useEffect, useState, useMemo } from "react";
import { formatTimestamp } from "@/lib/formatters";
import {
  fetchUsers,
  updateUserRole,
  toggleUserSuspension,
  UserRecord,
  UserRole,
} from "@/lib/user-service";

export default function UsersPage() {
  const [users, setUsers] = useState<UserRecord[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [roleFilter, setRoleFilter] = useState<UserRole | "ALL">("ALL");
  const [searchQuery, setSearchQuery] = useState("");

  // Role Edit Modal State
  const [selectedUser, setSelectedUser] = useState<UserRecord | null>(null);
  const [newRole, setNewRole] = useState<UserRole>("USER");
  const [submittingAction, setSubmittingAction] = useState(false);
  const [actionMessage, setActionMessage] = useState<{ type: "success" | "error"; text: string } | null>(null);

  // Suspend User Modal State
  const [suspendModalUser, setSuspendModalUser] = useState<UserRecord | null>(null);
  const [suspendReason, setSuspendReason] = useState("");
  const [modalError, setModalError] = useState<string | null>(null);

  const loadData = async () => {
    try {
      setLoading(true);
      setError(null);
      const data = await fetchUsers(roleFilter);
      setUsers(data);
    } catch (err: any) {
      console.error(err);
      setError(err.message || "Failed to load users");
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    loadData();
  }, [roleFilter]);

  const filteredUsers = useMemo(() => {
    return users.filter((u) => {
      const q = searchQuery.toLowerCase();
      const matchName = u.fullName.toLowerCase().includes(q);
      const matchEmail = u.email.toLowerCase().includes(q);
      const matchUid = u.uid.toLowerCase().includes(q);
      return matchName || matchEmail || matchUid;
    });
  }, [users, searchQuery]);

  const handleOpenRoleModal = (user: UserRecord) => {
    setSelectedUser(user);
    setNewRole(user.role);
    setModalError(null);
  };

  const handleConfirmRoleChange = async () => {
    if (!selectedUser) return;
    try {
      setSubmittingAction(true);
      setActionMessage(null);
      setModalError(null);

      await updateUserRole(selectedUser.uid, newRole);

      setActionMessage({
        type: "success",
        text: `Role for ${selectedUser.email || selectedUser.fullName} updated to ${newRole} in Firebase Auth & Firestore.`,
      });

      setUsers((prev) =>
        prev.map((u) => (u.uid === selectedUser.uid ? { ...u, role: newRole } : u))
      );

      setSelectedUser(null);
    } catch (err: any) {
      console.error("Failed to update user role:", err);
      const errMsg = err.message || "Failed to update user role.";
      setModalError(errMsg);
      setActionMessage({
        type: "error",
        text: errMsg,
      });
    } finally {
      setSubmittingAction(false);
    }
  };

  const handleToggleSuspension = async (user: UserRecord, isSuspending: boolean) => {
    try {
      setSubmittingAction(true);
      setActionMessage(null);
      setModalError(null);

      await toggleUserSuspension(user.uid, isSuspending, isSuspending ? suspendReason.trim() : undefined);

      setActionMessage({
        type: "success",
        text: isSuspending
          ? `User ${user.email || user.fullName} account was suspended and notification dispatched.`
          : `User ${user.email || user.fullName} account has been reactivated.`,
      });

      setUsers((prev) =>
        prev.map((u) =>
          u.uid === user.uid
            ? {
                ...u,
                isSuspended: isSuspending,
                status: isSuspending ? "SUSPENDED" : "ACTIVE",
                suspendReason: isSuspending ? suspendReason.trim() : undefined,
              }
            : u
        )
      );

      setSuspendModalUser(null);
      setSuspendReason("");
    } catch (err: any) {
      console.error("Failed to toggle suspension:", err);
      const errMsg = err.message || "Failed to update user suspension status.";
      setModalError(errMsg);
      setActionMessage({
        type: "error",
        text: errMsg,
      });
    } finally {
      setSubmittingAction(false);
    }
  };

  const stats = useMemo(() => {
    return {
      total: users.length,
      candidates: users.filter((u) => u.role === "USER").length,
      companies: users.filter((u) => u.role === "COMPANY").length,
      admins: users.filter((u) => u.role === "ADMIN").length,
    };
  }, [users]);

  const getRoleBadge = (role: UserRole) => {
    switch (role) {
      case "ADMIN":
        return (
          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-purple-100 text-purple-800 border border-purple-300">
            Admin
          </span>
        );
      case "COMPANY":
        return (
          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-blue-100 text-blue-800 border border-blue-300">
            Employer / Company
          </span>
        );
      case "USER":
      default:
        return (
          <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-slate-100 text-slate-800 border border-slate-300">
            Candidate
          </span>
        );
    }
  };

  return (
    <div className="space-y-6">
      {/* Page Header */}
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-slate-900 tracking-tight">User Identity & Access Management</h1>
          <p className="text-sm text-slate-500 mt-1">
            Manage candidate profiles, employer accounts, and administrative custom claims directly via Firebase.
          </p>
        </div>
        <button
          onClick={loadData}
          disabled={loading}
          className="inline-flex items-center gap-2 px-4 py-2 bg-white border border-slate-300 text-slate-700 text-sm font-medium rounded-lg hover:bg-slate-50 shadow-sm transition-colors"
        >
          {loading ? "Refreshing..." : "Refresh Users"}
        </button>
      </div>

      {/* Action Notification (floating over modals) */}
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
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">
          <div className="text-xs font-medium text-slate-500 uppercase">Registered Users</div>
          <div className="text-2xl font-bold text-slate-900 mt-1">{stats.total}</div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">
          <div className="text-xs font-medium text-slate-600 uppercase">Candidates (USER)</div>
          <div className="text-2xl font-bold text-slate-800 mt-1">{stats.candidates}</div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">
          <div className="text-xs font-medium text-blue-600 uppercase">Employers (COMPANY)</div>
          <div className="text-2xl font-bold text-blue-700 mt-1">{stats.companies}</div>
        </div>
        <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm">
          <div className="text-xs font-medium text-purple-600 uppercase">Administrators</div>
          <div className="text-2xl font-bold text-purple-700 mt-1">{stats.admins}</div>
        </div>
      </div>

      {/* Filter & Search */}
      <div className="bg-white p-4 rounded-xl border border-slate-200 shadow-sm flex flex-col md:flex-row items-stretch md:items-center justify-between gap-4">
        <div className="flex flex-wrap items-center gap-2">
          {(["ALL", "USER", "COMPANY", "ADMIN"] as const).map((r) => (
            <button
              key={r}
              onClick={() => setRoleFilter(r)}
              className={`px-3 py-1.5 text-xs font-semibold rounded-lg transition-colors ${
                roleFilter === r
                  ? "bg-slate-900 text-white shadow-sm"
                  : "bg-slate-100 text-slate-600 hover:bg-slate-200"
              }`}
            >
              {r === "ALL" ? "All Roles" : r === "USER" ? "Candidates" : r === "COMPANY" ? "Employers" : "Admins"}
            </button>
          ))}
        </div>

        <div className="w-full md:w-80">
          <input
            type="text"
            placeholder="Search by name, email, or UID..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="w-full px-3 py-2 text-sm border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:border-indigo-500"
          />
        </div>
      </div>

      {/* Users Table */}
      <div className="bg-white rounded-xl border border-slate-200 shadow-sm overflow-hidden">
        {loading ? (
          <div className="py-20 flex flex-col items-center justify-center gap-3">
            <div className="w-8 h-8 border-4 border-indigo-600 border-t-transparent rounded-full animate-spin"></div>
            <p className="text-sm text-slate-500 font-medium">Loading user directory from Firebase Firestore...</p>
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
        ) : filteredUsers.length === 0 ? (
          <div className="py-16 text-center text-slate-500 text-sm">
            No users found matching the selected filter criteria.
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-left border-collapse">
              <thead>
                <tr className="border-b border-slate-200 bg-slate-50/75 text-xs font-semibold text-slate-500 uppercase tracking-wider">
                  <th className="py-3.5 px-4">User</th>
                  <th className="py-3.5 px-4">Email</th>
                  <th className="py-3.5 px-4">Current Role</th>
                  <th className="py-3.5 px-4">Profile</th>
                  <th className="py-3.5 px-4">Account Status</th>
                  <th className="py-3.5 px-4">Registered Date</th>
                  <th className="py-3.5 px-4 text-right">Actions</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-slate-200 text-sm">
                {filteredUsers.map((user) => (
                  <tr key={user.uid} className="hover:bg-slate-50/60 transition-colors">
                    <td className="py-4 px-4">
                      <div className="flex items-center gap-3">
                        <div className="w-8 h-8 rounded-full bg-slate-200 text-slate-700 flex items-center justify-center font-bold text-xs uppercase">
                          {user.fullName ? user.fullName[0] : user.email ? user.email[0] : "U"}
                        </div>
                        <div>
                          <div className="font-semibold text-slate-900">{user.fullName || "Unnamed User"}</div>
                          <div className="text-[11px] text-slate-400 font-mono">UID: {user.uid}</div>
                        </div>
                      </div>
                    </td>
                    <td className="py-4 px-4 text-xs text-slate-600 whitespace-nowrap">
                      {user.email || "No email on record"}
                    </td>
                    <td className="py-4 px-4 whitespace-nowrap">
                      {getRoleBadge(user.role)}
                    </td>
                    <td className="py-4 px-4 whitespace-nowrap">
                      {user.isProfileComplete ? (
                        <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-emerald-50 text-emerald-700">
                          Complete
                        </span>
                      ) : (
                        <span className="inline-flex items-center px-2 py-0.5 rounded-full text-xs font-medium bg-amber-50 text-amber-700">
                          Incomplete
                        </span>
                      )}
                    </td>
                    <td className="py-4 px-4 whitespace-nowrap">
                      {user.isSuspended ? (
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-rose-100 text-rose-800 border border-rose-300">
                          Suspended
                        </span>
                      ) : (
                        <span className="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-800 border border-emerald-300">
                          Active
                        </span>
                      )}
                    </td>
                    <td className="py-4 px-4 whitespace-nowrap text-xs text-slate-500">
                      {formatTimestamp(user.createdAt, "en-US")}
                    </td>
                    <td className="py-4 px-4 text-right whitespace-nowrap">
                      <div className="inline-flex items-center justify-end gap-2">
                        <button
                          onClick={() => handleOpenRoleModal(user)}
                          className="px-2.5 py-1 text-xs font-medium text-indigo-600 bg-indigo-50 hover:bg-indigo-100 rounded-md transition-colors"
                        >
                          Role
                        </button>
                        {user.isSuspended ? (
                          <button
                            onClick={() => handleToggleSuspension(user, false)}
                            disabled={submittingAction}
                            className="px-2.5 py-1 text-xs font-medium text-emerald-700 bg-emerald-50 hover:bg-emerald-100 rounded-md transition-colors"
                          >
                            Reactivate
                          </button>
                        ) : (
                          <button
                            onClick={() => {
                              setSuspendModalUser(user);
                              setSuspendReason("");
                              setModalError(null);
                            }}
                            disabled={submittingAction}
                            className="px-2.5 py-1 text-xs font-medium text-rose-700 bg-rose-50 hover:bg-rose-100 rounded-md transition-colors"
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

      {/* Role Management Modal */}
      {selectedUser && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 backdrop-blur-sm p-4 overflow-y-auto">
          <div className="bg-white rounded-2xl max-w-md w-full shadow-2xl overflow-hidden border border-slate-200 animate-in fade-in zoom-in-95 duration-150 my-8">
            <div className="p-6 border-b border-slate-200 flex items-start justify-between">
              <div>
                <h3 className="text-lg font-bold text-slate-900">Modify User Role</h3>
                <p className="text-xs text-slate-500 mt-1">
                  Target: <span className="font-semibold text-slate-700">{selectedUser.email || selectedUser.fullName}</span>
                </p>
              </div>
              <button
                onClick={() => setSelectedUser(null)}
                className="text-slate-400 hover:text-slate-600 text-xl font-bold p-1"
              >
                ✕
              </button>
            </div>

            <div className="p-6 space-y-4 text-sm text-slate-700">
              {modalError && (
                <div className="p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs font-semibold">
                  {modalError}
                </div>
              )}
              <div>
                <label className="block text-xs font-semibold text-slate-600 uppercase mb-2">
                  Select Target Role
                </label>
                <div className="space-y-2">
                  {[
                    { id: "USER", title: "Candidate (USER)", desc: "Standard candidate job seeker access." },
                    { id: "COMPANY", title: "Employer (COMPANY)", desc: "Recruiter / company portal access to post jobs & exams." },
                    { id: "ADMIN", title: "Platform Admin (ADMIN)", desc: "Full administrative access with elevated claims." },
                  ].map((item) => (
                    <label
                      key={item.id}
                      className={`flex items-start gap-3 p-3 rounded-xl border cursor-pointer transition-colors ${
                        newRole === item.id
                          ? "border-indigo-600 bg-indigo-50/50"
                          : "border-slate-200 hover:bg-slate-50"
                      }`}
                    >
                      <input
                        type="radio"
                        name="userRole"
                        value={item.id}
                        checked={newRole === item.id}
                        onChange={(e) => setNewRole(e.target.value as UserRole)}
                        className="mt-0.5 text-indigo-600 focus:ring-indigo-500"
                      />
                      <div>
                        <div className="font-semibold text-slate-900">{item.title}</div>
                        <div className="text-xs text-slate-500">{item.desc}</div>
                      </div>
                    </label>
                  ))}
                </div>
              </div>

              <div className="p-3 bg-amber-50 rounded-xl border border-amber-200 text-xs text-amber-800">
                ⚠ Changing this role immediately syncs Firebase Auth Custom Claims (`request.auth.token.role`) and updates Firestore security privileges.
              </div>
            </div>

            <div className="p-4 border-t border-slate-200 bg-slate-50 flex items-center justify-end gap-3">
              <button
                type="button"
                onClick={() => setSelectedUser(null)}
                disabled={submittingAction}
                className="px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-200 rounded-lg transition-colors"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleConfirmRoleChange}
                disabled={submittingAction || newRole === selectedUser.role}
                className="px-4 py-2 text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 rounded-lg shadow-sm transition-colors"
              >
                {submittingAction ? "Updating Claims..." : "Save Role Assignment"}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Suspend Confirmation Modal */}
      {suspendModalUser && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-slate-900/60 backdrop-blur-sm p-4 overflow-y-auto">
          <div className="bg-white rounded-2xl max-w-md w-full shadow-2xl overflow-hidden border border-slate-200 animate-in fade-in zoom-in-95 duration-150 my-8">
            <div className="p-6 border-b border-slate-200 flex items-start justify-between bg-rose-50/50">
              <div className="flex items-center gap-3">
                <div className="w-10 h-10 rounded-full bg-rose-100 text-rose-600 flex items-center justify-center text-lg font-bold">
                  ⚠
                </div>
                <div>
                  <h3 className="text-lg font-bold text-slate-900">Suspend User Account</h3>
                  <p className="text-xs text-slate-500 mt-0.5">
                    Target: <span className="font-semibold text-slate-700">{suspendModalUser.email || suspendModalUser.fullName}</span>
                  </p>
                </div>
              </div>
              <button
                onClick={() => setSuspendModalUser(null)}
                className="text-slate-400 hover:text-slate-600 text-xl font-bold p-1"
              >
                ✕
              </button>
            </div>

            <div className="p-6 space-y-4 text-sm text-slate-700">
              {modalError && (
                <div className="p-3 rounded-xl bg-rose-50 border border-rose-200 text-rose-700 text-xs font-semibold">
                  {modalError}
                </div>
              )}

              <p className="text-slate-600 text-xs leading-relaxed">
                Confirming account suspension will revoke sign-in access in <strong>Firebase Auth</strong> and dispatch a push notification informing the user.
              </p>

              <div>
                <label className="block text-xs font-semibold text-slate-600 uppercase mb-2">
                  Suspension Reason (shown to user in notification):
                </label>
                <textarea
                  value={suspendReason}
                  onChange={(e) => setSuspendReason(e.target.value)}
                  placeholder="e.g. Policy violation, suspicious activity, repeated abuse reports..."
                  rows={3}
                  className="w-full px-3 py-2 text-sm border border-slate-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-rose-500 focus:border-rose-500"
                />
              </div>
            </div>

            <div className="p-4 border-t border-slate-200 bg-slate-50 flex items-center justify-end gap-3">
              <button
                type="button"
                onClick={() => setSuspendModalUser(null)}
                disabled={submittingAction}
                className="px-4 py-2 text-sm font-medium text-slate-700 hover:bg-slate-200 rounded-lg transition-colors"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={() => handleToggleSuspension(suspendModalUser, true)}
                disabled={submittingAction}
                className="px-4 py-2 text-sm font-medium text-white bg-rose-600 hover:bg-rose-700 disabled:opacity-50 rounded-lg shadow-sm transition-colors"
              >
                {submittingAction ? "Suspending..." : "Confirm Suspend & Notify"}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
