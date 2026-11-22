import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

export const db = admin.firestore();
try {
  db.settings({ ignoreUndefinedProperties: true });
} catch {
  // Ignore if Firestore settings were already applied in a hot-reload or test context.
}
export const auth = admin.auth();
export const storage = admin.storage();
export const messaging = admin.messaging();
