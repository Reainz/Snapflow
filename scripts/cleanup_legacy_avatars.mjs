/**
 * Cleanup legacy profile pictures stored at:
 *   profile-pictures/{userId}/avatar.<ext>
 *
 * Current format (kept):
 *   profile-pictures/{userId}.jpg
 *
 * This script finds legacy nested avatar objects and (optionally) deletes them.
 * It is a DRY RUN by default – no files are deleted unless APPLY=true is set.
 *
 * Usage (PowerShell example):
 *   cd snapflow/scripts
 *   $env:GOOGLE_APPLICATION_CREDENTIALS = "..\\snapflow-e2e-key.json"
 *   node .\\cleanup_legacy_avatars.mjs                # dry run
 *   $env:APPLY = "true"; node .\\cleanup_legacy_avatars.mjs   # delete legacy files
 */

import fs from 'node:fs';
import process from 'node:process';
import admin from 'firebase-admin';

function requireEnv(name) {
  const v = process.env[name];
  if (!v) {
    throw new Error(`Missing env ${name}`);
  }
  return v;
}

const APPLY_CHANGES = (process.env.APPLY || '').toLowerCase() === 'true';
const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || 'snapflow-4577d';
const CREDS_PATH = process.env.GOOGLE_APPLICATION_CREDENTIALS || '../snapflow-e2e-key.json';
const BUCKET_NAME = process.env.FIREBASE_STORAGE_BUCKET || `${PROJECT_ID}.firebasestorage.app`;

async function main() {
  // Ensure service account is available so applicationDefault() works.
  process.env.GOOGLE_APPLICATION_CREDENTIALS = CREDS_PATH;
  requireEnv('GOOGLE_APPLICATION_CREDENTIALS');
  if (!fs.existsSync(CREDS_PATH)) {
    throw new Error(`Service account file not found: ${CREDS_PATH}`);
  }

  if (admin.apps.length === 0) {
    admin.initializeApp({
      credential: admin.credential.applicationDefault(),
      storageBucket: BUCKET_NAME,
      projectId: PROJECT_ID,
    });
  }

  const bucket = admin.storage().bucket(BUCKET_NAME);

  console.log('Starting legacy avatar cleanup');
  console.log(`  Project: ${PROJECT_ID}`);
  console.log(`  Bucket:  ${BUCKET_NAME}`);
  console.log(`  Mode:    ${APPLY_CHANGES ? 'APPLY (delete legacy files)' : 'DRY RUN (no deletes)'}`);

  let checked = 0;
  let legacy = 0;
  let deleted = 0;

  let options = { prefix: 'profile-pictures/' };

  while (true) {
    const [files, nextQuery] = await bucket.getFiles(options);
    if (!files.length) break;

    for (const file of files) {
      checked += 1;
      const name = file.name; // e.g. "profile-pictures/uid.jpg" or "profile-pictures/uid/avatar.jpg"

      // Strip prefix
      const withoutPrefix = name.replace(/^profile-pictures\//, '');
      if (!withoutPrefix) continue;

      // Current layout stores avatars at root: "{uid}.jpg".
      // Legacy layout uses a nested path: "{uid}/avatar.ext".
      // We only want to delete the legacy nested objects.
      if (!withoutPrefix.includes('/')) {
        continue; // root-level -> keep
      }

      const [userIdPart, filePart, ...restParts] = withoutPrefix.split('/');
      if (!userIdPart || !filePart || restParts.length > 0) {
        continue; // unexpected structure
      }

      if (!filePart.startsWith('avatar.') || !filePart.includes('.')) {
        continue; // only treat avatar.* under uid/ as legacy
      }

      legacy += 1;
      console.log(`LEGACY avatar found: ${name}`);

      if (APPLY_CHANGES) {
        try {
          await file.delete();
          deleted += 1;
          console.log('  -> deleted');
        } catch (err) {
          console.error(`  !! failed to delete ${name}:`, err?.message || err);
        }
      }
    }

    if (!nextQuery) break;
    options = nextQuery;
  }

  console.log('\nSummary');
  console.log(`  Checked objects:        ${checked}`);
  console.log(`  Legacy root avatars:    ${legacy}`);
  console.log(`  Deleted (this run):     ${deleted}`);

  if (!APPLY_CHANGES) {
    console.log('\nDry run only. Set APPLY=true to actually delete the legacy avatar files.');
  }

  console.log('Done.');
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
