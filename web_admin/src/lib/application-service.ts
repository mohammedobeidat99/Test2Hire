import { db } from "./firebase";
import { compareTimestampsDesc } from "./formatters";
import { collection, query, where, limit, getDocs } from "firebase/firestore";

export interface JobApplicant {
  id: string;
  jobId: string;
  jobTitle: string;
  candidateId: string;
  candidateName: string;
  candidateEmail: string;
  candidatePhone?: string;
  candidateHeadline?: string;
  cvUrl?: string;
  cvFileName?: string;
  coverLetter?: string;
  status: string;
  appliedAt?: any;
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
    cvMatchScore?: number;
  };
}

export async function fetchJobApplicants(jobId: string): Promise<JobApplicant[]> {
  try {
    const q = query(collection(db, "applications"), where("jobId", "==", jobId), limit(200));
    const snapshot = await getDocs(q);
    return snapshot.docs
      .map((docSnap) => {
        const data = docSnap.data();
        return {
          id: docSnap.id,
          jobId: data.jobId || jobId,
          jobTitle: data.jobTitle || "",
          candidateId: data.candidateId || "",
          candidateName: data.candidateName || "Unnamed Candidate",
          candidateEmail: data.candidateEmail || "",
          candidatePhone: data.candidatePhone,
          candidateHeadline: data.candidateHeadline,
          cvUrl: data.cvUrl,
          cvFileName: data.cvFileName || "Resume.pdf",
          coverLetter: data.coverLetter,
          status: data.status || "applied",
          appliedAt: data.appliedAt || data.createdAt,
          overallFitScore: data.overallFitScore,
          cvMatchScore: data.cvMatchScore,
          aiRecommendation: data.aiRecommendation,
          aiParsedCv: data.aiParsedCv,
        };
      })
      .sort((a, b) => compareTimestampsDesc(a.appliedAt, b.appliedAt));
  } catch (error) {
    console.error("Failed to fetch job applicants:", error);
    throw error;
  }
}
