// Call ensureAdminRole Cloud Function to grant admin to demo1@snapflow.test
// This script authenticates as demo1, then calls the ensureAdminRole function
//
// Usage:
//   FIREBASE_PROJECT_ID=snapflow-4577d \
//   FIREBASE_API_KEY=your_api_key \
//   TEST_EMAIL=demo1@snapflow.test \
//   TEST_PASSWORD=your_password \
//   node call_ensure_admin.mjs

import process from 'node:process';
import https from 'node:https';
import { URL } from 'node:url';

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'snapflow-4577d';
const API_KEY = process.env.FIREBASE_API_KEY;
const EMAIL = process.env.TEST_EMAIL || 'demo1@snapflow.test';
const PASSWORD = process.env.TEST_PASSWORD;

if (!API_KEY) {
  console.error('❌ Error: FIREBASE_API_KEY environment variable is required');
  console.error('   Set it with: export FIREBASE_API_KEY=your_api_key');
  process.exit(1);
}

if (!PASSWORD) {
  console.error('❌ Error: TEST_PASSWORD environment variable is required');
  console.error('   Set it with: export TEST_PASSWORD=your_password');
  process.exit(1);
}

// Step 1: Sign in with email/password to get ID token
async function signInWithPassword() {
  return new Promise((resolve, reject) => {
    const data = JSON.stringify({
      email: EMAIL,
      password: PASSWORD,
      returnSecureToken: true,
    });

    const options = {
      hostname: 'identitytoolkit.googleapis.com',
      path: `/v1/accounts:signInWithPassword?key=${API_KEY}`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': data.length,
      },
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => {
        body += chunk;
      });
      res.on('end', () => {
        if (res.statusCode === 200) {
          const result = JSON.parse(body);
          resolve(result.idToken);
        } else {
          reject(new Error(`Sign in failed: ${res.statusCode} - ${body}`));
        }
      });
    });

    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

// Step 2: Call ensureAdminRole Cloud Function
async function callEnsureAdminRole(idToken) {
  return new Promise((resolve, reject) => {
    const functionUrl = `https://us-central1-${PROJECT_ID}.cloudfunctions.net/ensureAdminRole`;
    const data = JSON.stringify({ data: {} });

    const url = new URL(functionUrl);
    const options = {
      hostname: url.hostname,
      path: url.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': data.length,
        'Authorization': `Bearer ${idToken}`,
      },
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => {
        body += chunk;
      });
      res.on('end', () => {
        if (res.statusCode === 200) {
          const result = JSON.parse(body);
          resolve(result);
        } else {
          reject(new Error(`Function call failed: ${res.statusCode} - ${body}`));
        }
      });
    });

    req.on('error', reject);
    req.write(data);
    req.end();
  });
}

async function main() {
  console.log('🔐 Step 1: Signing in as demo1@snapflow.test...');
  try {
    const idToken = await signInWithPassword();
    console.log('✅ Signed in successfully');

    console.log('\n🔧 Step 2: Calling ensureAdminRole function...');
    const result = await callEnsureAdminRole(idToken);
    console.log('✅ Function call result:', JSON.stringify(result, null, 2));

    if (result.result?.applied) {
      console.log('\n✅ Admin role granted successfully!');
      console.log(`   Reason: ${result.result.reason}`);
      console.log('\n⚠️  IMPORTANT: User must sign out and sign in again for the new token to take effect.');
    } else if (result.result?.reason === 'already_admin') {
      console.log('\n✅ User already has admin role!');
    } else {
      console.log('\n⚠️  Admin role not granted. Reason:', result.result?.reason || 'unknown');
    }
  } catch (error) {
    console.error('❌ Error:', error.message);
    process.exitCode = 1;
  }
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exitCode = 1;
});
