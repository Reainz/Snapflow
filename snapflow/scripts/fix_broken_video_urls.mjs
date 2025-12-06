/**
 * Quick script to identify and optionally fix broken video URLs
 */

import admin from 'firebase-admin';
import { readFileSync } from 'fs';

// Initialize Firebase Admin SDK
const serviceAccount = JSON.parse(readFileSync('../snapflow-e2e-key.json', 'utf8'));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'snapflow-4577d.firebasestorage.app',
});

const db = admin.firestore();

// Known working test URLs
const workingUrls = [
  'https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8',
  'https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8',
  'https://demo.unified-streaming.com/k8s/features/stable/video/tears-of-steel/tears-of-steel.ism/.m3u8',
  'https://test-streams.mux.dev/tos_ismc/main.m3u8',
  'https://bitdash-a.akamaihd.net/content/MI201109210084_1/m3u8s/f08e80da-bf1d-4e3d-8899-f0f6155f6efa.m3u8',
];

// Known broken/problematic URLs
const brokenUrlPatterns = [
  'devstreaming-cdn.apple.com', // Apple streams block mobile apps (403)
  'storage.googleapis.com/shaka-demo-assets', // Old/broken
  'cph-p2p-msl.akamaized.net', // Old/broken
];

async function checkAndFixUrls() {
  console.log('🔍 Checking video URLs for broken patterns...\n');
  
  const videosSnapshot = await db.collection('videos').get();
  const brokenVideos = [];
  const fixedCount = 0;
  
  videosSnapshot.forEach((doc) => {
    const data = doc.data();
    const url = data.hlsUrl || '';
    const isBroken = brokenUrlPatterns.some(pattern => url.includes(pattern));
    
    if (isBroken && data.privacy === 'public') {
      brokenVideos.push({
        id: doc.id,
        title: data.title || 'Untitled',
        currentUrl: url,
        ownerUsername: data.ownerUsername || 'unknown',
      });
    }
  });
  
  if (brokenVideos.length === 0) {
    console.log('✅ No broken URLs found! All videos should work.\n');
    return;
  }
  
  console.log(`⚠️  Found ${brokenVideos.length} videos with potentially broken URLs:\n`);
  
  brokenVideos.slice(0, 10).forEach((video) => {
    console.log(`   📹 ${video.title} (@${video.ownerUsername})`);
    console.log(`      ID: ${video.id}`);
    console.log(`      URL: ${video.currentUrl.substring(0, 80)}...`);
    console.log('');
  });
  
  if (brokenVideos.length > 10) {
    console.log(`   ... and ${brokenVideos.length - 10} more\n`);
  }
  
  console.log('💡 To fix these, run the seed script again:');
  console.log('   cd snapflow/scripts');
  console.log('   $env:GOOGLE_APPLICATION_CREDENTIALS="../snapflow-e2e-key.json"; node seed_demo_data.mjs\n');
  
  process.exit(0);
}

checkAndFixUrls().catch((error) => {
  console.error('Error:', error);
  process.exit(1);
});

