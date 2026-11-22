import { NextRequest } from "next/server";
import app from "@/lib/firebase";

export const FIREBASE_API_KEY =
  process.env.NEXT_PUBLIC_FIREBASE_API_KEY ||
  (typeof app.options?.apiKey === "string" ? app.options.apiKey : "");

export const FIREBASE_PROJECT_ID =
  process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID ||
  (typeof app.options?.projectId === "string" ? app.options.projectId : "");

export interface VerifiedCaller {
  idToken: string;
  uid: string;
  role: string;
  isSuspended: boolean;
}

const ALLOWED_PRIVILEGED_ROLES = new Set(["COMPANY", "ADMIN", "SUPERADMIN"]);

export function isCompanyOrAdminRole(role: string): boolean {
  return ALLOWED_PRIVILEGED_ROLES.has(role.trim().toUpperCase());
}

/**
 * Verifies a Firebase ID Bearer token using Identity Toolkit and resolves
 * custom-claim role with a fail-closed Firestore REST fallback (`users/{uid}`).
 */
export async function verifyFirebaseCaller(req: NextRequest): Promise<VerifiedCaller | null> {
  const authHeader = req.headers.get("authorization") || "";
  if (!authHeader.startsWith("Bearer ")) {
    return null;
  }
  const idToken = authHeader.slice(7).trim();
  if (!idToken || !FIREBASE_API_KEY) {
    return null;
  }

  const lookupController = new AbortController();
  const lookupTimeout = setTimeout(() => lookupController.abort(), 8000);
  let uid = "";
  let role = "";

  try {
    const res = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=${encodeURIComponent(FIREBASE_API_KEY)}`,
      {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ idToken }),
        signal: lookupController.signal,
      }
    );
    if (!res.ok) return null;
    const data = await res.json();
    const user = data?.users?.[0];
    if (!user?.localId || user?.disabled === true) {
      return null;
    }

    uid = String(user.localId);
    if (typeof user.customAttributes === "string" && user.customAttributes.trim()) {
      try {
        const claims = JSON.parse(user.customAttributes);
        if (claims?.isAdmin === true) {
          role = "ADMIN";
        } else {
          role = String(claims?.role || "").trim().toUpperCase();
        }
      } catch {
        // ignore malformed customAttributes JSON
      }
    }
  } catch {
    return null;
  } finally {
    clearTimeout(lookupTimeout);
  }

  if (!FIREBASE_PROJECT_ID) {
    return { idToken, uid, role, isSuspended: false };
  }

  // Always check users/{uid} when role claim is empty (or to honor server-side role/suspension state)
  const docController = new AbortController();
  const docTimeout = setTimeout(() => docController.abort(), 8000);
  let isSuspended = false;

  try {
    const userDocUrl =
      `https://firestore.googleapis.com/v1/projects/${encodeURIComponent(FIREBASE_PROJECT_ID)}` +
      `/databases/(default)/documents/users/${encodeURIComponent(uid)}`;
    const userDocRes = await fetch(userDocUrl, {
      method: "GET",
      headers: { Authorization: `Bearer ${idToken}` },
      signal: docController.signal,
    });
    if (userDocRes.ok) {
      const userDoc = await userDocRes.json();
      const fields = userDoc?.fields || {};
      const firestoreRole = String(fields?.role?.stringValue || "").trim().toUpperCase();
      if (!role && firestoreRole) {
        role = firestoreRole;
      }
      isSuspended =
        fields?.isSuspended?.booleanValue === true ||
        String(fields?.accountStatus?.stringValue || "").toUpperCase() === "SUSPENDED" ||
        String(fields?.status?.stringValue || "").toUpperCase() === "SUSPENDED";
    }
  } catch {
    // Fail closed if role remains unresolved
  } finally {
    clearTimeout(docTimeout);
  }

  return { idToken, uid, role, isSuspended };
}
