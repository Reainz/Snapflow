import { initializeApp, getApps, cert, type App } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';
import { getAuth, type Auth } from 'firebase-admin/auth';

let adminApp: App | null = null;

/**
 * Initialize Firebase Admin SDK (server-side only)
 * This must be called before using getAdminAuth() or getAdminFirestore()
 */
export function initializeFirebaseAdmin(): App {
  if (adminApp) {
    return adminApp;
  }

  if (getApps().length > 0) {
    adminApp = getApps()[0];
    return adminApp;
  }

  const projectId = process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID;
  const serviceAccountKey = process.env.FIREBASE_SERVICE_ACCOUNT_KEY;

  if (!projectId) {
    throw new Error('Missing NEXT_PUBLIC_FIREBASE_PROJECT_ID environment variable.');
  }

  if (!serviceAccountKey) {
    throw new Error('Missing FIREBASE_SERVICE_ACCOUNT_KEY environment variable.');
  }

  try {
    const credentials = JSON.parse(serviceAccountKey);
    adminApp = initializeApp({
      credential: cert(credentials),
      projectId,
    });
    return adminApp;
  } catch (error) {
    console.error('Failed to parse FIREBASE_SERVICE_ACCOUNT_KEY:', error);
    throw new Error('Invalid Firebase service account key format. Ensure it is valid JSON.');
  }
}

/**
 * Get Firebase Admin Auth instance
 */
export function getAdminAuth(): Auth {
  initializeFirebaseAdmin();
  return getAuth();
}

/**
 * Get Firebase Admin Firestore instance
 */
export function getAdminFirestore(): Firestore {
  initializeFirebaseAdmin();
  return getFirestore();
}