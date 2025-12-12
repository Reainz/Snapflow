/**
 * Cleans up legacy (non-Cloudinary) HLS URLs by marking missing assets as failed.
 *
 * Behavior:
 * - Finds videos whose hlsUrl is NOT Cloudinary.
 * - If the referenced Firebase Storage object does not exist:
 *     - Default: set status='failed', clear hlsUrl, set error metadata.
 *     - If DELETE_DOCS=true: delete the document instead.
 * - Dry run by default. Set APPLY=true to write changes.
 *
 * Usage:
 *   cd snapflow/scripts
 *   set GOOGLE_APPLICATION_CREDENTIALS=../snapflow-e2e-key.json   # or export on *nix
 *   node cleanup_legacy_hls.mjs                                   # dry run
 *   APPLY=true node cleanup_legacy_hls.mjs                        # apply updates
 *   APPLY=true DELETE_DOCS=true node cleanup_legacy_hls.mjs       # delete broken docs
 */

import admin from 'firebase-admin';
import { readFileSync } from 'fs';

// --- Config ---
const APPLY_CHANGES = (process.env.APPLY || '').toLowerCase() === 'true';
const DELETE_DOCS = (process.env.DELETE_DOCS || '').toLowerCase() === 'true';
const SERVICE_KEY_PATH = process.env.GOOGLE_APPLICATION_CREDENTIALS || '../snapflow-e2e-key.json';
const BATCH_SIZE = 200;

// --- Init ---
const serviceAccount = JSON.parse(readFileSync(SERVICE_KEY_PATH, 'utf8'));
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();
const storage = admin.storage();

function isCloudinary(url) {
  if (!url) return false;
  return url.includes('res.cloudinary.com') || url.includes('cloudinary.com');
}

function isFirebaseStorageUrl(url) {
  if (!url) return false;
  return (
    url.includes('firebasestorage.googleapis.com') ||
    url.includes('storage.googleapis.com') ||
    url.startsWith('gs://')
  );
}

function parseFirebaseStoragePath(hlsUrl) {
  try {
    // https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<object>?...
    const apiMatch = hlsUrl.match(/https?:\/\/firebasestorage\.googleapis\.com\/v0\/b\/([^/]+)\/o\/([^?]+)/i);
    if (apiMatch) {
      return { bucket: apiMatch[1], objectPath: decodeURIComponent(apiMatch[2]) };
    }

    // https://storage.googleapis.com/<bucket>/<object>
    const storageMatch = hlsUrl.match(/https?:\/\/storage\.googleapis\.com\/([^/]+)\/(.+)/i);
    if (storageMatch) {
      return { bucket: storageMatch[1], objectPath: decodeURIComponent(storageMatch[2].split('?')[0]) };
    }

    // gs://<bucket>/<object>
    if (hlsUrl.startsWith('gs://')) {
      const withoutScheme = hlsUrl.replace('gs://', '');
      const firstSlash = withoutScheme.indexOf('/');
      if (firstSlash > 0) {
        return {
          bucket: withoutScheme.substring(0, firstSlash),
          objectPath: withoutScheme.substring(firstSlash + 1),
        };
      }
    }
  } catch (err) {
    console.error('Failed to parse Firebase Storage URL', err);
  }
  return null;
}

async function* pagedVideos() {
  let lastId = null;
  while (true) {
    let query = db.collection('videos').orderBy(admin.firestore.FieldPath.documentId()).limit(BATCH_SIZE);
    if (lastId) {
      query = query.startAfter(lastId);
    }
    const snap = await query.get();
    if (snap.empty) break;
    for (const doc of snap.docs) {
      yield doc;
    }
    lastId = snap.docs[snap.docs.length - 1].id;
  }
}

async function main() {
  let checked = 0;
  let skippedCloudinary = 0;
  let missingCount = 0;
  let updated = 0;
  let deleted = 0;
  let unparsable = 0;

  console.log(`Starting legacy HLS cleanup (apply=${APPLY_CHANGES}, delete=${DELETE_DOCS})`);

  for await (const doc of pagedVideos()) {
    checked += 1;
    const data = doc.data();
    const hlsUrl = data.hlsUrl || '';

    if (!hlsUrl || isCloudinary(hlsUrl)) {
      skippedCloudinary += 1;
      continue;
    }

    if (!isFirebaseStorageUrl(hlsUrl)) {
      // Unknown host; treat as unparsable legacy and mark failed if applying.
      unparsable += 1;
      console.warn(`Unrecognized non-Cloudinary URL for ${doc.id}: ${hlsUrl}`);
      if (APPLY_CHANGES && !DELETE_DOCS) {
        await doc.ref.update({
          status: 'failed',
          hlsUrl: '',
          error: 'Legacy HLS URL is not supported; please re-upload.',
          errorCode: 'LEGACY_HLS_UNSUPPORTED',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastErrorAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        updated += 1;
      } else if (APPLY_CHANGES && DELETE_DOCS) {
        await doc.ref.delete();
        deleted += 1;
      }
      continue;
    }

    const parsed = parseFirebaseStoragePath(hlsUrl);
    if (!parsed) {
      unparsable += 1;
      console.warn(`Could not parse Firebase Storage path for ${doc.id}: ${hlsUrl}`);
      if (APPLY_CHANGES && !DELETE_DOCS) {
        await doc.ref.update({
          status: 'failed',
          hlsUrl: '',
          error: 'Legacy HLS URL could not be parsed; please re-upload.',
          errorCode: 'LEGACY_HLS_UNPARSABLE',
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastErrorAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        updated += 1;
      } else if (APPLY_CHANGES && DELETE_DOCS) {
        await doc.ref.delete();
        deleted += 1;
      }
      continue;
    }

    const file = storage.bucket(parsed.bucket).file(parsed.objectPath);
    const [exists] = await file.exists();
    if (exists) {
      continue; // legacy but still present; leave it
    }

    missingCount += 1;
    console.warn(`Missing legacy asset for ${doc.id}: gs://${parsed.bucket}/${parsed.objectPath}`);

    if (!APPLY_CHANGES) {
      continue;
    }

    if (DELETE_DOCS) {
      await doc.ref.delete();
      deleted += 1;
      continue;
    }

    await doc.ref.update({
      status: 'failed',
      hlsUrl: '',
      error: 'Legacy HLS asset is missing; please re-upload.',
      errorCode: 'LEGACY_HLS_MISSING',
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastErrorAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    updated += 1;
  }

  console.log('\nSummary:');
  console.log(`  Checked docs:        ${checked}`);
  console.log(`  Cloudinary/empty:    ${skippedCloudinary}`);
  console.log(`  Unparsable legacy:   ${unparsable}`);
  console.log(`  Missing legacy objs: ${missingCount}`);
  console.log(`  Updated status:      ${updated}`);
  console.log(`  Deleted docs:        ${deleted}`);
  console.log('\nDone.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
