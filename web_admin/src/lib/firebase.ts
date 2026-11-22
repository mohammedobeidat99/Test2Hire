import { initializeApp, getApps, getApp } from "firebase/app";
import { getAuth } from "firebase/auth";
import { initializeFirestore, getFirestore } from "firebase/firestore";
import { getFunctions } from "firebase/functions";
import { getStorage } from "firebase/storage";

const firebaseConfig = {
  apiKey: process.env.NEXT_PUBLIC_FIREBASE_API_KEY || "AIzaSyD13nxqjaXdtUoAepn1OpF4b8flBFTSozM",
  authDomain: process.env.NEXT_PUBLIC_FIREBASE_AUTH_DOMAIN || "test2here-72346.firebaseapp.com",
  projectId: process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || "test2here-72346",
  storageBucket: process.env.NEXT_PUBLIC_FIREBASE_STORAGE_BUCKET || "test2here-72346.firebasestorage.app",
  messagingSenderId: process.env.NEXT_PUBLIC_FIREBASE_MESSAGING_SENDER_ID || "326304038955",
  appId: process.env.NEXT_PUBLIC_FIREBASE_APP_ID || "1:326304038955:web:2cdc5604a437527314ea6e",
};

const isNewApp = !getApps().length;
const app = isNewApp ? initializeApp(firebaseConfig) : getApp();
export const auth = getAuth(app);
export const db = isNewApp
  ? initializeFirestore(app, { experimentalAutoDetectLongPolling: true })
  : getFirestore(app);
export const functions = getFunctions(app);
export const storage = getStorage(app);
export default app;

