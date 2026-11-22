import { db, functions } from "./firebase";
import {
  collection,
  getDocs,
  doc,
  getDoc,
  query,
  where,
  orderBy,
  limit,
  Timestamp,
} from "firebase/firestore";
import { httpsCallable } from "firebase/functions";

export type CompanyVerificationStatus = "PENDING" | "APPROVED" | "REJECTED" | "SUSPENDED";

export interface CompanyRecord {
  id: string;
  name: string;
  industry: string;
  size: string;
  website: string;
  logoUrl?: string;
  coverUrl?: string;
  description: string;
  country: string;
  city: string;
  address: string;
  taxNumber?: string;
  commercialRegister?: string;
  contactEmail: string;
  contactPhone: string;
  verificationStatus: CompanyVerificationStatus;
  verificationNotes?: string;
  verifiedAt?: Timestamp | null;
  verifiedBy?: string | null;
  createdAt?: Timestamp | null;
  updatedAt?: Timestamp | null;
}

export interface ReviewCompanyPayload {
  companyId: string;
  status: CompanyVerificationStatus;
  notes?: string;
}

export interface ReviewCompanyResult {
  success: boolean;
  companyId: string;
  status: CompanyVerificationStatus;
}

/**
 * Fetch list of companies with optional status filtering.
 */
import { compareTimestampsDesc } from "./formatters";

export async function fetchCompanies(statusFilter?: CompanyVerificationStatus | "ALL"): Promise<CompanyRecord[]> {
  try {
    const companiesRef = collection(db, "companies");
    let snapshot;

    if (statusFilter && statusFilter !== "ALL") {
      try {
        snapshot = await getDocs(
          query(
            companiesRef,
            where("verificationStatus", "==", statusFilter),
            orderBy("createdAt", "desc"),
            limit(200)
          )
        );
      } catch (indexErr: any) {
        if (!String(indexErr?.code || "").includes("failed-precondition")) {
          throw indexErr;
        }
        snapshot = await getDocs(
          query(companiesRef, where("verificationStatus", "==", statusFilter), limit(200))
        );
      }
    } else {
      snapshot = await getDocs(query(companiesRef, orderBy("createdAt", "desc"), limit(200)));
    }
    const items = snapshot.docs.map((docSnap) => {
      const data = docSnap.data();
      return {
        id: docSnap.id,
        name: data.name || "Unnamed Company",
        industry: data.industry || "Not Specified",
        size: data.size || "1-10",
        website: data.website || "",
        logoUrl: data.logoUrl,
        coverUrl: data.coverUrl,
        description: data.description || "",
        country: data.country || "",
        city: data.city || "",
        address: data.address || "",
        taxNumber: data.taxNumber,
        commercialRegister: data.commercialRegister,
        contactEmail: data.contactEmail || "",
        contactPhone: data.contactPhone || "",
        verificationStatus: (data.verificationStatus as CompanyVerificationStatus) || "PENDING",
        verificationNotes: data.verificationNotes,
        verifiedAt: data.verifiedAt,
        verifiedBy: data.verifiedBy,
        createdAt: data.createdAt,
        updatedAt: data.updatedAt,
      };
    });

    if (statusFilter && statusFilter !== "ALL") {
      items.sort((a, b) => compareTimestampsDesc(a.createdAt, b.createdAt));
    }

    return items;
  } catch (error) {
    console.error("Failed to fetch companies:", error);
    throw error;
  }
}

/**
 * Fetch a single company by ID.
 */
export async function getCompanyById(companyId: string): Promise<CompanyRecord | null> {
  const docRef = doc(db, "companies", companyId);
  const snap = await getDoc(docRef);
  if (!snap.exists()) return null;
  const data = snap.data();
  return {
    id: snap.id,
    name: data.name || "Unnamed Company",
    industry: data.industry || "Not Specified",
    size: data.size || "1-10",
    website: data.website || "",
    logoUrl: data.logoUrl,
    coverUrl: data.coverUrl,
    description: data.description || "",
    country: data.country || "",
    city: data.city || "",
    address: data.address || "",
    taxNumber: data.taxNumber,
    commercialRegister: data.commercialRegister,
    contactEmail: data.contactEmail || "",
    contactPhone: data.contactPhone || "",
    verificationStatus: (data.verificationStatus as CompanyVerificationStatus) || "PENDING",
    verificationNotes: data.verificationNotes,
    verifiedAt: data.verifiedAt,
    verifiedBy: data.verifiedBy,
    createdAt: data.createdAt,
    updatedAt: data.updatedAt,
  };
}

import { auth } from "./firebase";
import { addDoc, serverTimestamp, updateDoc } from "firebase/firestore";

/**
 * Submit an admin review for a company (approving, rejecting, or suspending).
 * Calls the secure cloud function adminReviewCompany with graceful fallback to Firestore.
 */
export async function reviewCompany(payload: ReviewCompanyPayload): Promise<ReviewCompanyResult> {
  const { companyId, status, notes } = payload;
  try {
    const callFn = httpsCallable<ReviewCompanyPayload, ReviewCompanyResult>(
      functions,
      "adminReviewCompany"
    );
    const result = await callFn(payload);
    return result.data;
  } catch (fnError: any) {
    console.warn("Cloud function adminReviewCompany call failed or blocked by CORS. Falling back to direct Firestore update:", fnError);

    const currentUser = auth.currentUser;
    const companyRef = doc(db, "companies", companyId);

    // 1. Direct update permitted for ADMIN under firestore.rules; onCompanyUpdated CF handles notification
    await updateDoc(companyRef, {
      verificationStatus: status,
      verificationNotes: notes || null,
      verifiedAt: serverTimestamp(),
      verifiedBy: currentUser?.uid || "ADMIN",
      updatedAt: serverTimestamp(),
    });

    // 2. Add audit log
    try {
      await addDoc(collection(db, "auditLogs"), {
        actorId: currentUser?.uid || "ADMIN",
        actorRole: "ADMIN",
        action: `COMPANY_${status}`,
        targetType: "COMPANY",
        targetId: companyId,
        metadata: { status, notes, executionMode: "DIRECT_FALLBACK" },
        timestamp: serverTimestamp(),
      });
    } catch (auditErr) {
      console.warn("Failed to write audit log during fallback:", auditErr);
    }

    return {
      success: true,
      companyId,
      status,
    };
  }
}

