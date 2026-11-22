import { auth, db, functions } from "./firebase";
import { httpsCallable } from "firebase/functions";
import {
  collection,
  getDocs,
  doc,
  getDoc,
  addDoc,
  updateDoc,
  deleteDoc,
  query,
  where,
  limit,
  onSnapshot,
  serverTimestamp,
  Timestamp,
  writeBatch,
} from "firebase/firestore";

function shouldFallbackFromCallable(err: any): boolean {
  const code = String(err?.code || "").toLowerCase();
  const businessErrors = [
    "permission-denied",
    "unauthenticated",
    "invalid-argument",
    "not-found",
    "failed-precondition",
    "already-exists",
  ];
  return !businessErrors.some((b) => code.includes(b));
}

// --- Types ---

export interface CompanyJob {
  id: string;
  companyId: string;
  companyName: string;
  companyLogoUrl?: string;
  title: string;
  description: string;
  jobType: string;
  workplaceType: string;
  experienceLevel: string;
  location: {
    city?: string;
    country?: string;
  };
  salaryRange?: {
    min?: number;
    max?: number;
    currency?: string;
    isNegotiable?: boolean;
    isDisclosed?: boolean;
  } | null;
  requiredSkills: string[];
  requirements?: string[];
  optionalSkills?: string[];
  status: "DRAFT" | "PUBLISHED" | "CLOSED" | "ARCHIVED";
  applicantsCount: number;
  examId?: string | null;
  createdAt?: any;
  updatedAt?: any;
}

export interface CompanyApplicant {
  id: string;
  jobId: string;
  jobTitle: string;
  companyId: string;
  companyName?: string;
  candidateId: string;
  candidateName: string;
  candidateEmail: string;
  candidatePhone?: string;
  candidateHeadline?: string;
  cvUrl?: string;
  cvFileName?: string;
  coverLetter?: string;
  status:
    | "APPLIED"
    | "UNDER_REVIEW"
    | "EXAM_ASSIGNED"
    | "PASSED"
    | "FAILED"
    | "INTERVIEW_SCHEDULED"
    | "OFFER_EXTENDED"
    | "SELECTED"
    | "HIRED"
    | "REJECTED"
    | "WITHDRAWN"
    | string;
  appliedAt?: any;
  examScore?: number;
  examPassed?: boolean;
  examTerminated?: boolean;
  examViolationCount?: number;
  examToken?: string;
  examAttemptId?: string;
  examTitle?: string;
  assignedChallengeId?: string;
  assignedChallengeTitle?: string;
  overallFitScore?: number;
  cvMatchScore?: number;
  aiRecommendation?: string;
  aiParsedCv?: {
    summary?: string;
    extractedSkills?: string[];
    matchedSkills?: string[];
    missingSkills?: string[];
    yearsOfExperience?: number;
    educationLevel?: string;
    aiRationale?: string;
    aiRecommendation?: string;
  };
}

export interface CompanyExam {
  id: string;
  companyId: string;
  title: string;
  description?: string;
  durationMinutes: number;
  passingScore: number;
  questionsCount?: number;
  questionIds?: string[];
  questions?: Array<{
    text: string;
    options: string[];
    correctIndex: number;
    correctIndices?: number[];
    points: number;
    type?: string;
    programmingLanguage?: string;
  }>;
  isArchived?: boolean;
  createdAt?: any;
}

export interface CompanyInterview {
  id: string;
  applicationId?: string;
  companyId: string;
  companyName?: string;
  candidateId: string;
  candidateName: string;
  candidateEmail?: string;
  jobId: string;
  jobTitle: string;
  title?: string;
  scheduledAt: string; // ISO date-time or formatted
  meetingType: "ONLINE" | "IN_PERSON";
  meetingUrl?: string;
  location?: string;
  notes?: string;
  status: "SCHEDULED" | "CONFIRMED" | "PENDING_CANDIDATE" | "COMPLETED" | "CANCELLED" | "DECLINED";
  createdAt?: any;
}

export interface CompanyOffer {
  id: string;
  applicationId?: string;
  companyId: string;
  companyName?: string;
  candidateId: string;
  candidateName: string;
  candidateEmail?: string;
  jobId: string;
  jobTitle: string;
  salary: number;
  currency: string;
  salaryPeriod?: "MONTHLY" | "ANNUAL";
  startDate: string;
  expirationDate: string;
  notes?: string;
  status: "PENDING_CANDIDATE" | "SENT" | "ACCEPTED" | "DECLINED" | "EXPIRED" | "WITHDRAWN";
  createdAt?: any;
}

export interface CompanyDashboardKPIs {
  activeJobs: number;
  totalApplicants: number;
  completedExams: number;
  scheduledInterviews: number;
}

export interface CompanyExamAttempt {
  id: string;
  examId: string;
  examTitle: string;
  companyId: string;
  candidateId: string;
  candidateName: string;
  candidateEmail: string;
  jobId: string;
  jobTitle: string;
  applicationId: string;
  token: string;
  status: string;
  durationMinutes: number;
  passingPercentage: number;
  totalQuestions: number;
  totalPoints: number;
  score: number;
  passed: boolean;
  violationCount: number;
  terminationReason?: string;
  lastViolationType?: string;
  lastViolationDetails?: string;
  proctoringSnapshots?: Array<{
    label: string;
    timestamp: string;
    imageDataUrl: string;
  }>;
  proctoringReport?: {
    cameraVerified?: boolean;
    micVerified?: boolean;
    audioPeakLevel?: number;
    snapshotsCount?: number;
    snapshots?: Array<{
      label: string;
      timestamp: string;
      imageDataUrl: string;
    }>;
    violationEvents?: Array<{
      type: string;
      details: string;
      timestamp: string;
    }>;
  };
  startedAt?: any;
  completedAt?: any;
  createdAt?: any;
  updatedAt?: any;
}

export interface CompanyExamViolation {
  id: string;
  attemptId: string;
  candidateId: string;
  companyId: string;
  examId: string;
  violationType: string;
  details: string;
  snapshotDataUrl?: string;
  timestamp?: any;
}

export interface CompanyChallenge {
  id: string;
  companyId: string;
  companyName: string;
  jobId?: string | null;
  jobTitle?: string | null;
  candidateId?: string | null;
  candidateName?: string | null;
  applicationId?: string | null;
  title: string;
  brief: string;
  detailedInstructions: string;
  difficulty: "BEGINNER" | "INTERMEDIATE" | "ADVANCED" | "EXPERT";
  deadlineDays: number;
  techStack: string[];
  deliverables: string[];
  starterTemplateUrl?: string | null;
  createdAt?: any;
}

export interface CompanyChallengeSubmission {
  id: string;
  challengeId: string;
  companyId: string;
  candidateId: string;
  candidateName: string;
  candidateEmail: string;
  githubRepoUrl: string;
  liveDemoUrl?: string | null;
  candidateNotes?: string | null;
  status: "PENDING" | "SUBMITTED" | "UNDER_REVIEW" | "APPROVED" | "REJECTED" | string;
  score?: number | null;
  reviewerFeedback?: string | null;
  submittedAt?: any;
  reviewedAt?: any;
}

// --- Service Functions ---

/**
 * Fetch Company Profile
 */
export async function getCompanyProfile(companyId: string) {
  try {
    const compRef = doc(db, "companies", companyId);
    const snap = await getDoc(compRef);
    if (!snap.exists()) return null;
    return { id: snap.id, ...snap.data() } as any;
  } catch (error) {
    console.error("Failed to fetch company profile:", error);
    throw error;
  }
}

/**
 * Update Company Profile
 */
export async function updateCompanyProfile(companyId: string, data: any) {
  try {
    const compRef = doc(db, "companies", companyId);
    const payload: Record<string, any> = {
      ...data,
      updatedAt: serverTimestamp(),
    };
    if (data.size && !data.teamSize) {
      payload.teamSize = data.size;
    } else if (data.teamSize && !data.size) {
      payload.size = data.teamSize;
    }
    if (data.city !== undefined || data.country !== undefined) {
      const existingLoc =
        typeof data.location === "object" && data.location !== null ? data.location : {};
      payload.location = {
        city: data.city ?? existingLoc.city ?? "",
        country: data.country ?? existingLoc.country ?? "",
        address: data.address ?? existingLoc.address ?? "",
      };
    }

    await updateDoc(compRef, payload);

    // Sync user profile record
    try {
      const userRef = doc(db, "users", companyId);
      const userUpdates: Record<string, any> = { updatedAt: serverTimestamp() };
      if (data.name) {
        userUpdates.fullName = data.name;
        userUpdates.companyName = data.name;
      }
      if (data.logoUrl !== undefined) {
        userUpdates.photoUrl = data.logoUrl;
      }
      if (data.contactPhone !== undefined) {
        userUpdates.phoneNumber = data.contactPhone;
      }
      await updateDoc(userRef, userUpdates);
    } catch (uErr) {
      console.warn("Could not sync company updates to user doc:", uErr);
    }

    // Cascade company name / logo changes to jobs, applications, interviews, offers, and communityPosts
    const hasNameChange = typeof data.name === "string" && data.name.trim().length > 0;
    const hasLogoChange = data.logoUrl !== undefined;
    if (hasNameChange || hasLogoChange) {
      const companyColUpdates: Record<string, any> = { updatedAt: serverTimestamp() };
      if (hasNameChange) companyColUpdates.companyName = data.name;
      if (hasLogoChange) companyColUpdates.companyLogoUrl = data.logoUrl || "";

      const collectionsToSync = ["jobs", "applications", "interviews", "offers"];
      await Promise.all(
        collectionsToSync.map(async (colName) => {
          try {
            const snap = await getDocs(
              query(collection(db, colName), where("companyId", "==", companyId))
            );
            if (snap.empty) return;
            for (let i = 0; i < snap.docs.length; i += 400) {
              const b = writeBatch(db);
              snap.docs.slice(i, i + 400).forEach((d) => b.update(d.ref, companyColUpdates));
              await b.commit();
            }
          } catch (syncErr) {
            console.warn(`Could not cascade company updates to ${colName}:`, syncErr);
          }
        })
      );

      try {
        const postsSnap = await getDocs(
          query(collection(db, "communityPosts"), where("authorId", "==", companyId))
        );
        if (!postsSnap.empty) {
          const postUpdates: Record<string, any> = { updatedAt: serverTimestamp() };
          if (hasNameChange) postUpdates.authorName = data.name;
          if (hasLogoChange) postUpdates.authorAvatarUrl = data.logoUrl || "";
          for (let i = 0; i < postsSnap.docs.length; i += 400) {
            const b = writeBatch(db);
            postsSnap.docs.slice(i, i + 400).forEach((d) => b.update(d.ref, postUpdates));
            await b.commit();
          }
        }
      } catch (postSyncErr) {
        console.warn("Could not cascade company updates to communityPosts:", postSyncErr);
      }
    }
  } catch (error) {
    console.error("Failed to update company profile:", error);
    throw error;
  }
}

/**
 * Fetch all Jobs for this Company
 */
export async function fetchCompanyJobs(
  companyId: string,
  prefetchedApplicants?: Array<{ jobId?: string; status?: string }>
): Promise<CompanyJob[]> {
  try {
    const q = query(
      collection(db, "jobs"),
      where("companyId", "==", companyId),
      limit(200)
    );
    const appsQ = query(
      collection(db, "applications"),
      where("companyId", "==", companyId),
      limit(500)
    );

    const [snap, appsSnap] = await Promise.all([
      getDocs(q),
      prefetchedApplicants ? Promise.resolve(null) : getDocs(appsQ),
    ]);

    const countsByJob: Record<string, number> = {};
    if (prefetchedApplicants) {
      prefetchedApplicants.forEach((a) => {
        if (a.jobId && a.status !== "WITHDRAWN") {
          countsByJob[a.jobId] = (countsByJob[a.jobId] || 0) + 1;
        }
      });
    } else if (appsSnap) {
      appsSnap.forEach((d) => {
        const data = d.data();
        if (data.jobId && data.status !== "WITHDRAWN") {
          countsByJob[data.jobId] = (countsByJob[data.jobId] || 0) + 1;
        }
      });
    }

    const jobs = snap.docs.map((d) => {
      const data = d.data();
      const realApplicants =
        countsByJob[d.id] ??
        (typeof data.applicantsCount === "number" ? data.applicantsCount : 0);
      return {
        id: d.id,
        companyId: data.companyId || companyId,
        companyName: data.companyName || "My Company",
        companyLogoUrl: data.companyLogoUrl,
        title: data.title || "Untitled Position",
        description: data.description || "",
        jobType: data.jobType || "FULL_TIME",
        workplaceType: data.workplaceType || "ON_SITE",
        experienceLevel: data.experienceLevel || "MID",
        location:
          typeof data.location === "object" && data.location !== null
            ? data.location
            : { city: String(data.location || ""), country: "" },
        salaryRange: data.salaryRange,
        requiredSkills: Array.isArray(data.requiredSkills) ? data.requiredSkills : [],
        optionalSkills: Array.isArray(data.optionalSkills) ? data.optionalSkills : [],
        status: (data.status as any) || "DRAFT",
        applicantsCount: realApplicants,
        examId: data.examId,
        createdAt: data.createdAt,
        updatedAt: data.updatedAt,
      } as CompanyJob;
    });

    return jobs.sort((a, b) => {
      const aTime = a.createdAt?.toMillis ? a.createdAt.toMillis() : 0;
      const bTime = b.createdAt?.toMillis ? b.createdAt.toMillis() : 0;
      return bTime - aTime;
    });
  } catch (error) {
    console.error("Failed to fetch company jobs:", error);
    throw error;
  }
}

/**
 * Create a new Job (Fully compatible with Mobile App JobPostingModel)
 */
export async function createCompanyJob(jobData: Omit<CompanyJob, "id">): Promise<string> {
  try {
    let companyName = jobData.companyName;
    let companyLogoUrl = jobData.companyLogoUrl || null;

    // Fetch real company name from companies/{companyId}
    try {
      const compDoc = await getDoc(doc(db, "companies", jobData.companyId));
      if (compDoc.exists()) {
        const cData = compDoc.data();
        if (cData.name) companyName = cData.name;
        if (cData.logoUrl) companyLogoUrl = cData.logoUrl;
      }
    } catch (_) {}

    const payload: Record<string, any> = {
      companyId: jobData.companyId,
      companyName: companyName || "Hiring Company",
      companyLogoUrl,
      title: jobData.title,
      description: jobData.description,
      requirements: jobData.requiredSkills || [],
      responsibilities: [],
      benefits: [],
      jobType: jobData.jobType || "FULL_TIME",
      workplaceType: jobData.workplaceType || "HYBRID",
      experienceLevel: jobData.experienceLevel || "MID",
      location: {
        city: jobData.location?.city || "Amman",
        country: jobData.location?.country || "Jordan",
      },
      salaryRange:
        jobData.salaryRange &&
        (jobData.salaryRange.min !== undefined || jobData.salaryRange.max !== undefined)
          ? {
              min: Number(jobData.salaryRange.min ?? jobData.salaryRange.max ?? 0),
              max: Number(jobData.salaryRange.max ?? jobData.salaryRange.min ?? 0),
              currency: jobData.salaryRange.currency || "JOD",
              isNegotiable: false,
              isDisclosed: true,
            }
          : null,
      requiredSkills: jobData.requiredSkills || [],
      optionalSkills: jobData.optionalSkills || [],
      status: jobData.status || "PUBLISHED",
      applicantsCount: 0,
      examId: jobData.examId || null,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };

    const docRef = await addDoc(collection(db, "jobs"), payload);
    return docRef.id;
  } catch (error) {
    console.error("Failed to create job:", error);
    throw error;
  }
}

/**
 * Update Job details or status
 */
export async function updateCompanyJob(jobId: string, data: Partial<CompanyJob>): Promise<void> {
  try {
    const jobRef = doc(db, "jobs", jobId);
    const cleanData: Record<string, any> = { ...data, updatedAt: serverTimestamp() };
    if (Array.isArray(data.requiredSkills) && data.requirements === undefined) {
      cleanData.requirements = data.requiredSkills;
    }
    Object.keys(cleanData).forEach((k) => {
      if (cleanData[k] === undefined) delete cleanData[k];
    });
    await updateDoc(jobRef, cleanData);
  } catch (error) {
    console.error("Failed to update job:", error);
    throw error;
  }
}

/**
 * Delete a Job
 */
export async function deleteCompanyJob(jobId: string): Promise<void> {
  try {
    await deleteDoc(doc(db, "jobs", jobId));
  } catch (error) {
    console.error("Failed to delete job:", error);
    throw error;
  }
}

/**
 * Fetch all Applicants for this Company
 */
export async function fetchCompanyApplicants(
  companyId: string,
  jobIdFilter?: string
): Promise<CompanyApplicant[]> {
  try {
    let q = query(
      collection(db, "applications"),
      where("companyId", "==", companyId),
      limit(300)
    );
    if (jobIdFilter && jobIdFilter !== "ALL") {
      q = query(
        collection(db, "applications"),
        where("companyId", "==", companyId),
        where("jobId", "==", jobIdFilter),
        limit(300)
      );
    }
    const snap = await getDocs(q);
    const applicants = snap.docs.map((d) => {
      const data = d.data();
      return {
        id: d.id,
        jobId: data.jobId || "",
        jobTitle: data.jobTitle || "Job",
        companyId: data.companyId || companyId,
        companyName: data.companyName || "",
        candidateId: data.candidateId || "",
        candidateName: data.candidateName || "Candidate",
        candidateEmail: data.candidateEmail || "",
        candidatePhone: data.candidatePhone,
        candidateHeadline: data.candidateHeadline,
        cvUrl: data.cvUrl,
        cvFileName: data.cvFileName || "Resume.pdf",
        coverLetter: data.coverLetter,
        status: (data.status || "APPLIED").toUpperCase(),
        appliedAt: data.appliedAt || data.createdAt,
        examScore: data.examScore,
        examPassed: data.examPassed,
        examTerminated: data.examTerminated,
        examViolationCount: data.examViolationCount,
        examToken: data.examToken,
        examAttemptId: data.examAttemptId,
        examTitle: data.examTitle,
        assignedChallengeId: data.assignedChallengeId,
        assignedChallengeTitle: data.assignedChallengeTitle,
        overallFitScore: data.overallFitScore ?? data.compositeScore,
        cvMatchScore: data.cvMatchScore,
        aiRecommendation: data.aiRecommendation || data.aiRecommendationDecision,
        aiParsedCv: data.aiParsedCv,
      } as CompanyApplicant;
    });

    return applicants.sort((a, b) => {
      const aTime = a.appliedAt?.toMillis ? a.appliedAt.toMillis() : 0;
      const bTime = b.appliedAt?.toMillis ? b.appliedAt.toMillis() : 0;
      return bTime - aTime;
    });
  } catch (error) {
    console.error("Failed to fetch applicants:", error);
    throw error;
  }
}

/**
 * Update Application Status (onApplicationStatusUpdated trigger handles candidate notifications)
 */
export async function updateApplicationStatus(
  applicationId: string,
  newStatus: string,
  notes?: string
): Promise<void> {
  try {
    const appRef = doc(db, "applications", applicationId);
    await updateDoc(appRef, {
      status: newStatus,
      updatedAt: serverTimestamp(),
      ...(notes ? { companyNotes: notes, rejectionReason: notes } : {}),
    });
  } catch (error) {
    console.error("Failed to update application status:", error);
    throw error;
  }
}

/**
 * Assign an Exam to a Candidate Application (Uses assignExamToApplication Cloud Function with Firestore batch fallback)
 */
export async function assignExamToCandidate(params: {
  applicationId: string;
  examId: string;
  durationMinutes?: number;
  deadlineDays?: number;
}): Promise<{ attemptId: string; token: string }> {
  const { applicationId, examId, durationMinutes, deadlineDays = 7 } = params;

  const examSnap = await getDoc(doc(db, "exams", examId));
  if (!examSnap.exists()) {
    throw new Error("Selected exam template does not exist.");
  }
  const examData = examSnap.data();

  const appSnap = await getDoc(doc(db, "applications", applicationId));
  if (!appSnap.exists()) {
    throw new Error("Application document not found.");
  }
  const appData = appSnap.data();

  try {
    const callAssign = httpsCallable<
      {
        examId: string;
        applicationId: string;
        candidateId: string;
        jobId?: string;
        durationMinutes?: number;
        deadlineDays?: number;
      },
      { success: boolean; attemptId: string; token: string }
    >(functions, "assignExamToApplication");

    const res = await callAssign({
      examId,
      applicationId,
      candidateId: appData.candidateId,
      jobId: appData.jobId,
      durationMinutes,
      deadlineDays,
    });
    if (res.data?.attemptId && res.data?.token) {
      return { attemptId: res.data.attemptId, token: res.data.token };
    }
  } catch (fnErr: any) {
    if (!shouldFallbackFromCallable(fnErr)) {
      throw fnErr;
    }
    console.warn("assignExamToApplication callable fallback to Firestore batch:", fnErr);
  }

  const duration = durationMinutes || examData.durationMinutes || 45;
  const expiresAtDate = new Date(Date.now() + deadlineDays * 24 * 60 * 60 * 1000);

  // Generate cryptographically secure 32-character access token
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  if (typeof globalThis.crypto?.getRandomValues !== "function") {
    throw new Error("Cryptographically secure token generation is unavailable.");
  }
  const bytes = new Uint32Array(32);
  globalThis.crypto.getRandomValues(bytes);
  let token = "";
  for (let i = 0; i < 32; i++) {
    token += chars.charAt(bytes[i] % chars.length);
  }

  const attemptRef = doc(collection(db, "examAttempts"));
  const batch = writeBatch(db);

  batch.set(attemptRef, {
    id: attemptRef.id,
    examId,
    examTitle: examData.title || "Technical Assessment",
    companyId: examData.companyId || appData.companyId,
    candidateId: appData.candidateId,
    candidateName: appData.candidateName || "Candidate",
    candidateEmail: appData.candidateEmail || "",
    jobId: appData.jobId || "",
    jobTitle: appData.jobTitle || "",
    applicationId,
    token,
    status: "INVITED",
    durationMinutes: duration,
    passingPercentage: examData.passingPercentage || examData.passingScore || 70,
    totalQuestions: examData.totalQuestions || examData.questionsCount || 0,
    totalPoints: examData.totalPoints || 100,
    score: 0,
    passed: false,
    invitationSentAt: serverTimestamp(),
    expiresAt: Timestamp.fromDate(expiresAtDate),
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });

  batch.update(doc(db, "applications", applicationId), {
    status: "EXAM_ASSIGNED",
    examAttemptId: attemptRef.id,
    examToken: token,
    examTitle: examData.title || "Technical Assessment",
    examDurationMinutes: duration,
    examExpiresAt: Timestamp.fromDate(expiresAtDate),
    updatedAt: serverTimestamp(),
  });

  await batch.commit();
  return { attemptId: attemptRef.id, token };
}

/**
 * Fetch Company Exams
 */
export async function fetchCompanyExams(companyId: string): Promise<CompanyExam[]> {
  try {
    const q = query(
      collection(db, "exams"),
      where("companyId", "==", companyId),
      limit(100)
    );
    const snap = await getDocs(q);
    return snap.docs
      .map((d) => {
        const data = d.data();
        return {
          id: d.id,
          companyId: data.companyId || companyId,
          title: data.title || "Exam",
          description: data.description || "",
          durationMinutes: data.durationMinutes || 30,
          passingScore: data.passingScore ?? data.passingPercentage ?? 70,
          questionsCount:
            data.totalQuestions ??
            data.questionsCount ??
            (Array.isArray(data.questionIds)
              ? data.questionIds.length
              : Array.isArray(data.questions)
              ? data.questions.length
              : 0),
          questionIds: data.questionIds || [],
          questions: data.questions || [],
          isArchived: data.isArchived || false,
          createdAt: data.createdAt,
        } as CompanyExam;
      })
      .filter((ex) => !ex.isArchived);
  } catch (error) {
    console.error("Failed to fetch exams:", error);
    throw error;
  }
}

/**
 * Fetch Company Exam Questions securely from `questions` collection (keeps answer keys out of `/exams`)
 */
export async function fetchCompanyExamQuestions(
  companyId: string,
  questionIds: string[]
): Promise<NonNullable<CompanyExam["questions"]>> {
  if (!companyId || !questionIds || questionIds.length === 0) return [];
  const q = query(
    collection(db, "questions"),
    where("companyId", "==", companyId),
    limit(300)
  );
  const snap = await getDocs(q);
  const docMap = new Map<string, any>();
  snap.docs.forEach((d) => docMap.set(d.id, d.data()));

  const results: NonNullable<CompanyExam["questions"]> = [];
  for (const qId of questionIds) {
    const data = docMap.get(qId);
    if (!data) continue;
    const optionsArr: string[] = Array.isArray(data.options)
      ? data.options.map((opt: any) =>
          typeof opt === "string" ? opt : String(opt?.text || opt?.label || "")
        )
      : [];
    const correctAnswers: string[] = Array.isArray(data.correctAnswers) ? data.correctAnswers : [];
    const correctIndices = correctAnswers
      .map((ans) => {
        const match = /^opt_(\d+)$/.exec(String(ans));
        if (match) return Math.max(0, Number(match[1]) - 1);
        const idxByOpt = Array.isArray(data.options)
          ? data.options.findIndex((o: any) => o?.id === ans || o === ans)
          : -1;
        return idxByOpt;
      })
      .filter((n) => n >= 0);

    results.push({
      text: String(data.title || data.description || data.text || ""),
      type: data.type ? String(data.type) : "SINGLE_CHOICE",
      options: optionsArr,
      correctIndex: correctIndices[0] ?? 0,
      correctIndices,
      points: Number(data.points) || 10,
      ...(data.programmingLanguage ? { programmingLanguage: String(data.programmingLanguage) } : {}),
    });
  }
  return results;
}

/**
 * Create Company Exam (Creates documents in `questions` collection + `exams` collection for full Mobile & Web Proctoring compatibility)
 */
export async function createCompanyExam(examData: Omit<CompanyExam, "id">): Promise<string> {
  try {
    const batch = writeBatch(db);
    const questionIds: string[] = [];
    let totalPoints = 0;

    const questionsList = examData.questions || [];
    for (const q of questionsList) {
      const qRef = doc(collection(db, "questions"));
      const pts = Number(q.points) || 10;
      totalPoints += pts;
      questionIds.push(qRef.id);

      const formattedOptions = (q.options || []).map((optText, idx) => ({
        id: `opt_${idx + 1}`,
        text: optText,
      }));
      const qType = q.type || (formattedOptions.length === 2 ? "TRUE_FALSE" : "SINGLE_CHOICE");
      const correctAnswers =
        qType === "MULTIPLE_CHOICE" && Array.isArray(q.correctIndices) && q.correctIndices.length > 0
          ? q.correctIndices.map((idx) => `opt_${idx + 1}`)
          : [`opt_${(Number(q.correctIndex) || 0) + 1}`];

      batch.set(qRef, {
        companyId: examData.companyId,
        title: q.text,
        description: q.text,
        type: qType,
        difficulty: "MEDIUM",
        points: pts,
        options: formattedOptions,
        correctAnswers,
        ...(q.programmingLanguage ? { programmingLanguage: q.programmingLanguage } : {}),
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    }

    const examRef = doc(collection(db, "exams"));
    batch.set(examRef, {
      companyId: examData.companyId,
      title: examData.title,
      description: examData.description || "",
      durationMinutes: Number(examData.durationMinutes) || 30,
      passingScore: Number(examData.passingScore) || 70,
      passingPercentage: Number(examData.passingScore) || 70,
      questionIds,
      bankIds: [],
      randomizeQuestions: true,
      randomizeOptions: true,
      proctoringEnabled: true,
      totalQuestions: questionIds.length,
      questionsCount: questionIds.length,
      totalPoints,
      isArchived: false,
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    });

    await batch.commit();
    return examRef.id;
  } catch (error) {
    console.error("Failed to create exam:", error);
    throw error;
  }
}

/**
 * Soft-archive Company Exam so existing examAttempts and audit trails remain intact
 */
export async function deleteCompanyExam(examId: string): Promise<void> {
  try {
    await updateDoc(doc(db, "exams", examId), {
      isArchived: true,
      updatedAt: serverTimestamp(),
    });
  } catch (error) {
    console.error("Failed to archive exam:", error);
    throw error;
  }
}

/**
 * Update Company Exam & Questions (Writes new/updated question docs + updates /exams/{examId})
 */
export async function updateCompanyExam(
  examId: string,
  examData: Omit<CompanyExam, "id">
): Promise<void> {
  try {
    const batch = writeBatch(db);
    const questionIds: string[] = [];
    let totalPoints = 0;

    const questionsList = examData.questions || [];
    for (const q of questionsList) {
      const qRef = doc(collection(db, "questions"));
      const pts = Number(q.points) || 10;
      totalPoints += pts;
      questionIds.push(qRef.id);

      const formattedOptions = (q.options || []).map((optText, idx) => ({
        id: `opt_${idx + 1}`,
        text: optText,
      }));
      const qType = q.type || (formattedOptions.length === 2 ? "TRUE_FALSE" : "SINGLE_CHOICE");
      const correctAnswers =
        qType === "MULTIPLE_CHOICE" && Array.isArray(q.correctIndices) && q.correctIndices.length > 0
          ? q.correctIndices.map((idx) => `opt_${idx + 1}`)
          : [`opt_${(Number(q.correctIndex) || 0) + 1}`];

      batch.set(qRef, {
        companyId: examData.companyId,
        title: q.text,
        description: q.text,
        type: qType,
        difficulty: "MEDIUM",
        points: pts,
        options: formattedOptions,
        correctAnswers,
        ...(q.programmingLanguage ? { programmingLanguage: q.programmingLanguage } : {}),
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
    }

    batch.update(doc(db, "exams", examId), {
      title: examData.title,
      description: examData.description || "",
      durationMinutes: Number(examData.durationMinutes) || 30,
      passingScore: Number(examData.passingScore) || 70,
      passingPercentage: Number(examData.passingScore) || 70,
      questionIds,
      totalQuestions: questionIds.length,
      questionsCount: questionIds.length,
      totalPoints,
      updatedAt: serverTimestamp(),
    });

    await batch.commit();
  } catch (error) {
    console.error("Failed to update exam:", error);
    throw error;
  }
}

/**
 * Real-time listener for all Company Exam Attempts (scores, failed/terminated violation attempts, & proctoring records)
 */
export function listenCompanyExamAttempts(
  companyId: string,
  callback: (attempts: CompanyExamAttempt[]) => void,
  onError?: (error: Error) => void
): () => void {
  const q = query(
    collection(db, "examAttempts"),
    where("companyId", "==", companyId),
    limit(300)
  );
  return onSnapshot(
    q,
    (snap) => {
      const list = snap.docs.map((d) => {
        const data = d.data();
        const violationCount = Math.max(
          Number(data.violationCount) || 0,
          Number(data.violationsCount) || 0
        );
        return {
          id: d.id,
          examId: data.examId || "",
          examTitle: data.examTitle || "Assessment",
          companyId: data.companyId || companyId,
          candidateId: data.candidateId || "",
          candidateName: data.candidateName || "Candidate",
          candidateEmail: data.candidateEmail || "",
          jobId: data.jobId || "",
          jobTitle: data.jobTitle || "",
          applicationId: data.applicationId || "",
          token: data.token || "",
          status: String(data.status || "INVITED").toUpperCase(),
          durationMinutes: Number(data.durationMinutes) || 45,
          passingPercentage: Number(data.passingPercentage ?? data.passingScore) || 70,
          totalQuestions: Number(data.totalQuestions) || 0,
          totalPoints: Number(data.totalPoints) || 0,
          score: Number(data.score) || 0,
          passed: Boolean(data.passed),
          violationCount,
          terminationReason: data.terminationReason,
          lastViolationType: data.lastViolationType,
          lastViolationDetails: data.lastViolationDetails,
          proctoringSnapshots: Array.isArray(data.proctoringSnapshots)
            ? data.proctoringSnapshots
            : Array.isArray(data.proctoringReport?.snapshots)
            ? data.proctoringReport.snapshots
            : [],
          proctoringReport: data.proctoringReport,
          startedAt: data.startedAt,
          completedAt: data.completedAt,
          createdAt: data.createdAt,
          updatedAt: data.updatedAt,
        } as CompanyExamAttempt;
      });
      list.sort((a, b) => {
        const aTime = a.completedAt?.toMillis
          ? a.completedAt.toMillis()
          : a.createdAt?.toMillis
          ? a.createdAt.toMillis()
          : (a.createdAt?.seconds || 0) * 1000;
        const bTime = b.completedAt?.toMillis
          ? b.completedAt.toMillis()
          : b.createdAt?.toMillis
          ? b.createdAt.toMillis()
          : (b.createdAt?.seconds || 0) * 1000;
        return bTime - aTime;
      });
      callback(list);
    },
    (error) => {
      console.error("listenCompanyExamAttempts error:", error);
      onError?.(error);
    }
  );
}

/**
 * Fetch detailed violation logs for a specific exam attempt
 */
export async function fetchExamAttemptViolations(
  companyId: string,
  attemptId: string
): Promise<CompanyExamViolation[]> {
  try {
    const q = query(
      collection(db, "examViolations"),
      where("companyId", "==", companyId),
      where("attemptId", "==", attemptId),
      limit(50)
    );
    const snap = await getDocs(q);
    const list = snap.docs.map((d) => {
      const data = d.data();
      return {
        id: d.id,
        attemptId: data.attemptId || attemptId,
        candidateId: data.candidateId || "",
        companyId: data.companyId || companyId,
        examId: data.examId || "",
        violationType: data.violationType || "VIOLATION",
        details: data.details || "",
        snapshotDataUrl: data.snapshotDataUrl,
        timestamp: data.timestamp,
      } as CompanyExamViolation;
    });
    list.sort((a, b) => {
      const aT = a.timestamp?.toMillis ? a.timestamp.toMillis() : (a.timestamp?.seconds || 0) * 1000;
      const bT = b.timestamp?.toMillis ? b.timestamp.toMillis() : (b.timestamp?.seconds || 0) * 1000;
      return aT - bT;
    });
    return list;
  } catch (error) {
    console.error("Failed to fetch exam violations:", error);
    return [];
  }
}

/**
 * Fetch Practical Assignments (`challenges`) owned by a company
 */
export async function fetchCompanyChallenges(companyId: string): Promise<CompanyChallenge[]> {
  try {
    const q = query(
      collection(db, "challenges"),
      where("companyId", "==", companyId),
      limit(150)
    );
    const snap = await getDocs(q);
    const list = snap.docs.map((d) => {
      const data = d.data();
      return {
        id: d.id,
        companyId: data.companyId || companyId,
        companyName: data.companyName || "",
        jobId: data.jobId || null,
        jobTitle: data.jobTitle || null,
        candidateId: data.candidateId || null,
        candidateName: data.candidateName || null,
        applicationId: data.applicationId || null,
        title: data.title || "Assignment",
        brief: data.brief || "",
        detailedInstructions: data.detailedInstructions || "",
        difficulty: (data.difficulty || "INTERMEDIATE").toUpperCase() as any,
        deadlineDays: Number(data.deadlineDays) || 3,
        techStack: Array.isArray(data.techStack) ? data.techStack.map(String) : [],
        deliverables: Array.isArray(data.deliverables) ? data.deliverables.map(String) : [],
        starterTemplateUrl: data.starterTemplateUrl || null,
        createdAt: data.createdAt,
      } as CompanyChallenge;
    });
    list.sort((a, b) => {
      const aT = a.createdAt?.toMillis ? a.createdAt.toMillis() : (a.createdAt?.seconds || 0) * 1000;
      const bT = b.createdAt?.toMillis ? b.createdAt.toMillis() : (b.createdAt?.seconds || 0) * 1000;
      return bT - aT;
    });
    return list;
  } catch (error) {
    console.error("Failed to fetch company challenges:", error);
    return [];
  }
}

export async function createCompanyChallenge(
  challenge: Omit<CompanyChallenge, "id">
): Promise<string> {
  const docRef = await addDoc(collection(db, "challenges"), {
    companyId: challenge.companyId,
    companyName: challenge.companyName || "Company",
    jobId: challenge.jobId || null,
    jobTitle: challenge.jobTitle || null,
    candidateId: challenge.candidateId || null,
    candidateName: challenge.candidateName || null,
    applicationId: challenge.applicationId || null,
    title: challenge.title.trim(),
    brief: challenge.brief.trim(),
    detailedInstructions: challenge.detailedInstructions.trim(),
    difficulty: challenge.difficulty || "INTERMEDIATE",
    deadlineDays: Number(challenge.deadlineDays) || 3,
    techStack: challenge.techStack || [],
    deliverables: challenge.deliverables || [],
    starterTemplateUrl: challenge.starterTemplateUrl || null,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });
  return docRef.id;
}

export async function updateCompanyChallenge(
  challengeId: string,
  updates: Partial<Omit<CompanyChallenge, "id" | "companyId">>
): Promise<void> {
  const clean: Record<string, any> = { updatedAt: serverTimestamp() };
  Object.entries(updates).forEach(([k, v]) => {
    if (v !== undefined) clean[k] = v;
  });
  await updateDoc(doc(db, "challenges", challengeId), clean);
}

export async function deleteCompanyChallenge(challengeId: string): Promise<void> {
  await deleteDoc(doc(db, "challenges", challengeId));
}

/**
 * Create a candidate-scoped practical assignment & notify the specific applicant
 */
export async function assignChallengeToCandidate(params: {
  companyId: string;
  companyName: string;
  applicationId: string;
  candidateId: string;
  candidateName: string;
  jobId: string;
  jobTitle: string;
  title: string;
  brief: string;
  detailedInstructions: string;
  difficulty?: "BEGINNER" | "INTERMEDIATE" | "ADVANCED" | "EXPERT";
  deadlineDays?: number;
  deliverables?: string[];
  techStack?: string[];
  starterTemplateUrl?: string | null;
}): Promise<string> {
  const challengeRef = doc(collection(db, "challenges"));
  const batch = writeBatch(db);

  batch.set(challengeRef, {
    companyId: params.companyId,
    companyName: params.companyName || "Company",
    jobId: params.jobId || null,
    jobTitle: params.jobTitle || null,
    candidateId: params.candidateId,
    candidateName: params.candidateName || "Candidate",
    applicationId: params.applicationId,
    title: params.title.trim(),
    brief: params.brief.trim(),
    detailedInstructions: params.detailedInstructions.trim(),
    difficulty: params.difficulty || "INTERMEDIATE",
    deadlineDays: Number(params.deadlineDays) || 3,
    techStack: params.techStack || [],
    deliverables: params.deliverables || [],
    starterTemplateUrl: params.starterTemplateUrl || null,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });

  if (params.applicationId) {
    batch.update(doc(db, "applications", params.applicationId), {
      assignedChallengeId: challengeRef.id,
      assignedChallengeTitle: params.title.trim(),
      updatedAt: serverTimestamp(),
    });
  }

  if (params.candidateId) {
    const notifRef = doc(collection(db, "notifications"));
    batch.set(notifRef, {
      userId: params.candidateId,
      title: "New Practical Assignment Assigned!",
      body: `${params.companyName || "Employer"} assigned you a practical task "${params.title.trim()}" for ${params.jobTitle || "your application"}.`,
      type: "CHALLENGE_ASSIGNED",
      entityId: challengeRef.id,
      actionUrl: `/assessments/challenge/${challengeRef.id}`,
      data: {
        challengeId: challengeRef.id,
        applicationId: params.applicationId,
        jobId: params.jobId,
      },
      isRead: false,
      createdAt: serverTimestamp(),
    });
  }

  await batch.commit();
  return challengeRef.id;
}

export async function fetchCompanyChallengeSubmissions(
  companyId: string
): Promise<CompanyChallengeSubmission[]> {
  try {
    const q = query(
      collection(db, "challengeSubmissions"),
      where("companyId", "==", companyId),
      limit(300)
    );
    const snap = await getDocs(q);
    const list = snap.docs.map((d) => {
      const data = d.data();
      return {
        id: d.id,
        challengeId: data.challengeId || "",
        companyId: data.companyId || companyId,
        candidateId: data.candidateId || "",
        candidateName: data.candidateName || "Candidate",
        candidateEmail: data.candidateEmail || "",
        githubRepoUrl: data.githubRepoUrl || "",
        liveDemoUrl: data.liveDemoUrl || null,
        candidateNotes: data.candidateNotes || null,
        status: String(data.status || "SUBMITTED").toUpperCase(),
        score: typeof data.score === "number" ? data.score : null,
        reviewerFeedback: data.reviewerFeedback || null,
        submittedAt: data.submittedAt,
        reviewedAt: data.reviewedAt,
      } as CompanyChallengeSubmission;
    });
    list.sort((a, b) => {
      const aT = a.submittedAt?.toMillis ? a.submittedAt.toMillis() : (a.submittedAt?.seconds || 0) * 1000;
      const bT = b.submittedAt?.toMillis ? b.submittedAt.toMillis() : (b.submittedAt?.seconds || 0) * 1000;
      return bT - aT;
    });
    return list;
  } catch (error) {
    console.error("Failed to fetch challenge submissions:", error);
    return [];
  }
}

export async function gradeChallengeSubmission(params: {
  submissionId: string;
  score: number;
  reviewerFeedback: string;
  status: "APPROVED" | "REJECTED" | "UNDER_REVIEW";
  candidateId?: string;
  challengeTitle?: string;
  challengeId?: string;
}): Promise<void> {
  await updateDoc(doc(db, "challengeSubmissions", params.submissionId), {
    score: Number(params.score),
    reviewerFeedback: params.reviewerFeedback.trim(),
    status: params.status,
    reviewedAt: serverTimestamp(),
  });

  if (params.candidateId) {
    try {
      await addDoc(collection(db, "notifications"), {
        userId: params.candidateId,
        title: params.status === "APPROVED" ? "Practical Assignment Approved!" : "Practical Assignment Reviewed",
        body: `Your submission for "${params.challengeTitle || "Assignment"}" was reviewed (Score: ${Math.round(params.score)}/100).`,
        type: "EXAM_RESULT",
        entityId: params.challengeId || params.submissionId,
        actionUrl: params.challengeId ? `/assessments/challenge/${params.challengeId}` : "/candidate/exams",
        data: { challengeId: params.challengeId || "", score: String(params.score) },
        isRead: false,
        createdAt: serverTimestamp(),
      });
    } catch (_) {}
  }
}

/**
 * Deterministic local Date/Time helpers shared between Web & Mobile interview views
 */
function parseInterviewDateTime(val: any): Date | null {
  if (!val) return null;
  if (val instanceof Date) return isNaN(val.getTime()) ? null : val;
  if (typeof val?.toDate === "function") {
    const d = val.toDate();
    return d instanceof Date && !isNaN(d.getTime()) ? d : null;
  }
  const str = String(val).trim();
  if (!str) return null;
  const localMatch = /^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?$/.exec(str);
  if (localMatch) {
    const [, y, m, d, hh, mm, ss] = localMatch;
    return new Date(Number(y), Number(m) - 1, Number(d), Number(hh), Number(mm), Number(ss || 0));
  }
  const parsed = new Date(str);
  return isNaN(parsed.getTime()) ? null : parsed;
}

function formatInterviewLocalDisplay(data: Record<string, any>): string {
  const firstSlot =
    Array.isArray(data.slots) && data.slots.length > 0
      ? data.slots[data.selectedSlotIndex || 0] || data.slots[0]
      : null;
  const dt =
    parseInterviewDateTime(firstSlot?.startTime) ||
    parseInterviewDateTime(data.scheduledAt);
  if (dt) {
    return dt.toLocaleString("en-US", {
      weekday: "short",
      month: "short",
      day: "numeric",
      year: "numeric",
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
    });
  }
  return String(firstSlot?.startTime || data.scheduledAt || "Scheduled");
}

/**
 * Fetch Company Interviews (Compatible with both Mobile App `slots` and Web `scheduledAt`)
 */
export async function fetchCompanyInterviews(companyId: string): Promise<CompanyInterview[]> {
  try {
    const q = query(
      collection(db, "interviews"),
      where("companyId", "==", companyId),
      limit(200)
    );
    const snap = await getDocs(q);
    return snap.docs.map((d) => {
      const data = d.data();
      const scheduledStr = formatInterviewLocalDisplay(data);

      const rawType = (data.meetingType || data.type || "ONLINE").toUpperCase();
      const meetingType: "ONLINE" | "IN_PERSON" =
        rawType === "IN_PERSON" ? "IN_PERSON" : "ONLINE";

      return {
        id: d.id,
        applicationId: data.applicationId || "",
        companyId: data.companyId || companyId,
        companyName: data.companyName || "",
        candidateId: data.candidateId || "",
        candidateName: data.candidateName || "Candidate",
        candidateEmail: data.candidateEmail,
        jobId: data.jobId || "",
        jobTitle: data.jobTitle || "Job",
        title: data.title || `Interview - ${data.jobTitle || "Job"}`,
        scheduledAt: scheduledStr || "Scheduled",
        meetingType,
        meetingUrl: data.meetingUrl || "",
        location: data.location || "",
        notes: data.notes || data.description || "",
        status: (data.status || "CONFIRMED").toUpperCase() as any,
        createdAt: data.createdAt,
      } as CompanyInterview;
    });
  } catch (error) {
    console.error("Failed to fetch interviews:", error);
    return [];
  }
}

/**
 * Schedule New Interview (Writes Mobile App `slots` & `type` + updates Application + sends Notification)
 */
export async function scheduleInterview(data: Omit<CompanyInterview, "id">): Promise<string> {
  try {
    let companyName = data.companyName || "Hiring Company";
    try {
      const compDoc = await getDoc(doc(db, "companies", data.companyId));
      if (compDoc.exists() && compDoc.data().name) {
        companyName = compDoc.data().name;
      }
    } catch (_) {}

    // Parse start and end time via explicit local date/time components so Web & Mobile timestamps match
    let startIso = new Date().toISOString();
    let endIso = new Date(Date.now() + 45 * 60 * 1000).toISOString();
    if (data.scheduledAt) {
      const parsed = parseInterviewDateTime(data.scheduledAt);
      if (parsed) {
        startIso = parsed.toISOString();
        endIso = new Date(parsed.getTime() + 45 * 60 * 1000).toISOString();
      }
    }

    const mobileType = data.meetingType === "IN_PERSON" ? "IN_PERSON" : "VIDEO_CALL";

    if (data.applicationId) {
      try {
        const callSchedule = httpsCallable<
          {
            applicationId: string;
            title: string;
            description?: string;
            interviewType: string;
            meetingUrl?: string;
            location?: string;
            slots: Array<{ startTime: string; endTime: string }>;
            interviewerNames?: string[];
          },
          { success: boolean; interviewId: string }
        >(functions, "scheduleInterview");

        const res = await callSchedule({
          applicationId: data.applicationId,
          title: data.title || `Interview for ${data.jobTitle}`,
          description: data.notes || "",
          interviewType: mobileType,
          meetingUrl: data.meetingType === "ONLINE" ? data.meetingUrl : undefined,
          location: data.meetingType === "IN_PERSON" ? data.location : undefined,
          slots: [{ startTime: startIso, endTime: endIso }],
          interviewerNames: [],
        });

        if (res.data?.interviewId) {
          return res.data.interviewId;
        }
      } catch (fnErr: any) {
        if (!shouldFallbackFromCallable(fnErr)) {
          throw fnErr;
        }
        console.warn("scheduleInterview callable fallback to Firestore batch:", fnErr);
      }
    }

    let companyLogoUrl: string | null = null;
    try {
      const compSnap = await getDoc(doc(db, "companies", data.companyId));
      if (compSnap.exists()) {
        companyLogoUrl = compSnap.data().logoUrl || null;
      }
    } catch (_) {}

    const interviewRef = doc(collection(db, "interviews"));

    const payload = {
      id: interviewRef.id,
      applicationId: data.applicationId || "",
      companyId: data.companyId,
      companyName,
      companyLogoUrl,
      candidateId: data.candidateId,
      candidateName: data.candidateName,
      candidateEmail: data.candidateEmail || "",
      jobId: data.jobId,
      jobTitle: data.jobTitle,
      title: data.title || `Interview for ${data.jobTitle}`,
      description: data.notes || "",
      notes: data.notes || "",
      type: mobileType,
      meetingType: data.meetingType,
      meetingUrl: data.meetingType === "ONLINE" ? (data.meetingUrl || `https://meet.jit.si/test2hire-${interviewRef.id}`) : null,
      location: data.meetingType === "IN_PERSON" ? (data.location || "Company Office") : null,
      scheduledAt: startIso,
      slots: [
        {
          slotIndex: 0,
          startTime: startIso,
          endTime: endIso,
          isSelected: true,
        },
      ],
      selectedSlotIndex: 0,
      interviewerNames: [],
      status: data.status || "CONFIRMED",
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    };

    const batch = writeBatch(db);
    batch.set(interviewRef, payload);

    if (data.applicationId) {
      batch.update(doc(db, "applications", data.applicationId), {
        status: "INTERVIEW_SCHEDULED",
        interviewId: interviewRef.id,
        updatedAt: serverTimestamp(),
      });
    }

    if (data.candidateId) {
      const notifRef = doc(collection(db, "notifications"));
      batch.set(notifRef, {
        userId: data.candidateId,
        title: "Interview Invitation! 📅",
        body: `${companyName} invited you to an interview for ${data.jobTitle} on ${data.scheduledAt}. Please confirm your attendance.`,
        type: "INTERVIEW_INVITATION",
        entityId: interviewRef.id,
        data: {
          interviewId: interviewRef.id,
          jobId: data.jobId,
          applicationId: data.applicationId || "",
        },
        isRead: false,
        createdAt: serverTimestamp(),
      });
    }

    await batch.commit();
    return interviewRef.id;
  } catch (error) {
    console.error("Failed to schedule interview:", error);
    throw error;
  }
}

/**
 * Update Interview Status (e.g., COMPLETED, CANCELLED) & Notify Candidate
 */
export async function updateInterviewStatus(interviewId: string, status: string): Promise<void> {
  try {
    const intRef = doc(db, "interviews", interviewId);
    const intSnap = await getDoc(intRef);
    const intData = intSnap.exists() ? intSnap.data() : null;

    await updateDoc(intRef, {
      status,
      updatedAt: serverTimestamp(),
    });

    if (intData && intData.candidateId) {
      await addDoc(collection(db, "notifications"), {
        userId: intData.candidateId,
        title: status === "CANCELLED" ? "Interview Cancelled" : "Interview Completed",
        body:
          status === "CANCELLED"
            ? `Your scheduled interview for ${intData.jobTitle || "the position"} at ${intData.companyName || "the company"} has been cancelled.`
            : `Your interview for ${intData.jobTitle || "the position"} has been marked as completed. Thank you!`,
        type: status === "CANCELLED" ? "INTERVIEW_CANCELLED" : "INTERVIEW_COMPLETED",
        entityId: interviewId,
        isRead: false,
        createdAt: serverTimestamp(),
      });
    }
  } catch (error) {
    console.error("Failed to update interview status:", error);
    throw error;
  }
}

/**
 * Fetch Company Offers (Compatible with both Mobile App `offeredSalary` and Web `salary`)
 */
export async function fetchCompanyOffers(companyId: string): Promise<CompanyOffer[]> {
  try {
    const q = query(
      collection(db, "offers"),
      where("companyId", "==", companyId),
      limit(200)
    );
    const snap = await getDocs(q);
    return snap.docs.map((d) => {
      const data = d.data();
      let expDate = data.expirationDate || "";
      if (!expDate && data.expiresAt) {
        const dt = data.expiresAt?.toDate ? data.expiresAt.toDate() : new Date(data.expiresAt);
        if (!isNaN(dt.getTime())) {
          expDate = dt.toISOString().split("T")[0];
        }
      }

      return {
        id: d.id,
        applicationId: data.applicationId || "",
        companyId: data.companyId || companyId,
        companyName: data.companyName || "",
        candidateId: data.candidateId || "",
        candidateName: data.candidateName || "Candidate",
        candidateEmail: data.candidateEmail,
        jobId: data.jobId || "",
        jobTitle: data.jobTitle || "Job",
        salary: Number(data.offeredSalary ?? data.salary ?? 0),
        currency: data.salaryCurrency || data.currency || "SAR",
        salaryPeriod: data.salaryPeriod || "MONTHLY",
        startDate: data.startDate || "",
        expirationDate: expDate,
        notes: data.termsAndNotes || data.notes || "",
        status: (data.status || "PENDING_CANDIDATE").toUpperCase() as any,
        createdAt: data.createdAt,
      } as CompanyOffer;
    });
  } catch (error) {
    console.error("Failed to fetch offers:", error);
    return [];
  }
}

/**
 * Send Job Offer (Uses extendJobOffer Cloud Function with Firestore batch fallback)
 */
export async function sendJobOffer(data: Omit<CompanyOffer, "id">): Promise<string> {
  try {
    let companyName = data.companyName || "Hiring Company";
    try {
      const compDoc = await getDoc(doc(db, "companies", data.companyId));
      if (compDoc.exists() && compDoc.data().name) {
        companyName = compDoc.data().name;
      }
    } catch (_) {}

    // Resolve candidate email if missing
    let candidateEmail = data.candidateEmail || "";
    if (!candidateEmail && data.candidateId) {
      try {
        const uDoc = await getDoc(doc(db, "users", data.candidateId));
        if (uDoc.exists() && uDoc.data().email) {
          candidateEmail = uDoc.data().email;
        }
      } catch (_) {}
    }

    let expiresInDays = 7;
    let expiresAtTimestamp = Timestamp.fromDate(new Date(Date.now() + 7 * 24 * 60 * 60 * 1000));
    if (data.expirationDate) {
      const parsed = new Date(data.expirationDate);
      if (!isNaN(parsed.getTime())) {
        expiresInDays = Math.max(1, Math.ceil((parsed.getTime() - Date.now()) / (24 * 60 * 60 * 1000)));
        const seconds = Math.floor(parsed.getTime() / 1000);
        if (seconds >= -62135596800 && seconds <= 253402300799) {
          expiresAtTimestamp = new Timestamp(seconds, 0);
        }
      }
    }

    let createdOfferId: string | null = null;
    if (data.applicationId) {
      try {
        const callExtendOffer = httpsCallable<
          {
            applicationId: string;
            offeredSalary: number;
            salaryCurrency: string;
            salaryPeriod: string;
            startDate?: string;
            expiresInDays: number;
            termsAndNotes?: string;
          },
          { success: boolean; offerId: string }
        >(functions, "extendJobOffer");

        const res = await callExtendOffer({
          applicationId: data.applicationId,
          offeredSalary: Number(data.salary),
          salaryCurrency: data.currency || "USD",
          salaryPeriod: data.salaryPeriod || "MONTHLY",
          startDate: data.startDate,
          expiresInDays,
          termsAndNotes: data.notes || "",
        });
        if (res.data?.offerId) {
          createdOfferId = res.data.offerId;
        }
      } catch (fnErr: any) {
        if (!shouldFallbackFromCallable(fnErr)) {
          throw fnErr;
        }
        console.warn("extendJobOffer callable fallback to Firestore batch:", fnErr);
      }
    }

    if (!createdOfferId) {
      const offerRef = doc(collection(db, "offers"));
      createdOfferId = offerRef.id;
      const payload = {
        id: offerRef.id,
        applicationId: data.applicationId || "",
        companyId: data.companyId,
        companyName,
        candidateId: data.candidateId,
        candidateName: data.candidateName,
        candidateEmail: candidateEmail,
        jobId: data.jobId,
        jobTitle: data.jobTitle,
        // Dual fields for 100% compatibility between Mobile App & Web Portal
        offeredSalary: Number(data.salary),
        salary: Number(data.salary),
        salaryCurrency: data.currency || "USD",
        currency: data.currency || "USD",
        salaryPeriod: data.salaryPeriod || "MONTHLY",
        startDate: data.startDate,
        expirationDate: data.expirationDate,
        expiresAt: expiresAtTimestamp,
        benefits: [],
        termsAndNotes: data.notes || "",
        notes: data.notes || "",
        status: "PENDING_CANDIDATE",
        declineReason: null,
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      };

      const batch = writeBatch(db);
      batch.set(offerRef, payload);

      if (data.applicationId) {
        batch.update(doc(db, "applications", data.applicationId), {
          status: "SELECTED",
          offerId: offerRef.id,
          offerExtendedAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
        });
      } else if (data.candidateId) {
        const notifRef = doc(collection(db, "notifications"));
        batch.set(notifRef, {
          userId: data.candidateId,
          title: "Official Job Offer Received! 🎉",
          body: `Congratulations! ${companyName} has sent you a formal job offer for ${data.jobTitle} (${Number(data.salary).toLocaleString()} ${data.currency}).`,
          type: "JOB_OFFER_EXTENDED",
          entityId: offerRef.id,
          data: {
            offerId: offerRef.id,
            jobId: data.jobId,
            applicationId: data.applicationId || "",
          },
          isRead: false,
          createdAt: serverTimestamp(),
        });
      }

      if (data.companyId) {
        const companyNotifRef = doc(collection(db, "notifications"));
        batch.set(companyNotifRef, {
          userId: data.companyId,
          title: "تم إرسال عرض العمل بنجاح 📋",
          body: `تم إرسال العرض الوظيفي الرسمي للمرشح (${data.candidateName}) لمنصب (${data.jobTitle}) براتب (${Number(data.salary).toLocaleString()} ${data.currency}).`,
          type: "JOB_OFFER_SENT",
          entityId: offerRef.id,
          data: {
            offerId: offerRef.id,
            jobId: data.jobId,
            candidateId: data.candidateId,
          },
          isRead: false,
          createdAt: serverTimestamp(),
        });
      }

      await batch.commit();
    }

    // Trigger Email Dispatch to Candidate (authenticated with Firebase ID Token)
    if (candidateEmail) {
      try {
        const idToken = await auth.currentUser?.getIdToken();
        fetch("/api/send-email", {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            ...(idToken ? { Authorization: `Bearer ${idToken}` } : {}),
          },
          body: JSON.stringify({
            to: candidateEmail,
            candidateName: data.candidateName,
            jobTitle: data.jobTitle,
            companyName,
            salary: Number(data.salary),
            currency: data.currency || "USD",
            salaryPeriod: data.salaryPeriod || "MONTHLY",
            startDate: data.startDate,
            notes: data.notes,
          }),
        }).catch((e) => console.warn("Email API trigger error:", e));
      } catch (e) {
        console.warn("Could not dispatch email:", e);
      }
    }

    return createdOfferId;
  } catch (error) {
    console.error("Failed to send job offer:", error);
    throw error;
  }
}

/**
 * Update Offer Status (Uses withdrawJobOffer Cloud Function for WITHDRAWN, with Firestore fallback)
 */
export async function updateOfferStatus(offerId: string, status: string): Promise<void> {
  try {
    if (status === "WITHDRAWN") {
      try {
        const callWithdraw = httpsCallable<{ offerId: string; reason?: string }, { success: boolean }>(
          functions,
          "withdrawJobOffer"
        );
        await callWithdraw({ offerId });
        return;
      } catch (fnErr: any) {
        if (!shouldFallbackFromCallable(fnErr)) {
          throw fnErr;
        }
        console.warn("withdrawJobOffer callable fallback to Firestore update:", fnErr);
      }
    }

    const offerRef = doc(db, "offers", offerId);
    const offerSnap = await getDoc(offerRef);
    const offerData = offerSnap.exists() ? offerSnap.data() : null;

    await updateDoc(offerRef, {
      status,
      updatedAt: serverTimestamp(),
    });

    if (offerData && offerData.candidateId && status === "WITHDRAWN") {
      await addDoc(collection(db, "notifications"), {
        userId: offerData.candidateId,
        title: "Job Offer Update",
        body: `The job offer for ${offerData.jobTitle || "the position"} at ${offerData.companyName || "the company"} has been withdrawn.`,
        type: "JOB_OFFER_WITHDRAWN",
        entityId: offerId,
        isRead: false,
        createdAt: serverTimestamp(),
      });
    }
  } catch (error) {
    console.error("Failed to update offer status:", error);
    throw error;
  }
}

/**
 * Pure helper to compute Dashboard KPIs from already-loaded arrays (0 extra Firestore reads!)
 */
export function computeCompanyDashboardKPIs(
  jobs: CompanyJob[],
  applicants: CompanyApplicant[],
  interviews: CompanyInterview[] = []
): CompanyDashboardKPIs {
  const activeJobs = jobs.filter((j) => j.status === "PUBLISHED").length;
  const totalApplicants = applicants.filter((a) => a.status !== "WITHDRAWN").length;
  const completedExams = applicants.filter(
    (a) =>
      a.examScore !== undefined ||
      a.status === "PASSED" ||
      a.status === "COMPLETED" ||
      a.status === "FAILED"
  ).length;
  const scheduledInterviews =
    interviews.length > 0
      ? interviews.filter(
          (i) =>
            i.status === "SCHEDULED" ||
            i.status === "CONFIRMED" ||
            i.status === "PENDING_CANDIDATE"
        ).length
      : applicants.filter((a) => a.status === "INTERVIEW_SCHEDULED").length;

  return {
    activeJobs,
    totalApplicants,
    completedExams,
    scheduledInterviews,
  };
}

/**
 * Dynamically compute Dashboard KPIs for this Company
 */
export async function fetchCompanyDashboardKPIs(companyId: string): Promise<CompanyDashboardKPIs> {
  try {
    const [applicants, interviews] = await Promise.all([
      fetchCompanyApplicants(companyId),
      fetchCompanyInterviews(companyId),
    ]);
    const jobs = await fetchCompanyJobs(companyId, applicants);
    return computeCompanyDashboardKPIs(jobs, applicants, interviews);
  } catch (error) {
    console.error("Failed to calculate KPIs:", error);
    return {
      activeJobs: 0,
      totalApplicants: 0,
      completedExams: 0,
      scheduledInterviews: 0,
    };
  }
}

/**
 * Real-time listener for Company Jobs
 */
export function listenCompanyJobs(
  companyId: string,
  callback: (jobs: CompanyJob[]) => void,
  onError?: (error: Error) => void
): () => void {
  const q = query(collection(db, "jobs"), where("companyId", "==", companyId), limit(200));
  return onSnapshot(
    q,
    (snap) => {
      const jobs = snap.docs.map((d) => {
        const data = d.data();
        return {
          id: d.id,
          companyId: data.companyId || companyId,
          companyName: data.companyName || "My Company",
          companyLogoUrl: data.companyLogoUrl,
          title: data.title || "Untitled Position",
          description: data.description || "",
          jobType: data.jobType || "FULL_TIME",
          workplaceType: data.workplaceType || "ON_SITE",
          experienceLevel: data.experienceLevel || "MID",
          location:
            typeof data.location === "object" && data.location !== null
              ? data.location
              : { city: String(data.location || ""), country: "" },
          salaryRange: data.salaryRange,
          requiredSkills: Array.isArray(data.requiredSkills) ? data.requiredSkills : [],
          optionalSkills: Array.isArray(data.optionalSkills) ? data.optionalSkills : [],
          status: (data.status as any) || "DRAFT",
          applicantsCount: typeof data.applicantsCount === "number" ? data.applicantsCount : 0,
          examId: data.examId,
          createdAt: data.createdAt,
          updatedAt: data.updatedAt,
        } as CompanyJob;
      });
      jobs.sort((a, b) => {
        const aTime = a.createdAt?.toMillis ? a.createdAt.toMillis() : (a.createdAt?.seconds || 0) * 1000;
        const bTime = b.createdAt?.toMillis ? b.createdAt.toMillis() : (b.createdAt?.seconds || 0) * 1000;
        return bTime - aTime;
      });
      callback(jobs);
    },
    (error) => {
      console.error("listenCompanyJobs error:", error);
      onError?.(error);
    }
  );
}

/**
 * Real-time listener for Company Applicants
 */
export function listenCompanyApplicants(
  companyId: string,
  callback: (applicants: CompanyApplicant[]) => void,
  onError?: (error: Error) => void
): () => void {
  const q = query(collection(db, "applications"), where("companyId", "==", companyId), limit(300));
  return onSnapshot(
    q,
    (snap) => {
      const applicants = snap.docs.map((d) => {
        const data = d.data();
        return {
          id: d.id,
          jobId: data.jobId || "",
          jobTitle: data.jobTitle || "Job",
          companyId: data.companyId || companyId,
          companyName: data.companyName || "",
          candidateId: data.candidateId || "",
          candidateName: data.candidateName || "Candidate",
          candidateEmail: data.candidateEmail || "",
          candidatePhone: data.candidatePhone,
          candidateHeadline: data.candidateHeadline,
          cvUrl: data.cvUrl,
          cvFileName: data.cvFileName || "Resume.pdf",
          coverLetter: data.coverLetter,
          status: (data.status || "APPLIED").toUpperCase(),
          appliedAt: data.appliedAt || data.createdAt,
          examScore: data.examScore,
          examPassed: data.examPassed,
          examTerminated: data.examTerminated,
          examViolationCount: data.examViolationCount,
          examToken: data.examToken,
          examAttemptId: data.examAttemptId,
          examTitle: data.examTitle,
          assignedChallengeId: data.assignedChallengeId,
          assignedChallengeTitle: data.assignedChallengeTitle,
          overallFitScore: data.overallFitScore ?? data.compositeScore,
          cvMatchScore: data.cvMatchScore,
          aiRecommendation: data.aiRecommendation || data.aiRecommendationDecision,
          aiParsedCv: data.aiParsedCv,
        } as CompanyApplicant;
      });
      applicants.sort((a, b) => {
        const aTime = a.appliedAt?.toMillis ? a.appliedAt.toMillis() : (a.appliedAt?.seconds || 0) * 1000;
        const bTime = b.appliedAt?.toMillis ? b.appliedAt.toMillis() : (b.appliedAt?.seconds || 0) * 1000;
        return bTime - aTime;
      });
      callback(applicants);
    },
    (error) => {
      console.error("listenCompanyApplicants error:", error);
      onError?.(error);
    }
  );
}

/**
 * Real-time listener for Company Interviews
 */
export function listenCompanyInterviews(
  companyId: string,
  callback: (interviews: CompanyInterview[]) => void,
  onError?: (error: Error) => void
): () => void {
  const q = query(collection(db, "interviews"), where("companyId", "==", companyId), limit(200));
  return onSnapshot(
    q,
    (snap) => {
      const list = snap.docs.map((d) => {
        const data = d.data();
        const scheduledStr = formatInterviewLocalDisplay(data);

        const rawType = (data.meetingType || data.type || "ONLINE").toUpperCase();
        const meetingType: "ONLINE" | "IN_PERSON" =
          rawType === "IN_PERSON" ? "IN_PERSON" : "ONLINE";

        return {
          id: d.id,
          applicationId: data.applicationId || "",
          companyId: data.companyId || companyId,
          companyName: data.companyName || "",
          candidateId: data.candidateId || "",
          candidateName: data.candidateName || "Candidate",
          candidateEmail: data.candidateEmail,
          jobId: data.jobId || "",
          jobTitle: data.jobTitle || "Job",
          title: data.title || `Interview - ${data.jobTitle || "Job"}`,
          scheduledAt: scheduledStr || "Scheduled",
          meetingType,
          meetingUrl: data.meetingUrl || "",
          location: data.location || "",
          notes: data.notes || data.description || "",
          status: (data.status || "CONFIRMED").toUpperCase() as any,
          createdAt: data.createdAt,
        } as CompanyInterview;
      });
      list.sort((a, b) => {
        const aTime = a.createdAt?.toMillis ? a.createdAt.toMillis() : (a.createdAt?.seconds || 0) * 1000;
        const bTime = b.createdAt?.toMillis ? b.createdAt.toMillis() : (b.createdAt?.seconds || 0) * 1000;
        return bTime - aTime;
      });
      callback(list);
    },
    (error) => {
      console.error("listenCompanyInterviews error:", error);
      onError?.(error);
    }
  );
}

/**
 * Real-time listener for Company Offers
 */
export function listenCompanyOffers(
  companyId: string,
  callback: (offers: CompanyOffer[]) => void,
  onError?: (error: Error) => void
): () => void {
  const q = query(collection(db, "offers"), where("companyId", "==", companyId), limit(200));
  return onSnapshot(
    q,
    (snap) => {
      const list = snap.docs.map((d) => {
        const data = d.data();
        let expDate = data.expirationDate || "";
        if (!expDate && data.expiresAt) {
          const dt = data.expiresAt?.toDate ? data.expiresAt.toDate() : new Date(data.expiresAt);
          if (!isNaN(dt.getTime())) {
            expDate = dt.toISOString().split("T")[0];
          }
        }

        return {
          id: d.id,
          applicationId: data.applicationId || "",
          companyId: data.companyId || companyId,
          companyName: data.companyName || "",
          candidateId: data.candidateId || "",
          candidateName: data.candidateName || "Candidate",
          candidateEmail: data.candidateEmail,
          jobId: data.jobId || "",
          jobTitle: data.jobTitle || "Job",
          salary: Number(data.offeredSalary ?? data.salary ?? 0),
          currency: data.salaryCurrency || data.currency || "SAR",
          salaryPeriod: data.salaryPeriod || "MONTHLY",
          startDate: data.startDate || "",
          expirationDate: expDate,
          notes: data.termsAndNotes || data.notes || "",
          status: (data.status || "PENDING_CANDIDATE").toUpperCase() as any,
          createdAt: data.createdAt,
        } as CompanyOffer;
      });
      list.sort((a, b) => {
        const aTime = a.createdAt?.toMillis ? a.createdAt.toMillis() : (a.createdAt?.seconds || 0) * 1000;
        const bTime = b.createdAt?.toMillis ? b.createdAt.toMillis() : (b.createdAt?.seconds || 0) * 1000;
        return bTime - aTime;
      });
      callback(list);
    },
    (error) => {
      console.error("listenCompanyOffers error:", error);
      onError?.(error);
    }
  );
}

/**
 * Company Notifications Model
 */
export interface CompanyNotification {
  id: string;
  userId: string;
  title: string;
  body: string;
  type: string;
  entityId?: string;
  actionUrl?: string;
  link?: string;
  data?: any;
  isRead: boolean;
  createdAt?: any;
}

/**
 * Real-time listener for Company Notifications (Single-field query + fast client-side sort — 0 index errors)
 */
export function listenCompanyNotifications(
  companyId: string,
  callback: (notifs: CompanyNotification[]) => void
): () => void {
  const q = query(
    collection(db, "notifications"),
    where("userId", "==", companyId),
    limit(100)
  );

  return onSnapshot(q, (snap) => {
    const items: CompanyNotification[] = snap.docs.map((doc) => {
      const d = doc.data();
      const rawType = String(d.type || "SYSTEM").toUpperCase();
      const payloadData = (d.data && typeof d.data === "object" ? d.data : {}) as Record<string, any>;
      let inferredLink: string | undefined;

      if (rawType.includes("COMMUNITY")) {
        inferredLink = "/company/community";
      } else if (rawType.includes("OFFER")) {
        const offerId = String(payloadData.offerId || d.entityId || "").trim();
        inferredLink = offerId ? `/company/offers?offerId=${encodeURIComponent(offerId)}` : "/company/offers";
      } else if (rawType.includes("INTERVIEW")) {
        const interviewId = String(payloadData.interviewId || d.entityId || "").trim();
        inferredLink = interviewId
          ? `/company/interviews?interviewId=${encodeURIComponent(interviewId)}`
          : "/company/interviews";
      } else if (rawType.includes("CHALLENGE") || rawType.includes("ASSIGNMENT") || (d.actionUrl || "").includes("challenges")) {
        inferredLink = "/company/exams?tab=challenges";
      } else if (rawType.includes("EXAM") || rawType.includes("APPLICATION")) {
        const params = new URLSearchParams();
        const appId = String(
          payloadData.applicationId || (rawType.includes("APPLICATION") ? d.entityId || "" : "")
        ).trim();
        const candId = String(payloadData.candidateId || "").trim();
        const jobId = String(payloadData.jobId || "").trim();
        if (appId) params.set("applicationId", appId);
        if (candId) params.set("candidateId", candId);
        if (jobId) params.set("jobId", jobId);
        const qs = params.toString();
        inferredLink = qs ? `/company/applicants?${qs}` : "/company/applicants";
      } else if (rawType.includes("COMPANY")) {
        inferredLink = "/company/profile";
      }

      const explicitAction = typeof d.actionUrl === "string" && d.actionUrl.trim() ? d.actionUrl.trim() : undefined;
      const explicitLink = typeof d.link === "string" && d.link.trim() ? d.link.trim() : undefined;
      let resolvedLink = explicitLink || explicitAction || inferredLink;
      // Upgrade bare legacy /company/applicants or /company/exams when we can deep-link to specific application/tab
      if (
        (resolvedLink === "/company/applicants" || resolvedLink === "/company/exams") &&
        inferredLink &&
        inferredLink.includes("?")
      ) {
        resolvedLink = inferredLink;
      }

      return {
        id: doc.id,
        userId: d.userId,
        title: d.title || "",
        body: d.body || "",
        type: d.type || "SYSTEM",
        entityId: d.entityId,
        actionUrl: explicitAction,
        link: resolvedLink,
        data: d.data,
        isRead: d.isRead ?? false,
        createdAt: d.createdAt,
      };
    });
    items.sort((a, b) => {
      const tA = a.createdAt?.seconds || 0;
      const tB = b.createdAt?.seconds || 0;
      return tB - tA;
    });
    callback(items);
  });
}

/**
 * Mark a single notification as read
 */
export async function markNotificationAsRead(notifId: string): Promise<void> {
  try {
    await updateDoc(doc(db, "notifications", notifId), {
      isRead: true,
      updatedAt: serverTimestamp(),
    });
  } catch (err) {
    console.error("Failed to mark notification as read:", err);
  }
}

/**
 * Mark all notifications as read for a company
 */
export async function markAllCompanyNotificationsAsRead(companyId: string): Promise<void> {
  try {
    const q = query(
      collection(db, "notifications"),
      where("userId", "==", companyId),
      where("isRead", "==", false)
    );
    const snap = await getDocs(q);
    for (let i = 0; i < snap.docs.length; i += 400) {
      const batch = writeBatch(db);
      snap.docs.slice(i, i + 400).forEach((d) => {
        batch.update(d.ref, { isRead: true, updatedAt: serverTimestamp() });
      });
      await batch.commit();
    }
  } catch (err) {
    console.error("Failed to mark all notifications as read:", err);
  }
}

/**
 * Delete a single notification
 */
export async function deleteCompanyNotification(notifId: string): Promise<void> {
  try {
    await deleteDoc(doc(db, "notifications", notifId));
  } catch (err) {
    console.error("Failed to delete notification:", err);
  }
}

/**
 * Clear all notifications for a company
 */
export async function clearAllCompanyNotifications(companyId: string): Promise<void> {
  try {
    const q = query(
      collection(db, "notifications"),
      where("userId", "==", companyId)
    );
    const snap = await getDocs(q);
    if (snap.empty) return;
    for (let i = 0; i < snap.docs.length; i += 400) {
      const batch = writeBatch(db);
      snap.docs.slice(i, i + 400).forEach((d) => {
        batch.delete(d.ref);
      });
      await batch.commit();
    }
  } catch (err) {
    console.error("Failed to clear all notifications:", err);
  }
}
