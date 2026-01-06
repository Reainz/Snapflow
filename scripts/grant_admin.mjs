// Quick script to grant admin role to demo1@snapflow.test
// Usage: node grant_admin.mjs
// Requires: Firebase CLI login (firebase login) OR GOOGLE_APPLICATION_CREDENTIALS env var

import process from 'node:process';
import admin from 'firebase-admin';

async function main() {
  const projectId = process.env.FIREBASE_PROJECT_ID || 'snapflow-4577d';
  
  if (admin.apps.length === 0) {
    // Try explicit service account first if GOOGLE_APPLICATION_CREDENTIALS is set
    const credsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (credsPath) {
      const fs = await import('node:fs');
      const serviceAccount = JSON.parse(fs.readFileSync(credsPath, 'utf8'));
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        projectId,
      });
      console.log('✅ Using service account credentials');
    } else {
      // Fallback to application default credentials (works if Firebase CLI is logged in)
      admin.initializeApp({
        projectId, // Explicitly set project ID
      });
      console.log('✅ Using application default credentials with explicit project ID');
    }
  }

  const email = 'demo1@snapflow.test';
  console.log(`Granting admin role to ${email}...`);

  try {
    const user = await admin.auth().getUserByEmail(email);
    console.log(`Found user: ${user.uid}`);

    // Check if already admin
    if (user.customClaims?.admin === true) {
      console.log('User already has admin role.');
      return;
    }

    // Grant admin
    await admin.auth().setCustomUserClaims(user.uid, { admin: true });
    console.log('✅ Admin role granted!');

    // Update Firestore
    await admin.firestore().collection('users').doc(user.uid).set({
      isAdmin: true,
      adminGrantedAt: admin.firestore.FieldValue.serverTimestamp(),
      adminGrantReason: 'email_allowlist',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    console.log('✅ Firestore updated!');

    console.log('\n⚠️  Note: User must sign out and sign in again for the new token to take effect.');
  } catch (error) {
    console.error('Error:', error.message);
    process.exitCode = 1;
  }
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exitCode = 1;
});
