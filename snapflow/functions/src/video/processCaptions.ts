import * as admin from 'firebase-admin';
import { logger } from 'firebase-functions';
import { onRequest, onCall, HttpsError } from 'firebase-functions/v2/https';
import { v2 as cloudinary } from 'cloudinary';
import fetch from 'node-fetch';
import crypto from 'crypto';
import { withPerformanceMonitoring } from '../utils/performance-monitoring';
import { cloudinaryApiSecret, configureCloudinary, inferCloudinaryDeliveryTypeFromUrl } from '../utils/cloudinary';

// Cloudinary webhook handler for auto_transcription completion
export const processCaptions = onRequest({ region: 'us-central1' }, async (req, res) => {
  await withPerformanceMonitoring(async () => {
    if (req.method !== 'POST') {
      res.status(405).send('Method Not Allowed');
      return;
    }

    const signature = req.header('X-Cld-Signature');
    const timestamp = req.header('X-Cld-Timestamp');
    const apiSecret = cloudinaryApiSecret.value();

    const rawBodyBuffer: Buffer | undefined = (req as any).rawBody;
    const rawBody = rawBodyBuffer ? rawBodyBuffer.toString('utf8') : null;

    // Verify Cloudinary webhook signature when possible, but don't block caption processing
    // if the platform doesn't provide rawBody (common misconfiguration).
    if (signature && timestamp && apiSecret && rawBody) {
      const candidates = [
        // Variant used by some Cloudinary notification examples.
        crypto.createHash('sha1').update(`payload=${rawBody}&timestamp=${timestamp}${apiSecret}`).digest('hex'),
        // Fallback variants (different canonicalization).
        crypto.createHash('sha1').update(`${rawBody}${timestamp}${apiSecret}`).digest('hex'),
        crypto.createHash('sha1').update(`payload=${encodeURIComponent(rawBody)}&timestamp=${timestamp}${apiSecret}`).digest('hex'),
      ];

      const matches = candidates.some((expected) => {
        if (expected.length !== signature.length) return false;
        try {
          return crypto.timingSafeEqual(Buffer.from(expected), Buffer.from(signature));
        } catch {
          return false;
        }
      });

      if (!matches) {
        logger.error('Invalid Cloudinary webhook signature', {
          received: signature,
        });
        res.status(401).send('Unauthorized');
        return;
      }
    } else {
      logger.warn('Skipping Cloudinary webhook signature verification (missing inputs)', {
        hasSignature: !!signature,
        hasTimestamp: !!timestamp,
        hasApiSecret: !!apiSecret,
        hasRawBody: !!rawBody,
      });
    }

    const notification = req.body;
    logger.info('Received Cloudinary notification:', notification);

    if (notification.info_kind !== 'auto_transcription') {
      logger.debug('Not an auto_transcription notification, ignoring');
      res.status(200).send('OK');
      return;
    }

    if (notification.info_status !== 'complete') {
      logger.debug('Transcription status is ' + notification.info_status + ', ignoring');
      res.status(200).send('OK');
      return;
    }

    const publicId = notification.public_id as string | undefined;
    if (!publicId) {
      logger.error('No public_id in notification');
      res.status(400).send('Missing public_id');
      return;
    }

    try {
      const { videoId, captionUrl } = await generateCaptionsFromCloudinary(publicId);
      res.status(200).send({ success: true, videoId, captionUrl });
    } catch (error: any) {
      logger.error('Error processing captions:', error);
      res.status(500).send({ error: error.message });
    }
  }, 'processCaptions')();
});

export const retryProcessCaptions = onCall(async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError('unauthenticated', 'Sign-in required');
  }

  const videoId = (request.data?.videoId as string | undefined)?.trim();
  if (!videoId) {
    throw new HttpsError('invalid-argument', 'videoId is required');
  }

  if (!admin.apps.length) {
    admin.initializeApp();
  }

  const doc = await admin.firestore().collection('videos').doc(videoId).get();
  if (!doc.exists) {
    throw new HttpsError('not-found', 'Video not found');
  }

  const data = doc.data() as any;
  const ownerId = data?.ownerId as string | undefined;
  const publicId = data?.cloudinaryPublicId as string | undefined;

  if (!publicId) {
    throw new HttpsError('failed-precondition', 'Cloudinary publicId missing for this video');
  }

  const isAdmin = !!auth.token?.admin;
  const isOwner = ownerId ? ownerId === auth.uid : false;
  if (!isAdmin && !isOwner) {
    throw new HttpsError('permission-denied', 'You are not allowed to retry captions for this video');
  }

  try {
    const { captionUrl } = await generateCaptionsFromCloudinary(publicId, videoId);
    return { success: true, videoId, captionUrl };
  } catch (error: any) {
    logger.error('retryProcessCaptions failed', { videoId, error: error?.message || error });
    throw new HttpsError('internal', error?.message || 'Failed to regenerate captions');
  }
});

async function generateCaptionsFromCloudinary(publicId: string, explicitVideoId?: string) {
  if (!publicId) {
    throw new Error('publicId is required');
  }

  if (!admin.apps.length) {
    admin.initializeApp();
  }
  configureCloudinary();

  const videoId = explicitVideoId ?? extractVideoIdFromPublicId(publicId);
  if (!videoId) {
    throw new Error('Could not determine videoId from public_id');
  }

  logger.info('Processing captions for videoId: ' + videoId + ', publicId: ' + publicId);

  // Determine delivery type from stored hlsUrl when available (backward compatible).
  let deliveryType: 'upload' | 'authenticated' = 'upload';
  try {
    const doc = await admin.firestore().collection('videos').doc(videoId).get();
    const hlsUrl = (doc.data() as any)?.hlsUrl as string | undefined;
    if (hlsUrl) {
      deliveryType = inferCloudinaryDeliveryTypeFromUrl(hlsUrl);
    }
  } catch (_) {
    // Best-effort only.
  }

  // Some accounts deliver transcripts as a raw resource; others expose it under the video resource.
  // Try raw first, then fall back to video if needed.
  const transcriptCandidates = [
    cloudinary.url(publicId, {
      resource_type: 'raw',
      format: 'transcript',
      type: deliveryType,
      sign_url: deliveryType === 'authenticated',
      expires_at: Math.floor(Date.now() / 1000) + 60 * 10,
    } as any),
    cloudinary.url(publicId, {
      resource_type: 'video',
      format: 'transcript',
      type: deliveryType,
      sign_url: deliveryType === 'authenticated',
      expires_at: Math.floor(Date.now() / 1000) + 60 * 10,
    } as any),
  ];

  let transcriptResponse: any | null = null;
  let lastFetchError: string | null = null;
  for (const transcriptUrl of transcriptCandidates) {
    logger.info('Fetching transcript from:', transcriptUrl);
    const res = await fetch(transcriptUrl);
    if (res.ok) {
      transcriptResponse = res;
      break;
    }
    lastFetchError = `${res.status} ${res.statusText}`;
  }

  if (!transcriptResponse) {
    throw new Error('Failed to fetch transcript: ' + (lastFetchError || 'unknown'));
  }

  const transcriptData = (await transcriptResponse.json()) as any;
  logger.info('Transcript data received:', { wordCount: transcriptData.data?.length || 0 });

  const vttContent = convertToVTT(transcriptData);

  const bucket = admin.storage().bucket();
  const vttFilePath = 'captions/' + videoId + '.vtt';
  const file = bucket.file(vttFilePath);

  const downloadToken = crypto.randomUUID();
  await file.save(vttContent, {
    resumable: false,
    metadata: {
      contentType: 'text/vtt',
      cacheControl: 'private, max-age=86400',
      metadata: {
        firebaseStorageDownloadTokens: downloadToken,
      },
    },
  } as any);
  logger.info('VTT file uploaded to Firebase Storage:', vttFilePath);

  const captionUrl =
    'https://firebasestorage.googleapis.com/v0/b/' +
    bucket.name +
    '/o/' +
    encodeURIComponent(vttFilePath) +
    '?alt=media&token=' +
    downloadToken;

  const db = admin.firestore();
  await db.collection('videos').doc(videoId).update({
    captionUrl,
    captionStoragePath: vttFilePath,
    hasCaptions: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  logger.info('Video updated with caption URL:', { videoId, captionUrl });
  return { videoId, captionUrl };
}

function extractVideoIdFromPublicId(publicId: string): string | null {
  if (!publicId) return null;
  const segments = publicId
    .split('/')
    .map((s) => s.trim())
    .filter((s) => s.length > 0);
  if (segments.length === 0) return null;

  // Prefer the last segment if present.
  const last = segments[segments.length - 1];
  if (last.length > 0) return last;

  // Fallback: try the parent segment (folder name).
  if (segments.length >= 2) {
    return segments[segments.length - 2];
  }

  return null;
}
// Convert Cloudinary transcript JSON to WebVTT format
function convertToVTT(transcriptData: any): string {
  const lines: string[] = ['WEBVTT', ''];

  // Extract transcript entries (Cloudinary format has data array with word-level timing)
  const data = transcriptData.data || [];

  if (data.length === 0) {
    logger.warn('Transcript data is empty');
    return lines.join('\n');
  }

  // Group words into subtitle chunks (max 12 words or 3 seconds)
  const maxWordsPerChunk = 12;
  const maxDurationSeconds = 3;
  let currentChunk: any[] = [];
  let chunkIndex = 1;

  for (let i = 0; i < data.length; i++) {
    const word = data[i];
    currentChunk.push(word);

    // Check if we should finalize this chunk
    const shouldFinalize =
      currentChunk.length >= maxWordsPerChunk ||
      i === data.length - 1 ||
      (currentChunk.length > 0 && word.end_time - currentChunk[0].start_time >= maxDurationSeconds);

    if (shouldFinalize) {
      const startTime = currentChunk[0].start_time;
      const endTime = currentChunk[currentChunk.length - 1].end_time;
      const text = currentChunk.map((w) => w.word).join(' ');

      // VTT format: HH:MM:SS.mmm
      const startVTT = formatVTTTime(startTime);
      const endVTT = formatVTTTime(endTime);

      lines.push(String(chunkIndex));
      lines.push(startVTT + ' --> ' + endVTT);
      lines.push(text);
      lines.push('');

      currentChunk = [];
      chunkIndex++;
    }
  }

  return lines.join('\n');
}

// Format seconds to VTT timestamp HH:MM:SS.mmm
function formatVTTTime(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  const secs = Math.floor(seconds % 60);
  const millis = Math.floor((seconds % 1) * 1000);

  return padZero(hours, 2) + ':' + padZero(minutes, 2) + ':' + padZero(secs, 2) + '.' + padZero(millis, 3);
}

function padZero(num: number, length: number): string {
  return num.toString().padStart(length, '0');
}
