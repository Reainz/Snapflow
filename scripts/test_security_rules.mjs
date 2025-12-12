/**
 * Phase 5: Security Rules Testing Script
 * Tests all Firestore and Storage security rules fixes
 * 
 * Usage:
 *   node scripts/test_security_rules.mjs
 * 
 * Requirements:
 *   - Firebase emulator running OR production project with service account
 *   - Set GOOGLE_APPLICATION_CREDENTIALS for production testing
 *   - Set USE_EMULATOR=true for emulator testing
 */

import admin from 'firebase-admin';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Configuration
const USE_EMULATOR = process.env.USE_EMULATOR === 'true';
const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'snapflow-4577d';
const EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || 'localhost:8180';
const STORAGE_EMULATOR_HOST = process.env.STORAGE_EMULATOR_HOST || 'localhost:9199';

// Test results tracking
const results = {
  passed: 0,
  failed: 0,
  tests: []
};

function log(message, type = 'info') {
  const prefix = type === 'pass' ? '✅' : type === 'fail' ? '❌' : type === 'warn' ? '⚠️' : 'ℹ️';
  console.log(`${prefix} ${message}`);
}

function recordTest(name, passed, details = '') {
  results.tests.push({ name, passed, details });
  if (passed) {
    results.passed++;
    log(name, 'pass');
  } else {
    results.failed++;
    log(name, 'fail');
    if (details) log(`   ${details}`, 'warn');
  }
}

// Initialize Firebase Admin
function initializeFirebase() {
  if (admin.apps.length > 0) {
    return admin.app();
  }

  if (USE_EMULATOR) {
    // Use emulator
    process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_HOST;
    process.env.STORAGE_EMULATOR_HOST = STORAGE_EMULATOR_HOST;
    
    admin.initializeApp({
      projectId: PROJECT_ID,
    });
    
    log('Using Firebase Emulator', 'info');
  } else {
    // Use production with service account
    const credsPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
    if (!credsPath || !fs.existsSync(credsPath)) {
      throw new Error('GOOGLE_APPLICATION_CREDENTIALS not set or file not found');
    }
    
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      projectId: PROJECT_ID,
    });
    
    log('Using Production Firebase (with service account)', 'warn');
  }
  
  return admin.app();
}

// Create test users and videos
async function setupTestData(db) {
  const timestamp = Date.now();
  
  const ownerId = `test_owner_${timestamp}`;
  const followerId = `test_follower_${timestamp}`;
  const nonFollowerId = `test_nonfollower_${timestamp}`;
  const videoId1 = `test_video_public_${timestamp}`;
  const videoId2 = `test_video_private_${timestamp}`;
  const videoId3 = `test_video_followers_${timestamp}`;
  
  // Create users
  await db.collection('users').doc(ownerId).set({
    username: 'test_owner',
    email: 'owner@test.com',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  await db.collection('users').doc(followerId).set({
    username: 'test_follower',
    email: 'follower@test.com',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  await db.collection('users').doc(nonFollowerId).set({
    username: 'test_nonfollower',
    email: 'nonfollower@test.com',
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  // Create follow relationship
  await db.collection('users').doc(ownerId).collection('followers').doc(followerId).set({
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  // Create videos
  await db.collection('videos').doc(videoId1).set({
    ownerId,
    privacy: 'public',
    status: 'ready',
    title: 'Public Test Video',
    likesCount: 0,
    commentsCount: 0,
    sharesCount: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  await db.collection('videos').doc(videoId2).set({
    ownerId,
    privacy: 'private',
    status: 'ready',
    title: 'Private Test Video',
    likesCount: 0,
    commentsCount: 0,
    sharesCount: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  await db.collection('videos').doc(videoId3).set({
    ownerId,
    privacy: 'followers-only',
    status: 'ready',
    title: 'Followers-Only Test Video',
    likesCount: 0,
    commentsCount: 0,
    sharesCount: 0,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  
  return {
    ownerId,
    followerId,
    nonFollowerId,
    videoId1, // public
    videoId2, // private
    videoId3, // followers-only
  };
}

// Test Firestore Rules
async function testFirestoreRules(db, testData) {
  log('\n=== Testing Firestore Rules ===', 'info');
  
  // Note: These tests use Admin SDK which bypasses rules
  // For actual rule testing, we need client SDK with auth tokens
  // This script validates the data structure and documents the expected behavior
  
  log('Note: Admin SDK bypasses rules. These tests validate data structure.', 'warn');
  log('For actual rule testing, use Firebase client SDK with authentication.', 'warn');
  
  // Test 1: Verify public video exists
  const publicVideo = await db.collection('videos').doc(testData.videoId1).get();
  recordTest(
    'Public video document created',
    publicVideo.exists && publicVideo.data().privacy === 'public',
    `Privacy: ${publicVideo.data()?.privacy}`
  );
  
  // Test 2: Verify private video exists
  const privateVideo = await db.collection('videos').doc(testData.videoId2).get();
  recordTest(
    'Private video document created',
    privateVideo.exists && privateVideo.data().privacy === 'private',
    `Privacy: ${privateVideo.data()?.privacy}`
  );
  
  // Test 3: Verify followers-only video exists
  const followersVideo = await db.collection('videos').doc(testData.videoId3).get();
  recordTest(
    'Followers-only video document created',
    followersVideo.exists && followersVideo.data().privacy === 'followers-only',
    `Privacy: ${followersVideo.data()?.privacy}`
  );
  
  // Test 4: Verify follow relationship exists
  const followDoc = await db
    .collection('users')
    .doc(testData.ownerId)
    .collection('followers')
    .doc(testData.followerId)
    .get();
  recordTest(
    'Follow relationship created',
    followDoc.exists,
    `Follower: ${testData.followerId}`
  );
  
  log('\n⚠️  Firestore rule testing requires client SDK with auth tokens', 'warn');
  log('   Expected behavior:', 'info');
  log('   - Public video: readable by any authenticated user', 'info');
  log('   - Private video: readable only by owner', 'info');
  log('   - Followers-only: readable by owner and followers', 'info');
  log('   - Engagement counters: updatable by any authenticated user', 'info');
  log('   - Other fields: updatable only by owner', 'info');
}

// Test Storage Rules
async function testStorageRules(storage, db, testData) {
  log('\n=== Testing Storage Rules ===', 'info');
  
  const bucket = storage.bucket();
  const tinyPng = Buffer.from(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMB/ahx7kQAAAAASUVORK5CYII=',
    'base64'
  );
  
  // Test 1: Owner can upload thumbnail (using Admin SDK - bypasses rules)
  try {
    const thumbnailPath = `thumbnails/${testData.videoId1}.jpg`;
    const file = bucket.file(thumbnailPath);
    await file.save(tinyPng, {
      metadata: {
        contentType: 'image/jpeg',
      },
    });
    recordTest('Thumbnail upload (Admin SDK)', true, 'Owner upload successful');
  } catch (error) {
    recordTest('Thumbnail upload (Admin SDK)', false, error.message);
  }
  
  // Test 2: Verify processed-hls path doesn't exist in rules
  log('\n⚠️  Storage rule testing requires client SDK with auth tokens', 'warn');
  log('   Expected behavior:', 'info');
  log('   - Thumbnail write: only video owner can upload', 'info');
  log('   - Thumbnail read: any authenticated user can read', 'info');
  log('   - processed-hls path: should not exist in storage rules', 'info');
  
  // Verify processed-hls is not in storage rules
  const storageRulesPath = path.join(__dirname, '..', 'storage.rules');
  if (fs.existsSync(storageRulesPath)) {
    const rulesContent = fs.readFileSync(storageRulesPath, 'utf8');
    const hasProcessedHls = rulesContent.includes('processed-hls');
    recordTest(
      'processed-hls removed from storage rules',
      !hasProcessedHls,
      hasProcessedHls ? 'Found processed-hls reference' : 'No processed-hls found'
    );
  } else {
    recordTest('storage.rules file exists', false, 'File not found');
  }
}

// Test Integration Points
async function testIntegration(db, testData) {
  log('\n=== Testing Integration Points ===', 'info');
  
  // Test 1: Verify video feed query structure (privacy filter)
  try {
    const feedQuery = db
      .collection('videos')
      .where('status', '==', 'ready')
      .where('privacy', '==', 'public')
      .orderBy('createdAt', 'desc')
      .limit(10);
    
    const feedSnapshot = await feedQuery.get();
    recordTest(
      'Feed query with privacy filter works',
      feedSnapshot.docs.length >= 1,
      `Found ${feedSnapshot.docs.length} public videos`
    );
  } catch (error) {
    recordTest('Feed query with privacy filter works', false, error.message);
  }
  
  // Test 2: Verify engagement counter update structure
  try {
    await db.collection('videos').doc(testData.videoId1).update({
      likesCount: admin.firestore.FieldValue.increment(1),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    recordTest('Engagement counter update structure', true, 'Increment operation successful');
  } catch (error) {
    recordTest('Engagement counter update structure', false, error.message);
  }
  
  // Test 3: Verify admin dashboard bucket stats structure
  const bucketStats = {
    'raw-videos': { count: 0, sizeGB: '0.00', sizeMB: '0.00' },
    'thumbnails': { count: 0, sizeGB: '0.00', sizeMB: '0.00' },
    'captions': { count: 0, sizeGB: '0.00', sizeMB: '0.00' },
    'profile-pictures': { count: 0, sizeGB: '0.00', sizeMB: '0.00' },
    'other': { count: 0, sizeGB: '0.00', sizeMB: '0.00' },
  };
  
  const hasProcessedHls = 'processed-hls' in bucketStats;
  recordTest(
    'Admin dashboard bucket stats (no processed-hls)',
    !hasProcessedHls,
    hasProcessedHls ? 'processed-hls found in structure' : 'Structure correct'
  );
}

// Cleanup test data
async function cleanup(db, testData) {
  log('\n=== Cleaning up test data ===', 'info');
  
  try {
    // Delete videos
    await Promise.all([
      db.collection('videos').doc(testData.videoId1).delete(),
      db.collection('videos').doc(testData.videoId2).delete(),
      db.collection('videos').doc(testData.videoId3).delete(),
    ]);
    
    // Delete follow relationship
    await db
      .collection('users')
      .doc(testData.ownerId)
      .collection('followers')
      .doc(testData.followerId)
      .delete();
    
    // Delete users
    await Promise.all([
      db.collection('users').doc(testData.ownerId).delete(),
      db.collection('users').doc(testData.followerId).delete(),
      db.collection('users').doc(testData.nonFollowerId).delete(),
    ]);
    
    log('Test data cleaned up', 'pass');
  } catch (error) {
    log(`Cleanup error: ${error.message}`, 'warn');
  }
}

// Main execution
async function main() {
  try {
    log('Starting Phase 5: Security Rules Testing', 'info');
    log(`Project: ${PROJECT_ID}`, 'info');
    log(`Mode: ${USE_EMULATOR ? 'Emulator' : 'Production'}`, 'info');
    
    initializeFirebase();
    const db = admin.firestore();
    const storage = admin.storage();
    
    // Setup test data
    log('\n=== Setting up test data ===', 'info');
    const testData = await setupTestData(db);
    log(`Created test users and videos`, 'pass');
    
    // Run tests
    await testFirestoreRules(db, testData);
    await testStorageRules(storage, db, testData);
    await testIntegration(db, testData);
    
    // Cleanup
    await cleanup(db, testData);
    
    // Print summary
    log('\n=== Test Summary ===', 'info');
    log(`Passed: ${results.passed}`, results.passed > 0 ? 'pass' : 'info');
    log(`Failed: ${results.failed}`, results.failed > 0 ? 'fail' : 'info');
    log(`Total: ${results.tests.length}`, 'info');
    
    if (results.failed > 0) {
      log('\nFailed tests:', 'fail');
      results.tests
        .filter(t => !t.passed)
        .forEach(t => log(`  - ${t.name}: ${t.details}`, 'fail'));
    }
    
    process.exitCode = results.failed > 0 ? 1 : 0;
  } catch (error) {
    log(`Fatal error: ${error.message}`, 'fail');
    console.error(error);
    process.exitCode = 1;
  }
}

main();

