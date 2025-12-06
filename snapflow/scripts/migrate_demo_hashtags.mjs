// Migration script to normalize demo video hashtags to include a leading '#'
// Usage: node scripts/migrate_demo_hashtags.mjs

import fs from 'node:fs';
import process from 'node:process';
import admin from 'firebase-admin';

function requireEnv(name) {
  const v = process.env[name];
  if (!v) throw new Error(`Missing environment variable: ${name}`);
  return v;
}

function initializeFirebase() {
  const projectId = process.env.FIREBASE_PROJECT_ID || 'snapflow-4577d';
  const creds = requireEnv('GOOGLE_APPLICATION_CREDENTIALS');

  if (!fs.existsSync(creds)) {
    throw new Error(`Service account file not found: ${creds}`);
  }

  if (!admin.apps.length) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId,
    });
  }

  return { db: admin.firestore() };
}

async function migrate() {
  const { db } = initializeFirebase();

  const demoVideoIds = [
    'demo_video_001',
    'demo_video_002',
    'demo_video_003',
    'demo_video_004',
    'demo_video_005',
    'demo_video_006',
    'demo_video_007',
    'demo_video_008',
    'demo_video_009',
    'demo_video_010',
    'demo_video_011',
  ];

  let updated = 0;
  const errors = [];

  for (const videoId of demoVideoIds) {
    try {
      const ref = db.collection('videos').doc(videoId);
      const snap = await ref.get();
      if (!snap.exists) {
        console.warn(`⚠️  Video ${videoId} not found, skipping`);
        continue;
      }

      const data = snap.data() || {};
      const current = Array.isArray(data.hashtags) ? data.hashtags : [];
      const normalized = current.map((tag) => {
        const trimmed = String(tag ?? '').trim();
        if (!trimmed) return trimmed;
        return trimmed.startsWith('#') ? trimmed : `#${trimmed}`;
      });

      if (JSON.stringify(current) === JSON.stringify(normalized)) {
        console.log(`ℹ️  ${videoId} already normalized, skipping`);
        continue;
      }

      await ref.update({
        hashtags: normalized,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      console.log(`✅ Updated ${videoId}: ${current} -> ${normalized}`);
      updated++;
    } catch (error) {
      console.error(`❌ Failed to update ${videoId}: ${error.message || error}`);
      errors.push({ videoId, error: error.message || String(error) });
    }
  }

  console.log('\nMigration summary:');
  console.log(`  Updated: ${updated}`);
  console.log(`  Errors: ${errors.length}`);
  if (errors.length) {
    console.log(errors);
  }
}

migrate()
  .then(() => {
    console.log('Done.');
    process.exit(0);
  })
  .catch((err) => {
    console.error('Migration failed:', err);
    process.exit(1);
  });
