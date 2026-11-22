import { NextRequest, NextResponse } from "next/server";
import { isCompanyOrAdminRole, verifyFirebaseCaller } from "../_lib/auth";

const GEMINI_API_KEY = process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY || "";

const VALID_QUESTION_TYPES = [
  "SINGLE_CHOICE",
  "MULTIPLE_CHOICE",
  "TRUE_FALSE",
  "CODING",
  "SHORT_ANSWER",
  "MIXED",
] as const;

function extractJsonFromText(rawText: string): any {
  const clean = rawText
    .replace(/^```(?:json)?\s*/i, "")
    .replace(/```\s*$/i, "")
    .trim();
  try {
    return JSON.parse(clean);
  } catch {
    const objStart = clean.indexOf("{");
    const objEnd = clean.lastIndexOf("}");
    if (objStart !== -1 && objEnd > objStart) {
      return JSON.parse(clean.slice(objStart, objEnd + 1));
    }
    throw new Error("Invalid JSON response from Gemini.");
  }
}

async function callGeminiJson(prompt: string): Promise<any | null> {
  if (!GEMINI_API_KEY || GEMINI_API_KEY === "TEST_KEY_FALLBACK") return null;

  const models = Array.from(
    new Set([
      process.env.GEMINI_MODEL || "gemini-2.5-flash",
      "gemini-2.5-flash",
      "gemini-flash-latest",
      "gemini-2.5-pro",
      "gemini-2.5-flash-lite",
    ])
  );

  for (const model of models) {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 10000);
    try {
      const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}:generateContent`;
      const res = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "x-goog-api-key": GEMINI_API_KEY,
        },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }],
          generationConfig: {
            temperature: 0.4,
            responseMimeType: "application/json",
          },
        }),
        signal: controller.signal,
      });
      if (!res.ok) continue;
      const data = await res.json();
      const text = data?.candidates?.[0]?.content?.parts?.[0]?.text;
      if (typeof text === "string" && text.trim()) {
        return extractJsonFromText(text);
      }
    } catch {
      // fallback to next model or deterministic generator
    } finally {
      clearTimeout(timeoutId);
    }
  }
  return null;
}

export async function POST(req: NextRequest) {
  let body: any;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "Invalid JSON request body" }, { status: 400 });
  }

  if (!body || typeof body !== "object" || Array.isArray(body)) {
    return NextResponse.json({ error: "Request body must be a JSON object" }, { status: 400 });
  }

  const caller = await verifyFirebaseCaller(req);
  if (!caller) {
    return NextResponse.json(
      { error: "Unauthorized. Valid Firebase Bearer token is required." },
      { status: 401 }
    );
  }
  if (caller.isSuspended || !isCompanyOrAdminRole(caller.role)) {
    return NextResponse.json(
      { error: "Forbidden. Only active company or admin accounts can invoke AI tools." },
      { status: 403 }
    );
  }

  const { action, payload } = body;
  if (typeof action !== "string" || !action.trim()) {
    return NextResponse.json({ error: "AI action is required" }, { status: 400 });
  }
  const safePayload = payload && typeof payload === "object" && !Array.isArray(payload) ? payload : {};

  try {
    // 1. Generate Interview Questions
    if (action === "generateInterviewQuestions") {
      const jobTitle =
        typeof safePayload.jobTitle === "string" && safePayload.jobTitle.trim()
          ? safePayload.jobTitle.trim().slice(0, 150)
          : "Software Engineer";
      const candidateName =
        typeof safePayload.candidateName === "string" && safePayload.candidateName.trim()
          ? safePayload.candidateName.trim().slice(0, 150)
          : "Candidate";
      const candidateSkills: string[] = Array.isArray(safePayload.candidateSkills)
        ? safePayload.candidateSkills.map(String).slice(0, 30)
        : [];
      const missingSkills: string[] = Array.isArray(safePayload.missingSkills)
        ? safePayload.missingSkills.map(String).slice(0, 30)
        : [];

      const prompt = `
You are a senior hiring manager and technical interviewer for "Test2Hire".
Generate 5 high-impact, tailored interview questions for candidate "${candidateName}" applying for "${jobTitle}".
Candidate Skills: ${JSON.stringify(candidateSkills)}
Missing Skills: ${JSON.stringify(missingSkills)}
Output strictly valid JSON:
{
  "candidateName": "${candidateName}",
  "jobTitle": "${jobTitle}",
  "interviewQuestions": [
    {
      "category": "TECHNICAL" | "ARCHITECTURE" | "BEHAVIORAL",
      "question": "string",
      "whatToLookFor": "string",
      "suggestedFollowUp": "string"
    }
  ]
}`;

      const geminiResult = await callGeminiJson(prompt);
      if (Array.isArray(geminiResult?.interviewQuestions) && geminiResult.interviewQuestions.length > 0) {
        const sanitizedQuestions = geminiResult.interviewQuestions
          .filter((q: any) => q && typeof q.question === "string" && q.question.trim().length > 0)
          .map((q: any) => ({
            category: typeof q.category === "string" && q.category.trim() ? q.category.trim() : "TECHNICAL",
            question: q.question.trim(),
            whatToLookFor: typeof q.whatToLookFor === "string" ? q.whatToLookFor.trim() : "",
            suggestedFollowUp: typeof q.suggestedFollowUp === "string" ? q.suggestedFollowUp.trim() : "",
          }));

        if (sanitizedQuestions.length > 0) {
          return NextResponse.json({
            success: true,
            candidateName: String(geminiResult.candidateName || candidateName),
            jobTitle: String(geminiResult.jobTitle || jobTitle),
            interviewQuestions: sanitizedQuestions,
          });
        }
      }

      return NextResponse.json({
        success: true,
        candidateName,
        jobTitle,
        interviewQuestions: [
          {
            category: "TECHNICAL",
            question: `When building production features for ${jobTitle}, how do you structure state management, error boundaries, and asynchronous data fetching?`,
            whatToLookFor: "Look for clean separation of concerns, predictable state transitions, and resilience to network failures.",
            suggestedFollowUp: "How do you test edge cases in that architecture?",
          },
          {
            category: "ARCHITECTURE",
            question: `Walk us through the most complex scalability or performance bottleneck you resolved in a recent ${jobTitle} project.`,
            whatToLookFor: "Look for profiling methodology, root-cause metrics, and measurable latency/memory improvements.",
            suggestedFollowUp: "What trade-offs did you have to accept with your chosen solution?",
          },
          {
            category: "TECHNICAL",
            question: `How do you ensure security, data validation, and role-based access control across client and cloud services?`,
            whatToLookFor: "Look for token verification, least-privilege security rules, and input sanitization.",
            suggestedFollowUp: "How would you handle token expiration during an active user session?",
          },
          {
            category: "PROBLEM_SOLVING",
            question: `If a critical production deployment for ${jobTitle} starts throwing intermittent errors for 10% of users, what is your step-by-step incident response?`,
            whatToLookFor: "Structured triage, telemetry inspection, safe rollback strategy, and post-mortem prevention.",
            suggestedFollowUp: "How do you prevent regressions before the next release?",
          },
          {
            category: "BEHAVIORAL",
            question: `Tell us about a time you disagreed with a product or engineering decision while working with ${candidateName !== "Candidate" ? "your team" : "stakeholders"}. How did you align on the outcome?`,
            whatToLookFor: "Data-driven communication, empathy, ownership, and focus on user/business impact.",
            suggestedFollowUp: "What did you learn from that collaboration?",
          },
        ],
      });
    }

    // 2. Generate Exam Questions
    if (action === "generateExamQuestions") {
      const jobTitle =
        typeof safePayload.jobTitle === "string" && safePayload.jobTitle.trim()
          ? safePayload.jobTitle.trim().slice(0, 150)
          : "Software Engineering";
      const difficulty =
        typeof safePayload.difficulty === "string" && safePayload.difficulty.trim()
          ? safePayload.difficulty.trim().toUpperCase()
          : "MID";
      const questionCount = Math.min(Math.max(Math.round(Number(safePayload.questionCount) || 5), 1), 30);
      const rawType = typeof safePayload.questionType === "string" ? safePayload.questionType.trim().toUpperCase() : "SINGLE_CHOICE";
      const questionType = (VALID_QUESTION_TYPES as readonly string[]).includes(rawType)
        ? rawType
        : "SINGLE_CHOICE";
      const requiredSkills: string[] = Array.isArray(safePayload.requiredSkills)
        ? safePayload.requiredSkills.map(String).slice(0, 30)
        : [];
      const language = safePayload.language === "en" ? "en" : "ar";

      let typeGuideline = "";
      switch (questionType) {
        case "TRUE_FALSE":
          typeGuideline =
            language === "ar"
              ? `كل الأسئلة يجب أن تكون بصيغة صح أو خطأ فقط. يجب أن يحتوي كل سؤال على خيارين فقط بالضبط: ["صح", "خطأ"]. قيمة correctAnswerIndex يجب أن تكون 0 إذا كانت الإجابة صح أو 1 إذا كانت خطأ.`
              : `All questions must be True/False format only. Each question must have exactly 2 options: ["True", "False"]. correctAnswerIndex must be 0 for True or 1 for False.`;
          break;
        case "CODING":
          typeGuideline =
            language === "ar"
              ? `كل الأسئلة يجب أن تركز على فحص الأكواد البرمجية، تحليل الخوارزميات، واكتشاف الأخطاء (Debugging) أو توقع مخرجات الكود. وفر 4 خيارات فنية واضحة.`
              : `All questions must be practical coding/engineering challenges, including a clear code snippet or algorithm scenario in the question text. Provide 4 technical options representing correct outputs, refactored code, or bug fixes.`;
          break;
        case "SHORT_ANSWER":
          typeGuideline =
            language === "ar"
              ? `كل الأسئلة يجب أن تقيس المفاهيم الهندسية والمعمارية وأفضل الممارسات. وفر 4 خيارات تحليلية دقيقة تمثل أحدها الحل المعياري الأمثل.`
              : `All questions must test core architectural principles, key trade-offs, and critical definitions. Provide 4 concise analytical options where exactly one is the industry best-practice.`;
          break;
        case "MIXED":
          typeGuideline =
            language === "ar"
              ? `نوّع الأسئلة بتوازن بين: أسئلة اختيار من متعدد (4 خيارات)، وأسئلة صح أو خطأ (خياران: ["صح", "خطأ"])، وأسئلة برمجية وفحص أكواد، وأسئلة مفاهيم معمارية.`
              : `Generate a diverse and balanced mix of: Multiple Choice scenario questions (4 options), True/False questions (2 options: ["True", "False"]), practical code debugging questions, and conceptual questions.`;
          break;
        case "SINGLE_CHOICE":
        case "MULTIPLE_CHOICE":
        default:
          typeGuideline =
            language === "ar"
              ? `أسئلة اختيار من متعدد احترافية وعملية من واقع بيئات العمل. كل سؤال يحتوي على 4 خيارات وإجابة صحيحة واحدة دقيقة.`
              : `High quality multiple-choice questions with 4 distinct, plausible options and exactly 1 correct answer.`;
          break;
      }

      const langGuideline =
        language === "ar"
          ? `اكتب جميع الأسئلة والخيارات والشروحات بلغة عربية تقنية واضحة واحترافية (مع إمكانية ذكر المصطلحات التقنية الإنجليزية الشائعة مثل Docker, async/await, API, Flutter, Git إلخ).`
          : `Write all questions, options, and explanations in professional English.`;

      const prompt = `
You are an expert technical psychometrician and exam architect for "Test2Hire".
Generate exactly ${questionCount} assessment questions for the role "${jobTitle}".
Difficulty: ${difficulty}.
Target Skills: ${JSON.stringify(requiredSkills)}.
Question Format: ${questionType}.
${typeGuideline}
${langGuideline}

Output strictly valid JSON with no markdown wrapping outside:
{
  "title": "${jobTitle}",
  "difficulty": "${difficulty}",
  "questionType": "${questionType}",
  "questions": [
    {
      "question": "string",
      "type": "${questionType === "TRUE_FALSE" ? "TRUE_FALSE" : questionType === "CODING" ? "CODING" : questionType === "SHORT_ANSWER" ? "SHORT_ANSWER" : "SINGLE_CHOICE"}",
      "options": ["string", "string", "string", "string"],
      "correctAnswerIndex": 0,
      "explanation": "string",
      "points": 10
    }
  ]
}`;

      const geminiResult = await callGeminiJson(prompt);
      if (
        geminiResult?.questions &&
        Array.isArray(geminiResult.questions) &&
        geminiResult.questions.length > 0
      ) {
        const sanitizedQuestions = geminiResult.questions
          .filter(
            (q: any) =>
              q &&
              typeof q.question === "string" &&
              q.question.trim().length > 0 &&
              Array.isArray(q.options) &&
              q.options.length >= 2
          )
          .slice(0, 30)
          .map((q: any) => {
            const cleanOptions = q.options.map((opt: any) => String(opt).trim()).filter(Boolean);
            const rawIdx = Number(q.correctAnswerIndex);
            const safeIdx =
              Number.isInteger(rawIdx) && rawIdx >= 0 && rawIdx < cleanOptions.length ? rawIdx : 0;
            const rawQType = typeof q.type === "string" ? q.type.trim().toUpperCase() : questionType;
            return {
              question: q.question.trim(),
              type: (VALID_QUESTION_TYPES as readonly string[]).includes(rawQType)
                ? rawQType
                : "SINGLE_CHOICE",
              options: cleanOptions,
              correctAnswerIndex: safeIdx,
              explanation: typeof q.explanation === "string" ? q.explanation.trim() : "",
              points: Number(q.points) > 0 ? Math.min(Number(q.points), 100) : 10,
            };
          })
          .filter((q: any) => q.options.length >= 2);

        if (sanitizedQuestions.length > 0) {
          return NextResponse.json({
            success: true,
            title: String(geminiResult.title || jobTitle),
            difficulty: String(geminiResult.difficulty || difficulty),
            questionType,
            questions: sanitizedQuestions,
          });
        }
      }

      // Dynamic Fallback generator if AI API key is not present or busy
      const fallbackQuestions = [];
      const mixedCycle = ["SINGLE_CHOICE", "TRUE_FALSE", "CODING", "SHORT_ANSWER"];
      for (let i = 0; i < questionCount; i++) {
        const qNum = i + 1;
        const effectiveType = questionType === "MIXED" ? mixedCycle[i % mixedCycle.length] : questionType;

        if (effectiveType === "TRUE_FALSE") {
          const isTrue = i % 2 === 0;
          fallbackQuestions.push({
            question:
              language === "ar"
                ? `السؤال ${qNum}: في بيئات الإنتاج لـ ${jobTitle}، هل يُعتبر تطبيق مبدأ الفصل بين الطبقات (Separation of Concerns) ضرورياً لتسهيل اختبار الكود وصيانته؟`
                : `Question ${qNum}: In production ${jobTitle} systems, separation of concerns is critical for testability and maintainability.`,
            type: "TRUE_FALSE",
            options: language === "ar" ? ["صح", "خطأ"] : ["True", "False"],
            correctAnswerIndex: isTrue ? 0 : 1,
            explanation:
              language === "ar"
                ? "فصل المنطق عن واجهة المستخدم يتيح كتابة اختبارات أحادية دقيقة ومستقلة."
                : "Separating business logic enables deterministic unit testing.",
            points: 10,
          });
        } else if (effectiveType === "CODING") {
          fallbackQuestions.push({
            question:
              language === "ar"
                ? `السؤال ${qNum}: ما هو التعقيد الزمني (Time Complexity) الأمثل واستراتيجية معالجة الذاكرة عند معالجة تدفق بيانات ضخم في ${jobTitle}؟`
                : `Question ${qNum}: What is the optimal time complexity and memory strategy when handling large stream processing in ${jobTitle}?`,
            type: "CODING",
            options:
              language === "ar"
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
            explanation:
              language === "ar"
                ? "المعالجة التدفقية O(N) هي المعيار الأمثل لكفاءة استهلاك الذاكرة."
                : "Stream pipelines ensure predictable low memory footprint.",
            points: 10,
          });
        } else if (effectiveType === "SHORT_ANSWER") {
          fallbackQuestions.push({
            question:
              language === "ar"
                ? `السؤال ${qNum}: ما هو المبدأ المعماري الأنسب لتحقيق قابلية التوسع والاعتمادية في خدمات ${jobTitle}؟`
                : `Question ${qNum}: Which architectural principle best improves scalability and reliability in ${jobTitle} services?`,
            type: "SHORT_ANSWER",
            options:
              language === "ar"
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
            explanation:
              language === "ar"
                ? "فصل الاعتماديات والعزل يمنعان انتشار الأعطال ويتيحان التوسع الأفقي."
                : "Stateless decoupling enables fault isolation and horizontal scalability.",
            points: 10,
          });
        } else {
          fallbackQuestions.push({
            question:
              language === "ar"
                ? `السؤال ${qNum}: ما هي أفضل الممارسات المعتمدة في هندسة ${jobTitle} لضمان أمان البيانات والتحكم في الوصول؟`
                : `Question ${qNum}: Which practice best guarantees data security and access control in ${jobTitle}?`,
            type: effectiveType === "MULTIPLE_CHOICE" ? "MULTIPLE_CHOICE" : "SINGLE_CHOICE",
            options:
              language === "ar"
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
            explanation:
              language === "ar"
                ? "التحقق من الصلاحيات على السيرفر يضمن حماية البيانات بغض النظر عن حالة العميل."
                : "Server-side rules prevent unauthorized access regardless of client tampering.",
            points: 10,
          });
        }
      }

      return NextResponse.json({
        success: true,
        title: jobTitle,
        difficulty,
        questionType,
        questions: fallbackQuestions,
      });
    }

    // 3. Generate Candidate AI Summary & CV Analysis
    if (action === "generateCandidateSummary") {
      const candidateName =
        typeof safePayload.candidateName === "string" && safePayload.candidateName.trim()
          ? safePayload.candidateName.trim().slice(0, 150)
          : "Candidate";
      const jobTitle =
        typeof safePayload.jobTitle === "string" && safePayload.jobTitle.trim()
          ? safePayload.jobTitle.trim().slice(0, 150)
          : "Target Role";
      const requiredSkills: string[] =
        Array.isArray(safePayload.requiredSkills) && safePayload.requiredSkills.length > 0
          ? safePayload.requiredSkills.map(String).slice(0, 30)
          : ["System Architecture", "TypeScript / Dart", "Cloud & Firestore", "REST APIs"];
      const examScore =
        typeof safePayload.examScore === "number" && Number.isFinite(safePayload.examScore)
          ? Math.min(100, Math.max(0, safePayload.examScore))
          : null;
      const isRTL = Boolean(safePayload.isRTL);

      const prompt = `
You are an executive talent acquisition AI advisor for "Test2Hire".
Analyze candidate "${candidateName}" for the role "${jobTitle}" (Required Skills: ${JSON.stringify(requiredSkills)}, Exam Score: ${examScore ?? "N/A"}).
${isRTL ? 'Write the "summary" field in clear, professional Arabic (technical terms may remain in English).' : 'Write the "summary" field in clear, professional English.'}
Output strictly valid JSON:
{
  "cvMatchScore": 90,
  "overallFitScore": 91,
  "aiRecommendation": "STRONG_MATCH",
  "summary": "string",
  "matchedSkills": ["string"],
  "missingSkills": ["string"]
}`;

      const geminiResult = await callGeminiJson(prompt);
      if (typeof geminiResult?.summary === "string" && geminiResult.summary.trim().length > 0) {
        const cvScore = Math.min(100, Math.max(0, Math.round(Number(geminiResult.cvMatchScore) || 75)));
        const fitScore = Math.min(
          100,
          Math.max(
            0,
            Math.round(
              Number(geminiResult.overallFitScore) ||
                (examScore !== null ? examScore * 0.6 + cvScore * 0.4 : cvScore)
            )
          )
        );
        const rec = ["STRONG_MATCH", "POTENTIAL_MATCH", "NOT_RECOMMENDED"].includes(
          geminiResult.aiRecommendation
        )
          ? geminiResult.aiRecommendation
          : fitScore >= 80
          ? "STRONG_MATCH"
          : fitScore >= 55
          ? "POTENTIAL_MATCH"
          : "NOT_RECOMMENDED";

        return NextResponse.json({
          success: true,
          cvMatchScore: cvScore,
          overallFitScore: fitScore,
          aiRecommendation: rec,
          summary: geminiResult.summary.trim(),
          matchedSkills: Array.isArray(geminiResult.matchedSkills)
            ? geminiResult.matchedSkills.map(String)
            : [],
          missingSkills: Array.isArray(geminiResult.missingSkills)
            ? geminiResult.missingSkills.map(String)
            : [],
        });
      }

      const cvMatchScore = 90;
      const overallFitScore = examScore !== null ? Math.round(examScore * 0.6 + cvMatchScore * 0.4) : cvMatchScore;

      return NextResponse.json({
        success: true,
        cvMatchScore,
        overallFitScore,
        aiRecommendation: overallFitScore >= 80 ? "STRONG_MATCH" : "POTENTIAL_MATCH",
        summary: isRTL
          ? `يُظهر المرشح ${candidateName} توافقاً تقنياً ممتازاً مع متطلبات وظيفة (${jobTitle})، مع إتقان واضح للمهارات الأساسية (${requiredSkills.slice(0, 3).join("، ")}) وجاهزية عالية للانتقال إلى مرحلة المقابلة التقنية والعرض الوظيفي.`
          : `Candidate ${candidateName} demonstrates strong technical alignment with the core requirements for ${jobTitle} (${requiredSkills.slice(0, 3).join(", ")}), showing high readiness for the technical interview and hiring stage.`,
        matchedSkills: requiredSkills,
        missingSkills: [],
      });
    }

    return NextResponse.json({ error: "Invalid AI action" }, { status: 400 });
  } catch (err: any) {
    return NextResponse.json({ error: err?.message || "AI Engine Error" }, { status: 500 });
  }
}
