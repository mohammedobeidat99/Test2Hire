import { NextRequest, NextResponse } from "next/server";
import {
  FIREBASE_PROJECT_ID,
  isCompanyOrAdminRole,
  verifyFirebaseCaller,
} from "../_lib/auth";

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function sanitizeHeaderLine(value: string): string {
  return value.replace(/[\r\n]+/g, " ").trim();
}

class MailQueueHttpError extends Error {
  status: number;
  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

async function queueMailInFirestore(
  idToken: string,
  payload: {
    to: string;
    subject: string;
    text: string;
    html: string;
    senderUid: string;
    candidateName: string;
    companyName: string;
    jobTitle: string;
  }
): Promise<void> {
  if (!FIREBASE_PROJECT_ID) {
    throw new Error("Firebase project ID is not configured.");
  }

  const nowIso = new Date().toISOString();
  const firestoreUrl = `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(FIREBASE_PROJECT_ID)}/databases/(default)/documents/mail`;

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 10000);
  try {
    const res = await fetch(firestoreUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${idToken}`,
      },
      body: JSON.stringify({
        fields: {
          to: { arrayValue: { values: [{ stringValue: payload.to }] } },
          message: {
            mapValue: {
              fields: {
                subject: { stringValue: payload.subject },
                text: { stringValue: payload.text },
                html: { stringValue: payload.html },
              },
            },
          },
          metadata: {
            mapValue: {
              fields: {
                type: { stringValue: "JOB_OFFER" },
                senderUid: { stringValue: payload.senderUid },
                candidateName: { stringValue: payload.candidateName },
                companyName: { stringValue: payload.companyName },
                jobTitle: { stringValue: payload.jobTitle },
              },
            },
          },
          status: { stringValue: "QUEUED" },
          createdAt: { timestampValue: nowIso },
        },
      }),
      signal: controller.signal,
    });

    if (!res.ok) {
      const errText = await res.text().catch(() => "");
      if (res.status === 403 || res.status === 401) {
        throw new MailQueueHttpError(
          403,
          "Forbidden. Company account must be approved and active to send offer emails."
        );
      }
      throw new MailQueueHttpError(502, `Firestore mail queue failed (${res.status}): ${errText}`);
    }
  } finally {
    clearTimeout(timeoutId);
  }
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
      { error: "Forbidden. Only approved companies or administrators can send offer emails." },
      { status: 403 }
    );
  }

  try {
    const {
      to,
      candidateName,
      jobTitle,
      companyName,
      salary,
      currency,
      salaryPeriod,
      startDate,
      notes,
    } = body;

    const cleanTo = typeof to === "string" ? to.trim() : "";
    if (!cleanTo || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(cleanTo) || cleanTo.length > 254) {
      return NextResponse.json({ error: "A valid recipient email address is required" }, { status: 400 });
    }

    const cleanCandidate = typeof candidateName === "string" && candidateName.trim()
      ? candidateName.trim().slice(0, 150)
      : "";
    const cleanJobTitle = typeof jobTitle === "string" && jobTitle.trim()
      ? jobTitle.trim().slice(0, 150)
      : "";
    const cleanCompany = typeof companyName === "string" && companyName.trim()
      ? companyName.trim().slice(0, 150)
      : "Test2Hire";

    if (!cleanCandidate || !cleanJobTitle) {
      return NextResponse.json(
        { error: "candidateName and jobTitle are required" },
        { status: 400 }
      );
    }

    const numericSalary = Number(salary);
    if (!Number.isFinite(numericSalary) || numericSalary <= 0) {
      return NextResponse.json(
        { error: "A valid positive numeric salary is required" },
        { status: 400 }
      );
    }

    const cleanCurrency = typeof currency === "string" && currency.trim()
      ? currency.trim().toUpperCase().slice(0, 10)
      : "SAR";
    const normalizedPeriod = String(salaryPeriod || "MONTHLY").toUpperCase() === "ANNUAL" ? "ANNUAL" : "MONTHLY";
    const periodLabel = normalizedPeriod === "ANNUAL" ? "سنوياً" : "شهرياً";
    const cleanStartDate = typeof startDate === "string" && startDate.trim()
      ? startDate.trim().slice(0, 64)
      : "";
    const cleanNotes = typeof notes === "string" && notes.trim()
      ? notes.trim().slice(0, 2000)
      : "";

    const formattedSalary = numericSalary.toLocaleString("en-US");
    const emailSubject = sanitizeHeaderLine(
      `🎉 عرض عمل رسمي من شركة ${cleanCompany} لمنصب ${cleanJobTitle}`
    ).slice(0, 240);
    const emailPlainText =
      `مرحباً ${cleanCandidate}،\n\n` +
      `يسر شركة ${cleanCompany} تقديم عرض عمل رسمي لك لمنصب ${cleanJobTitle}.\n` +
      `الراتب المعروض: ${formattedSalary} ${cleanCurrency} ${periodLabel}.\n` +
      `تاريخ البدء المتوقع: ${cleanStartDate || "حسب الاتفاق"}.\n\n` +
      `يرجى فتح تطبيق Test2Hire على هاتفك لمراجعة كافة بنود العرض وقبوله رسمياً.`;

    const safeCandidateHtml = escapeHtml(cleanCandidate);
    const safeCompanyHtml = escapeHtml(cleanCompany);
    const safeJobHtml = escapeHtml(cleanJobTitle);
    const safeSalaryHtml = escapeHtml(formattedSalary);
    const safeCurrencyHtml = escapeHtml(cleanCurrency);
    const safeStartDateHtml = escapeHtml(cleanStartDate);
    const safeNotesHtml = escapeHtml(cleanNotes);

    const emailHtml = `
      <div style="font-family: Arial, sans-serif; direction: rtl; text-align: right; background-color: #f1f5f9; padding: 32px 16px;">
        <div style="max-width: 580px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 12px rgba(0,0,0,0.06); border: 1px solid #e2e8f0;">
          <div style="background: linear-gradient(135deg, #047857 0%, #10b981 100%); padding: 28px 24px; text-align: center; color: white;">
            <h1 style="margin: 0; font-size: 24px; font-weight: bold;">🎉 عرض عمل رسمي جديد</h1>
            <p style="margin: 6px 0 0 0; font-size: 14px; opacity: 0.95;">منصة التوظيف الذكية Test2Hire Cloud</p>
          </div>
          <div style="padding: 28px 24px; color: #1e293b; line-height: 1.6;">
            <p style="font-size: 16px; margin-top: 0;">عزيزي/عزيزتي <strong>${safeCandidateHtml}</strong>،</p>
            <p style="font-size: 14px; color: #475569;">
              يسرنا إبلاغك بأن شركة <strong>${safeCompanyHtml}</strong> قد قامت بإصدار عرض عمل رسمي لك بعد مراجعة تقييمك واجتيازك لمراحل التوظيف بنجاح!
            </p>
            
            <div style="background-color: #f8fafc; border: 1px solid #cbd5e1; border-radius: 12px; padding: 20px; margin: 20px 0;">
              <table style="width: 100%; border-collapse: collapse; font-size: 14px;">
                <tr>
                  <td style="padding: 8px 0; color: #64748b; width: 40%;">المسمى الوظيفي:</td>
                  <td style="padding: 8px 0; font-weight: bold; color: #0f172a;">${safeJobHtml}</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; color: #64748b;">الشركة:</td>
                  <td style="padding: 8px 0; font-weight: bold; color: #047857;">${safeCompanyHtml}</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; color: #64748b;">الراتب المعروض:</td>
                  <td style="padding: 8px 0; font-weight: bold; color: #047857; font-size: 16px;">${safeSalaryHtml} ${safeCurrencyHtml} ${periodLabel}</td>
                </tr>
                ${safeStartDateHtml ? `
                <tr>
                  <td style="padding: 8px 0; color: #64748b;">تاريخ البدء:</td>
                  <td style="padding: 8px 0; font-weight: bold; color: #0f172a;">${safeStartDateHtml}</td>
                </tr>` : ""}
              </table>
            </div>

            ${safeNotesHtml ? `<div style="background-color: #eff6ff; border-right: 4px solid #3b82f6; padding: 12px 16px; border-radius: 4px; margin: 16px 0; font-size: 13px; color: #1e40af;"><strong>ملاحظات الشركة:</strong> ${safeNotesHtml}</div>` : ""}

            <div style="text-align: center; margin: 32px 0 16px 0;">
              <div style="display: inline-block; background-color: #047857; color: #ffffff; text-decoration: none; padding: 14px 28px; border-radius: 30px; font-weight: bold; font-size: 15px; box-shadow: 0 4px 8px rgba(4,120,87,0.25);">
                افتح تطبيق Test2Hire لمراجعة وتوقيع العرض
              </div>
            </div>

            <p style="font-size: 12px; color: #94a3b8; text-align: center; margin-top: 24px;">
              هذه الرسالة تم إرسالها تلقائياً عبر نظام Test2Hire Cloud ATS المتزامن مع تطبيق الهاتف للمرشحين.
            </p>
          </div>
        </div>
      </div>
    `;

    await queueMailInFirestore(caller.idToken, {
      to: cleanTo,
      subject: emailSubject,
      text: emailPlainText,
      html: emailHtml,
      senderUid: caller.uid,
      candidateName: cleanCandidate,
      companyName: cleanCompany,
      jobTitle: cleanJobTitle,
    });

    console.log(`[Email Service] Queued job offer email cleanly for UID: ${caller.uid}`);

    return NextResponse.json({
      success: true,
      message: `Email notification dispatched to ${cleanTo}`,
    });
  } catch (error: any) {
    if (error instanceof MailQueueHttpError) {
      return NextResponse.json({ error: error.message }, { status: error.status });
    }
    console.error("[Email Service Error]:", error);
    return NextResponse.json(
      { error: error?.message || "Failed to send email" },
      { status: 500 }
    );
  }
}
