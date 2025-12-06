/**
 * Quick verification script to check demo video restoration
 */

import admin from 'firebase-admin';
import { readFileSync } from 'fs';

const SERVICE_KEY_PATH = process.env.GOOGLE_APPLICATION_CREDENTIALS || '../snapflow-e2e-key.json';
const serviceAccount = JSON.parse(readFileSync(SERVICE_KEY_PATH, 'utf8'));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

const snap = await db.collection('videos')
  .where('videoId', '>=', 'demo_video_')
  .where('videoId', '<=', 'demo_video_\uf8ff')
  .limit(10)
  .get();

console.log(`\nChecking ${snap.size} demo videos:\n`);

let ready = 0;
let failed = 0;
let withHlsUrl = 0;
let withError = 0;

snap.docs.forEach(doc => {
  const d = doc.data();
  const status = d.status || 'unknown';
  const hasHlsUrl = !!d.hlsUrl;
  const hasError = !!d.errorCode;
  
  if (status === 'ready') ready++;
  if (status === 'failed') failed++;
  if (hasHlsUrl) withHlsUrl++;
  if (hasError) withError++;
  
  console.log(`${doc.id}:`);
  console.log(`  status: ${status}`);
  console.log(`  hlsUrl: ${hasHlsUrl ? d.hlsUrl.substring(0, 60) + '...' : 'EMPTY'}`);
  console.log(`  errorCode: ${d.errorCode || 'none'}`);
  console.log('');
});

console.log(`\nSummary (sample of ${snap.size} videos):`);
console.log(`  Ready: ${ready}`);
console.log(`  Failed: ${failed}`);
console.log(`  With hlsUrl: ${withHlsUrl}`);
console.log(`  With error: ${withError}`);

process.exit(0);

