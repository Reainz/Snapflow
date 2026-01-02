/**
 * Restores demo videos that were incorrectly marked as failed by cleanup_legacy_hls.mjs
 * 
 * This script:
 * - Finds demo videos (IDs starting with 'demo_video_') that have status='failed' and errorCode='LEGACY_HLS_UNSUPPORTED'
 * - Recalculates the original hlsUrl using the same hash function from seed_demo_data.mjs
 * - Restores hlsUrl, sets status='ready', and clears error fields
 * 
 * Usage:
 *   cd snapflow/scripts
 *   set GOOGLE_APPLICATION_CREDENTIALS=../snapflow-e2e-key.json
 *   node restore_demo_videos.mjs                    # dry run
 *   APPLY=true node restore_demo_videos.mjs          # apply restorations
 */

import admin from 'firebase-admin';
import { readFileSync } from 'fs';

// --- Config ---
const APPLY_CHANGES = (process.env.APPLY || '').toLowerCase() === 'true';
const SERVICE_KEY_PATH = process.env.GOOGLE_APPLICATION_CREDENTIALS || '../snapflow-e2e-key.json';
const BATCH_SIZE = 200;

// --- Init ---
const serviceAccount = JSON.parse(readFileSync(SERVICE_KEY_PATH, 'utf8'));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

// Same hlsPool from seed_demo_data.mjs
const hlsPool = [
  // Mux demo streams
  'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
  'https://test-streams.mux.dev/tos_ismc/main.m3u8',
  // Unified Streaming demo (Tears of Steel)
  'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
  // Apple demo streams
  'https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_4x3/gear1/prog_index.m3u8',
  'https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_ts/v1/prog_index.m3u8',
];

// Same hash function from seed_demo_data.mjs
function hashString(value) {
  let hash = 0;
  for (let i = 0; i < value.length; i++) {
    hash = ((hash << 5) - hash) + value.charCodeAt(i);
    hash |= 0; // keep 32-bit
  }
  return Math.abs(hash);
}

// Calculate original hlsUrl for a video (same logic as seed script)
function calculateOriginalHlsUrl(videoId, ownerUsername) {
  const hash = hashString(videoId + ownerUsername);
  return hlsPool[hash % hlsPool.length];
}

async function* pagedVideos() {
  let lastId = null;
  while (true) {
    let query = db.collection('videos')
      .where('videoId', '>=', 'demo_video_')
      .where('videoId', '<=', 'demo_video_\uf8ff')
      .orderBy('videoId')
      .limit(BATCH_SIZE);
    
    if (lastId) {
      query = query.startAfter(lastId);
    }
    
    const snap = await query.get();
    if (snap.empty) break;
    
    for (const doc of snap.docs) {
      yield doc;
    }
    lastId = snap.docs[snap.docs.length - 1];
  }
}

async function main() {
  let checked = 0;
  let needsRestore = 0;
  let restored = 0;
  let skipped = 0;
  let errors = 0;

  console.log(`Starting demo video restoration (apply=${APPLY_CHANGES})`);
  console.log('');

  for await (const doc of pagedVideos()) {
    checked += 1;
    const data = doc.data();
    const videoId = doc.id;
    const status = data.status || '';
    const errorCode = data.errorCode || '';
    const currentHlsUrl = data.hlsUrl || '';
    const ownerUsername = data.ownerUsername || '';

    // Only restore videos that were incorrectly marked as failed
    if (status !== 'failed' || errorCode !== 'LEGACY_HLS_UNSUPPORTED') {
      skipped += 1;
      continue;
    }

    // Calculate the original hlsUrl
    if (!ownerUsername) {
      console.warn(`⚠️  Video ${videoId} missing ownerUsername, skipping`);
      skipped += 1;
      continue;
    }

    const originalHlsUrl = calculateOriginalHlsUrl(videoId, ownerUsername);
    needsRestore += 1;

    console.log(`📹 ${videoId} (${data.title || 'Untitled'})`);
    console.log(`   Owner: ${ownerUsername}`);
    console.log(`   Current hlsUrl: ${currentHlsUrl || '(empty)'}`);
    console.log(`   Original hlsUrl: ${originalHlsUrl}`);

    if (!APPLY_CHANGES) {
      console.log(`   [DRY RUN] Would restore hlsUrl and set status='ready'`);
      console.log('');
      continue;
    }

    try {
      await doc.ref.update({
        status: 'ready',
        hlsUrl: originalHlsUrl,
        error: admin.firestore.FieldValue.delete(),
        errorCode: admin.firestore.FieldValue.delete(),
        lastErrorAt: admin.firestore.FieldValue.delete(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      restored += 1;
      console.log(`   ✅ Restored successfully`);
      console.log('');
    } catch (error) {
      errors += 1;
      console.error(`   ❌ Failed to restore: ${error.message}`);
      console.log('');
    }
  }

  console.log('\nSummary:');
  console.log(`  Checked demo videos:    ${checked}`);
  console.log(`  Skipped (not failed):   ${skipped}`);
  console.log(`  Needs restoration:     ${needsRestore}`);
  console.log(`  Restored:              ${restored}`);
  console.log(`  Errors:                ${errors}`);
  
  if (!APPLY_CHANGES && needsRestore > 0) {
    console.log('\n💡 Run with APPLY=true to apply restorations');
  } else if (APPLY_CHANGES && restored > 0) {
    console.log('\n✅ Demo videos restored successfully!');
  } else if (needsRestore === 0) {
    console.log('\n✅ No demo videos need restoration');
  }
  
  console.log('\nDone.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

