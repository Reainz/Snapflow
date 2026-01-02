import { initializeApp, applicationDefault, cert } from 'firebase-admin/app';
import { getStorage } from 'firebase-admin/storage';
import { getFirestore } from 'firebase-admin/firestore';

// Usage: node scripts/process_video_e2e.mjs <projectId> <videoId>
const [,, projectId, videoId] = process.argv;
if (!projectId || !videoId) {
  console.error('Usage: node scripts/process_video_e2e.mjs <projectId> <videoId>');
  process.exit(1);
}

initializeApp({ projectId });
const db = getFirestore();

async function main() {
  const doc = await db.collection('videos').doc(videoId).get();
  if (!doc.exists) {
    throw new Error('Video doc not found');
  }
  const data = doc.data();
  console.log('Video status:', data.status);
  console.log('HLS URL:', data.hlsUrl);
  console.log('Processing duration (ms):', data.processingDurationMs);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
