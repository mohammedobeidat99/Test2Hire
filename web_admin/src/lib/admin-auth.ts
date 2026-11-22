import { auth } from "./firebase";
import { signInWithEmailAndPassword, signOut as fbSignOut, User } from "firebase/auth";

export interface AdminUser {
  uid: string;
  email: string | null;
  role: string;
}

export async function signInAdmin(email: string, password: string): Promise<AdminUser> {
  // Purely authenticate directly against Firebase Authentication
  const credential = await signInWithEmailAndPassword(auth, email, password);
  
  // Force refresh token to get latest custom claims from Firebase
  const idTokenResult = await credential.user.getIdTokenResult(true);
  const role = idTokenResult.claims.role as string | undefined;

  // Verify that Firebase Auth custom claims explicitly grant ADMIN role
  if (role !== "ADMIN") {
    await fbSignOut(auth);
    throw new Error("Access denied. This account does not have administrator privileges in Firebase Authentication.");
  }

  return {
    uid: credential.user.uid,
    email: credential.user.email,
    role: role,
  };
}

/**
 * Signs out the current admin session.
 */
export async function signOutAdmin(): Promise<void> {
  await fbSignOut(auth);
}
