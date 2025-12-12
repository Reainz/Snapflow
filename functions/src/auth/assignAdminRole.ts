import * as admin from 'firebase-admin';
import * as functionsV1 from 'firebase-functions/v1';
import { checkAdminAllowed } from './allowlist';

// NOTE: Auth user lifecycle triggers (auth.user().onCreate) are only available in
// the firebase-functions v1 namespace today, so these auth helpers intentionally
// use functionsV1 rather than the v2 API used elsewhere in the codebase.

export const assignAdminRole = functionsV1.auth.user().onCreate(async (user: functionsV1.auth.UserRecord) => {
  try {
    if (!admin.apps.length) admin.initializeApp();

    const email = (user.email || '').toLowerCase();
    const uid = user.uid;

    if (!email) {
      console.log(`User ${uid} has no email, skipping admin assignment.`);
      return;
    }

    // Idempotency: if claim already set, skip
    const record = await admin.auth().getUser(uid);
    if (record.customClaims?.admin === true) {
      console.log(`User ${uid} (${email}) already has admin claim. Skipping.`);
      return;
    }

    const { allowed: shouldBeAdmin, reason } = checkAdminAllowed(email);

    if (!shouldBeAdmin) {
      console.log(`User ${uid} (${email}) did not match admin criteria.`);
      return;
    }

    // Set custom claims
    await admin.auth().setCustomUserClaims(uid, { admin: true });
    console.log(`Admin claim set for ${uid} (${email}) via ${reason}.`);

    // Best-effort Firestore update (do not block function on failure)
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
    } catch (firestoreErr) {
      console.error('Failed to update Firestore user admin fields:', firestoreErr);
    }
  } catch (err) {
    console.error('assignAdminRole failed:', err);
    // Do not throw; user creation should not be blocked by this function.
  }
});
