import { db, auth } from "./firebase";
import {
  collection,
  getDocs,
  doc,
  updateDoc,
  deleteDoc,
  query,
  orderBy,
  limit,
  Timestamp,
  addDoc,
  serverTimestamp,
} from "firebase/firestore";

export interface ExamRecord {
  id: string;
  companyId: string;
  title: string;
  description: string;
  durationMinutes: number;
  passingPercentage: number;
  totalQuestions: number;
  totalPoints: number;
  proctoringEnabled: boolean;
  isArchived: boolean;
  questionIds?: string[];
  createdAt?: Timestamp | null;
  updatedAt?: Timestamp | null;
}

export interface ExamAttemptRecord {
  id: string;
  examId: string;
  candidateId: string;
  companyId: string;
  score?: number;
  passed?: boolean;
  status: "INVITED" | "ASSIGNED" | "IN_PROGRESS" | "COMPLETED" | "EXPIRED" | "TERMINATED" | "TERMINATED_VIOLATION" | string;
  violationsCount?: number;
  startedAt?: Timestamp | null;
  completedAt?: Timestamp | null;
  createdAt?: Timestamp | null;
}

export async function fetchExams(): Promise<ExamRecord[]> {
  try {
    const examsRef = collection(db, "exams");
    const q = query(examsRef, orderBy("createdAt", "desc"), limit(200));
    const snapshot = await getDocs(q);

    return snapshot.docs.map((docSnap) => {
      const data = docSnap.data();
      const totalQuestions =
        typeof data.totalQuestions === "number"
          ? data.totalQuestions
          : typeof data.questionsCount === "number"
          ? data.questionsCount
          : Array.isArray(data.questionIds)
          ? data.questionIds.length
          : Array.isArray(data.questions)
          ? data.questions.length
          : 0;

      return {
        id: docSnap.id,
        companyId: data.companyId || "",
        title: data.title || "Untitled Exam",
        description: data.description || "",
        durationMinutes: typeof data.durationMinutes === "number" ? data.durationMinutes : 45,
        passingPercentage:
          typeof data.passingPercentage === "number"
            ? data.passingPercentage
            : typeof data.passingScore === "number"
            ? data.passingScore
            : 70,
        totalQuestions,
        totalPoints: typeof data.totalPoints === "number" ? data.totalPoints : 100,
        proctoringEnabled: data.proctoringEnabled ?? true,
        isArchived: data.isArchived ?? false,
        questionIds: Array.isArray(data.questionIds) ? data.questionIds : [],
        createdAt: data.createdAt,
        updatedAt: data.updatedAt,
      };
    });
  } catch (error) {
    console.error("Failed to fetch exams:", error);
    throw error;
  }
}

export async function fetchExamAttempts(): Promise<ExamAttemptRecord[]> {
  try {
    const attemptsRef = collection(db, "examAttempts");
    const q = query(attemptsRef, orderBy("createdAt", "desc"), limit(200));
    const snapshot = await getDocs(q);

    return snapshot.docs.map((docSnap) => {
      const data = docSnap.data();
      const rawViolations =
        typeof data.violationsCount === "number"
          ? data.violationsCount
          : typeof data.violationCount === "number"
          ? data.violationCount
          : Array.isArray(data.violations)
          ? data.violations.length
          : 0;

      return {
        id: docSnap.id,
        examId: data.examId || "",
        candidateId: data.candidateId || "",
        companyId: data.companyId || "",
        score: typeof data.score === "number" ? data.score : undefined,
        passed: data.passed,
        status: data.status || "ASSIGNED",
        violationsCount: rawViolations,
        startedAt: data.startedAt,
        completedAt: data.completedAt,
        createdAt: data.createdAt,
      };
    });
  } catch (error) {
    console.error("Failed to fetch exam attempts:", error);
    return [];
  }
}

export async function toggleExamArchive(examId: string, isArchived: boolean): Promise<void> {
  try {
    const examRef = doc(db, "exams", examId);
    await updateDoc(examRef, {
      isArchived,
      updatedAt: serverTimestamp(),
    });

    if (auth.currentUser) {
      await addDoc(collection(db, "auditLogs"), {
        actorId: auth.currentUser.uid,
        actorRole: "ADMIN",
        action: isArchived ? "EXAM_ARCHIVED" : "EXAM_UNARCHIVED",
        targetType: "EXAM",
        targetId: examId,
        metadata: { isArchived },
        timestamp: serverTimestamp(),
      });
    }
  } catch (error) {
    console.error("Failed to toggle exam archive status:", error);
    throw error;
  }
}

export async function deleteExam(examId: string): Promise<void> {
  try {
    const examRef = doc(db, "exams", examId);
    await deleteDoc(examRef);

    if (auth.currentUser) {
      await addDoc(collection(db, "auditLogs"), {
        actorId: auth.currentUser.uid,
        actorRole: "ADMIN",
        action: "EXAM_DELETED",
        targetType: "EXAM",
        targetId: examId,
        timestamp: serverTimestamp(),
      });
    }
  } catch (error) {
    console.error("Failed to delete exam:", error);
    throw error;
  }
}
