// End-to-end Storage test: creates a test video doc, uploads a thumbnail, verifies read
// Requirements:
// - Node 18+
// - Env: GOOGLE_APPLICATION_CREDENTIALS points to a service account JSON with Firebase Admin
// - npm i firebase-admin node-fetch@3 (fetch is used to verify the download URL)

import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import { fileURLToPath } from 'node:url';
import admin from 'firebase-admin';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function requireEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing env ${name}`);
  return v;
}

async function main() {
  const projectId = process.env.FIREBASE_PROJECT_ID || 'snapflow-4577d';
  const creds = requireEnv('GOOGLE_APPLICATION_CREDENTIALS');
  if (!fs.existsSync(creds)) throw new Error(`Service account file not found: ${creds}`);
  const bucketName = process.env.FIREBASE_STORAGE_BUCKET || `${projectId}.firebasestorage.app`;

  if (admin.apps.length === 0) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      storageBucket: bucketName,
      projectId,
    });
  }

  const db = admin.firestore();
  const bucket = admin.storage().bucket(bucketName);

  // Generate a test user/video
  const testUserId = `e2e_${Date.now()}`;
  const videoId = `e2e_${Date.now()}`;

  console.log('Using project:', projectId);
  console.log('Test user:', testUserId);
  console.log('Video ID:', videoId);

  // 1) Create a minimal video doc with ownerId and privacy
  const videoRef = db.collection('videos').doc(videoId);
  await videoRef.set({
    ownerId: testUserId,
    privacy: 'public',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    status: 'ready',
    title: 'E2E Test Video',
  });
  console.log('Created videos/', videoId);

  // 2) Upload a small test image as thumbnails/{videoId}.jpg
  // Create a tiny 1x1 PNG buffer (pre-encoded) to avoid external deps
  const tinyPng = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMB/ahx7kQAAAAASUVORK5CYII=',
    'base64'
  );
  const dest = `thumbnails/${videoId}.jpg`;
  const tmp = path.join(__dirname, `thumb_${videoId}.png`);
  fs.writeFileSync(tmp, tinyPng);

  await bucket.upload(tmp, {
    destination: dest,
    gzip: false,
    metadata: {
      contentType: 'image/png',
      cacheControl: 'public, max-age=604800',
    },
  });
  console.log('Uploaded', dest);

  // 3) Get a signed URL to verify read (public rules also allow read for public video)
  const [file] = await bucket.file(dest).get();
  const [url] = await file.getSignedUrl({ action: 'read', expires: Date.now() + 5 * 60 * 1000 });
  console.log('Signed URL:', url);

  // 4) Head request to confirm Cache-Control header
  const res = await fetch(url, { method: 'HEAD' });
  console.log('Response status:', res.status);
  console.log('Cache-Control:', res.headers.get('cache-control'));

  // Cleanup temp file
  fs.unlinkSync(tmp);
  console.log('Success. Cleaned temp file. (Video and thumbnail kept for inspection)');
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
