const { initializeApp } = require("firebase/app");
const { getAuth, signInWithEmailAndPassword } = require("firebase/auth");
const { 
  getFirestore, 
  collection, 
  doc, 
  getDocs, 
  setDoc, 
  updateDoc, 
  query, 
  where, 
  serverTimestamp 
} = require("firebase/firestore");

const firebaseConfig = {
  apiKey: "AIzaSyD13nxqjaXdtUoAepn1OpF4b8flBFTSozM",
  authDomain: "test2here-72346.firebaseapp.com",
  projectId: "test2here-72346",
  storageBucket: "test2here-72346.firebasestorage.app",
  messagingSenderId: "326304038955",
  appId: "1:326304038955:web:2cdc5604a437527314ea6e",
};

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

async function createFreshExam() {
  console.log("Signing in as Company (hr@techcorp.com)...");
  const compCred = await signInWithEmailAndPassword(auth, "hr@techcorp.com", "123456");
  const companyUid = compCred.user.uid;
  const candidateUid = "VVQg1Ula1yeMVPAWJLBgGRpy7H42"; // Ahmed Al-Sayed

  // 1. Create questions
  const q1Ref = doc(collection(db, "questions"));
  await setDoc(q1Ref, {
    id: q1Ref.id,
    title: "What is the primary benefit of using a Repository Pattern in modern scalable applications?",
    description: "Architecture & Clean Code assessment",
    type: "SINGLE_CHOICE",
    difficulty: "SENIOR",
    points: 10,
    companyId: companyUid,
    options: [
      { id: "opt_0", text: "Decoupling domain business logic from specific data access mechanisms" },
      { id: "opt_1", text: "Directly writing SQL and database queries inside presentation widgets" },
      { id: "opt_2", text: "Eliminating the need for unit testing and state management" },
      { id: "opt_3", text: "Enforcing single-threaded execution across all app layers" }
    ],
    correctAnswers: ["opt_0"],
    createdAt: serverTimestamp(),
  });

  const q2Ref = doc(collection(db, "questions"));
  await setDoc(q2Ref, {
    id: q2Ref.id,
    title: "How does Google Gemini optimize large-context processing in multi-turn interactions?",
    description: "AI Integration & LLM architecture",
    type: "SINGLE_CHOICE",
    difficulty: "SENIOR",
    points: 10,
    companyId: companyUid,
    options: [
      { id: "opt_0", text: "Through context caching and sparse attention mechanisms" },
      { id: "opt_1", text: "By deleting past conversational history on every turn" },
      { id: "opt_2", text: "By using hardcoded rule-based regex patterns" },
      { id: "opt_3", text: "By restricting prompt tokens to a maximum of 256 words" }
    ],
    correctAnswers: ["opt_0"],
    createdAt: serverTimestamp(),
  });

  const q3Ref = doc(collection(db, "questions"));
  await setDoc(q3Ref, {
    id: q3Ref.id,
    title: "In Firebase Cloud Functions, what is the best practice for handling heavy asynchronous background tasks?",
    description: "Cloud Engineering & Scalability",
    type: "SINGLE_CHOICE",
    difficulty: "SENIOR",
    points: 10,
    companyId: companyUid,
    options: [
      { id: "opt_0", text: "Offloading tasks using Cloud Tasks or event-driven Pub/Sub queues" },
      { id: "opt_1", text: "Blocking the main HTTP request with infinite while-loops" },
      { id: "opt_2", text: "Running them inside client mobile app threads with elevated permissions" },
      { id: "opt_3", text: "Disabling all timeouts and logging mechanisms" }
    ],
    correctAnswers: ["opt_0"],
    createdAt: serverTimestamp(),
  });

  const questionIds = [q1Ref.id, q2Ref.id, q3Ref.id];

  // 2. Create Exam template
  const examRef = doc(collection(db, "exams"));
  await setDoc(examRef, {
    id: examRef.id,
    title: "Senior AI & Full-Stack Systems Technical Assessment",
    description: "Official evaluation covering Architecture, Gemini AI, and Cloud Scale systems.",
    companyId: companyUid,
    companyName: "TechCorp Solutions",
    questionIds: questionIds,
    durationMinutes: 30,
    passingPercentage: 70,
    totalQuestions: 3,
    totalPoints: 30,
    status: "PUBLISHED",
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });

  // 3. Generate Token & Expiration (7 days from now)
  const characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  let token = "";
  for (let i = 0; i < 32; i++) {
    token += characters.charAt(Math.floor(Math.random() * characters.length));
  }
  const now = new Date();
  const expiresAt = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

  // 4. Create fresh Attempt
  const attemptRef = doc(collection(db, "examAttempts"));
  await setDoc(attemptRef, {
    id: attemptRef.id,
    examId: examRef.id,
    examTitle: "Senior AI & Full-Stack Systems Technical Assessment",
    companyId: companyUid,
    candidateId: candidateUid,
    candidateName: "Ahmed Al-Sayed",
    candidateEmail: "ahmed@test.com",
    token: token,
    status: "INVITED",
    durationMinutes: 30,
    passingPercentage: 70,
    totalQuestions: 3,
    totalPoints: 30,
    score: 0,
    passed: false,
    invitationSentAt: serverTimestamp(),
    expiresAt: expiresAt,
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });

  // 5. Update Candidate's active application in Firestore
  const appsQuery = query(
    collection(db, "applications"),
    where("candidateId", "==", candidateUid),
    where("companyId", "==", companyUid)
  );
  const appsSnap = await getDocs(appsQuery);
  if (!appsSnap.empty) {
    const activeApp = appsSnap.docs[0];
    await updateDoc(activeApp.ref, {
      status: "EXAM_ASSIGNED",
      examAttemptId: attemptRef.id,
      examToken: token,
      examTitle: "Senior AI & Full-Stack Systems Technical Assessment",
      examDurationMinutes: 30,
      examExpiresAt: expiresAt,
      updatedAt: serverTimestamp(),
    });
    console.log(`Updated application ${activeApp.id} with new token!`);
  }

  console.log("================================================================================");
  console.log("🎉 FRESH ACTIVE EXAM READY TO TAKE!");
  console.log("================================================================================");
  console.log(`• Exam Title:      Senior AI & Full-Stack Systems Technical Assessment`);
  console.log(`• Candidate:       Ahmed Al-Sayed (ahmed@test.com)`);
  console.log(`• Duration:        30 Minutes`);
  console.log(`• Status:          INVITED (Ready to start)`);
  console.log(`• Deadline:        ${expiresAt.toISOString()}`);
  console.log(`• Exam Token:      ${token}`);
  console.log(`• Local Portal:    http://localhost:3001/exam/${token}`);
  console.log(`• Hosted Portal:   https://test2here-72346.web.app/exam/${token}`);
  console.log("================================================================================\n");

  return token;
}

createFreshExam()
  .then((token) => {
    console.log("EXAM_TOKEN=" + token);
    process.exit(0);
  })
  .catch((err) => {
    console.error("Error creating fresh exam:", err);
    process.exit(1);
  });
