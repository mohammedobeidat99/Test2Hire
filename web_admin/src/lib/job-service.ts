import { db, auth } from "./firebase";
import {
  collection,
  getDocs,
  doc,
  updateDoc,
  deleteDoc,
  query,
  where,
  orderBy,
  limit,
  Timestamp,
  addDoc,
  serverTimestamp,
} from "firebase/firestore";

export type JobStatus = "DRAFT" | "PUBLISHED" | "CLOSED" | "ARCHIVED";

export interface JobRecord {
  id: string;
  companyId: string;
  companyName: string;
  companyLogoUrl?: string;
  title: string;
  description: string;
  jobType: string;
  workplaceType: string;
  experienceLevel: string;
  location?: {
    city?: string;
    country?: string;
  };
  salaryRange?: {
    min?: number;
    max?: number;
    currency?: string;
    isNegotiable?: boolean;
    isDisclosed?: boolean;
  };
  requiredSkills: string[];
  optionalSkills?: string[];
  status: JobStatus;
  applicantsCount: number;
  examId?: string;
  createdAt?: Timestamp | null;
  updatedAt?: Timestamp | null;
}

import { compareTimestampsDesc } from "./formatters";

export async function fetchJobs(statusFilter?: JobStatus | "ALL"): Promise<JobRecord[]> {
  try {
    const jobsRef = collection(db, "jobs");
    let snapshot;

    if (statusFilter && statusFilter !== "ALL") {
      try {
        snapshot = await getDocs(
          query(
            jobsRef,
            where("status", "==", statusFilter),
            orderBy("createdAt", "desc"),
            limit(200)
          )
        );
      } catch (indexErr: any) {
        if (!String(indexErr?.code || "").includes("failed-precondition")) {
          throw indexErr;
        }
        snapshot = await getDocs(
          query(jobsRef, where("status", "==", statusFilter), limit(200))
        );
      }
    } else {
      snapshot = await getDocs(query(jobsRef, orderBy("createdAt", "desc"), limit(200)));
    }
    const items = snapshot.docs.map((docSnap) => {
      const data = docSnap.data();
      return {
        id: docSnap.id,
        companyId: data.companyId || "",
        companyName: data.companyName || "Unknown Company",
        companyLogoUrl: data.companyLogoUrl,
        title: data.title || "Untitled Job",
        description: data.description || "",
        jobType: data.jobType || "FULL_TIME",
        workplaceType: data.workplaceType || "ON_SITE",
        experienceLevel: data.experienceLevel || "MID",
        location: data.location || { city: "", country: "" },
        salaryRange: data.salaryRange,
        requiredSkills: Array.isArray(data.requiredSkills) ? data.requiredSkills : [],
        optionalSkills: Array.isArray(data.optionalSkills) ? data.optionalSkills : [],
        status: (data.status as JobStatus) || "DRAFT",
        applicantsCount: typeof data.applicantsCount === "number" ? data.applicantsCount : 0,
        examId: data.examId,
        createdAt: data.createdAt,
        updatedAt: data.updatedAt,
      };
    });

    if (statusFilter && statusFilter !== "ALL") {
      items.sort((a, b) => compareTimestampsDesc(a.createdAt, b.createdAt));
    }

    return items;
  } catch (error) {
    console.error("Failed to fetch jobs:", error);
    throw error;
  }
}

export async function updateJobStatus(jobId: string, status: JobStatus): Promise<void> {
  try {
    const jobRef = doc(db, "jobs", jobId);
    await updateDoc(jobRef, {
      status,
      updatedAt: serverTimestamp(),
    });

    // Log admin action to auditLogs
    if (auth.currentUser) {
      await addDoc(collection(db, "auditLogs"), {
        actorId: auth.currentUser.uid,
        actorRole: "ADMIN",
        action: `JOB_${status}`,
        targetType: "JOB",
        targetId: jobId,
        metadata: { newStatus: status },
        timestamp: serverTimestamp(),
      });
    }
  } catch (error) {
    console.error(`Failed to update job status to ${status}:`, error);
    throw error;
  }
}

export async function deleteJob(jobId: string): Promise<void> {
  try {
    const jobRef = doc(db, "jobs", jobId);
    await deleteDoc(jobRef);

    if (auth.currentUser) {
      await addDoc(collection(db, "auditLogs"), {
        actorId: auth.currentUser.uid,
        actorRole: "ADMIN",
        action: "JOB_DELETED",
        targetType: "JOB",
        targetId: jobId,
        timestamp: serverTimestamp(),
      });
    }
  } catch (error) {
    console.error("Failed to delete job:", error);
    throw error;
  }
}
