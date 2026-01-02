import * as admin from 'firebase-admin';
import * as functionsV1 from 'firebase-functions/v1';
import { checkAdminAllowed } from './allowlist';

// HTTPS callable: ensure admin role for existing accounts that match the allow-list.
// Returns { applied: boolean, reason?: string }
// NOTE: We keep this callable on the firebase-functions v1 surface because it needs
// access to the auth.user() trigger ecosystem/v1 callable auth helpers that are not
// yet available in v2.
export const ensureAdminRole = functionsV1.https.onCall(async (_data, context) => {
  try {
    if (!admin.apps.length) admin.initializeApp();

    if (!context.auth) {
      throw new functionsV1.https.HttpsError('unauthenticated', 'Must be authenticated.');
    }

    const uid = context.auth.uid;
    const email = (context.auth.token.email as string | undefined)?.toLowerCase() || '';
    if (!email) {
      throw new functionsV1.https.HttpsError('failed-precondition', 'No email on account.');
    }

    // Idempotency: if already admin, short-circuit
    const record = await admin.auth().getUser(uid);
    if (record.customClaims?.admin === true) {
      return { applied: false, reason: 'already_admin' };
    }

    const { allowed, reason } = checkAdminAllowed(email);
    if (!allowed) {
      return { applied: false, reason: 'not_allowed' };
    }

    await admin.auth().setCustomUserClaims(uid, { admin: true });

    // Best-effort Firestore audit
    try {
      const db = admin.firestore();
      await db.collection('users').doc(uid).set(
        {
          isAdmin: true,
          adminGrantedAt: admin.firestore.FieldValue.serverTimestamp(),
          adminGrantReason: reason,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    } catch (e) {
      console.error('ensureAdminRole: Firestore update failed', e);
    }

    return { applied: true, reason };
  } catch (err: any) {
    console.error('ensureAdminRole failed:', err);
    if (err instanceof functionsV1.https.HttpsError) throw err;
    throw new functionsV1.https.HttpsError('internal', err?.message || 'Unknown error');
  }
});
