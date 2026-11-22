import { onRequest } from "firebase-functions/v2/https";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { beforeUserCreated } from "firebase-functions/v2/identity";
import { onDocumentCreated, onDocumentUpdated, onDocumentDeleted } from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as crypto from "crypto";
import { db, auth, messaging } from "./config/firebase";
import { FieldPath, FieldValue, Timestamp } from "firebase-admin/firestore";
import { GoogleGenerativeAI } from "@google/generative-ai";

/**
 * Shared helpers for validation, cryptographic randomness, Firestore date parsing, and audit logs.
 */
function toDateOrNull(val: unknown): Date | null {
  if (!val) return null;
  if (val instanceof Date) {
    return Number.isNaN(val.getTime()) ? null : val;
  }
  if (typeof (val as { toDate?: unknown }).toDate === "function") {
    const d = (val as { toDate: () => Date }).toDate();
    return d instanceof Date && !Number.isNaN(d.getTime()) ? d : null;
  }
  if (typeof val === "string" || typeof val === "number") {
    const d = new Date(val);
    return Number.isNaN(d.getTime()) ? null : d;
  }
  return null;
}

function isAttemptWindowExpired(
  attempt: Record<string, any>,
  now: Date,
  submitGraceMs = 0
): boolean {
  const expiresAtDate = toDateOrNull(attempt.expiresAt);
  if (expiresAtDate && expiresAtDate.getTime() < now.getTime()) {
    return true;
  }
  const startedAtDate = toDateOrNull(attempt.startedAt);
  const durationMinutes = Number(attempt.durationMinutes) || 0;
  if (startedAtDate && durationMinutes > 0) {
    const hardDeadlineMs = startedAtDate.getTime() + durationMinutes * 60 * 1000 + submitGraceMs;
    if (hardDeadlineMs < now.getTime()) {
      return true;
    }
  }
  return false;
}

function shuffleArray<T>(items: T[]): T[] {
  const arr = [...items];
  for (let i = arr.length - 1; i > 0; i--) {
    const j = crypto.randomInt(0, i + 1);
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}

function sanitizeJsonResponse<T>(rawText: string): T {
  const stripped = rawText
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/```\s*$/i, "")
    .trim();
  try {
    return JSON.parse(stripped) as T;
  } catch {
    const objStart = stripped.indexOf("{");
    const objEnd = stripped.lastIndexOf("}");
    if (objStart !== -1 && objEnd > objStart) {
      return JSON.parse(stripped.slice(objStart, objEnd + 1)) as T;
    }
    const arrStart = stripped.indexOf("[");
    const arrEnd = stripped.lastIndexOf("]");
    if (arrStart !== -1 && arrEnd > arrStart) {
      return JSON.parse(stripped.slice(arrStart, arrEnd + 1)) as T;
    }
    throw new Error("Unable to parse JSON payload from AI response.");
  }
}

function isCallerAdmin(token: Record<string, any> | undefined): boolean {
  return (
    token?.role === "ADMIN" ||
    token?.role === "SUPERADMIN" ||
    token?.isAdmin === true
  );
}

async function writeAuditLog(entry: {
  actorId: string;
  actorRole: string;
  action: string;
  targetType: string;
  targetId?: string;
  metadata?: Record<string, any>;
}): Promise<void> {
  await db.collection("auditLogs").add({
    actorId: entry.actorId || "SYSTEM",
    actorRole: entry.actorRole || "SYSTEM",
    action: entry.action,
    targetType: entry.targetType,
    targetId: entry.targetId || "",
    metadata: entry.metadata || {},
    timestamp: FieldValue.serverTimestamp(),
  });
}

function sanitizeAnswerEntry(raw: any): {
  selectedOptionIds?: string[];
  textAnswer?: string;
  answer?: string;
} {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) {
    return {};
  }
  const clean: { selectedOptionIds?: string[]; textAnswer?: string; answer?: string } = {};
  if (Array.isArray(raw.selectedOptionIds)) {
    clean.selectedOptionIds = raw.selectedOptionIds
      .filter((id: any) => typeof id === "string" || typeof id === "number")
      .map((id: any) => String(id).trim().slice(0, 128))
      .filter((id: string) => id.length > 0)
      .slice(0, 50);
  }
  if (typeof raw.textAnswer === "string") {
    clean.textAnswer = raw.textAnswer.slice(0, 50000);
  }
  if (typeof raw.answer === "string" || typeof raw.answer === "number") {
    clean.answer = String(raw.answer).slice(0, 50000);
  }
  return clean;
}

function sanitizeProctoringSnapshot(
  raw: any,
  fallbackLabel = "SNAPSHOT"
): { label: string; timestamp: string; imageDataUrl: string } | null {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null;
  const url = typeof raw.imageDataUrl === "string" ? raw.imageDataUrl.trim() : "";
  if (!url.startsWith("data:image/") || url.length > 150000) {
    return null;
  }
  const label =
    typeof raw.label === "string" && raw.label.trim().length > 0
      ? raw.label.trim().slice(0, 80)
      : fallbackLabel;
  const timestamp =
    typeof raw.timestamp === "string" && raw.timestamp.trim().length > 0
      ? raw.timestamp.trim().slice(0, 64)
      : new Date().toISOString();
  return { label, timestamp, imageDataUrl: url };
}

function sanitizeProctoringReport(raw: any): Record<string, any> | null {
  if (!raw || typeof raw !== "object" || Array.isArray(raw)) return null;
  const snapshots = Array.isArray(raw.snapshots)
    ? raw.snapshots
        .map((s: any) => sanitizeProctoringSnapshot(s))
        .filter((s: any): s is NonNullable<typeof s> => s !== null)
        .slice(0, 12)
    : [];
  const violationEvents = Array.isArray(raw.violationEvents)
    ? raw.violationEvents
        .filter((v: any) => v && typeof v === "object")
        .slice(0, 20)
        .map((v: any) => ({
          type: String(v.type || "VIOLATION").trim().slice(0, 80),
          details: String(v.details || "").trim().slice(0, 300),
          timestamp: String(v.timestamp || new Date().toISOString()).trim().slice(0, 64),
        }))
    : [];
  const rawPeak = Number(raw.audioPeakLevel);
  return {
    cameraVerified: raw.cameraVerified === true,
    micVerified: raw.micVerified === true,
    audioPeakLevel: Number.isFinite(rawPeak) ? Math.max(0, Math.min(100, Math.round(rawPeak))) : 0,
    snapshotsCount: snapshots.length,
    snapshots,
    violationEvents,
    updatedAt: new Date().toISOString(),
  };
}

/**
 * Health check endpoint for Test2Hire Cloud Functions
 */
export const healthCheck = onRequest({ cors: true }, (req, res) => {
  logger.info("Test2Hire Cloud Functions health check requested", { structuredData: true });
  res.status(200).json({
    status: "ok",
    service: "Test2Hire Backend Functions",
    timestamp: new Date().toISOString(),
    version: "1.0.0",
  });
});

/**
 * Auth Blocking Trigger: Executes right before a new user is created in Firebase Auth.
 * Assigns custom claims based on user creation parameters.
 */
export const beforeCreateUser = beforeUserCreated(async (event) => {
  const user = event.data;
  if (!user) {
    return;
  }
  const requestedRole = (event.additionalUserInfo?.profile as any)?.role || "USER";
  const role = ["USER", "COMPANY"].includes(requestedRole) ? requestedRole : "USER";

  logger.info(`Assigning initial role claim '${role}' to user ${user.uid}`);

  return {
    customClaims: {
      role: role,
      isApproved: role === "COMPANY" ? false : true,
    },
  };
});

/**
 * Callable Function: Synchronizes Firestore User profile and claims upon registration.
 * Ensures consistent data between Auth Custom Claims and Firestore collection.
 */
export const syncUserProfile = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const uid = request.auth.uid;
  const email = request.auth.token.email || "";
  const rawRequestedRole = typeof request.data?.role === "string" ? request.data.role.trim().toUpperCase() : "";
  const fullName = typeof request.data?.fullName === "string" ? request.data.fullName.trim() : "";
  const companyName = typeof request.data?.companyName === "string" ? request.data.companyName.trim() : "";
  const industry = typeof request.data?.industry === "string" && request.data.industry.trim().length > 0
    ? request.data.industry.trim()
    : "Technology";
  const description = typeof request.data?.description === "string" ? request.data.description.trim() : "";

  if (rawRequestedRole && !["USER", "COMPANY"].includes(rawRequestedRole)) {
    throw new HttpsError("invalid-argument", "Invalid role specified.");
  }

  try {
    const [authUser, existingDoc] = await Promise.all([
      auth.getUser(uid),
      db.collection("users").doc(uid).get(),
    ]);
    const userRef = existingDoc.ref;
    const existingClaims = authUser.customClaims || {};
    const existingIsAdmin = isCallerAdmin(existingClaims);
    const claimRole = typeof existingClaims.role === "string" ? existingClaims.role.trim().toUpperCase() : "";
    const docRole = existingDoc.exists && typeof existingDoc.data()?.role === "string"
      ? String(existingDoc.data()!.role).trim().toUpperCase()
      : "";
    const existingRole = claimRole || docRole;

    if (existingIsAdmin) {
      const adminRole = claimRole || docRole || "ADMIN";
      if (rawRequestedRole && rawRequestedRole !== adminRole) {
        throw new HttpsError("permission-denied", "Cannot change an existing administrator account role.");
      }
    } else if (existingRole) {
      if (rawRequestedRole && rawRequestedRole !== existingRole) {
        throw new HttpsError("permission-denied", "Account role already exists and cannot be modified.");
      }
    } else if (existingDoc.exists && rawRequestedRole && rawRequestedRole !== "USER") {
      throw new HttpsError("permission-denied", "Cannot elevate role after user profile creation.");
    }

    const effectiveRole = existingIsAdmin
      ? String(claimRole || docRole || "ADMIN")
      : existingRole || (existingDoc.exists ? "USER" : (rawRequestedRole || "USER"));

    let isApproved = effectiveRole !== "COMPANY";
    if (effectiveRole === "COMPANY") {
      if (existingClaims.isApproved === true) {
        isApproved = true;
      } else {
        const companySnap = await db.collection("companies").doc(uid).get();
        isApproved = companySnap.exists && companySnap.data()?.verificationStatus === "APPROVED";
      }
    }

    // 1. Set Custom Claims on Firebase Auth token without stripping existing admin/approval claims
    await auth.setCustomUserClaims(uid, {
      ...existingClaims,
      role: effectiveRole,
      ...(existingIsAdmin ? { isAdmin: true } : {}),
      isApproved,
    });

    const userData: Record<string, any> = {
      uid: uid,
      email: email,
      role: effectiveRole,
      ...(fullName ? { fullName } : !existingDoc.exists ? { fullName: "" } : {}),
      updatedAt: FieldValue.serverTimestamp(),
    };

    if (!existingDoc.exists) {
      userData.isProfileComplete = false;
      userData.createdAt = FieldValue.serverTimestamp();
      userData.skills = [];
      userData.education = [];
      userData.experience = [];
      userData.certifications = [];
      userData.languages = [];
      userData.fcmTokens = [];
    }

    await userRef.set(userData, { merge: true });

    // 2. If registering as a COMPANY, initialize company document
    if (effectiveRole === "COMPANY") {
      const companyRef = db.collection("companies").doc(uid);
      const companyDoc = await companyRef.get();
      if (!companyDoc.exists) {
        await companyRef.set({
          id: uid,
          ownerUid: uid,
          name: companyName.length > 0 ? companyName : fullName,
          industry,
          description,
          contactEmail: email,
          verificationStatus: isApproved ? "APPROVED" : "PENDING",
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }

    logger.info(`User profile & claims synchronized successfully for UID: ${uid} (Role: ${effectiveRole})`);
    return { success: true, role: effectiveRole };
  } catch (error: any) {
    if (error instanceof HttpsError) throw error;
    logger.error("Error in syncUserProfile:", error);
    throw new HttpsError("internal", error.message || "Failed to synchronize profile.");
  }
});

/**
 * Callable Function: Allows Admin to update user roles or approve companies.
 */
export const adminSetRole = onCall({ cors: true }, async (request) => {
  if (!request.auth || !isCallerAdmin(request.auth.token)) {
    throw new HttpsError("permission-denied", "Only administrators can perform this action.");
  }

  const rawUid = request.data?.targetUid;
  const newRole = typeof request.data?.newRole === "string" ? request.data.newRole.trim().toUpperCase() : "";
  const targetUid = typeof rawUid === "string" ? rawUid.trim() : "";

  if (!targetUid || !["USER", "COMPANY", "ADMIN"].includes(newRole)) {
    throw new HttpsError("invalid-argument", "Valid target UID and role are required.");
  }

  try {
    const targetUser = await auth.getUser(targetUid);
    const existingClaims = targetUser.customClaims || {};

    await auth.setCustomUserClaims(targetUid, {
      ...existingClaims,
      role: newRole,
      isAdmin: newRole === "ADMIN",
      isApproved: newRole === "COMPANY" ? Boolean(existingClaims.isApproved) : true,
    });

    await db.collection("users").doc(targetUid).set({
      uid: targetUid,
      role: newRole,
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    // Record audit log
    await writeAuditLog({
      actorId: request.auth.uid,
      actorRole: String(request.auth.token.role || "ADMIN"),
      action: "ADMIN_UPDATE_ROLE",
      targetType: "USER",
      targetId: targetUid,
      metadata: { newRole },
    });

    return { success: true, targetUid, newRole };
  } catch (error: any) {
    logger.error("Error setting role by admin:", error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", error.message || "Failed to update role.");
  }
});

/**
 * Callable Function: Allows Admin to approve, reject, or suspend a company.
 * Synchronizes company verificationStatus, updates Auth claims, dispatches notification, and logs audit record.
 */
export const adminReviewCompany = onCall({ cors: true }, async (request) => {
  if (!request.auth || !isCallerAdmin(request.auth.token)) {
    throw new HttpsError("permission-denied", "Only platform administrators can review companies.");
  }

  const companyId = typeof request.data?.companyId === "string" ? request.data.companyId.trim() : "";
  const status = typeof request.data?.status === "string" ? request.data.status.trim().toUpperCase() : "";
  const notes = typeof request.data?.notes === "string" ? request.data.notes.trim() : null;
  const validStatuses = ["APPROVED", "REJECTED", "SUSPENDED", "PENDING"];

  if (!companyId || !validStatuses.includes(status)) {
    throw new HttpsError("invalid-argument", "Valid companyId and status are required.");
  }

  try {
    const companyRef = db.collection("companies").doc(companyId);
    const companyDoc = await companyRef.get();

    if (!companyDoc.exists) {
      throw new HttpsError("not-found", "Company profile does not exist.");
    }

    const prevStatus = companyDoc.data()?.verificationStatus;
    const isApproved = status === "APPROVED";

    // 1. Update Company document (status transitions to APPROVED/REJECTED/SUSPENDED trigger onCompanyUpdated)
    await companyRef.update({
      verificationStatus: status,
      verificationNotes: notes,
      verifiedAt: FieldValue.serverTimestamp(),
      verifiedBy: request.auth.uid,
      updatedAt: FieldValue.serverTimestamp(),
    });

    // 2. Update Firebase Auth Custom Claims for the company owner
    const targetOwnerUid = companyDoc.data()?.ownerUid || companyId;
    const existingClaims = (await auth.getUser(targetOwnerUid)).customClaims || {};
    await auth.setCustomUserClaims(targetOwnerUid, {
      ...existingClaims,
      role: existingClaims.role || "COMPANY",
      isApproved: isApproved,
    });

    // 3. Only dispatch direct notification when onCompanyUpdated trigger will not fire
    const handledByCompanyTrigger = prevStatus !== status && ["APPROVED", "REJECTED", "SUSPENDED"].includes(status);
    if (!handledByCompanyTrigger) {
      await db.collection("notifications").add({
        userId: companyId,
        title: isApproved ? "Company Account Approved!" : `Company Status: ${status}`,
        body: isApproved
          ? "Your company profile has been verified by Test2Hire administrators. You can now publish jobs and assign online assessments."
          : `Your company verification was updated to ${status}. Notes: ${notes || "None"}`,
        type: "COMPANY_APPROVAL",
        data: { companyId, status },
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    // 4. Record Audit Log
    await writeAuditLog({
      actorId: request.auth.uid,
      actorRole: String(request.auth.token.role || "ADMIN"),
      action: `COMPANY_${status}`,
      targetType: "COMPANY",
      targetId: companyId,
      metadata: { status, notes: notes ?? "" },
    });

    logger.info(`Company ${companyId} status updated to ${status} by admin ${request.auth.uid}`);
    return { success: true, companyId, status };
  } catch (error: any) {
    logger.error("Error in adminReviewCompany:", error);
    if (error instanceof HttpsError) throw error;
    throw new HttpsError("internal", error.message || "Failed to review company.");
  }
});

/**
 * Trigger: When a new application document is created in Firestore.
 * Automatically increments applicantsCount on the corresponding job and dispatches in-app notifications.
 */
export const onApplicationCreated = onDocumentCreated(
  "applications/{applicationId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    const applicationId = event.params.applicationId;
    const { jobId, jobTitle, companyId, companyName, candidateId, candidateName } = data;

    try {
      // 1. Increment applicantsCount on jobs/{jobId} if job exists
      if (jobId) {
        const jobRef = db.collection("jobs").doc(jobId);
        const jobSnap = await jobRef.get();
        if (jobSnap.exists) {
          await jobRef.update({
            applicantsCount: FieldValue.increment(1),
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      }

      // 2. Notify company of new applicant
      if (companyId) {
        await db.collection("notifications").add({
          userId: companyId,
          title: `New Candidate: ${candidateName || "A candidate"}`,
          body: `${candidateName || "A candidate"} applied for ${jobTitle || "your vacancy"}.`,
          type: "NEW_APPLICATION",
          entityId: applicationId,
          actionUrl: `/company/applicants?applicationId=${applicationId}&jobId=${jobId || ""}&candidateId=${candidateId || ""}`,
          data: { applicationId, jobId: jobId || "", candidateId: candidateId || "" },
          isRead: false,
          createdAt: FieldValue.serverTimestamp(),
        });
      }

      // 3. Notify candidate of successful submission
      if (candidateId) {
        await db.collection("notifications").add({
          userId: candidateId,
          title: "Application Received!",
          body: `Your application for ${jobTitle || "the position"} at ${companyName || "the company"} was received.`,
          type: "APPLICATION_CONFIRMATION",
          entityId: applicationId,
          data: { applicationId, jobId: jobId || "" },
          isRead: false,
          createdAt: FieldValue.serverTimestamp(),
        });
      }

      // 4. Audit Log
      await writeAuditLog({
        actorId: candidateId || "SYSTEM",
        actorRole: "USER",
        action: "APPLICATION_SUBMITTED",
        targetType: "APPLICATION",
        targetId: applicationId,
        metadata: { jobId: jobId || "", companyId: companyId || "" },
      });

      logger.info(`Processed application creation for ${applicationId} on job ${jobId}`);
    } catch (error) {
      logger.error(`Failed to process onApplicationCreated for ${applicationId}:`, error);
    }
  }
);

/**
 * Trigger: When an application document is updated.
 * Notifies candidate on meaningful manual status transitions and decrements job count if withdrawn.
 */
export const onApplicationStatusUpdated = onDocumentUpdated(
  "applications/{applicationId}",
  async (event) => {
    const beforeSnap = event.data?.before;
    const afterSnap = event.data?.after;
    if (!beforeSnap || !afterSnap) return;

    const beforeData = beforeSnap.data();
    const afterData = afterSnap.data();
    const applicationId = event.params.applicationId;

    if (beforeData.status === afterData.status) return;

    const {
      jobId,
      jobTitle,
      companyId,
      companyName,
      candidateId,
      candidateName,
      status,
      rejectionReason,
    } = afterData;

    try {
      // 1. If application was withdrawn, safely decrement applicantsCount (never below 0) and notify company
      if (status === "WITHDRAWN" && beforeData.status !== "WITHDRAWN") {
        if (jobId) {
          const jobRef = db.collection("jobs").doc(jobId);
          await db.runTransaction(async (tx) => {
            const jobSnap = await tx.get(jobRef);
            if (!jobSnap.exists) return;
            const currentCount = Number(jobSnap.data()?.applicantsCount) || 0;
            tx.update(jobRef, {
              applicantsCount: Math.max(0, currentCount - 1),
              updatedAt: FieldValue.serverTimestamp(),
            });
          });
        }

        if (companyId) {
          await db.collection("notifications").add({
            userId: companyId,
            title: "Application Withdrawn",
            body: `${candidateName || "A candidate"} withdrew their application for ${jobTitle || "your vacancy"}.`,
            type: "APPLICATION_WITHDRAWN",
            entityId: applicationId,
            data: { applicationId, jobId: jobId || "", candidateId: candidateId || "" },
            isRead: false,
            createdAt: FieldValue.serverTimestamp(),
          });
        }
      }

      // 2. Suppress candidate status notifications for transitions already handled by dedicated callables/triggers
      const suppressedStatuses = new Set([
        "EXAM_ASSIGNED",
        "SELECTED",
        "OFFER_EXTENDED",
        "WITHDRAWN",
        "EXAM_IN_PROGRESS",
      ]);
      const alreadyHandledByCallable =
        afterData._lastNotifiedStatus === status && beforeData._lastNotifiedStatus !== status;

      if (candidateId && !suppressedStatuses.has(status) && !alreadyHandledByCallable) {
        let title = `Application Status: ${status}`;
        let body = `Your application for ${jobTitle || "position"} at ${companyName || "company"} is now ${status}.`;

        if (status === "HIRED") {
          title = "Congratulations! You Have Been Hired!";
          body = `Welcome aboard! Your hiring status for ${jobTitle || "the position"} at ${companyName || "the company"} is confirmed.`;
        } else if (status === "REJECTED") {
          title = "Application Update";
          body = `Your application for ${jobTitle || "position"} was not selected.${rejectionReason ? ` Feedback: ${rejectionReason}` : ""}`;
        } else if (status === "SHORTLISTED") {
          title = "Application Shortlisted!";
          body = `Great news! ${companyName || "The hiring team"} shortlisted your application for ${jobTitle || "position"}.`;
        } else if (status === "UNDER_REVIEW") {
          title = "Application Under Review";
          body = `${companyName || "The hiring team"} is now reviewing your application for ${jobTitle || "position"}.`;
        } else if (status === "INTERVIEW_INVITED" || status === "INTERVIEW_SCHEDULED") {
          title = "Interview Invitation!";
          body = `You have been invited to an interview for ${jobTitle || "position"}!`;
        } else if (status === "FAILED") {
          title = "Assessment Update";
          body = `Your assessment status for ${jobTitle || "position"} has been updated.${rejectionReason ? ` Details: ${rejectionReason}` : ""}`;
        }

        await db.collection("notifications").add({
          userId: candidateId,
          title,
          body,
          type: "APPLICATION_STATUS_CHANGE",
          entityId: applicationId,
          data: { applicationId, jobId: jobId || "", status },
          isRead: false,
          createdAt: FieldValue.serverTimestamp(),
        });
      }

      logger.info(`Processed application status update for ${applicationId} to ${status}`);
    } catch (error) {
      logger.error(`Failed to process onApplicationStatusUpdated for ${applicationId}:`, error);
    }
  }
);

/**
 * Trigger: When a new question is added to a question bank.
 * Automatically increments questionsCount and accumulates totalPoints in questionBanks/{bankId}.
 */
export const onQuestionCreated = onDocumentCreated(
  "questions/{questionId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    const questionId = event.params.questionId;
    const { bankId, points = 1, companyId, title } = data;

    if (!bankId) {
      logger.warn(`Question ${questionId} created without bankId.`);
      return;
    }

    try {
      const bankRef = db.collection("questionBanks").doc(bankId);
      const pts = Number(points) || 1;
      await db.runTransaction(async (tx) => {
        const bankSnap = await tx.get(bankRef);
        if (!bankSnap.exists) return;
        tx.update(bankRef, {
          questionsCount: FieldValue.increment(1),
          totalPoints: FieldValue.increment(pts),
          updatedAt: FieldValue.serverTimestamp(),
        });
      });

      // Write unified audit log
      await writeAuditLog({
        actorId: companyId || "SYSTEM",
        actorRole: companyId ? "COMPANY" : "SYSTEM",
        action: "QUESTION_CREATED",
        targetType: "QUESTION",
        targetId: questionId,
        metadata: {
          bankId,
          companyId: companyId || "",
          questionTitle: title || "",
        },
      });

      logger.info(`Question ${questionId} linked to bank ${bankId}, counters updated.`);
    } catch (error) {
      logger.error(`Failed to update question bank counters for ${bankId}:`, error);
    }
  }
);

/**
 * Trigger: When a question is deleted from a question bank.
 * Automatically decrements questionsCount and totalPoints in questionBanks/{bankId}.
 */
export const onQuestionDeleted = onDocumentDeleted(
  "questions/{questionId}",
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const data = snap.data();
    const questionId = event.params.questionId;
    const { bankId, points = 1, companyId, title } = data;

    if (!bankId) return;

    try {
      const bankRef = db.collection("questionBanks").doc(bankId);
      const pts = Number(points) || 1;
      await db.runTransaction(async (tx) => {
        const bankSnap = await tx.get(bankRef);
        if (!bankSnap.exists) return;
        const bankData = bankSnap.data() || {};
        tx.update(bankRef, {
          questionsCount: Math.max(0, (Number(bankData.questionsCount) || 0) - 1),
          totalPoints: Math.max(0, (Number(bankData.totalPoints) || 0) - pts),
          updatedAt: FieldValue.serverTimestamp(),
        });
      });

      await writeAuditLog({
        actorId: companyId || "SYSTEM",
        actorRole: companyId ? "COMPANY" : "SYSTEM",
        action: "QUESTION_DELETED",
        targetType: "QUESTION",
        targetId: questionId,
        metadata: {
          bankId,
          companyId: companyId || "",
          questionTitle: title || "",
        },
      });

      logger.info(`Question ${questionId} removed from bank ${bankId}, counters updated.`);
    } catch (error) {
      logger.error(`Failed to decrement question bank counters for ${bankId}:`, error);
    }
  }
);

/**
 * Callable Function: Assigns an Exam Template to a Candidate Application.
 * Generates an access token and creates an /examAttempts record.
 */
export const assignExamToApplication = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required to assign assessments.");
  }

  const callerUid = request.auth.uid;
  const callerIsAdmin = isCallerAdmin(request.auth.token);
  const callerRole = String(request.auth.token.role || "COMPANY");
  const { examId, applicationId, candidateId, jobId, durationMinutes, deadlineDays } = request.data || {};

  if (
    typeof examId !== "string" || !examId.trim() ||
    typeof applicationId !== "string" || !applicationId.trim() ||
    typeof candidateId !== "string" || !candidateId.trim()
  ) {
    throw new HttpsError("invalid-argument", "Missing required parameters: examId, applicationId, candidateId.");
  }

  // 1 & 2. Parallelize exam template & application lookups, then verify existence and ownership
  const appRef = db.collection("applications").doc(applicationId.trim());
  const [examDoc, appDoc] = await Promise.all([
    db.collection("exams").doc(examId.trim()).get(),
    appRef.get(),
  ]);

  if (!examDoc.exists) {
    throw new HttpsError("not-found", "Exam template not found.");
  }
  const examData = examDoc.data()!;

  if (!callerIsAdmin && examData.companyId !== callerUid) {
    throw new HttpsError("permission-denied", "You can only assign exams owned by your company.");
  }

  if (!appDoc.exists) {
    throw new HttpsError("not-found", "Application not found.");
  }
  const appData = appDoc.data()!;

  if (!callerIsAdmin && appData.companyId && appData.companyId !== callerUid) {
    throw new HttpsError("permission-denied", "You can only assign exams to your company's applications.");
  }
  if (appData.candidateId && appData.candidateId !== candidateId.trim()) {
    throw new HttpsError("invalid-argument", "candidateId does not match the application candidate.");
  }

  // 3. Generate cryptographically secure 256-bit hex access token and expiration
  const token = crypto.randomBytes(32).toString("hex");

  const duration = Number(durationMinutes) > 0 ? Math.min(Math.round(Number(durationMinutes)), 600) : (Number(examData.durationMinutes) || 45);
  const days = Number(deadlineDays) > 0 ? Math.min(Number(deadlineDays), 90) : 7;
  const passingPercentage = Number(examData.passingPercentage ?? examData.passingScore) || 70;
  const now = new Date();
  const expiresAt = new Date(now.getTime() + days * 24 * 60 * 60 * 1000);

  // 4. Atomically create attempt, update application, and queue candidate notification
  const attemptRef = db.collection("examAttempts").doc();
  const attemptData = {
    id: attemptRef.id,
    examId: examId.trim(),
    examTitle: examData.title || "Assessment",
    companyId: examData.companyId,
    candidateId: candidateId.trim(),
    candidateName: appData.candidateName || "Candidate",
    candidateEmail: appData.candidateEmail || "",
    jobId: (typeof jobId === "string" && jobId.trim()) ? jobId.trim() : (appData.jobId || ""),
    jobTitle: appData.jobTitle || "",
    applicationId: applicationId.trim(),
    token,
    status: "INVITED",
    durationMinutes: duration,
    passingPercentage,
    totalQuestions: examData.totalQuestions || (Array.isArray(examData.questionIds) ? examData.questionIds.length : 0),
    totalPoints: examData.totalPoints || 0,
    score: 0,
    passed: false,
    violationCount: 0,
    violationsCount: 0,
    invitationSentAt: FieldValue.serverTimestamp(),
    expiresAt: Timestamp.fromDate(expiresAt),
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };

  const notificationRef = db.collection("notifications").doc();
  const batch = db.batch();
  batch.set(attemptRef, attemptData);
  batch.update(appRef, {
    status: "EXAM_ASSIGNED",
    _lastNotifiedStatus: "EXAM_ASSIGNED",
    examAttemptId: attemptRef.id,
    examToken: token,
    examTitle: examData.title || "Assessment",
    examDurationMinutes: duration,
    examExpiresAt: Timestamp.fromDate(expiresAt),
    updatedAt: FieldValue.serverTimestamp(),
  });
  batch.set(notificationRef, {
    userId: candidateId.trim(),
    title: "Assessment Assigned!",
    body: `You have been invited to take "${examData.title || "Assessment"}". Exam Key: ${token} (${duration} mins). Copy your key and start your exam on the web portal.`,
    type: "EXAM_ASSIGNED",
    entityId: attemptRef.id,
    data: {
      attemptId: attemptRef.id,
      token,
      examId: examId.trim(),
      applicationId: applicationId.trim(),
      durationMinutes: String(duration),
    },
    isRead: false,
    createdAt: FieldValue.serverTimestamp(),
  });
  await batch.commit();

  // 6. Unified Audit log
  await writeAuditLog({
    actorId: callerUid,
    actorRole: callerIsAdmin ? "ADMIN" : callerRole,
    action: "EXAM_ASSIGNED",
    targetType: "EXAM_ATTEMPT",
    targetId: attemptRef.id,
    metadata: {
      examId: examId.trim(),
      applicationId: applicationId.trim(),
      candidateId: candidateId.trim(),
      companyId: examData.companyId || callerUid,
    },
  });

  logger.info(`Assigned exam ${examId} to application ${applicationId}, attempt ID: ${attemptRef.id}`);

  return {
    success: true,
    attemptId: attemptRef.id,
    token,
    durationMinutes: duration,
    expiresAt: expiresAt.toISOString(),
  };
});

/**
 * Callable: Retrieves the active assessment session using a secure 32-character token.
 * Strips correct answers, rationales, and private rubrics before transmitting to candidate frontend.
 */
export const getExamSession = onCall({ cors: true }, async (request) => {
  const token = request.data?.token;
  if (!token || typeof token !== "string" || token.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid assessment token is required.");
  }

  // 1. Query attempt by token
  const attemptsSnap = await db
    .collection("examAttempts")
    .where("token", "==", token.trim())
    .limit(1)
    .get();

  if (attemptsSnap.empty) {
    throw new HttpsError("not-found", "Assessment attempt not found or link has expired.");
  }

  const attemptDoc = attemptsSnap.docs[0];
  const attempt = attemptDoc.data();

  if (attempt.status === "COMPLETED") {
    throw new HttpsError("failed-precondition", "This examination has already been completed.");
  }

  if (attempt.status === "TERMINATED") {
    throw new HttpsError("permission-denied", "This examination was terminated due to policy violations.");
  }

  if (attempt.status === "EXPIRED") {
    throw new HttpsError("deadline-exceeded", "The exam window has expired.");
  }

  // Check expiration
  const now = new Date();
  const expiresAtDate = toDateOrNull(attempt.expiresAt);
  if (isAttemptWindowExpired(attempt, now, 0)) {
    await attemptDoc.ref.update({ status: "EXPIRED", updatedAt: FieldValue.serverTimestamp() });
    throw new HttpsError("deadline-exceeded", "The exam window has expired.");
  }

  // 2. Fetch Exam Template
  const examDoc = await db.collection("exams").doc(attempt.examId).get();
  if (!examDoc.exists) {
    throw new HttpsError("not-found", "Exam template configuration is missing.");
  }
  const exam = examDoc.data()!;

  // 3. Mark attempt IN_PROGRESS if first time
  const startedAtDate = attempt.status === "INVITED"
    ? now
    : (toDateOrNull(attempt.startedAt) || now);

  if (attempt.status === "INVITED") {
    await attemptDoc.ref.update({
      status: "IN_PROGRESS",
      startedAt: Timestamp.fromDate(startedAtDate),
      updatedAt: FieldValue.serverTimestamp(),
    });
  }

  // 4. Fetch questions via single db.getAll RPC preserving exam.questionIds order (NO correct answers)
  const questionIds: string[] = Array.isArray(exam.questionIds)
    ? Array.from(new Set(exam.questionIds.filter((id: any) => typeof id === "string" && id.trim().length > 0)))
    : [];
  const questionMap = new Map<string, any>();

  if (questionIds.length > 0) {
    const qRefs = questionIds.map((id) => db.collection("questions").doc(id));
    const qSnaps = await db.getAll(...qRefs);
    qSnaps.forEach((doc) => {
      if (!doc.exists) return;
      const q = doc.data()!;
      questionMap.set(doc.id, {
        id: doc.id,
        title: q.title || "",
        description: q.description || "",
        type: q.type || "SINGLE_CHOICE",
        difficulty: q.difficulty || "MEDIUM",
        points: Number(q.points) || 1,
        programmingLanguage: q.programmingLanguage || null,
        sampleCodeSnippet: q.sampleCodeSnippet || null,
        options: Array.isArray(q.options)
          ? q.options.map((opt: any) => ({
              id: opt.id,
              text: opt.text,
            }))
          : [],
      });
    });
  }

  let sanitizedQuestions = questionIds
    .map((id) => questionMap.get(id))
    .filter((q): q is NonNullable<typeof q> => Boolean(q));

  // Optional unbiased Fisher-Yates randomization
  if (exam.randomizeQuestions) {
    sanitizedQuestions = shuffleArray(sanitizedQuestions);
  }
  if (exam.randomizeOptions) {
    sanitizedQuestions = sanitizedQuestions.map((q) => ({
      ...q,
      options: Array.isArray(q.options) ? shuffleArray(q.options) : [],
    }));
  }

  const invitationDate = toDateOrNull(attempt.invitationSentAt);

  return {
    attemptId: attemptDoc.id,
    examId: attempt.examId,
    examTitle: attempt.examTitle || exam.title,
    candidateName: attempt.candidateName,
    durationMinutes: attempt.durationMinutes || exam.durationMinutes || 45,
    passingPercentage: attempt.passingPercentage ?? exam.passingPercentage ?? exam.passingScore ?? 70,
    proctoringEnabled: exam.proctoringEnabled ?? true,
    totalQuestions: sanitizedQuestions.length,
    totalPoints: attempt.totalPoints || exam.totalPoints || 0,
    questions: sanitizedQuestions,
    savedAnswers: attempt.answers || {},
    violationCount: Math.max(Number(attempt.violationCount) || 0, Number(attempt.violationsCount) || 0),
    startedAt: startedAtDate.toISOString(),
    expiresAt: expiresAtDate ? expiresAtDate.toISOString() : null,
    invitationSentAt: invitationDate ? invitationDate.toISOString() : null,
    serverNow: now.toISOString(),
  };
});

/**
 * Callable: Persists in-progress candidate answer drafts validated strictly by exam token.
 * Enables token-authenticated web_exam clients (without Firebase Auth) to sync drafts securely.
 */
export const saveExamDraft = onCall({ cors: true }, async (request) => {
  const { token, questionId, answer, answers, proctoringReport } = request.data || {};
  if (!token || typeof token !== "string" || token.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Valid assessment token is required.");
  }

  const hasSingleAnswer = typeof questionId === "string" && questionId.trim().length > 0 && answer && typeof answer === "object" && !Array.isArray(answer);
  const hasBatchAnswers = answers && typeof answers === "object" && !Array.isArray(answers);
  const sanitizedReport = sanitizeProctoringReport(proctoringReport);

  if (!hasSingleAnswer && !hasBatchAnswers && !sanitizedReport) {
    throw new HttpsError("invalid-argument", "Provide either { questionId, answer }, { answers }, or proctoringReport payload.");
  }

  const attemptsSnap = await db
    .collection("examAttempts")
    .where("token", "==", token.trim())
    .limit(1)
    .get();

  if (attemptsSnap.empty) {
    throw new HttpsError("not-found", "Assessment attempt not found.");
  }

  const attemptRef = attemptsSnap.docs[0].ref;
  const now = new Date();

  const txResult = await db.runTransaction(async (tx) => {
    const freshSnap = await tx.get(attemptRef);
    if (!freshSnap.exists) {
      throw new HttpsError("not-found", "Assessment attempt not found.");
    }
    const attempt = freshSnap.data()!;

    if (attempt.status === "COMPLETED") {
      throw new HttpsError("failed-precondition", "Exam has already been submitted.");
    }
    if (attempt.status === "TERMINATED") {
      throw new HttpsError("permission-denied", "Exam was terminated.");
    }
    if (attempt.status === "EXPIRED") {
      throw new HttpsError("deadline-exceeded", "The exam window has expired.");
    }
    if (isAttemptWindowExpired(attempt, now, 60 * 1000)) {
      tx.update(attemptRef, { status: "EXPIRED", updatedAt: FieldValue.serverTimestamp() });
      return "EXPIRED";
    }
    if (attempt.status !== "IN_PROGRESS") {
      throw new HttpsError("failed-precondition", "Attempt is not currently in progress.");
    }

    const args: [FieldPath | string, any, ...(FieldPath | string | any)[]] = [
      "lastHeartbeat",
      FieldValue.serverTimestamp(),
      "updatedAt",
      FieldValue.serverTimestamp(),
    ];

    if (hasSingleAnswer) {
      const qId = questionId.trim().slice(0, 128);
      args.push(new FieldPath("answers", qId), sanitizeAnswerEntry(answer));
    }

    if (hasBatchAnswers) {
      const entries = Object.entries(answers as Record<string, any>).slice(0, 200);
      for (const [rawQId, rawAns] of entries) {
        const qId = String(rawQId).trim().slice(0, 128);
        if (qId.length > 0 && rawAns && typeof rawAns === "object" && !Array.isArray(rawAns)) {
          args.push(new FieldPath("answers", qId), sanitizeAnswerEntry(rawAns));
        }
      }
    }

    if (sanitizedReport) {
      args.push("proctoringReport", sanitizedReport);
      if (Array.isArray(sanitizedReport.snapshots) && sanitizedReport.snapshots.length > 0) {
        args.push("proctoringSnapshots", sanitizedReport.snapshots.slice(-10));
      }
    }

    tx.update(attemptRef, args[0], args[1], ...args.slice(2));
    return "OK";
  });

  if (txResult === "EXPIRED") {
    throw new HttpsError("deadline-exceeded", "The exam window has expired.");
  }

  return {
    success: true,
    savedAt: now.toISOString(),
  };
});

/**
 * Callable: Records proctoring violations (tab switch, window blur, fullscreen exit)
 * Automatically terminates assessment if violations exceed maximum threshold (3).
 */
export const recordExamViolation = onCall({ cors: true }, async (request) => {
  const { token, violationType, details, snapshotDataUrl, proctoringSummary } = request.data || {};
  if (
    typeof token !== "string" || token.trim().length === 0 ||
    typeof violationType !== "string" || violationType.trim().length === 0
  ) {
    throw new HttpsError("invalid-argument", "Token and violationType are required.");
  }

  const attemptsSnap = await db
    .collection("examAttempts")
    .where("token", "==", token.trim())
    .limit(1)
    .get();

  if (attemptsSnap.empty) {
    throw new HttpsError("not-found", "Assessment attempt not found.");
  }

  const attemptRef = attemptsSnap.docs[0].ref;
  const cleanType = violationType.trim().slice(0, 100);
  const cleanDetails = typeof details === "string" && details.trim().length > 0
    ? details.trim().slice(0, 1000)
    : "Security violation detected.";
  const cleanSnapshot = snapshotDataUrl
    ? sanitizeProctoringSnapshot(
        { label: cleanType, timestamp: new Date().toISOString(), imageDataUrl: snapshotDataUrl },
        cleanType
      )
    : null;
  const sanitizedSummary = sanitizeProctoringReport(proctoringSummary);

  const txResult = await db.runTransaction(async (tx) => {
    const freshSnap = await tx.get(attemptRef);
    if (!freshSnap.exists) {
      throw new HttpsError("not-found", "Assessment attempt not found.");
    }
    const freshAttempt = freshSnap.data()!;
    const currentCount = Math.max(
      Number(freshAttempt.violationCount) || 0,
      Number(freshAttempt.violationsCount) || 0
    );

    if (freshAttempt.status !== "IN_PROGRESS") {
      return {
        success: false,
        reason: "Attempt is not in progress.",
        violationCount: currentCount,
        terminated: freshAttempt.status === "TERMINATED",
        newlyTerminated: false,
        attempt: freshAttempt,
      };
    }

    const newViolationCount = currentCount + 1;
    const shouldTerminate = newViolationCount >= 3;
    const appId = typeof freshAttempt.applicationId === "string" ? freshAttempt.applicationId.trim() : "";
    const appRef = appId ? db.collection("applications").doc(appId) : null;
    const appSnap = shouldTerminate && appRef ? await tx.get(appRef) : null;

    const violationRef = db.collection("examViolations").doc();
    tx.set(violationRef, {
      attemptId: attemptRef.id,
      candidateId: freshAttempt.candidateId || "",
      companyId: freshAttempt.companyId || "",
      examId: freshAttempt.examId || "",
      violationType: cleanType,
      details: cleanDetails,
      ...(cleanSnapshot ? { snapshotDataUrl: cleanSnapshot.imageDataUrl } : {}),
      timestamp: FieldValue.serverTimestamp(),
    });

    const existingSnapshots: any[] = Array.isArray(freshAttempt.proctoringSnapshots)
      ? freshAttempt.proctoringSnapshots
      : [];
    const nextSnapshots = cleanSnapshot
      ? [...existingSnapshots, cleanSnapshot].slice(-10)
      : existingSnapshots;

    const updates: Record<string, any> = {
      violationCount: newViolationCount,
      violationsCount: newViolationCount,
      lastViolationType: cleanType,
      lastViolationDetails: cleanDetails,
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (cleanSnapshot) {
      updates.proctoringSnapshots = nextSnapshots;
    }
    if (sanitizedSummary) {
      updates.proctoringReport = {
        ...sanitizedSummary,
        snapshots: nextSnapshots.length > 0 ? nextSnapshots : sanitizedSummary.snapshots,
        snapshotsCount: nextSnapshots.length > 0 ? nextSnapshots.length : sanitizedSummary.snapshotsCount,
      };
    }

    if (shouldTerminate) {
      updates.status = "TERMINATED";
      updates.completedAt = FieldValue.serverTimestamp();
      updates.score = 0;
      updates.earnedPoints = 0;
      updates.passed = false;
      updates.terminationReason = "PROCTORING_VIOLATION_LIMIT";

      if (appRef && appSnap?.exists) {
        tx.update(appRef, {
          status: "FAILED",
          _lastNotifiedStatus: "FAILED",
          examScore: 0,
          examPassed: false,
          examTerminated: true,
          examViolationCount: newViolationCount,
          examAttemptId: attemptRef.id,
          examTitle: freshAttempt.examTitle || "Assessment",
          rejectionReason: "Assessment terminated due to exceeding proctoring violation limit (tab/fullscreen exit).",
          updatedAt: FieldValue.serverTimestamp(),
        });
      }
    }

    tx.update(attemptRef, updates);

    return {
      success: true,
      violationCount: newViolationCount,
      terminated: shouldTerminate,
      newlyTerminated: shouldTerminate,
      attempt: freshAttempt,
    };
  });

  if (!txResult.success) {
    return {
      success: false,
      reason: txResult.reason,
      violationCount: txResult.violationCount,
      terminated: txResult.terminated,
    };
  }

  if (txResult.newlyTerminated) {
    const attempt = txResult.attempt;
    if (attempt.companyId) {
      await db.collection("notifications").add({
        userId: attempt.companyId,
        title: "Assessment Terminated (Proctoring Violation)",
        body: `${attempt.candidateName || "Candidate"}'s assessment "${attempt.examTitle || "Assessment"}" was automatically terminated after ${txResult.violationCount} security violations.`,
        type: "EXAM_TERMINATED",
        entityId: attempt.applicationId || attemptRef.id,
        actionUrl: `/company/applicants?applicationId=${attempt.applicationId || ""}&candidateId=${attempt.candidateId || ""}&jobId=${attempt.jobId || ""}`,
        data: {
          attemptId: attemptRef.id,
          examId: attempt.examId || "",
          applicationId: attempt.applicationId || "",
          candidateId: attempt.candidateId || "",
          jobId: attempt.jobId || "",
          violationCount: String(txResult.violationCount),
        },
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    if (attempt.candidateId) {
      await db.collection("notifications").add({
        userId: attempt.candidateId,
        title: "Assessment Terminated",
        body: `Your assessment "${attempt.examTitle || "Assessment"}" was terminated due to reaching the proctoring violation threshold.`,
        type: "EXAM_TERMINATED",
        entityId: attemptRef.id,
        actionUrl: "/candidate/exams",
        data: {
          attemptId: attemptRef.id,
          examId: attempt.examId || "",
          applicationId: attempt.applicationId || "",
        },
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
    await writeAuditLog({
      actorId: attempt.candidateId || "SYSTEM",
      actorRole: "USER",
      action: "EXAM_TERMINATED_VIOLATION",
      targetType: "EXAM_ATTEMPT",
      targetId: attemptRef.id,
      metadata: {
        examId: attempt.examId || "",
        applicationId: attempt.applicationId || "",
        companyId: attempt.companyId || "",
        violationCount: txResult.violationCount,
      },
    });
  }

  return {
    success: true,
    violationCount: txResult.violationCount,
    terminated: txResult.terminated,
  };
});

/**
 * Callable: Submits candidate answers, auto-grades MCQ/TF/option-based and exact-match questions,
 * computes final score and pass/fail status transactionally, and syncs candidate application status.
 */
export const submitExam = onCall({ cors: true }, async (request) => {
  const { token, answers, proctoringReport } = request.data || {};
  if (
    typeof token !== "string" || token.trim().length === 0 ||
    !answers || typeof answers !== "object" || Array.isArray(answers)
  ) {
    throw new HttpsError("invalid-argument", "Token and answers payload are required.");
  }
  const sanitizedReport = sanitizeProctoringReport(proctoringReport);

  const attemptsSnap = await db
    .collection("examAttempts")
    .where("token", "==", token.trim())
    .limit(1)
    .get();

  if (attemptsSnap.empty) {
    throw new HttpsError("not-found", "Assessment attempt not found.");
  }

  const attemptDoc = attemptsSnap.docs[0];
  const attempt = attemptDoc.data();

  if (attempt.status === "COMPLETED") {
    throw new HttpsError("failed-precondition", "Exam already submitted.");
  }
  if (attempt.status === "TERMINATED") {
    throw new HttpsError("permission-denied", "Exam was terminated.");
  }
  if (attempt.status === "EXPIRED") {
    throw new HttpsError("deadline-exceeded", "Exam window has expired.");
  }

  const now = new Date();
  if (isAttemptWindowExpired(attempt, now, 2 * 60 * 1000)) {
    await attemptDoc.ref.update({ status: "EXPIRED", updatedAt: FieldValue.serverTimestamp() });
    throw new HttpsError("deadline-exceeded", "Exam window has expired.");
  }

  // Fetch exam template and deduplicated questions with protected answer keys
  const examDoc = await db.collection("exams").doc(attempt.examId).get();
  const exam = examDoc.exists ? examDoc.data()! : {};
  const questionIds: string[] = Array.isArray(exam.questionIds)
    ? Array.from(new Set(exam.questionIds.filter((id: any) => typeof id === "string" && id.trim().length > 0)))
    : [];

  let earnedPoints = 0;
  let totalPointsPossible = 0;
  const gradedResults: Record<string, any> = {};
  const sanitizedAnswers: Record<string, any> = {};

  Object.entries(answers as Record<string, any>).forEach(([rawQId, rawAns]) => {
    const qId = String(rawQId).trim().slice(0, 128);
    if (qId.length > 0) {
      sanitizedAnswers[qId] = sanitizeAnswerEntry(rawAns);
    }
  });

  if (questionIds.length > 0) {
    const qRefs = questionIds.map((id) => db.collection("questions").doc(id));
    const qSnaps = await db.getAll(...qRefs);

    qSnaps.forEach((doc) => {
      if (!doc.exists) return;
      const q = doc.data()!;
      const qId = doc.id;
      const qPoints = Number(q.points) || 1;
      totalPointsPossible += qPoints;

      const candidateAnswer = sanitizedAnswers[qId];
      const correctAnswers: string[] = Array.isArray(q.correctAnswers)
        ? q.correctAnswers.map((s: any) => String(s).trim()).filter((s: string) => s.length > 0)
        : [];
      const optionsList = Array.isArray(q.options) ? q.options : [];
      const hasOptions = optionsList.length > 0;
      const normalizedType = String(q.type || "SINGLE_CHOICE").toUpperCase();

      let isCorrect = false;
      let pendingManualReview = false;

      if (normalizedType === "MULTIPLE_CHOICE") {
        const rawSelected: unknown[] = Array.isArray(candidateAnswer?.selectedOptionIds)
          ? candidateAnswer.selectedOptionIds
          : [];
        const selectedOptions = Array.from(
          new Set<string>(
            rawSelected
              .map((opt: unknown) => String(opt).trim())
              .filter((opt: string) => opt.length > 0)
          )
        );
        const uniqueCorrect = Array.from(new Set<string>(correctAnswers));
        if (
          uniqueCorrect.length > 0 &&
          selectedOptions.length === uniqueCorrect.length &&
          selectedOptions.every((opt) => uniqueCorrect.includes(opt))
        ) {
          isCorrect = true;
        }
      } else if (
        normalizedType === "SINGLE_CHOICE" ||
        normalizedType === "TRUE_FALSE" ||
        hasOptions ||
        (Array.isArray(candidateAnswer?.selectedOptionIds) && candidateAnswer.selectedOptionIds.length > 0)
      ) {
        const selectedOption = candidateAnswer?.selectedOptionIds?.[0] ?? candidateAnswer?.answer;
        if (selectedOption !== undefined && selectedOption !== null && String(selectedOption).trim().length > 0) {
          if (correctAnswers.includes(String(selectedOption).trim())) {
            isCorrect = true;
          }
        }
      } else {
        // Open-ended short answer / coding without MCQ options
        const textAns = String(candidateAnswer?.textAnswer ?? candidateAnswer?.answer ?? "").trim();
        if (correctAnswers.length === 0) {
          pendingManualReview = true;
        } else if (textAns.length > 0 && correctAnswers.some((c) => c.toLowerCase() === textAns.toLowerCase())) {
          isCorrect = true;
        }
      }

      if (isCorrect) {
        earnedPoints += qPoints;
      }

      gradedResults[qId] = {
        points: qPoints,
        earned: isCorrect ? qPoints : 0,
        isCorrect,
        pendingManualReview,
      };
    });
  }

  if (totalPointsPossible === 0) totalPointsPossible = 1;
  const scorePercentage = Math.round((earnedPoints / totalPointsPossible) * 100);
  const passingPercentage = attempt.passingPercentage ?? exam.passingPercentage ?? exam.passingScore ?? 70;
  const passed = scorePercentage >= passingPercentage;
  const appStatus = passed ? "PASSED" : "FAILED";

  // Atomically guard against concurrent double submission, expiration & sync application
  const txResult = await db.runTransaction(async (tx) => {
    const freshAttemptSnap = await tx.get(attemptDoc.ref);
    if (!freshAttemptSnap.exists) {
      throw new HttpsError("not-found", "Assessment attempt not found.");
    }
    const freshAttempt = freshAttemptSnap.data()!;
    if (freshAttempt.status === "COMPLETED") {
      throw new HttpsError("failed-precondition", "Exam already submitted.");
    }
    if (freshAttempt.status === "TERMINATED") {
      throw new HttpsError("permission-denied", "Exam was terminated.");
    }
    if (freshAttempt.status === "EXPIRED") {
      throw new HttpsError("deadline-exceeded", "Exam window has expired.");
    }
    if (isAttemptWindowExpired(freshAttempt, new Date(), 2 * 60 * 1000)) {
      tx.update(attemptDoc.ref, { status: "EXPIRED", updatedAt: FieldValue.serverTimestamp() });
      return "EXPIRED";
    }

    const appId = typeof freshAttempt.applicationId === "string" ? freshAttempt.applicationId.trim() : "";
    const appRef = appId ? db.collection("applications").doc(appId) : null;
    const appSnap = appRef ? await tx.get(appRef) : null;

    const existingSnapshots: any[] = Array.isArray(freshAttempt.proctoringSnapshots)
      ? freshAttempt.proctoringSnapshots
      : [];
    const reportSnapshots: any[] = Array.isArray(sanitizedReport?.snapshots)
      ? sanitizedReport!.snapshots
      : [];
    const mergedSnapshots = [...existingSnapshots, ...reportSnapshots].slice(-12);

    tx.update(attemptDoc.ref, {
      status: "COMPLETED",
      answers: sanitizedAnswers,
      gradedResults,
      score: scorePercentage,
      earnedPoints,
      totalPoints: totalPointsPossible,
      passed,
      ...(sanitizedReport ? { proctoringReport: sanitizedReport } : {}),
      ...(mergedSnapshots.length > 0 ? { proctoringSnapshots: mergedSnapshots } : {}),
      completedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });

    if (appRef && appSnap?.exists) {
      const appData = appSnap.data() || {};
      const resolvedExamTitle = attempt.examTitle || exam.title || "Assessment";
      const appUpdates: Record<string, any> = {
        status: appStatus,
        _lastNotifiedStatus: appStatus,
        examScore: scorePercentage,
        examPassed: passed,
        examTerminated: false,
        examAttemptId: attemptDoc.id,
        examTitle: resolvedExamTitle,
        updatedAt: FieldValue.serverTimestamp(),
      };
      if (typeof appData.cvMatchScore === "number") {
        appUpdates.overallFitScore = Math.round(scorePercentage * 0.6 + appData.cvMatchScore * 0.4);
      }
      tx.update(appRef, appUpdates);
    }
    return "OK";
  });

  if (txResult === "EXPIRED") {
    throw new HttpsError("deadline-exceeded", "Exam window has expired.");
  }

  // 4 & 5. Dispatch in-app notifications to company and candidate concurrently
  const notificationTasks: Promise<any>[] = [];
  if (attempt.companyId) {
    notificationTasks.push(
      db.collection("notifications").add({
        userId: attempt.companyId,
        title: "Assessment Completed",
        body: `${attempt.candidateName || "Candidate"} has completed "${attempt.examTitle || "Assessment"}" with a score of ${scorePercentage}%.`,
        type: "EXAM_COMPLETED",
        entityId: attempt.applicationId || attemptDoc.id,
        actionUrl: `/company/applicants?applicationId=${attempt.applicationId || ""}&candidateId=${attempt.candidateId || ""}&jobId=${attempt.jobId || ""}`,
        data: {
          attemptId: attemptDoc.id,
          candidateId: attempt.candidateId || "",
          examId: attempt.examId || "",
          applicationId: attempt.applicationId || "",
          jobId: attempt.jobId || "",
          score: String(scorePercentage),
          passed: String(passed),
        },
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      })
    );
  }

  if (attempt.candidateId) {
    notificationTasks.push(
      db.collection("notifications").add({
        userId: attempt.candidateId,
        title: passed ? "Assessment Passed! 🎉" : "Assessment Completed",
        body: `You completed "${attempt.examTitle || "Assessment"}" with score ${scorePercentage}%.`,
        type: "EXAM_RESULT",
        entityId: attemptDoc.id,
        actionUrl: "/candidate/exams",
        data: {
          attemptId: attemptDoc.id,
          examId: attempt.examId || "",
          applicationId: attempt.applicationId || "",
          score: String(scorePercentage),
          passed: String(passed),
        },
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      })
    );
  }
  if (notificationTasks.length > 0) {
    await Promise.all(notificationTasks);
  }

  // Write unified Audit Log
  await writeAuditLog({
    actorId: attempt.candidateId || "SYSTEM",
    actorRole: "USER",
    action: "EXAM_SUBMITTED",
    targetType: "EXAM_ATTEMPT",
    targetId: attemptDoc.id,
    metadata: {
      candidateId: attempt.candidateId || "",
      companyId: attempt.companyId || "",
      examId: attempt.examId || "",
      applicationId: attempt.applicationId || "",
      score: scorePercentage,
      passed,
    },
  });

  logger.info(`Exam attempt ${attemptDoc.id} submitted. Score: ${scorePercentage}%, Passed: ${passed}`);

  return {
    success: true,
    score: scorePercentage,
    passed,
    passingPercentage,
    earnedPoints,
    totalPointsPossible,
  };
});

/**
 * Executes Gemini AI content generation with deduplicated automatic model fallback and retries.
 */
async function generateAiContentWithFallback(genAI: GoogleGenerativeAI, prompt: string): Promise<string> {
  const models = Array.from(
    new Set([
      process.env.GEMINI_MODEL || "gemini-2.5-flash",
      "gemini-2.5-flash",
      "gemini-flash-latest",
      "gemini-2.5-pro",
      "gemini-2.5-flash-lite",
    ])
  );

  let lastError: any = null;
  for (const modelName of models) {
    try {
      const model = genAI.getGenerativeModel({ model: modelName });
      const result = await model.generateContent(prompt);
      const text = result.response.text().trim();
      return text;
    } catch (err: any) {
      lastError = err;
      logger.warn(`Gemini model ${modelName} call failed (${err.status || err.message}), attempting fallback model...`);
    }
  }
  throw lastError || new Error("All available Gemini models failed.");
}

/**
 * Interface for Structured AI Resume Parsing Result
 */
interface ParsedResumeData {
  extractedSkills: string[];
  yearsOfExperience: number;
  educationLevel: string;
  summary: string;
  matchedSkills: string[];
  missingSkills: string[];
  cvMatchScore: number; // 0 - 100
  aiRecommendation: "STRONG_MATCH" | "POTENTIAL_MATCH" | "NOT_RECOMMENDED";
  aiRationale: string;
}

/**
 * Callable: Parses a candidate's uploaded resume using Google Gemini AI,
 * performs semantic skill extraction, matches against target job requirements,
 * and updates candidate application with AI insights.
 */
export const parseResumeWithAI = onCall({ cors: true }, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const callerIsAdmin = isCallerAdmin(request.auth?.token);
  const { applicationId } = request.data || {};
  if (typeof applicationId !== "string" || !applicationId.trim()) {
    throw new HttpsError("invalid-argument", "applicationId is required.");
  }
  const cleanAppId = applicationId.trim();

  // 1. Fetch application document and authorize company owner or admin strictly
  const appRef = db.collection("applications").doc(cleanAppId);
  const appDoc = await appRef.get();
  if (!appDoc.exists) {
    throw new HttpsError("not-found", "Application not found.");
  }
  const appData = appDoc.data()!;

  const isCompanyOwner = appData.companyId === callerUid;
  if (!callerIsAdmin && !isCompanyOwner) {
    throw new HttpsError("permission-denied", "Unauthorized to analyze this application.");
  }

  // 2 & 3. Fetch associated job posting and candidate profile concurrently
  const jobId = typeof appData.jobId === "string" ? appData.jobId.trim() : "";
  const candId = typeof appData.candidateId === "string" ? appData.candidateId.trim() : "";
  const [jobDoc, candidateDoc] = await Promise.all([
    jobId ? db.collection("jobs").doc(jobId).get() : Promise.resolve(null),
    candId ? db.collection("candidateProfiles").doc(candId).get() : Promise.resolve(null),
  ]);
  const jobData = jobDoc?.exists ? jobDoc.data()! : {};
  const requiredSkills: string[] = Array.isArray(jobData.requiredSkills) ? jobData.requiredSkills : [];
  const jobTitle = jobData.title || appData.jobTitle || "Job Position";
  const jobDesc = jobData.description || "";
  const experienceLevel = jobData.experienceLevel || "MID";

  const candidateData = candidateDoc?.exists ? candidateDoc.data()! : {};

  // Construct text profile payload for LLM analysis
  const candidateSkills: string[] = Array.isArray(candidateData.skills) ? candidateData.skills : [];
  const candidateExperience: any[] = Array.isArray(candidateData.experience) ? candidateData.experience : [];
  const candidateEducation: any[] = Array.isArray(candidateData.education) ? candidateData.education : [];
  const coverLetter = appData.coverLetter || "";

  // 4. Initialize Gemini strictly from server-configured environment credentials
  const apiKey = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY || "";

  let parsedResult: ParsedResumeData;

  try {
    if (!apiKey || apiKey === "TEST_KEY_FALLBACK") {
      throw new Error("Gemini API key is not configured.");
    }
    const genAI = new GoogleGenerativeAI(apiKey);

    const prompt = `
You are an expert HR Talent & Technical Recruitment AI for the hiring platform "Test2Hire".
Analyze the candidate's credentials against the job posting requirements and output a strictly valid JSON response.

=== TARGET JOB ===
Title: ${jobTitle}
Experience Level Required: ${experienceLevel}
Required Skills: ${JSON.stringify(requiredSkills)}
Job Summary: ${jobDesc}

=== CANDIDATE PROFILE ===
Name: ${appData.candidateName}
Headline: ${candidateData.headline || "Candidate"}
Bio/Summary: ${candidateData.bio || ""}
Documented Skills: ${JSON.stringify(candidateSkills)}
Experience Items: ${JSON.stringify(candidateExperience)}
Education Items: ${JSON.stringify(candidateEducation)}
Candidate Cover Letter: ${coverLetter}
CV File: ${appData.cvFileName || "N/A"} (${appData.cvUrl || "N/A"})

=== INSTRUCTIONS ===
1. Extract all technical and soft skills possessed by the candidate.
2. Calculate the candidate's estimated relevant years of professional experience.
3. Determine matched skills and missing skills relative to the job's required skills.
4. Calculate a cvMatchScore from 0 to 100 based on skill overlap, seniority, and education relevance.
5. Provide a 2-3 sentence hiring rationale and an aiRecommendation ("STRONG_MATCH", "POTENTIAL_MATCH", or "NOT_RECOMMENDED").

Output ONLY a JSON object with this exact structure, with no markdown code fences:
{
  "extractedSkills": ["string"],
  "yearsOfExperience": number,
  "educationLevel": "string",
  "summary": "string",
  "matchedSkills": ["string"],
  "missingSkills": ["string"],
  "cvMatchScore": number,
  "aiRecommendation": "STRONG_MATCH" | "POTENTIAL_MATCH" | "NOT_RECOMMENDED",
  "aiRationale": "string"
}
`;

    const responseText = await generateAiContentWithFallback(genAI, prompt);
    const rawParsed = sanitizeJsonResponse<Partial<ParsedResumeData>>(responseText);
    const clampedScore = Math.min(100, Math.max(0, Math.round(Number(rawParsed.cvMatchScore) || 0)));
    parsedResult = {
      extractedSkills: Array.isArray(rawParsed.extractedSkills) ? rawParsed.extractedSkills.map(String) : candidateSkills,
      yearsOfExperience: Math.max(0, Number(rawParsed.yearsOfExperience) || 0),
      educationLevel: String(rawParsed.educationLevel || "N/A"),
      summary: String(rawParsed.summary || ""),
      matchedSkills: Array.isArray(rawParsed.matchedSkills) ? rawParsed.matchedSkills.map(String) : [],
      missingSkills: Array.isArray(rawParsed.missingSkills) ? rawParsed.missingSkills.map(String) : [],
      cvMatchScore: clampedScore,
      aiRecommendation:
        rawParsed.aiRecommendation && ["STRONG_MATCH", "POTENTIAL_MATCH", "NOT_RECOMMENDED"].includes(rawParsed.aiRecommendation)
          ? rawParsed.aiRecommendation
          : (clampedScore >= 75 ? "STRONG_MATCH" : clampedScore >= 50 ? "POTENTIAL_MATCH" : "NOT_RECOMMENDED"),
      aiRationale: String(rawParsed.aiRationale || ""),
    };
  } catch (error) {
    logger.warn(`Gemini AI API call failed or unconfigured, using semantic rule-based fallback:`, error);

    // Rule-based deterministic fallback matching
    const normReq = requiredSkills.map((s) => s.toLowerCase().trim());
    const normCand = candidateSkills.map((s) => s.toLowerCase().trim());

    const matched = requiredSkills.filter((s) => normCand.includes(s.toLowerCase().trim()));
    const missing = requiredSkills.filter((s) => !normCand.includes(s.toLowerCase().trim()));

    const matchRatio = normReq.length > 0 ? matched.length / normReq.length : 0.7;
    const computedScore = Math.round(matchRatio * 100);

    const recommendation =
      computedScore >= 75
        ? "STRONG_MATCH"
        : computedScore >= 50
        ? "POTENTIAL_MATCH"
        : "NOT_RECOMMENDED";

    parsedResult = {
      extractedSkills: candidateSkills.length > 0 ? candidateSkills : ["General Technical Skills"],
      yearsOfExperience: candidateExperience.length > 0 ? candidateExperience.length * 2 : 2,
      educationLevel: candidateEducation[0]?.degree || "Bachelor's Degree",
      summary: candidateData.headline || "Evaluated candidate profile based on skills and submitted application.",
      matchedSkills: matched,
      missingSkills: missing,
      cvMatchScore: computedScore,
      aiRecommendation: recommendation,
      aiRationale: `Candidate possesses ${matched.length} out of ${requiredSkills.length} required skills for ${jobTitle}.`,
    };
  }

  // 5. Calculate Overall Candidate Fit Score (60% Exam Score + 40% CV Match Score)
  const examScore = Number(appData.examScore) || 0;
  const cvScore = parsedResult.cvMatchScore || 0;
  const overallFitScore = appData.examScore != null
    ? Math.round(examScore * 0.6 + cvScore * 0.4)
    : cvScore;

  // 6. Update Application with AI Insights and Score
  await appRef.update({
    aiParsedCv: parsedResult,
    cvMatchScore: parsedResult.cvMatchScore,
    overallFitScore,
    aiRecommendation: parsedResult.aiRecommendation,
    aiAnalyzedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });

  // 7. Unified Audit log
  await writeAuditLog({
    actorId: callerUid,
    actorRole: callerIsAdmin ? "ADMIN" : String(request.auth?.token?.role || (isCompanyOwner ? "COMPANY" : "USER")),
    action: "AI_RESUME_PARSED",
    targetType: "APPLICATION",
    targetId: cleanAppId,
    metadata: {
      companyId: appData.companyId || "",
      candidateId: appData.candidateId || "",
      cvMatchScore: parsedResult.cvMatchScore,
      overallFitScore,
      aiRecommendation: parsedResult.aiRecommendation,
    },
  });

  logger.info(`AI Resume parsing complete for application ${cleanAppId}. Fit score: ${overallFitScore}%`);

  return {
    success: true,
    applicationId: cleanAppId,
    parsedResult,
    overallFitScore,
  };
});

/**
 * ============================================================================
 * PHASE 11: CANDIDATE INTERVIEW MANAGEMENT & SCHEDULING
 * ============================================================================
 */

/**
 * Callable Function: Schedule an interview with a candidate
 */
export const scheduleInterview = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required to schedule interviews.");
  }

  const {
    applicationId,
    title,
    description,
    interviewType, // "VIDEO_CALL" | "IN_PERSON" | "PHONE"
    meetingUrl,
    location,
    slots, // Array of { startTime: string, endTime: string }
    interviewerNames,
  } = request.data || {};

  if (
    typeof applicationId !== "string" || !applicationId.trim() ||
    typeof title !== "string" || !title.trim() ||
    !Array.isArray(slots) || slots.length === 0
  ) {
    throw new HttpsError("invalid-argument", "Application ID, title, and at least one time slot are required.");
  }

  const cleanAppId = applicationId.trim();
  const validTypes = ["VIDEO_CALL", "IN_PERSON", "PHONE"];
  const normalizedType = typeof interviewType === "string" && validTypes.includes(interviewType)
    ? interviewType
    : "VIDEO_CALL";

  for (const s of slots) {
    if (!s || typeof s !== "object" || !s.startTime || !s.endTime) {
      throw new HttpsError("invalid-argument", "Each interview slot must include startTime and endTime.");
    }
  }

  // 1. Fetch application
  const appRef = db.collection("applications").doc(cleanAppId);
  const appDoc = await appRef.get();
  if (!appDoc.exists) {
    throw new HttpsError("not-found", "Application not found.");
  }

  const appData = appDoc.data()!;
  const isCompany = appData.companyId === request.auth.uid;
  const isAdmin = isCallerAdmin(request.auth.token);

  if (!isCompany && !isAdmin) {
    throw new HttpsError("permission-denied", "Only the hiring company can schedule an interview.");
  }

  // 2. Prepare interview document
  const interviewRef = db.collection("interviews").doc();
  const interviewId = interviewRef.id;

  // Auto-generate secure Jitsi room if video call and no custom URL provided
  const finalMeetingUrl = normalizedType === "VIDEO_CALL"
    ? (typeof meetingUrl === "string" && meetingUrl.trim().length > 0 ? meetingUrl.trim() : `https://meet.jit.si/test2hire-${interviewId}`)
    : (typeof meetingUrl === "string" && meetingUrl.trim().length > 0 ? meetingUrl.trim() : null);

  const parsedSlots = slots.map((s: any, index: number) => ({
    slotIndex: index,
    startTime: s.startTime,
    endTime: s.endTime,
    isSelected: slots.length === 1,
  }));

  const initialStatus = slots.length === 1 ? "CONFIRMED" : "PENDING_CANDIDATE";

  const interviewPayload = {
    id: interviewId,
    applicationId: cleanAppId,
    jobId: appData.jobId || "",
    jobTitle: appData.jobTitle || "",
    companyId: appData.companyId || request.auth.uid,
    companyName: appData.companyName || "",
    companyLogoUrl: appData.companyLogoUrl || null,
    candidateId: appData.candidateId || "",
    candidateName: appData.candidateName || "Candidate",
    candidateEmail: appData.candidateEmail || "",
    title: title.trim(),
    description: typeof description === "string" ? description.trim() : "",
    type: normalizedType,
    status: initialStatus,
    meetingUrl: finalMeetingUrl,
    location: typeof location === "string" && location.trim().length > 0 ? location.trim() : null,
    scheduledAt: parsedSlots[0]?.startTime || null,
    slots: parsedSlots,
    selectedSlotIndex: slots.length === 1 ? 0 : null,
    interviewerNames: Array.isArray(interviewerNames) ? interviewerNames.map(String) : [],
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };

  const batch = db.batch();
  batch.set(interviewRef, interviewPayload);
  batch.update(appRef, {
    status: "INTERVIEW_SCHEDULED",
    _lastNotifiedStatus: "INTERVIEW_SCHEDULED",
    interviewId,
    interviewStatus: initialStatus,
    updatedAt: FieldValue.serverTimestamp(),
  });
  if (appData.candidateId) {
    batch.set(db.collection("notifications").doc(), {
      userId: appData.candidateId,
      title: "Interview Invitation Received!",
      body: `${appData.companyName || "The hiring team"} has invited you to an interview for ${appData.jobTitle || "your application"}.`,
      type: "INTERVIEW_INVITATION",
      entityId: interviewId,
      data: {
        interviewId,
        applicationId: cleanAppId,
        jobId: appData.jobId || "",
      },
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();

  // 5. Unified Audit log
  await writeAuditLog({
    actorId: request.auth.uid,
    actorRole: isAdmin ? "ADMIN" : String(request.auth.token.role || "COMPANY"),
    action: "INTERVIEW_SCHEDULED",
    targetType: "INTERVIEW",
    targetId: interviewId,
    metadata: {
      applicationId: cleanAppId,
      companyId: appData.companyId || request.auth.uid,
      candidateId: appData.candidateId || "",
      status: initialStatus,
    },
  });

  logger.info(`Interview ${interviewId} scheduled for candidate ${appData.candidateName} (${appData.candidateId})`);

  return {
    success: true,
    interviewId,
    meetingUrl: finalMeetingUrl,
    status: initialStatus,
  };
});

/**
 * Callable Function: Candidate responds to interview invitation (Accept/Decline/Pick Slot)
 */
export const respondToInterview = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required to respond to interviews.");
  }

  const {
    interviewId,
    response, // "ACCEPT" | "DECLINE"
    selectedSlotIndex,
    declineReason,
  } = request.data || {};

  if (
    typeof interviewId !== "string" || !interviewId.trim() ||
    !["ACCEPT", "DECLINE"].includes(response)
  ) {
    throw new HttpsError("invalid-argument", "Valid interview ID and response (ACCEPT/DECLINE) are required.");
  }

  const cleanInterviewId = interviewId.trim();
  const interviewRef = db.collection("interviews").doc(cleanInterviewId);
  const interviewDoc = await interviewRef.get();
  if (!interviewDoc.exists) {
    throw new HttpsError("not-found", "Interview not found.");
  }

  const interviewData = interviewDoc.data()!;
  if (interviewData.candidateId !== request.auth.uid) {
    throw new HttpsError("permission-denied", "Only the invited candidate can respond to this interview.");
  }

  if (["COMPLETED", "CANCELLED"].includes(interviewData.status)) {
    throw new HttpsError("failed-precondition", `Cannot respond to an interview that is ${interviewData.status}.`);
  }

  const appId = typeof interviewData.applicationId === "string" ? interviewData.applicationId.trim() : "";
  const appRef = appId ? db.collection("applications").doc(appId) : null;
  const appSnap = appRef ? await appRef.get() : null;

  if (response === "ACCEPT") {
    const slots = Array.isArray(interviewData.slots) ? interviewData.slots : [];
    const slotIdx = typeof selectedSlotIndex === "number" ? selectedSlotIndex : 0;

    if (slots.length > 0 && (!Number.isInteger(slotIdx) || slotIdx < 0 || slotIdx >= slots.length)) {
      throw new HttpsError("invalid-argument", "Selected time slot index is out of range.");
    }

    const updatedSlots = slots.map((s: any, idx: number) => ({
      ...s,
      isSelected: idx === slotIdx,
    }));

    const batch = db.batch();
    batch.update(interviewRef, {
      status: "CONFIRMED",
      selectedSlotIndex: slotIdx,
      slots: updatedSlots,
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (appRef && appSnap?.exists) {
      batch.update(appRef, {
        interviewStatus: "CONFIRMED",
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    // Notify company
    if (interviewData.companyId) {
      await db.collection("notifications").add({
        userId: interviewData.companyId,
        title: "Interview Confirmed!",
        body: `${interviewData.candidateName || "Candidate"} has accepted the interview invitation for ${interviewData.jobTitle || "your vacancy"}.`,
        type: "INTERVIEW_CONFIRMED",
        entityId: cleanInterviewId,
        data: {
          interviewId: cleanInterviewId,
          applicationId: appId,
          jobId: interviewData.jobId || "",
        },
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
  } else {
    // DECLINE
    const cleanReason = typeof declineReason === "string" && declineReason.trim().length > 0
      ? declineReason.trim()
      : "Candidate declined the invitation.";

    const batch = db.batch();
    batch.update(interviewRef, {
      status: "DECLINED",
      declineReason: cleanReason,
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (appRef && appSnap?.exists) {
      batch.update(appRef, {
        interviewStatus: "DECLINED",
        interviewDeclineReason: cleanReason,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    // Notify company
    if (interviewData.companyId) {
      await db.collection("notifications").add({
        userId: interviewData.companyId,
        title: "Interview Declined",
        body: `${interviewData.candidateName || "Candidate"} declined the interview for ${interviewData.jobTitle || "your vacancy"}. ${declineReason ? `Reason: ${cleanReason}` : ""}`,
        type: "INTERVIEW_DECLINED",
        entityId: cleanInterviewId,
        data: {
          interviewId: cleanInterviewId,
          applicationId: appId,
          jobId: interviewData.jobId || "",
        },
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
  }

  await writeAuditLog({
    actorId: request.auth.uid,
    actorRole: String(request.auth.token.role || "USER"),
    action: response === "ACCEPT" ? "INTERVIEW_ACCEPTED" : "INTERVIEW_DECLINED",
    targetType: "INTERVIEW",
    targetId: cleanInterviewId,
    metadata: {
      applicationId: appId,
      companyId: interviewData.companyId || "",
      status: response === "ACCEPT" ? "CONFIRMED" : "DECLINED",
    },
  });

  logger.info(`Candidate ${request.auth.uid} responded ${response} to interview ${cleanInterviewId}`);

  return {
    success: true,
    interviewId: cleanInterviewId,
    status: response === "ACCEPT" ? "CONFIRMED" : "DECLINED",
  };
});

/**
 * Callable Function: Submit interview evaluation feedback and score (0-100 scale)
 */
export const submitInterviewFeedback = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required to submit feedback.");
  }

  const {
    interviewId,
    score, // 0 - 100
    recommendation, // "RECOMMEND_HIRE" | "NEUTRAL" | "DO_NOT_HIRE"
    notes,
  } = request.data || {};

  const numScore = Number(score);
  if (
    typeof interviewId !== "string" || !interviewId.trim() ||
    !Number.isFinite(numScore) ||
    typeof recommendation !== "string" || !recommendation.trim()
  ) {
    throw new HttpsError("invalid-argument", "Interview ID, numeric score, and recommendation are required.");
  }

  const cleanInterviewId = interviewId.trim();
  const interviewRef = db.collection("interviews").doc(cleanInterviewId);
  const interviewDoc = await interviewRef.get();
  if (!interviewDoc.exists) {
    throw new HttpsError("not-found", "Interview not found.");
  }

  const interviewData = interviewDoc.data()!;
  const isCompany = interviewData.companyId === request.auth.uid;
  const isAdmin = isCallerAdmin(request.auth.token);

  if (!isCompany && !isAdmin) {
    throw new HttpsError("permission-denied", "Only the interviewing company can submit evaluation feedback.");
  }

  const feedbackPayload = {
    interviewerId: request.auth.uid,
    score: Math.min(100, Math.max(0, Math.round(numScore))),
    recommendation: recommendation.trim(),
    notes: typeof notes === "string" ? notes.trim() : "",
    submittedAt: FieldValue.serverTimestamp(),
  };

  const appId = typeof interviewData.applicationId === "string" ? interviewData.applicationId.trim() : "";
  const appRef = appId ? db.collection("applications").doc(appId) : null;
  const appSnap = appRef ? await appRef.get() : null;

  const batch = db.batch();
  batch.update(interviewRef, {
    status: "COMPLETED",
    feedback: feedbackPayload,
    updatedAt: FieldValue.serverTimestamp(),
  });
  if (appRef && appSnap?.exists) {
    batch.update(appRef, {
      interviewScore: feedbackPayload.score,
      interviewRecommendation: feedbackPayload.recommendation,
      interviewStatus: "COMPLETED",
      updatedAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();

  // Unified Audit log
  await writeAuditLog({
    actorId: request.auth.uid,
    actorRole: isAdmin ? "ADMIN" : String(request.auth.token.role || "COMPANY"),
    action: "INTERVIEW_FEEDBACK_SUBMITTED",
    targetType: "INTERVIEW",
    targetId: cleanInterviewId,
    metadata: {
      applicationId: appId,
      companyId: interviewData.companyId || "",
      candidateId: interviewData.candidateId || "",
      score: feedbackPayload.score,
      recommendation: feedbackPayload.recommendation,
    },
  });

  logger.info(`Feedback submitted for interview ${cleanInterviewId}: score ${feedbackPayload.score}, rec ${feedbackPayload.recommendation}`);

  return {
    success: true,
    interviewId: cleanInterviewId,
    feedback: feedbackPayload,
  };
});

/**
 * ============================================================================
 * PHASE 12: JOB OFFER MANAGEMENT & CANDIDATE SELECTION
 * ============================================================================
 */

/**
 * Callable Function: Extend a formal digital job offer to a candidate
 */
export const extendJobOffer = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required to extend job offers.");
  }

  const {
    applicationId,
    offeredSalary,
    salaryCurrency, // "USD" | "EUR" | "JOD" | "SAR" | "AED" ...
    salaryPeriod, // "ANNUAL" | "MONTHLY"
    startDate,
    expiresInDays,
    benefits,
    termsAndNotes,
  } = request.data || {};

  const numericSalary = Number(offeredSalary);
  if (typeof applicationId !== "string" || !applicationId.trim() || !Number.isFinite(numericSalary) || numericSalary <= 0) {
    throw new HttpsError("invalid-argument", "Application ID and positive offered salary are required.");
  }

  const cleanAppId = applicationId.trim();

  // 1. Fetch application
  const appRef = db.collection("applications").doc(cleanAppId);
  const appDoc = await appRef.get();
  if (!appDoc.exists) {
    throw new HttpsError("not-found", "Application not found.");
  }

  const appData = appDoc.data()!;
  const isCompany = appData.companyId === request.auth.uid;
  const isAdmin = isCallerAdmin(request.auth.token);

  if (!isCompany && !isAdmin) {
    throw new HttpsError("permission-denied", "Only the hiring company can extend a job offer.");
  }

  // 2. Prepare offer document with dual Web/Mobile field compatibility
  const offerRef = db.collection("offers").doc();
  const offerId = offerRef.id;

  const daysValid = Number(expiresInDays) > 0 ? Math.min(Math.round(Number(expiresInDays)), 180) : 7;
  const expiresAtDate = new Date(Date.now() + daysValid * 24 * 60 * 60 * 1000);
  const normalizedCurrency = typeof salaryCurrency === "string" && salaryCurrency.trim() ? salaryCurrency.trim().toUpperCase() : "USD";
  const normalizedPeriod = salaryPeriod === "MONTHLY" ? "MONTHLY" : "ANNUAL";
  const cleanNotes = typeof termsAndNotes === "string" ? termsAndNotes.trim() : "";

  const offerPayload = {
    id: offerId,
    applicationId: cleanAppId,
    jobId: appData.jobId || "",
    jobTitle: appData.jobTitle || "",
    companyId: appData.companyId || request.auth.uid,
    companyName: appData.companyName || "",
    companyLogoUrl: appData.companyLogoUrl || null,
    candidateId: appData.candidateId || "",
    candidateName: appData.candidateName || "Candidate",
    candidateEmail: appData.candidateEmail || "",
    offeredSalary: numericSalary,
    salary: numericSalary,
    salaryCurrency: normalizedCurrency,
    currency: normalizedCurrency,
    salaryPeriod: normalizedPeriod,
    startDate: typeof startDate === "string" && startDate.trim() ? startDate.trim() : null,
    expiresAt: Timestamp.fromDate(expiresAtDate),
    benefits: Array.isArray(benefits) ? benefits.map(String) : [],
    termsAndNotes: cleanNotes,
    notes: cleanNotes,
    status: "PENDING_CANDIDATE",
    declineReason: null,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };

  const batch = db.batch();
  batch.set(offerRef, offerPayload);
  batch.update(appRef, {
    status: "SELECTED",
    _lastNotifiedStatus: "SELECTED",
    offerId,
    offerStatus: "PENDING_CANDIDATE",
    offerExtendedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
  if (appData.candidateId) {
    batch.set(db.collection("notifications").doc(), {
      userId: appData.candidateId,
      title: "Official Job Offer Received!",
      body: `Congratulations! ${appData.companyName || "The hiring team"} has extended an official job offer for the position of ${appData.jobTitle || "your application"}.`,
      type: "JOB_OFFER_EXTENDED",
      entityId: offerId,
      data: {
        offerId,
        applicationId: cleanAppId,
        jobId: appData.jobId || "",
      },
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  }
  await batch.commit();

  // 5. Unified Audit log
  await writeAuditLog({
    actorId: request.auth.uid,
    actorRole: isAdmin ? "ADMIN" : String(request.auth.token.role || "COMPANY"),
    action: "JOB_OFFER_EXTENDED",
    targetType: "OFFER",
    targetId: offerId,
    metadata: {
      applicationId: cleanAppId,
      companyId: appData.companyId || request.auth.uid,
      candidateId: appData.candidateId || "",
      offeredSalary: numericSalary,
      salaryCurrency: normalizedCurrency,
      salaryPeriod: normalizedPeriod,
    },
  });

  logger.info(`Job offer ${offerId} extended to candidate ${appData.candidateName} (${appData.candidateId})`);

  return {
    success: true,
    offerId,
    expiresAt: expiresAtDate.toISOString(),
  };
});

/**
 * Callable Function: Candidate responds to formal digital job offer (Accept/Decline)
 */
export const respondToJobOffer = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required to respond to job offers.");
  }

  const {
    offerId,
    response, // "ACCEPT" | "DECLINE"
    declineReason,
  } = request.data || {};

  if (
    typeof offerId !== "string" || !offerId.trim() ||
    !["ACCEPT", "DECLINE"].includes(response)
  ) {
    throw new HttpsError("invalid-argument", "Valid offer ID and response (ACCEPT/DECLINE) are required.");
  }

  const cleanOfferId = offerId.trim();
  const offerRef = db.collection("offers").doc(cleanOfferId);
  const offerDoc = await offerRef.get();
  if (!offerDoc.exists) {
    throw new HttpsError("not-found", "Job offer not found.");
  }

  const offerData = offerDoc.data()!;
  if (offerData.candidateId !== request.auth.uid) {
    throw new HttpsError("permission-denied", "Only the offered candidate can respond to this offer.");
  }

  if (offerData.status !== "PENDING_CANDIDATE") {
    throw new HttpsError("failed-precondition", `Cannot respond to an offer that is already ${offerData.status}.`);
  }

  // Verify offer hasn't expired
  const expiresAtDate = toDateOrNull(offerData.expiresAt);
  if (expiresAtDate && expiresAtDate < new Date()) {
    await offerRef.update({
      status: "EXPIRED",
      updatedAt: FieldValue.serverTimestamp(),
    });
    throw new HttpsError("deadline-exceeded", "This job offer has expired.");
  }

  const appId = typeof offerData.applicationId === "string" ? offerData.applicationId.trim() : "";
  const appRef = appId ? db.collection("applications").doc(appId) : null;
  const appSnap = appRef ? await appRef.get() : null;

  if (response === "ACCEPT") {
    const batch = db.batch();
    batch.update(offerRef, {
      status: "ACCEPTED",
      acceptedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (appRef && appSnap?.exists) {
      batch.update(appRef, {
        status: "SELECTED",
        _lastNotifiedStatus: "SELECTED",
        offerStatus: "ACCEPTED",
        offerAcceptedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    // Notify company
    if (offerData.companyId) {
      await db.collection("notifications").add({
        userId: offerData.companyId,
        title: "Job Offer Accepted!",
        body: `${offerData.candidateName || "Candidate"} has formally accepted the job offer for ${offerData.jobTitle || "your vacancy"}!`,
        type: "JOB_OFFER_ACCEPTED",
        entityId: cleanOfferId,
        data: {
          offerId: cleanOfferId,
          applicationId: appId,
          jobId: offerData.jobId || "",
        },
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
  } else {
    // DECLINE
    const cleanReason = typeof declineReason === "string" && declineReason.trim().length > 0
      ? declineReason.trim()
      : "Candidate declined the job offer.";

    const batch = db.batch();
    batch.update(offerRef, {
      status: "DECLINED",
      declineReason: cleanReason,
      declinedAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    if (appRef && appSnap?.exists) {
      batch.update(appRef, {
        offerStatus: "DECLINED",
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    // Notify company
    if (offerData.companyId) {
      await db.collection("notifications").add({
        userId: offerData.companyId,
        title: "Job Offer Declined",
        body: `${offerData.candidateName || "Candidate"} declined the job offer for ${offerData.jobTitle || "your vacancy"}. ${declineReason ? `Reason: ${cleanReason}` : ""}`,
        type: "JOB_OFFER_DECLINED",
        entityId: cleanOfferId,
        data: {
          offerId: cleanOfferId,
          applicationId: appId,
          jobId: offerData.jobId || "",
        },
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
  }

  // Unified Audit log
  await writeAuditLog({
    actorId: request.auth.uid,
    actorRole: String(request.auth.token.role || "USER"),
    action: response === "ACCEPT" ? "OFFER_ACCEPTED" : "OFFER_DECLINED",
    targetType: "OFFER",
    targetId: cleanOfferId,
    metadata: {
      applicationId: appId,
      companyId: offerData.companyId || "",
      candidateId: offerData.candidateId || "",
    },
  });

  logger.info(`Candidate ${request.auth.uid} responded ${response} to offer ${cleanOfferId}`);

  return {
    success: true,
    offerId: cleanOfferId,
    status: response === "ACCEPT" ? "ACCEPTED" : "DECLINED",
  };
});

/**
 * Callable Function: Employer withdraws a pending job offer
 */
export const withdrawJobOffer = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required to withdraw job offers.");
  }

  const { offerId, reason } = request.data || {};
  if (typeof offerId !== "string" || !offerId.trim()) {
    throw new HttpsError("invalid-argument", "Valid offer ID is required.");
  }

  const cleanOfferId = offerId.trim();
  const offerRef = db.collection("offers").doc(cleanOfferId);
  const offerDoc = await offerRef.get();
  if (!offerDoc.exists) {
    throw new HttpsError("not-found", "Job offer not found.");
  }

  const offerData = offerDoc.data()!;
  const isCompany = offerData.companyId === request.auth.uid;
  const isAdmin = isCallerAdmin(request.auth.token);

  if (!isCompany && !isAdmin) {
    throw new HttpsError("permission-denied", "Only the hiring company can withdraw this offer.");
  }

  if (["WITHDRAWN", "ACCEPTED", "DECLINED"].includes(offerData.status)) {
    throw new HttpsError("failed-precondition", `Cannot withdraw an offer that is already ${offerData.status}.`);
  }

  const cleanReason = typeof reason === "string" && reason.trim().length > 0
    ? reason.trim()
    : "Offer withdrawn by employer.";

  const appId = typeof offerData.applicationId === "string" ? offerData.applicationId.trim() : "";
  const appRef = appId ? db.collection("applications").doc(appId) : null;
  const appSnap = appRef ? await appRef.get() : null;

  const batch = db.batch();
  batch.update(offerRef, {
    status: "WITHDRAWN",
    declineReason: cleanReason,
    updatedAt: FieldValue.serverTimestamp(),
  });
  if (appRef && appSnap?.exists) {
    const appData = appSnap.data() || {};
    const appUpdates: Record<string, any> = {
      offerStatus: "WITHDRAWN",
      updatedAt: FieldValue.serverTimestamp(),
    };
    if (["SELECTED", "OFFER_EXTENDED"].includes(appData.status)) {
      appUpdates.status = "UNDER_REVIEW";
      appUpdates._lastNotifiedStatus = "UNDER_REVIEW";
    }
    batch.update(appRef, appUpdates);
  }
  await batch.commit();

  // Notify candidate about withdrawn offer
  if (offerData.candidateId) {
    await db.collection("notifications").add({
      userId: offerData.candidateId,
      title: "Job Offer Withdrawn",
      body: `${offerData.companyName || "The hiring company"} has withdrawn the job offer for ${offerData.jobTitle || "this position"}.${reason ? ` Note: ${cleanReason}` : ""}`,
      type: "JOB_OFFER_WITHDRAWN",
      entityId: cleanOfferId,
      data: {
        offerId: cleanOfferId,
        applicationId: appId,
        jobId: offerData.jobId || "",
      },
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  }

  // Unified Audit log
  await writeAuditLog({
    actorId: request.auth.uid,
    actorRole: isAdmin ? "ADMIN" : String(request.auth.token.role || "COMPANY"),
    action: "OFFER_WITHDRAWN",
    targetType: "OFFER",
    targetId: cleanOfferId,
    metadata: {
      applicationId: appId,
      companyId: offerData.companyId || "",
      candidateId: offerData.candidateId || "",
      reason: cleanReason,
    },
  });

  logger.info(`Job offer ${cleanOfferId} withdrawn by company ${offerData.companyId}`);

  return {
    success: true,
    offerId: cleanOfferId,
    status: "WITHDRAWN",
  };
});

/**
 * ============================================================================
 * PHASE 13: PUSH NOTIFICATIONS & IN-APP ALERTS ENGINE
 * ============================================================================
 */

/**
 * Callable Function: Register or refresh device FCM token
 */
export const saveFcmToken = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required to register device tokens.");
  }

  const { token, platform } = request.data || {};
  if (!token || typeof token !== "string" || token.trim().length === 0 || token.length > 4096) {
    throw new HttpsError("invalid-argument", "A valid FCM token string is required.");
  }

  const userId = request.auth.uid;
  const userRef = db.collection("users").doc(userId);

  await userRef.set(
    {
      fcmTokens: FieldValue.arrayUnion(token.trim()),
      lastDevicePlatform: typeof platform === "string" && platform.trim() ? platform.trim() : "unknown",
      updatedAt: FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  logger.info(`Registered FCM token for user ${userId}`);
  return { success: true };
});

/**
 * Callable Function: Unregister device FCM token on logout
 */
export const removeFcmToken = onCall({ cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const { token } = request.data || {};
  if (!token || typeof token !== "string" || token.trim().length === 0) {
    throw new HttpsError("invalid-argument", "Token string is required.");
  }

  const userId = request.auth.uid;
  const trimmedToken = token.trim();
  const userRef = db.collection("users").doc(userId);
  const userSnap = await userRef.get();

  if (userSnap.exists) {
    await userRef.update({
      fcmTokens: FieldValue.arrayRemove(trimmedToken),
      updatedAt: FieldValue.serverTimestamp(),
    });
  }

  const companyRef = db.collection("companies").doc(userId);
  const companySnap = await companyRef.get();
  if (companySnap.exists) {
    await companyRef.update({
      fcmTokens: FieldValue.arrayRemove(trimmedToken),
      updatedAt: FieldValue.serverTimestamp(),
    });
  }

  logger.info(`Removed FCM token for user ${userId}`);
  return { success: true };
});

/**
 * Firestore Trigger: When a notification document is created in /notifications/{id},
 * look up user device tokens and dispatch push notification via Firebase Cloud Messaging.
 */
export const onNotificationCreated = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) {
      logger.warn("No snapshot data for notification trigger");
      return;
    }

    const data = snapshot.data();
    const notificationId = event.params.notificationId;
    const userId = typeof data.userId === "string" ? data.userId.trim() : "";

    if (!userId) {
      logger.warn(`Notification ${notificationId} lacks target userId.`);
      return;
    }

    try {
      // 1. Fetch user and company documents concurrently to resolve registered FCM tokens
      let tokens: string[] = [];
      let ownerUidForCleanup: string | null = null;
      const [userDoc, companyDoc] = await Promise.all([
        db.collection("users").doc(userId).get(),
        db.collection("companies").doc(userId).get(),
      ]);
      let hasUserDoc = userDoc.exists;
      const hasCompanyDoc = companyDoc.exists;

      if (userDoc.exists) {
        const userData = userDoc.data()!;
        if (Array.isArray(userData.fcmTokens) && userData.fcmTokens.length > 0) {
          tokens.push(...userData.fcmTokens);
        } else if (userData.lastFcmToken) {
          tokens.push(userData.lastFcmToken);
        }
      }

      if (tokens.length === 0 && companyDoc.exists) {
        const compData = companyDoc.data()!;
        if (Array.isArray(compData.fcmTokens) && compData.fcmTokens.length > 0) {
          tokens.push(...compData.fcmTokens);
        } else if (compData.lastFcmToken) {
          tokens.push(compData.lastFcmToken);
        } else if (typeof compData.ownerUid === "string" && compData.ownerUid.trim()) {
          ownerUidForCleanup = compData.ownerUid.trim();
          const ownerDoc = await db.collection("users").doc(ownerUidForCleanup).get();
          hasUserDoc = hasUserDoc || ownerDoc.exists;
          if (ownerDoc.exists) {
            const ownerData = ownerDoc.data()!;
            if (Array.isArray(ownerData.fcmTokens)) {
              tokens.push(...ownerData.fcmTokens);
            } else if (ownerData.lastFcmToken) {
              tokens.push(ownerData.lastFcmToken);
            }
          }
        }
      }

      // Deduplicate tokens
      tokens = Array.from(new Set(tokens.filter((t) => typeof t === "string" && t.trim().length > 0)));

      if (tokens.length === 0) {
        logger.info(`User or Company ${userId} has no registered FCM tokens. Skipping push.`);
        return;
      }

      const title = String(data.title || "Test2Hire Alert");
      const body = String(data.body || "You have a new update in Test2Hire.");
      const type = String(data.type || "system");
      const actionUrl = String(data.actionUrl || "");
      const entityId = String(data.entityId || "");

      // Coerce custom payload values to string (FCM data map requires strictly strings)
      const extraData: Record<string, string> = {};
      if (data.data && typeof data.data === "object") {
        for (const [k, v] of Object.entries(data.data as Record<string, unknown>)) {
          if (v !== undefined && v !== null) {
            extraData[k] = typeof v === "string" ? v : JSON.stringify(v);
          }
        }
      }

      // 2. Dispatch multicast push in chunks of 500 tokens (FCM limit)
      const tokensToRemove: string[] = [];
      let totalSuccess = 0;
      let totalFailure = 0;

      for (let i = 0; i < tokens.length; i += 500) {
        const tokenChunk = tokens.slice(i, i + 500);
        const response = await messaging.sendEachForMulticast({
          tokens: tokenChunk,
          notification: {
            title,
            body,
          },
          data: {
            ...extraData,
            notificationId: String(notificationId),
            type,
            title,
            body,
            actionUrl,
            entityId,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          android: {
            priority: "high",
            notification: {
              channelId: "test2hire_alerts",
              title,
              body,
              sound: "default",
              defaultSound: true,
              defaultVibrateTimings: true,
              visibility: "public",
            },
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
                badge: 1,
              },
            },
          },
        });

        totalSuccess += response.successCount;
        totalFailure += response.failureCount;

        if (response.failureCount > 0) {
          response.responses.forEach((resp, idx) => {
            if (!resp.success) {
              const error = resp.error;
              if (
                error &&
                (error.code === "messaging/invalid-registration-token" ||
                  error.code === "messaging/registration-token-not-registered")
              ) {
                tokensToRemove.push(tokenChunk[idx]);
              }
            }
          });
        }
      }

      logger.info(
        `Dispatched push for notification ${notificationId}: ${totalSuccess} succeeded, ${totalFailure} failed.`
      );

      // 3. Safely purge expired / invalid tokens only on existing documents
      if (tokensToRemove.length > 0) {
        logger.info(`Purging ${tokensToRemove.length} stale FCM tokens for target ${userId}`);
        const cleanupOps: Promise<any>[] = [];
        if (userDoc.exists) {
          cleanupOps.push(
            db.collection("users").doc(userId).update({
              fcmTokens: FieldValue.arrayRemove(...tokensToRemove),
            })
          );
        }
        if (ownerUidForCleanup && ownerUidForCleanup !== userId) {
          const ownerSnap = await db.collection("users").doc(ownerUidForCleanup).get();
          if (ownerSnap.exists) {
            cleanupOps.push(
              db.collection("users").doc(ownerUidForCleanup).update({
                fcmTokens: FieldValue.arrayRemove(...tokensToRemove),
              })
            );
          }
        }
        if (hasCompanyDoc) {
          cleanupOps.push(
            db.collection("companies").doc(userId).update({
              fcmTokens: FieldValue.arrayRemove(...tokensToRemove),
            })
          );
        }
        if (cleanupOps.length > 0 || !hasUserDoc) {
          await Promise.allSettled(cleanupOps);
        }
      }
    } catch (err: any) {
      logger.error(`Failed to dispatch FCM push for notification ${notificationId}:`, err);
    }
  }
);

/**
 * Firestore Trigger: When a direct sourcing invitation is sent to a candidate in /talentPoolInvites/{inviteId},
 * automatically create an in-app and push notification for the candidate.
 */
export const onTalentPoolInviteCreated = onDocumentCreated(
  "talentPoolInvites/{inviteId}",
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const data = snapshot.data();
    const inviteId = event.params.inviteId;
    const candidateId = data.candidateId;

    if (!candidateId) return;

    const companyName = data.companyName || "A hiring company";
    const jobTitle = data.jobTitle || "an exciting position";

    await db.collection("notifications").add({
      userId: candidateId,
      title: "New Job Invitation! 🚀",
      body: `${companyName} invited you to apply for "${jobTitle}".`,
      type: "SOURCING_INVITATION",
      data: {
        inviteId,
        companyId: data.companyId || "",
        jobId: data.jobId || "",
      },
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });

    logger.info(`Notification dispatched for sourcing invite ${inviteId} to candidate ${candidateId}`);
  }
);
/**
 * Phase 14: Automated Evaluation, Candidate Scoring & Ranking Engine
 */

export interface ScorecardWeights {
  cvMatchWeight: number;    // e.g. 0.20
  examScoreWeight: number;   // e.g. 0.40
  interviewWeight: number;   // e.g. 0.40
}

const DEFAULT_WEIGHTS: ScorecardWeights = {
  cvMatchWeight: 0.20,
  examScoreWeight: 0.40,
  interviewWeight: 0.40,
};

/**
 * Callable Function: calculateCandidateScorecard
 * Calculates the multi-factor weighted composite score for an applicant, creates or updates
 * their scorecard, and updates the ranking position across all applicants for that job.
 */
export const calculateCandidateScorecard = onCall(
  { region: "us-central1", cors: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const { applicationId, customWeights } = (request.data || {}) as {
      applicationId?: string;
      customWeights?: Partial<ScorecardWeights>;
    };

    if (typeof applicationId !== "string" || !applicationId.trim()) {
      throw new HttpsError("invalid-argument", "applicationId is required.");
    }
    const cleanAppId = applicationId.trim();

    try {
      const appRef = db.collection("applications").doc(cleanAppId);
      const appSnap = await appRef.get();

      if (!appSnap.exists) {
        throw new HttpsError("not-found", "Application not found.");
      }

      const appData = appSnap.data()!;
      const callerId = request.auth.uid;
      const isOwnerCompany = appData.companyId === callerId;
      const isAdminUser = isCallerAdmin(request.auth.token);

      if (!isOwnerCompany && !isAdminUser) {
        throw new HttpsError("permission-denied", "Unauthorized to evaluate this application.");
      }

      const rawCvW = Number(customWeights?.cvMatchWeight ?? DEFAULT_WEIGHTS.cvMatchWeight);
      const rawExamW = Number(customWeights?.examScoreWeight ?? DEFAULT_WEIGHTS.examScoreWeight);
      const rawIntW = Number(customWeights?.interviewWeight ?? DEFAULT_WEIGHTS.interviewWeight);
      const weightSum =
        (Number.isFinite(rawCvW) && rawCvW >= 0 ? rawCvW : 0) +
        (Number.isFinite(rawExamW) && rawExamW >= 0 ? rawExamW : 0) +
        (Number.isFinite(rawIntW) && rawIntW >= 0 ? rawIntW : 0);

      const weights: ScorecardWeights =
        weightSum > 0
          ? {
              cvMatchWeight: Number(((Math.max(0, rawCvW)) / weightSum).toFixed(4)),
              examScoreWeight: Number(((Math.max(0, rawExamW)) / weightSum).toFixed(4)),
              interviewWeight: Number(((Math.max(0, rawIntW)) / weightSum).toFixed(4)),
            }
          : { ...DEFAULT_WEIGHTS };

      // 1. Gather component scores (all normalized to 0 - 100)
      const cvScore: number =
        typeof appData.cvMatchScore === "number" && Number.isFinite(appData.cvMatchScore)
          ? Math.min(100, Math.max(0, Math.round(appData.cvMatchScore)))
          : 0;

      const examScore: number =
        typeof appData.examScore === "number" && Number.isFinite(appData.examScore)
          ? Math.min(100, Math.max(0, Math.round(appData.examScore)))
          : 0;

      // Interview Score: fetch from completed interviews (0-100 scale, with legacy 1-5 scale support)
      let interviewScore = 0;
      const interviewsSnap = await db
        .collection("interviews")
        .where("applicationId", "==", cleanAppId)
        .where("status", "==", "COMPLETED")
        .get();

      if (!interviewsSnap.empty) {
        let totalFeedbackScore = 0;
        let count = 0;
        interviewsSnap.docs.forEach((doc) => {
          const fb = doc.data().feedback;
          if (fb && typeof fb.score === "number" && Number.isFinite(fb.score)) {
            totalFeedbackScore += Math.max(0, fb.score);
            count++;
          }
        });

        if (count > 0) {
          const avgScore = totalFeedbackScore / count;
          interviewScore = avgScore <= 5
            ? Math.min(100, Math.max(0, Math.round((avgScore / 5) * 100)))
            : Math.min(100, Math.max(0, Math.round(avgScore)));
        }
      }

      // 2. Compute composite weighted score clamped cleanly to 0 - 100
      const compositeScore = Math.min(
        100,
        Math.max(
          0,
          Math.round(
            cvScore * weights.cvMatchWeight +
            examScore * weights.examScoreWeight +
            interviewScore * weights.interviewWeight
          )
        )
      );

      // Determine recommendation badge
      let recommendation = "NEUTRAL";
      if (compositeScore >= 80) {
        recommendation = "STRONGLY_RECOMMENDED";
      } else if (compositeScore >= 65) {
        recommendation = "RECOMMENDED";
      } else if (compositeScore < 50) {
        recommendation = "NOT_RECOMMENDED";
      }

      // 3. Save or update scorecard document
      const scorecardData = {
        id: cleanAppId,
        applicationId: cleanAppId,
        jobId: appData.jobId || "",
        companyId: appData.companyId || "",
        candidateId: appData.candidateId || "",
        candidateName: appData.candidateName ?? "Candidate",
        candidateEmail: appData.candidateEmail ?? "",
        compositeScore,
        recommendation,
        weights,
        breakdown: {
          cvMatchScore: cvScore,
          examScore,
          interviewScore,
        },
        calculatedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };

      await db.collection("scorecards").doc(cleanAppId).set(scorecardData, { merge: true });

      // 4. Update the application document with composite score summary
      await appRef.update({
        compositeScore,
        overallFitScore: compositeScore,
        scorecardId: cleanAppId,
        evaluationRecommendation: recommendation,
        updatedAt: FieldValue.serverTimestamp(),
      });

      // 5. Trigger rank update across all applicants for this job
      if (typeof appData.jobId === "string" && appData.jobId.trim()) {
        await recalculateJobApplicantsRanking(appData.jobId.trim());
      }

      return {
        success: true,
        applicationId: cleanAppId,
        compositeScore,
        recommendation,
        breakdown: scorecardData.breakdown,
      };
    } catch (err: any) {
      logger.error("Error in calculateCandidateScorecard:", err);
      if (err instanceof HttpsError) throw err;
      throw new HttpsError("internal", err.message || "Failed to calculate candidate scorecard.");
    }
  }
);

/**
 * Helper: Recalculate ranking order for all applicants of a specific job in chunked batches
 */
async function recalculateJobApplicantsRanking(jobId: string): Promise<void> {
  if (!jobId) return;
  try {
    const scorecardsSnap = await db
      .collection("scorecards")
      .where("jobId", "==", jobId)
      .get();

    if (scorecardsSnap.empty) return;

    // Sort descending by compositeScore
    const sortedDocs = [...scorecardsSnap.docs].sort((a, b) => {
      const scoreA = a.data().compositeScore ?? 0;
      const scoreB = b.data().compositeScore ?? 0;
      return scoreB - scoreA;
    });

    // Chunk by 200 candidates per batch (max 2 ops each = 400 <= 500 Firestore batch limit)
    for (let start = 0; start < sortedDocs.length; start += 200) {
      const chunk = sortedDocs.slice(start, start + 200);
      const appRefs = chunk.map((docSnap) => db.collection("applications").doc(docSnap.id));
      const appSnaps = await db.getAll(...appRefs);
      const existingApps = new Map(appSnaps.filter((s) => s.exists).map((s) => [s.id, s]));

      const batch = db.batch();
      let hasChanges = false;
      chunk.forEach((docSnap, idx) => {
        const rank = start + idx + 1;
        if (docSnap.data().ranking !== rank) {
          batch.update(docSnap.ref, { ranking: rank, updatedAt: FieldValue.serverTimestamp() });
          hasChanges = true;
        }

        const appSnap = existingApps.get(docSnap.id);
        if (appSnap && appSnap.data()?.ranking !== rank) {
          batch.update(appSnap.ref, {
            ranking: rank,
            updatedAt: FieldValue.serverTimestamp(),
          });
          hasChanges = true;
        }
      });

      if (hasChanges) {
        await batch.commit();
      }
    }

    logger.info(`Updated applicant rankings for job ${jobId} (${sortedDocs.length} candidates).`);
  } catch (err: any) {
    logger.error(`Error recalculating ranking for job ${jobId}:`, err);
  }
}

/**
 * Callable Function: recalculateJobRankings
 * Allows owning company or admin to manually trigger re-ranking for a job
 */
export const recalculateJobRankings = onCall(
  { region: "us-central1", cors: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const { jobId } = (request.data || {}) as { jobId?: string };
    if (typeof jobId !== "string" || !jobId.trim()) {
      throw new HttpsError("invalid-argument", "jobId is required.");
    }
    const cleanJobId = jobId.trim();

    const jobSnap = await db.collection("jobs").doc(cleanJobId).get();
    if (!jobSnap.exists) {
      throw new HttpsError("not-found", "Job posting not found.");
    }
    const jobData = jobSnap.data()!;
    if (!isCallerAdmin(request.auth.token) && jobData.companyId !== request.auth.uid) {
      throw new HttpsError("permission-denied", "Only the hiring company or an administrator can recalculate rankings for this job.");
    }

    await recalculateJobApplicantsRanking(cleanJobId);
    return { success: true, jobId: cleanJobId };
  }
);

/**
 * Phase 15: AI Hiring Assistant & Smart Recommendation Engine
 */

export interface AiCandidateSummaryData {
  summaryText: string;
  keyStrengths: string[];
  potentialRedFlags: string[];
  hiringRisk: "LOW" | "MODERATE" | "HIGH";
  suggestedQuestions: string[];
  recommendationDecision: "STRONG_HIRE" | "HIRE" | "LEAN_HIRE" | "DO_NOT_HIRE";
  confidenceScore: number;
}

/**
 * Callable: generateCandidateAiSummary
 * Synthesizes candidate CV, assessment scores, and interview performance into an actionable AI executive briefing.
 */
export const generateCandidateAiSummary = onCall(
  { region: "us-central1", cors: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const { applicationId } = (request.data || {}) as {
      applicationId?: string;
    };

    if (typeof applicationId !== "string" || !applicationId.trim()) {
      throw new HttpsError("invalid-argument", "applicationId is required.");
    }
    const cleanAppId = applicationId.trim();

    try {
      const appRef = db.collection("applications").doc(cleanAppId);
      const appSnap = await appRef.get();

      if (!appSnap.exists) {
        throw new HttpsError("not-found", "Application not found.");
      }

      const appData = appSnap.data()!;
      const callerId = request.auth.uid;
      const isOwnerCompany = appData.companyId === callerId;
      const isAdminUser = isCallerAdmin(request.auth.token);

      if (!isOwnerCompany && !isAdminUser) {
        throw new HttpsError("permission-denied", "Unauthorized to generate AI summary for this application.");
      }

      // 1-3. Fetch scorecard, candidate profile, and interviews concurrently
      const candId = typeof appData.candidateId === "string" ? appData.candidateId.trim() : "";
      const [scorecardSnap, candidateSnap, interviewsSnap] = await Promise.all([
        db.collection("scorecards").doc(cleanAppId).get(),
        candId ? db.collection("candidateProfiles").doc(candId).get() : Promise.resolve(null),
        db.collection("interviews").where("applicationId", "==", cleanAppId).get(),
      ]);
      const scorecardData = scorecardSnap.exists ? scorecardSnap.data()! : {};
      const candidateProfile = candidateSnap?.exists ? candidateSnap.data()! : {};

      const interviewNotes: string[] = [];
      interviewsSnap.docs.forEach((doc) => {
        const d = doc.data();
        if (d.feedback?.notes) interviewNotes.push(d.feedback.notes);
      });

      const apiKey = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY || "";

      let summaryResult: AiCandidateSummaryData;

      try {
        if (!apiKey || apiKey === "TEST_KEY_FALLBACK") {
          throw new Error("Gemini API key not configured.");
        }
        const genAI = new GoogleGenerativeAI(apiKey);

        const prompt = `
You are an executive talent acquisition AI advisor for the hiring platform "Test2Hire".
Analyze the candidate's complete assessment profile for the position "${appData.jobTitle || "Target Role"}" and produce an executive hiring synthesis.

=== CANDIDATE PROFILE ===
Name: ${appData.candidateName || "Candidate"}
Headline: ${candidateProfile.headline || "Candidate"}
Skills: ${JSON.stringify(candidateProfile.skills || [])}
CV Match Score: ${appData.cvMatchScore ?? scorecardData.breakdown?.cvMatchScore ?? "N/A"}%
Technical Assessment Score: ${appData.examScore ?? scorecardData.breakdown?.examScore ?? "N/A"}%
Composite Overall Score: ${appData.compositeScore ?? scorecardData.compositeScore ?? "N/A"}%
Interview Feedback Notes: ${JSON.stringify(interviewNotes)}

=== INSTRUCTIONS ===
1. Provide a concise 2-3 paragraph executive summary of the candidate's fitness for the position.
2. List 3-5 distinct key strengths.
3. List 1-3 potential red flags, gap areas, or risks (or "None identified" if excellent).
4. Determine hiring risk level ("LOW", "MODERATE", or "HIGH").
5. Provide 3 tailored interview questions to probe remaining uncertainties.
6. Provide a recommendation decision: "STRONG_HIRE", "HIRE", "LEAN_HIRE", or "DO_NOT_HIRE".
7. Assign a confidence score from 50 to 100.

Output ONLY a JSON object with this exact structure:
{
  "summaryText": "string",
  "keyStrengths": ["string"],
  "potentialRedFlags": ["string"],
  "hiringRisk": "LOW" | "MODERATE" | "HIGH",
  "suggestedQuestions": ["string"],
  "recommendationDecision": "STRONG_HIRE" | "HIRE" | "LEAN_HIRE" | "DO_NOT_HIRE",
  "confidenceScore": number
}
`;

        const responseText = await generateAiContentWithFallback(genAI, prompt);
        const parsed = sanitizeJsonResponse<Partial<AiCandidateSummaryData>>(responseText);
        summaryResult = {
          summaryText: String(parsed.summaryText || ""),
          keyStrengths: Array.isArray(parsed.keyStrengths) ? parsed.keyStrengths.map(String) : [],
          potentialRedFlags: Array.isArray(parsed.potentialRedFlags) ? parsed.potentialRedFlags.map(String) : [],
          hiringRisk:
            parsed.hiringRisk && ["LOW", "MODERATE", "HIGH"].includes(parsed.hiringRisk)
              ? parsed.hiringRisk
              : "MODERATE",
          suggestedQuestions: Array.isArray(parsed.suggestedQuestions) ? parsed.suggestedQuestions.map(String) : [],
          recommendationDecision:
            parsed.recommendationDecision &&
            ["STRONG_HIRE", "HIRE", "LEAN_HIRE", "DO_NOT_HIRE"].includes(parsed.recommendationDecision)
              ? parsed.recommendationDecision
              : "HIRE",
          confidenceScore: Math.min(100, Math.max(0, Math.round(Number(parsed.confidenceScore) || 75))),
        };
      } catch (geminiErr) {
        logger.warn(`Gemini AI call failed, using deterministic fallback for summary:`, geminiErr);

        const score = appData.compositeScore ?? appData.examScore ?? 75;
        const isHigh = score >= 80;
        const isMed = score >= 60;

        summaryResult = {
          summaryText: `Candidate ${appData.candidateName || "Candidate"} demonstrates solid potential for ${appData.jobTitle || "Target Role"}. Evaluated composite rating stands at ${score}%.`,
          keyStrengths: [
            "Demonstrated relevant technical background and domain proficiency",
            "Clear alignment with core requirements for the target role",
            "Consistent performance in structured assessment stages",
          ],
          potentialRedFlags: isHigh ? ["No significant red flags detected."] : ["Further probe depth in advanced architecture topics during interview."],
          hiringRisk: isHigh ? "LOW" : isMed ? "MODERATE" : "HIGH",
          suggestedQuestions: [
            "Can you describe your experience leading technical delivery under tight deadlines?",
            "How do you approach debugging complex, non-deterministic performance bottlenecks?",
            "What criteria do you use to choose between competing architectural tradeoffs?",
          ],
          recommendationDecision: isHigh ? "STRONG_HIRE" : isMed ? "HIRE" : "LEAN_HIRE",
          confidenceScore: 85,
        };
      }

      // Save summary in aiSummaries collection
      const summaryDocRef = db.collection("aiSummaries").doc(cleanAppId);
      const summaryPayload = {
        id: cleanAppId,
        applicationId: cleanAppId,
        jobId: appData.jobId || "",
        companyId: appData.companyId || "",
        candidateId: appData.candidateId || "",
        candidateName: appData.candidateName || "Candidate",
        ...summaryResult,
        generatedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      };

      await summaryDocRef.set(summaryPayload, { merge: true });

      // Update application document with AI summary flag
      await appRef.update({
        aiSummaryGenerated: true,
        aiRecommendationDecision: summaryResult.recommendationDecision,
        updatedAt: FieldValue.serverTimestamp(),
      });

      return {
        success: true,
        summary: summaryPayload,
      };
    } catch (err: any) {
      logger.error("Error in generateCandidateAiSummary:", err);
      if (err instanceof HttpsError) throw err;
      throw new HttpsError("internal", err.message || "Failed to generate AI summary.");
    }
  }
);

/**
 * Callable: compareCandidatesWithAi
 * Generates an automated side-by-side comparative matrix and hiring decision rationale between multiple candidates.
 */
export const compareCandidatesWithAi = onCall(
  { region: "us-central1", cors: true },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Authentication is required.");
    }

    const { applicationIds, jobId } = (request.data || {}) as {
      applicationIds?: string[];
      jobId?: string;
    };

    const uniqueAppIds = Array.isArray(applicationIds)
      ? Array.from(new Set(applicationIds.filter((id) => typeof id === "string" && id.trim().length > 0).map((id) => id.trim()))).slice(0, 20)
      : [];

    if (uniqueAppIds.length < 2) {
      throw new HttpsError("invalid-argument", "At least 2 distinct valid applications are required for comparison.");
    }

    const callerUid = request.auth.uid;
    const callerIsAdmin = isCallerAdmin(request.auth.token);

    try {
      const cleanJobId = typeof jobId === "string" ? jobId.trim() : "";
      const appRefs = uniqueAppIds.map((id) => db.collection("applications").doc(id));
      const scorecardRefs = uniqueAppIds.map((id) => db.collection("scorecards").doc(id));

      const [appSnaps, scorecardSnaps, jobSnap] = await Promise.all([
        db.getAll(...appRefs),
        db.getAll(...scorecardRefs),
        cleanJobId ? db.collection("jobs").doc(cleanJobId).get() : Promise.resolve(null),
      ]);

      if (jobSnap?.exists && !callerIsAdmin && jobSnap.data()?.companyId !== callerUid) {
        throw new HttpsError("permission-denied", "Unauthorized to compare candidates for this job.");
      }

      const scorecardById = new Map(
        scorecardSnaps.filter((s) => s.exists).map((s) => [s.id, s.data()!])
      );

      const candidatesData: any[] = [];
      for (const appSnap of appSnaps) {
        if (appSnap.exists) {
          const data = appSnap.data()!;
          if (!callerIsAdmin && data.companyId !== callerUid) {
            throw new HttpsError("permission-denied", "Unauthorized to compare applications from another company.");
          }
          const sc = scorecardById.get(appSnap.id) || {};

          candidatesData.push({
            applicationId: appSnap.id,
            candidateName: data.candidateName || "Candidate",
            candidateEmail: data.candidateEmail || "",
            cvMatchScore: data.cvMatchScore ?? sc.breakdown?.cvMatchScore ?? 0,
            examScore: data.examScore ?? sc.breakdown?.examScore ?? 0,
            compositeScore: data.compositeScore ?? sc.compositeScore ?? 0,
            ranking: data.ranking ?? sc.ranking ?? 999,
          });
        }
      }

      if (candidatesData.length < 2) {
        throw new HttpsError("not-found", "At least 2 valid applications must exist for comparison.");
      }

      const apiKey = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY || "";

      let comparisonAnalysis: {
        winnerCandidateId: string;
        winnerCandidateName: string;
        comparativeRationale: string;
        keyDifferentiators: string[];
      };

      try {
        if (!apiKey || apiKey === "TEST_KEY_FALLBACK") {
          throw new Error("Gemini API key not configured.");
        }
        const genAI = new GoogleGenerativeAI(apiKey);

        const prompt = `
You are a senior talent partner evaluating multiple final-round candidates for Job ID ${cleanJobId || "N/A"}.
Compare the following candidates side-by-side:
${JSON.stringify(candidatesData, null, 2)}

Provide a decisive comparative recommendation.
Output ONLY JSON:
{
  "winnerCandidateId": "applicationId of the best candidate",
  "winnerCandidateName": "Name of the best candidate",
  "comparativeRationale": "Detailed paragraph explaining why the winner edges out the competition.",
  "keyDifferentiators": ["3-4 bullet points highlighting key competitive edges"]
}
`;

        const responseText = await generateAiContentWithFallback(genAI, prompt);
        const parsed = sanitizeJsonResponse<Partial<typeof comparisonAnalysis>>(responseText);
        const fallbackTop = [...candidatesData].sort((a, b) => b.compositeScore - a.compositeScore)[0];
        comparisonAnalysis = {
          winnerCandidateId:
            typeof parsed.winnerCandidateId === "string" && parsed.winnerCandidateId.trim()
              ? parsed.winnerCandidateId.trim()
              : fallbackTop.applicationId,
          winnerCandidateName:
            typeof parsed.winnerCandidateName === "string" && parsed.winnerCandidateName.trim()
              ? parsed.winnerCandidateName.trim()
              : fallbackTop.candidateName,
          comparativeRationale: String(parsed.comparativeRationale || ""),
          keyDifferentiators: Array.isArray(parsed.keyDifferentiators) ? parsed.keyDifferentiators.map(String) : [],
        };
      } catch (geminiErr) {
        // Deterministic fallback: pick highest compositeScore
        candidatesData.sort((a, b) => b.compositeScore - a.compositeScore);
        const top = candidatesData[0];
        comparisonAnalysis = {
          winnerCandidateId: top.applicationId,
          winnerCandidateName: top.candidateName,
          comparativeRationale: `${top.candidateName} ranked highest overall with a composite score of ${top.compositeScore}%, demonstrating the best balance between technical evaluation and resume alignment.`,
          keyDifferentiators: [
            `Top overall composite evaluation score (${top.compositeScore}%)`,
            `Strongest technical assessment rating (${top.examScore}%)`,
            "Well-rounded skill profile fitting organizational needs",
          ],
        };
      }

      const comparisonId = `comp_${cleanJobId || "job"}_${Date.now()}`;
      const payload = {
        id: comparisonId,
        jobId: cleanJobId,
        companyId: callerUid,
        candidates: candidatesData,
        ...comparisonAnalysis,
        createdAt: FieldValue.serverTimestamp(),
      };

      await db.collection("candidateComparisons").doc(comparisonId).set(payload);

      return {
        success: true,
        comparison: payload,
      };
    } catch (err: any) {
      logger.error("Error in compareCandidatesWithAi:", err);
      if (err instanceof HttpsError) throw err;
      throw new HttpsError("internal", err.message || "Failed to compare candidates.");
    }
  }
);

/**
 * Endpoint to safely initialize/seed the primary Admin account directly in Firebase Auth & Firestore.
 * Requires POST and a configured ADMIN_INIT_SECRET environment variable.
 */
export const initializeAdminAccount = onRequest({ cors: true }, async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).json({ error: "Method not allowed. Use POST." });
    return;
  }

  const expectedSecret = process.env.ADMIN_INIT_SECRET;
  if (!expectedSecret) {
    res.status(503).json({ error: "Admin initialization endpoint is not configured on this environment." });
    return;
  }

  const providedKeyRaw = req.get("x-admin-init-key") || (typeof req.body?.key === "string" ? req.body.key : "");
  const providedBuf = Buffer.from(providedKeyRaw);
  const expectedBuf = Buffer.from(expectedSecret);

  if (providedBuf.length !== expectedBuf.length || !crypto.timingSafeEqual(providedBuf, expectedBuf)) {
    res.status(403).json({ error: "Unauthorized. Secret key is invalid." });
    return;
  }

  const adminEmail = typeof req.body?.email === "string" ? req.body.email.trim() : "";
  const adminPassword = typeof req.body?.password === "string" ? req.body.password : "";

  if (!adminEmail || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(adminEmail)) {
    res.status(400).json({ error: "A valid admin email is required in request body." });
    return;
  }
  if (adminPassword.length < 10) {
    res.status(400).json({ error: "Admin password must be at least 10 characters." });
    return;
  }

  try {
    // Fail closed if any administrator already exists in Firestore
    const existingAdminSnap = await db
      .collection("users")
      .where("role", "in", ["ADMIN", "SUPERADMIN"])
      .limit(1)
      .get();
    if (!existingAdminSnap.empty) {
      res.status(403).json({ error: "An administrator account has already been initialized." });
      return;
    }

    let userRecord;
    try {
      userRecord = await auth.createUser({
        email: adminEmail,
        password: adminPassword,
        displayName: "Platform Administrator",
        emailVerified: true,
      });
    } catch (createError: any) {
      if (createError?.code === "auth/email-already-exists") {
        res.status(409).json({ error: "An account with this email already exists and cannot be overwritten." });
        return;
      }
      throw createError;
    }

    // Set Custom User Claims on Firebase Auth
    await auth.setCustomUserClaims(userRecord.uid, {
      role: "ADMIN",
      isAdmin: true,
      isApproved: true,
    });

    // Save in Firestore users collection
    await db.collection("users").doc(userRecord.uid).set({
      uid: userRecord.uid,
      email: adminEmail,
      fullName: "Platform Administrator",
      role: "ADMIN",
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });

    logger.info(`Admin account initialized successfully in Firebase Auth: ${userRecord.uid}`);
    res.status(200).json({
      success: true,
      message: "Admin account initialized successfully in Firebase Authentication.",
      uid: userRecord.uid,
      email: adminEmail,
      role: "ADMIN",
    });
  } catch (error: any) {
    logger.error("Error initializing admin account:", error);
    res.status(500).json({ error: error.message || "Failed to initialize admin account." });
  }
});

/**
 * Firestore Trigger: When a user document in /users/{userId} is updated,
 * detects changes in account suspension (isSuspended / status), disables or enables the user
 * in Firebase Auth, and creates an official notification which triggers an FCM push notification.
 */
export const onUserUpdated = onDocumentUpdated(
  "users/{userId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const userId = event.params.userId;
    const wasSuspended = before.isSuspended === true || before.status === "SUSPENDED";
    const isNowSuspended = after.isSuspended === true || after.status === "SUSPENDED";

    // 1. Account suspended
    if (!wasSuspended && isNowSuspended) {
      logger.info(`User ${userId} was suspended. Disabling in Firebase Auth and dispatching notification.`);
      try {
        await auth.updateUser(userId, { disabled: true });
      } catch (authErr) {
        logger.warn(`Failed to disable user ${userId} in Firebase Auth:`, authErr);
      }

      const reason = after.suspendReason || after.suspensionReason || "";
      await db.collection("notifications").add({
        userId: userId,
        title: "تم تعطيل حسابك / Account Suspended",
        body: reason
          ? `تم تعطيل حسابك من قبل إدارة المنصة. السبب: ${reason}`
          : "تم تعطيل حسابك من قبل إدارة المنصة. يرجى التواصل مع الدعم الفني لمزيد من التفاصيل.",
        type: "ACCOUNT_SUSPENDED",
        data: {
          isSuspended: "true",
          reason: reason,
        },
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }

    // 2. Account reactivated
    if (wasSuspended && !isNowSuspended) {
      logger.info(`User ${userId} was reactivated. Enabling in Firebase Auth and dispatching notification.`);
      try {
        await auth.updateUser(userId, { disabled: false });
      } catch (authErr) {
        logger.warn(`Failed to enable user ${userId} in Firebase Auth:`, authErr);
      }

      await db.collection("notifications").add({
        userId: userId,
        title: "تمت إعادة تفعيل حسابك / Account Reactivated",
        body: "تمت إعادة تفعيل حسابك بنجاح من قبل إدارة المنصة. يمكنك الآن تسجيل الدخول واستخدام المنصة.",
        type: "ACCOUNT_REACTIVATED",
        data: {
          isSuspended: "false",
        },
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
  }
);

/**
 * Firestore Trigger: When a company document in /companies/{companyId} is updated,
 * detects changes in verificationStatus (APPROVED, REJECTED, SUSPENDED) and creates a notification
 * which automatically dispatches an FCM push notification to the employer's device.
 */
export const onCompanyUpdated = onDocumentUpdated(
  "companies/{companyId}",
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;

    const companyId = event.params.companyId;
    const prevStatus = before.verificationStatus;
    const newStatus = after.verificationStatus;

    if (prevStatus === newStatus) return;

    const notes = after.verificationNotes || "";
    let title = "";
    let body = "";
    let notifType = "COMPANY_STATUS";

    if (newStatus === "SUSPENDED") {
      title = "تم تعليق حساب الشركة / Company Account Suspended";
      body = notes
        ? `تم تعليق حساب شركتك من قبل إدارة المنصة. السبب: ${notes}`
        : "تم تعليق حساب شركتك من قبل إدارة المنصة. يرجى التواصل مع الإدارة لمزيد من التفاصيل.";
      notifType = "COMPANY_SUSPENDED";
    } else if (newStatus === "APPROVED") {
      title = "تم توثيق وقبول الشركة / Company Approved";
      body = "تمت الموافقة على توثيق حساب شركتك بنجاح. يمكنك الآن نشر الوظائف وإجراء الاختبارات والمقابلات.";
      notifType = "COMPANY_APPROVED";
    } else if (newStatus === "REJECTED") {
      title = "تم رفض توثيق الشركة / Company Verification Rejected";
      body = notes
        ? `لم يتم قبول طلب توثيق شركتك. السبب: ${notes}`
        : "تم رفض طلب توثيق حساب الشركة. يرجى مراجعة البيانات وتقديم طلب جديد.";
      notifType = "COMPANY_REJECTED";
    }

    if (title) {
      await db.collection("notifications").add({
        userId: companyId,
        title: title,
        body: body,
        type: notifType,
        data: {
          companyId,
          status: newStatus,
          notes,
        },
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
  }
);

/**
 * Callable: Automatically generates exam assessment questions based on job requirements and skills
 * using Google Gemini AI.
 */
async function isCompanyOrAdminUser(uid: string, token: Record<string, any> | undefined): Promise<boolean> {
  if (isCallerAdmin(token) || token?.role === "COMPANY") {
    return true;
  }
  if (token?.role === "USER") {
    return false;
  }
  const [userSnap, companySnap] = await Promise.all([
    db.collection("users").doc(uid).get(),
    db.collection("companies").doc(uid).get(),
  ]);
  if (companySnap.exists) return true;
  const role = userSnap.data()?.role;
  return role === "COMPANY" || role === "ADMIN" || role === "SUPERADMIN";
}

/**
 * Callable: Automatically generates exam assessment questions based on job requirements and skills
 * using Google Gemini AI.
 */
export const generateExamQuestionsWithAI = onCall({ cors: true }, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const authorized = await isCompanyOrAdminUser(callerUid, request.auth?.token);
  if (!authorized) {
    throw new HttpsError("permission-denied", "Only hiring companies and administrators can generate assessments.");
  }

  const {
    jobTitle,
    requiredSkills = [],
    difficulty = "MID",
    questionCount: rawCount = 5,
    questionType = "SINGLE_CHOICE",
    language = "ar",
  } = request.data || {};

  if (typeof jobTitle !== "string" || !jobTitle.trim()) {
    throw new HttpsError("invalid-argument", "jobTitle is required.");
  }
  const cleanJobTitle = jobTitle.trim().slice(0, 200);
  const questionCount = Math.min(Math.max(Math.round(Number(rawCount) || 5), 1), 30);
  const cleanSkills = Array.isArray(requiredSkills) ? requiredSkills.map(String).slice(0, 30) : [];

  const apiKey = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY || "";

  try {
    if (!apiKey || apiKey === "TEST_KEY_FALLBACK") {
      throw new Error("Gemini API key not configured.");
    }
    const genAI = new GoogleGenerativeAI(apiKey);

    let typeGuideline = "";
    if (questionType === "TRUE_FALSE") {
      typeGuideline = `All questions must be True/False questions only. Each question must have exactly 2 options: ["صح", "خطأ"] (or ["True", "False"]). correctAnswerIndex must be 0 for True or 1 for False.`;
    } else if (questionType === "CODING") {
      typeGuideline = `All questions must be practical coding/engineering challenges containing code snippets or bug analyses with 4 technical options.`;
    } else if (questionType === "SHORT_ANSWER") {
      typeGuideline = `All questions must test core concepts and architectural trade-offs with 4 concise analytical options.`;
    } else if (questionType === "MIXED") {
      typeGuideline = `Generate a balanced mix of Multiple Choice (4 options), True/False (2 options), coding challenges (CODING), and conceptual analytical questions (SHORT_ANSWER).`;
    } else {
      typeGuideline = `Standard 4-option multiple-choice questions testing practical domain knowledge.`;
    }

    const langGuideline = language === "ar"
      ? `Write questions, options, and explanations in professional Arabic (you may include standard English technical terms like Docker, REST API, Git, async/await, Flutter, etc.).`
      : `Write all questions, options, and explanations in professional English.`;

    const prompt = `
You are an expert technical psychometrician and engineering interviewer for the hiring platform "Test2Hire".
Generate a technical assessment containing exactly ${questionCount} questions for the following role:
Role Title: ${cleanJobTitle}
Difficulty / Experience Level: ${difficulty}
Required Skills: ${JSON.stringify(cleanSkills)}
Question Format Requirement: ${questionType}
${typeGuideline}
${langGuideline}

Output strictly valid JSON with NO markdown fences:
{
  "title": "${cleanJobTitle} Assessment",
  "difficulty": "${difficulty}",
  "questionType": "${questionType}",
  "questions": [
    {
      "question": "string",
      "type": "${questionType === "TRUE_FALSE" ? "TRUE_FALSE" : questionType === "CODING" ? "CODING" : questionType === "SHORT_ANSWER" ? "SHORT_ANSWER" : "SINGLE_CHOICE"}",
      "options": ["string", "string"],
      "correctAnswerIndex": 0,
      "explanation": "string",
      "points": 10
    }
  ]
}
`;

    const responseText = await generateAiContentWithFallback(genAI, prompt);
    const parsed = sanitizeJsonResponse<Record<string, any>>(responseText);
    return { success: true, ...parsed };
  } catch (error: any) {
    logger.warn("Using structured fallback for exam question generation:", error?.message || error);

    const fallbackQuestions = [];
    const mixedCycle = ["SINGLE_CHOICE", "TRUE_FALSE", "CODING", "SHORT_ANSWER"];
    for (let i = 0; i < questionCount; i++) {
      const qNum = i + 1;
      const effectiveType = questionType === "MIXED" ? mixedCycle[i % mixedCycle.length] : questionType;

      if (effectiveType === "TRUE_FALSE") {
        const isTrue = i % 2 === 0;
        fallbackQuestions.push({
          question: language === "ar"
            ? `السؤال ${qNum}: في بيئات الإنتاج لـ ${cleanJobTitle}، هل يُعتبر تطبيق مبدأ الفصل بين الطبقات (Separation of Concerns) ضرورياً لتسهيل اختبار الكود وصيانته؟`
            : `Question ${qNum}: In production ${cleanJobTitle} systems, separation of concerns is critical for testability and maintainability.`,
          type: "TRUE_FALSE",
          options: language === "ar" ? ["صح", "خطأ"] : ["True", "False"],
          correctAnswerIndex: isTrue ? 0 : 1,
          explanation: language === "ar" ? "فصل المنطق عن واجهة المستخدم يتيح كتابة اختبارات أحادية دقيقة ومستقلة." : "Separating business logic enables deterministic unit testing.",
          points: 10,
        });
      } else if (effectiveType === "CODING") {
        fallbackQuestions.push({
          question: language === "ar"
            ? `السؤال ${qNum}: ما هو التعقيد الزمني (Time Complexity) الأمثل واستراتيجية معالجة الذاكرة عند معالجة تدفق بيانات ضخم في ${cleanJobTitle}؟`
            : `Question ${qNum}: What is the optimal time complexity and memory strategy when handling large stream processing in ${cleanJobTitle}?`,
          type: "CODING",
          options: language === "ar"
            ? [
                "استخدام O(N) مع معالجة الـ Streams وإلغاء الاشتراكات عند الانتهاء لتفادي تسريب الذاكرة (Memory Leaks)",
                "استخدام O(N^2) مع تحميل كامل البيانات دفعة واحدة في ذاكرة الـ RAM",
                "تكرار طلبات الشبكة المتزامنة داخل حلقة تكرارية دون Caching",
                "تعطيل الـ Garbage Collector تماماً أثناء المعالجة",
              ]
            : [
                "O(N) utilizing streaming pipelines and deterministically closing subscriptions to prevent leaks",
                "O(N^2) buffering entire datasets in heap memory synchronously",
                "Executing un-indexed sequential network calls inside nested loops",
                "Disabling runtime memory cleanups and disposal lifecycles",
              ],
          correctAnswerIndex: 0,
          explanation: language === "ar" ? "المعالجة التدفقية O(N) هي المعيار الأمثل لكفاءة استهلاك الذاكرة." : "Stream pipelines ensure predictable low memory footprint.",
          points: 10,
        });
      } else if (effectiveType === "SHORT_ANSWER") {
        fallbackQuestions.push({
          question: language === "ar"
            ? `السؤال ${qNum}: ما هو المبدأ المعماري الأنسب لتحقيق قابلية التوسع والاعتمادية في خدمات ${cleanJobTitle}؟`
            : `Question ${qNum}: Which architectural principle best improves scalability and reliability in ${cleanJobTitle} services?`,
          type: "SHORT_ANSWER",
          options: language === "ar"
            ? [
                "فصل المسؤوليات (Decoupling) واستخدام المعالجة غير المتزامنة مع آليات إعادة المحاولة المحدودة (Bounded Retries)",
                "ربط كافة الخدمات بقاعدة بيانات وعمليات متزامنة واحدة دون عزل للأعطال",
                "تخزين حالة الجلسات في ذاكرة خادم واحد فقط دون دعم التوسع الأفقي",
                "تجاهل معالجة الأخطاء لتقليل زمن الاستجابة الظاهري",
              ]
            : [
                "Decoupling services, stateless scaling, and asynchronous processing with bounded retries",
                "Tightly coupling synchronous service calls without circuit breakers or isolation",
                "Persisting all session state exclusively in single-node in-memory globals",
                "Suppressing error propagation paths to minimize response payload checks",
              ],
          correctAnswerIndex: 0,
          explanation: language === "ar" ? "فصل الاعتماديات والعزل يمنعان انتشار الأعطال ويتيحان التوسع الأفقي." : "Stateless decoupling enables fault isolation and horizontal scalability.",
          points: 10,
        });
      } else {
        fallbackQuestions.push({
          question: language === "ar"
            ? `السؤال ${qNum}: ما هي أفضل الممارسات المعتمدة في هندسة ${cleanJobTitle} لضمان أمان البيانات والتحكم في الوصول؟`
            : `Question ${qNum}: Which practice best guarantees data security and access control in ${cleanJobTitle}?`,
          type: effectiveType === "MULTIPLE_CHOICE" ? "MULTIPLE_CHOICE" : "SINGLE_CHOICE",
          options: language === "ar"
            ? [
                "التحقق من صحة الصلاحيات (Authorization) وتشفير البيانات على مستوى السيرفر وقواعد الأمان",
                "الاعتماد فقط على إخفاء الأزرار في واجهة المستخدم الأمامية",
                "تضمين مفاتيح المشرف السرية (API Keys) مباشرة داخل كود المتصفح أو التطبيق",
                "السماح بتمرير الحقول الحساسة بدون أي Validation",
              ]
            : [
                "Enforcing server-side and security-rule authorization tokens and claim validations",
                "Relying solely on hiding buttons in the client-side user interface",
                "Hardcoding administrator secret credentials directly in frontend bundles",
                "Trusting client-provided user roles without verification",
              ],
          correctAnswerIndex: 0,
          explanation: language === "ar" ? "التحقق من الصلاحيات على السيرفر يضمن حماية البيانات بغض النظر عن حالة العميل." : "Server-side rules prevent unauthorized access regardless of client tampering.",
          points: 10,
        });
      }
    }

    return {
      success: true,
      title: `${cleanJobTitle} Assessment`,
      difficulty: difficulty,
      questionType: questionType,
      questions: fallbackQuestions,
    };
  }
});

/**
 * Callable: Generates tailored interview questions and evaluation criteria for a candidate
 * based on their CV, matching skills, and missing requirements using Google Gemini AI.
 */
export const generateInterviewQuestionsWithAI = onCall({ cors: true }, async (request) => {
  const callerUid = request.auth?.uid;
  if (!callerUid) {
    throw new HttpsError("unauthenticated", "Authentication is required.");
  }

  const callerIsAdmin = isCallerAdmin(request.auth?.token);
  const { applicationId, jobTitle, candidateName, candidateSkills = [], missingSkills = [] } = request.data || {};

  let targetRole = typeof jobTitle === "string" && jobTitle.trim() ? jobTitle.trim() : "Target Role";
  let name = typeof candidateName === "string" && candidateName.trim() ? candidateName.trim() : "Candidate";
  let candSkills = Array.isArray(candidateSkills) ? candidateSkills : [];
  let gapSkills = Array.isArray(missingSkills) ? missingSkills : [];

  if (typeof applicationId === "string" && applicationId.trim()) {
    const appDoc = await db.collection("applications").doc(applicationId.trim()).get();
    if (!appDoc.exists) {
      throw new HttpsError("not-found", "Application not found.");
    }
    const appData = appDoc.data()!;
    if (!callerIsAdmin && appData.companyId !== callerUid) {
      throw new HttpsError("permission-denied", "Unauthorized to access this candidate application.");
    }
    name = appData.candidateName || name;
    targetRole = appData.jobTitle || targetRole;
    if (appData.aiParsedCv) {
      candSkills = appData.aiParsedCv.extractedSkills || candSkills;
      gapSkills = appData.aiParsedCv.missingSkills || gapSkills;
    }
  } else {
    const authorized = await isCompanyOrAdminUser(callerUid, request.auth?.token);
    if (!authorized) {
      throw new HttpsError("permission-denied", "Only hiring companies and administrators can generate interview guides.");
    }
  }

  const apiKey = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY || "";

  try {
    if (!apiKey || apiKey === "TEST_KEY_FALLBACK") {
      throw new Error("Gemini API key not configured.");
    }
    const genAI = new GoogleGenerativeAI(apiKey);

    const prompt = `
You are a senior hiring manager and technical interviewer for "Test2Hire".
Generate 5 high-impact, tailored interview questions for candidate "${name}" applying for "${targetRole}".
Candidate Extracted Skills: ${JSON.stringify(candSkills)}
Identified Skill Gaps / Missing Requirements: ${JSON.stringify(gapSkills)}

Structure:
- 2 Deep Technical questions to test their stated core competencies.
- 2 Questions specifically probing how they handle the missing skills / gap areas (${JSON.stringify(gapSkills)}).
- 1 Situational / behavioral leadership question.

For each question provide:
- "category": ("TECHNICAL" | "SKILL_GAP" | "BEHAVIORAL")
- "question": The exact interview question to ask.
- "whatToLookFor": What an excellent candidate response must demonstrate.
- "suggestedFollowUp": A follow-up probe.

Output strictly valid JSON with NO markdown fences:
{
  "candidateName": "${name}",
  "jobTitle": "${targetRole}",
  "interviewQuestions": [
    {
      "category": "string",
      "question": "string",
      "whatToLookFor": "string",
      "suggestedFollowUp": "string"
    }
  ]
}
`;

    const responseText = await generateAiContentWithFallback(genAI, prompt);
    const parsed = sanitizeJsonResponse<Record<string, any>>(responseText);
    return { success: true, ...parsed };
  } catch (error: any) {
    logger.warn("Using structured fallback for interview question generation:", error?.message || error);
    return {
      success: true,
      candidateName: name,
      jobTitle: targetRole,
      interviewQuestions: [
        {
          category: "TECHNICAL",
          question: `Can you walk us through a recent project where you applied your expertise in ${targetRole}?`,
          whatToLookFor: "Clear architecture, technical depth, and trade-off analysis.",
          suggestedFollowUp: "What were the primary performance bottlenecks and how did you resolve them?"
        }
      ]
    };
  }
});


