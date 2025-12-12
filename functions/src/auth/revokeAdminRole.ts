import * as admin from 'firebase-admin';
import * as functionsV1 from 'firebase-functions/v1';

// NOTE: Admin role management sticks with firebase-functions v1 because callable
// auth helpers and auth.user() triggers are only supported there. Migrating to v2
// would drop support for these auth integrations.

export const revokeAdminRole = functionsV1.https.onCall(async (data, context) => {
  if (!context.auth || context.auth.token.admin !== true) {
    throw new functionsV1.https.HttpsError('permission-denied', 'Only admins can revoke admin access');
  }

  const userId = data?.userId as string | undefined;
  if (!userId) {
    throw new functionsV1.https.HttpsError('invalid-argument', 'userId is required');
  }

  try {
    if (!admin.apps.length) admin.initializeApp();
    await admin.auth().setCustomUserClaims(userId, { admin: false });
    const db = admin.firestore();
    await db.collection('users').doc(userId).set(
      {
        isAdmin: false,
        adminRevokedAt: admin.firestore.FieldValue.serverTimestamp(),
        adminRevokedBy: context.auth.uid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
    return { success: true, userId };
  } catch (err) {
    console.error('revokeAdminRole failed:', err);
    throw new functionsV1.https.HttpsError('internal', 'Failed to revoke admin access');
  }
});
