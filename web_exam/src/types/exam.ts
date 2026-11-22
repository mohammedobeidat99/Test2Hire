export type QuestionType =
  | "SINGLE_CHOICE"
  | "MULTIPLE_CHOICE"
  | "TRUE_FALSE"
  | "CODING"
  | "SHORT_ANSWER"
  | "MIXED"
  | (string & {});

export type QuestionDifficulty = "EASY" | "MEDIUM" | "HARD" | (string & {});

export interface QuestionOption {
  id: string;
  text: string;
}

export interface SanitizedQuestion {
  id: string;
  title: string;
  description: string;
  type: QuestionType;
  difficulty: QuestionDifficulty;
  points: number;
  sampleCodeSnippet?: string | null;
  programmingLanguage?: string | null;
  options: QuestionOption[];
}

export type ExamAttemptStatus =
  | "INVITED"
  | "IN_PROGRESS"
  | "COMPLETED"
  | "TERMINATED"
  | "EXPIRED";

export interface ExamSessionData {
  attemptId: string;
  examId: string;
  examTitle: string;
  candidateName: string;
  durationMinutes: number;
  passingPercentage: number;
  proctoringEnabled: boolean;
  totalQuestions: number;
  totalPoints: number;
  questions: SanitizedQuestion[];
  savedAnswers: Record<string, CandidateAnswer>;
  violationCount: number;
  startedAt: string;
  serverNow?: string | null;
  expiresAt?: string | null;
  invitationSentAt?: string | null;
}

export interface CandidateAnswer {
  selectedOptionIds?: string[];
  textAnswer?: string;
}

export interface ExamSubmissionResult {
  success: boolean;
  score: number;
  passed: boolean;
  passingPercentage: number;
  earnedPoints: number;
  totalPointsPossible: number;
}

export interface ProctoringSnapshot {
  label: string;
  timestamp: string;
  imageDataUrl: string;
}

export interface ProctoringViolationEvent {
  type: string;
  details: string;
  timestamp: string;
}

export interface ProctoringReport {
  cameraVerified: boolean;
  micVerified: boolean;
  audioPeakLevel: number;
  snapshots: ProctoringSnapshot[];
  violationEvents: ProctoringViolationEvent[];
}
