/**
 * Quick script to check video URLs in Firestore
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

async function checkVideoUrls() {
  console.log('🔍 Checking video URLs in Firestore...\n');
  
  const videosSnapshot = await db.collection('videos').limit(10).get();
  
  console.log(`Found ${videosSnapshot.size} videos (showing first 10):\n`);
  
  videosSnapshot.forEach((doc) => {
    const data = doc.data();
    console.log(`📹 Video: ${doc.id}`);
    console.log(`   Title: ${data.title || 'N/A'}`);
    console.log(`   Privacy: ${data.privacy || 'N/A'}`);
    console.log(`   HLS URL: ${data.hlsUrl || 'N/A'}`);
    console.log(`   Status: ${data.status || 'N/A'}`);
    console.log('');
  });
  
  // Check for broken URLs
  const allVideos = await db.collection('videos').get();
  const brokenUrls = [];
  const cloudinaryUrls = [];
  const testUrls = [];
  
  allVideos.forEach((doc) => {
    const data = doc.data();
    const url = data.hlsUrl || '';
    
    if (url.includes('storage.googleapis.com/shaka-demo-assets') || 
        url.includes('cph-p2p-msl.akamaized.net')) {
      brokenUrls.push({ id: doc.id, url, title: data.title });
    } else if (url.includes('cloudinary.com')) {
      cloudinaryUrls.push({ id: doc.id, url, title: data.title });
    } else if (url.includes('test-streams.mux.dev') || 
               url.includes('bitdash-a.akamaihd.net') ||
               url.includes('apple.com') ||
               url.includes('unified-streaming.com')) {
      testUrls.push({ id: doc.id, url, title: data.title });
    }
  });
  
  console.log('\n📊 URL Statistics:');
  console.log(`   Total videos: ${allVideos.size}`);
  console.log(`   Cloudinary URLs: ${cloudinaryUrls.length}`);
  console.log(`   Working test URLs: ${testUrls.length}`);
  console.log(`   Potentially broken URLs: ${brokenUrls.length}`);
  
  if (brokenUrls.length > 0) {
    console.log('\n⚠️  Videos with potentially broken URLs:');
    brokenUrls.slice(0, 5).forEach((video) => {
      console.log(`   - ${video.id}: ${video.title}`);
      console.log(`     URL: ${video.url.substring(0, 80)}...`);
    });
    if (brokenUrls.length > 5) {
      console.log(`   ... and ${brokenUrls.length - 5} more`);
    }
  }
  
  process.exit(0);
}

checkVideoUrls().catch((error) => {
  console.error('Error:', error);
  process.exit(1);
});

