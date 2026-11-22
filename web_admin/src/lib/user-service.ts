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

export type UserRole = "USER" | "COMPANY" | "ADMIN";

export interface UserRecord {
  uid: string;
  email: string;
  role: UserRole;
  fullName: string;
  isProfileComplete?: boolean;
  isSuspended?: boolean;
  status?: string;
  suspendReason?: string;
  headline?: string;
  bio?: string;
  phoneNumber?: string;
  createdAt?: Timestamp | null;
  updatedAt?: Timestamp | null;
}

export interface SetUserRolePayload {
  targetUid: string;
  newRole: UserRole;
}

export interface SetUserRoleResult {
  success: boolean;
  targetUid: string;
  newRole: UserRole;
}

import { compareTimestampsDesc } from "./formatters";

export async function fetchUsers(roleFilter?: UserRole | "ALL"): Promise<UserRecord[]> {
  try {
    const usersRef = collection(db, "users");
    let snapshot;

    if (roleFilter && roleFilter !== "ALL") {
      try {
        snapshot = await getDocs(
          query(
            usersRef,
            where("role", "==", roleFilter),
            orderBy("createdAt", "desc"),
            limit(200)
          )
        );
      } catch (indexErr: any) {
        if (!String(indexErr?.code || "").includes("failed-precondition")) {
          throw indexErr;
        }
        snapshot = await getDocs(
          query(usersRef, where("role", "==", roleFilter), limit(200))
        );
      }
    } else {
      snapshot = await getDocs(query(usersRef, orderBy("createdAt", "desc"), limit(200)));
    }
    const items = snapshot.docs.map((docSnap) => {
      const data = docSnap.data();
      const suspended = data.isSuspended === true || data.status === "SUSPENDED";
      return {
        uid: docSnap.id,
        email: data.email || "",
        role: (data.role as UserRole) || "USER",
        fullName: data.fullName || "Unnamed User",
        isProfileComplete: data.isProfileComplete ?? false,
        isSuspended: suspended,
        status: data.status || (suspended ? "SUSPENDED" : "ACTIVE"),
        suspendReason: data.suspendReason,
        headline: data.headline,
        bio: data.bio,
        phoneNumber: data.phoneNumber,
        createdAt: data.createdAt,
        updatedAt: data.updatedAt,
      };
    });

    if (roleFilter && roleFilter !== "ALL") {
      items.sort((a, b) => compareTimestampsDesc(a.createdAt, b.createdAt));
    }

    return items;
  } catch (error) {
    console.error("Failed to fetch users:", error);
    throw error;
  }
}

import { auth } from "./firebase";
import { addDoc, serverTimestamp, updateDoc } from "firebase/firestore";

export async function updateUserRole(targetUid: string, newRole: UserRole): Promise<SetUserRoleResult> {
  try {
    const callFn = httpsCallable<SetUserRolePayload, SetUserRoleResult>(
      functions,
      "adminSetRole"
    );
    const result = await callFn({ targetUid, newRole });
    return result.data;
  } catch (fnError: any) {
    console.warn("Cloud function adminSetRole call failed or blocked by CORS. Falling back to direct Firestore update:", fnError);
    const userRef = doc(db, "users", targetUid);
    await updateDoc(userRef, {
      role: newRole,
      updatedAt: serverTimestamp(),
    });

    try {
      await addDoc(collection(db, "auditLogs"), {
        actorId: auth.currentUser?.uid || "ADMIN",
        actorRole: "ADMIN",
        action: "ADMIN_UPDATE_ROLE",
        targetType: "USER",
        targetId: targetUid,
        metadata: { newRole, executionMode: "DIRECT_FALLBACK" },
        timestamp: serverTimestamp(),
      });
    } catch (auditErr) {
      console.warn("Failed to write audit log during fallback:", auditErr);
    }

    return {
      success: true,
      targetUid,
      newRole,
    };
  }
}

export async function toggleUserSuspension(
  targetUid: string,
  isSuspended: boolean,
  reason?: string
): Promise<{ success: boolean }> {
  const userRef = doc(db, "users", targetUid);
  await updateDoc(userRef, {
    isSuspended: isSuspended,
    status: isSuspended ? "SUSPENDED" : "ACTIVE",
    suspendReason: reason || null,
    suspendedAt: isSuspended ? serverTimestamp() : null,
    updatedAt: serverTimestamp(),
  });

  try {
    await addDoc(collection(db, "auditLogs"), {
      actorId: auth.currentUser?.uid || "ADMIN",
      actorRole: "ADMIN",
      action: isSuspended ? "USER_SUSPENDED" : "USER_REACTIVATED",
      targetType: "USER",
      targetId: targetUid,
      metadata: { isSuspended, reason: reason || "" },
      timestamp: serverTimestamp(),
    });
  } catch (auditErr) {
    console.warn("Failed to write audit log:", auditErr);
  }

  return { success: true };
}

