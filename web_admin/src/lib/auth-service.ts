import { auth, db, functions, storage } from "./firebase";
import {
  signInWithEmailAndPassword,
  createUserWithEmailAndPassword,
  sendEmailVerification,
  signOut as fbSignOut,
  User,
} from "firebase/auth";
import { doc, getDoc, setDoc, serverTimestamp } from "firebase/firestore";
import { httpsCallable } from "firebase/functions";
import { ref, uploadBytes, getDownloadURL } from "firebase/storage";

export type UserRole = "ADMIN" | "COMPANY" | "USER";

export interface PortalUser {
  uid: string;
  email: string | null;
  role: UserRole;
  displayName?: string;
  companyName?: string;
  emailVerified?: boolean;
  redirectUrl: string;
}

const STRICT_EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

export function isValidEmailAddress(email: string): boolean {
  const clean = email.trim();
  return clean.length <= 254 && STRICT_EMAIL_REGEX.test(clean);
}

export interface ResolvedRoleResult {
  role: UserRole;
  companyName?: string;
  logoUrl?: string;
  industry?: string;
  verificationStatus?: string;
}

/**
 * Resolves the authenticated user's role from cached Auth custom claims and parallel Firestore checks.
 */
export async function resolveUserRole(user: User): Promise<ResolvedRoleResult> {
  try {
    const idToken = await user.getIdTokenResult(false);
    let roleStr = (idToken.claims.role as string)?.toUpperCase();

    const needUserDoc = !roleStr || (roleStr !== "ADMIN" && roleStr !== "COMPANY");
    const needCompanyDoc = roleStr !== "ADMIN";

    const [userSnap, compSnap] = await Promise.all([
      needUserDoc ? getDoc(doc(db, "users", user.uid)) : Promise.resolve(null),
      needCompanyDoc ? getDoc(doc(db, "companies", user.uid)) : Promise.resolve(null),
    ]);

    if (userSnap?.exists()) {
      const udata = userSnap.data();
      if (udata.role) {
        roleStr = String(udata.role).toUpperCase();
      }
    }

    let companyName: string | undefined;
    let logoUrl: string | undefined;
    let industry: string | undefined;
    let verificationStatus: string | undefined;

    if (compSnap?.exists()) {
      if (!roleStr || roleStr === "USER") {
        roleStr = "COMPANY";
      }
      const cdata = compSnap.data();
      companyName = cdata.name || cdata.companyName;
      logoUrl = cdata.logoUrl || cdata.logo || "";
      industry = cdata.industry || "";
      verificationStatus = (cdata.verificationStatus || "PENDING").toUpperCase();
    }

    if (roleStr === "ADMIN") {
      return { role: "ADMIN" };
    }
    if (roleStr === "COMPANY") {
      return {
        role: "COMPANY",
        companyName,
        logoUrl,
        industry,
        verificationStatus: verificationStatus || "PENDING",
      };
    }
    return { role: "USER" };
  } catch (error) {
    console.error("Failed to resolve user role:", error);
    return { role: "USER" };
  }
}

/**
 * Sign in for both Administrators and Company Employers.
 */
export async function signInPortalUser(email: string, password: string): Promise<PortalUser> {
  const credential = await signInWithEmailAndPassword(auth, email, password);
  const user = credential.user;
  const { role, companyName } = await resolveUserRole(user);

  if (role === "ADMIN") {
    return {
      uid: user.uid,
      email: user.email,
      role: "ADMIN",
      redirectUrl: "/dashboard/companies",
    };
  }

  if (role === "COMPANY") {
    return {
      uid: user.uid,
      email: user.email,
      role: "COMPANY",
      companyName: companyName || "My Company",
      redirectUrl: "/company/dashboard",
    };
  }

  // Reject Candidate logins on the web portal
  await fbSignOut(auth);
  throw new Error(
    "هذا الحساب مخصص للباحثين عن عمل (Job Seeker). يرجى استخدام تطبيق الهاتف للتقديم على الوظائف وخوض الاختبارات والمقابلات."
  );
}

export interface RegisterCompanyParams {
  companyName: string;
  email: string;
  password: string;
  industry?: string;
  city?: string;
  country?: string;
  website?: string;
  size?: string;
  phone?: string;
  description?: string;
  logoUrl?: string;
  logoFile?: File | null;
}

/**
 * Register a new Company Employer directly from the Web Portal.
 */
export async function registerCompanyPortalUser(params: RegisterCompanyParams): Promise<PortalUser> {
  const cleanEmail = params.email.trim();
  if (!isValidEmailAddress(cleanEmail)) {
    throw new Error("يرجى إدخال عنوان بريد إلكتروني صحيح وموثق.");
  }

  const credential = await createUserWithEmailAndPassword(auth, cleanEmail, params.password);
  const user = credential.user;

  try {
    await sendEmailVerification(user);
  } catch (verErr) {
    console.warn("Failed to send verification email during company registration:", verErr);
  }

  let resolvedLogoUrl = params.logoUrl || "";
  if (params.logoFile && storage) {
    try {
      const mime = (params.logoFile.type || "").toLowerCase();
      const allowed = ["image/jpeg", "image/jpg", "image/png", "image/webp", "image/gif"];
      if (!allowed.includes(mime)) {
        throw new Error("Unsupported image format. Please use PNG, JPG, WebP, or GIF.");
      }
      const safeName = params.logoFile.name.replace(/[^a-zA-Z0-9._-]/g, "_");
      const storageRef = ref(storage, `companies/${user.uid}/logo/${Date.now()}_${safeName}`);
      await uploadBytes(storageRef, params.logoFile, { contentType: mime });
      resolvedLogoUrl = await getDownloadURL(storageRef);
    } catch (storageErr) {
      console.warn("Post-auth company logo upload failed, retaining fallback:", storageErr);
    }
  }

  const city = params.city || "Amman";
  const country = params.country || "Jordan";
  const teamSize = params.size || "11-50";

  await Promise.all([
    setDoc(doc(db, "users", user.uid), {
      uid: user.uid,
      email: cleanEmail,
      fullName: params.companyName,
      companyName: params.companyName,
      role: "COMPANY",
      accountStatus: "ACTIVE",
      photoUrl: resolvedLogoUrl,
      phoneNumber: params.phone || "",
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
    setDoc(doc(db, "companies", user.uid), {
      id: user.uid,
      uid: user.uid,
      ownerUid: user.uid,
      name: params.companyName,
      companyName: params.companyName,
      email: cleanEmail,
      industry: params.industry || "Technology & Software",
      location: {
        city,
        country,
        address: "",
      },
      city,
      country,
      website: params.website || "",
      size: teamSize,
      teamSize,
      contactEmail: cleanEmail,
      contactPhone: params.phone || "",
      description: params.description || "",
      logoUrl: resolvedLogoUrl,
      verificationStatus: "PENDING",
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
    }),
  ]);

  // Sync Firebase Auth custom claims best-effort without blocking signup if CF unavailable
  try {
    const syncFn = httpsCallable(functions, "syncUserProfile");
    await syncFn({
      role: "COMPANY",
      fullName: params.companyName,
      companyName: params.companyName,
      industry: params.industry || "Technology & Software",
      description: params.description || "",
    });
  } catch (claimErr) {
    console.warn("syncUserProfile custom-claims sync skipped:", claimErr);
  }

  return {
    uid: user.uid,
    email: user.email,
    role: "COMPANY",
    companyName: params.companyName,
    emailVerified: user.emailVerified,
    redirectUrl: "/company/dashboard",
  };
}

export async function resendCompanyVerificationEmail(): Promise<void> {
  if (!auth.currentUser) {
    throw new Error("No authenticated company user.");
  }
  await sendEmailVerification(auth.currentUser);
}

export async function reloadCompanyUser(): Promise<boolean> {
  if (!auth.currentUser) {
    return false;
  }
  await auth.currentUser.reload();
  return Boolean(auth.currentUser.emailVerified);
}

/**
 * Sign out current session
 */
export async function signOutPortalUser(): Promise<void> {
  await fbSignOut(auth);
}

