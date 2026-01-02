import * as admin from 'firebase-admin';
import { updateVideoStatus } from '../utils/firestore-helpers';
import { uploadVideoToCloudinary } from '../utils/cloudinary';
import { withPerformanceMonitoring } from '../utils/performance-monitoring';
import { checkRateLimit } from '../utils/rate-limiter';

import { logger } from 'firebase-functions';
import { CloudEvent } from 'firebase-functions/v2';
import { onObjectFinalized, StorageObjectData } from 'firebase-functions/v2/storage';
import { onCall, HttpsError } from 'firebase-functions/v2/https';

// Prefer the bucket from FIREBASE_CONFIG (recommended) else fall back to common Firebase defaults.
const firebaseConfig = process.env.FIREBASE_CONFIG ? JSON.parse(process.env.FIREBASE_CONFIG) : {};
const storageBucketFromConfig: string | undefined = firebaseConfig.storageBucket;
const projectId = process.env.GCLOUD_PROJECT || firebaseConfig.projectId;
// Newer Firebase projects often use "<projectId>.firebasestorage.app" (not appspot.com).
const defaultBucket =
  storageBucketFromConfig ||
  (projectId ? `${projectId}.firebasestorage.app` : undefined) ||
  (projectId ? `${projectId}.appspot.com` : undefined);

// Validate bucket configuration early to avoid runtime crashes during deploy/startup
const resolvedBucket = defaultBucket;
if (!resolvedBucket) {
  throw new Error(
    'Firebase Storage bucket is not configured. Set storageBucket in FIREBASE_CONFIG or provide GCLOUD_PROJECT.'
  );
}

type CloudinaryErrorInfo = {
  userMessage: string;
  errorCode: string;
  retryable: boolean;
};

type VideoProcessingNotificationStatus = 'ready' | 'failed';

async function createVideoProcessingNotification(params: {
  ownerId: string;
  videoId: string;
  status: VideoProcessingNotificationStatus;
  videoTitle?: string | null;
  error?: string | null;
}): Promise<void> {
  const { ownerId, videoId, status, videoTitle, error } = params;
  if (!ownerId || !videoId) return;

  const safeTitle = (videoTitle || '').toString().trim();
  const title =
    status === 'ready' ? 'Video ready' : 'Video processing failed';
  const body =
    status === 'ready'
      ? safeTitle
        ? `Your video "${safeTitle}" is ready to watch.`
        : 'Your video is ready to watch.'
      : safeTitle
        ? `Your video "${safeTitle}" failed to process. Tap to retry.`
        : 'Your video failed to process. Tap to retry.';

  const db = admin.firestore();
  await db
    .collection('users')
    .doc(ownerId)
    .collection('notifications')
    .add({
      type: 'video',
      actorUserId: 'system',
      videoId,
      title,
      body,
      read: false,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      payload: {
        route: 'video',
        videoId,
        status,
        ...(status === 'failed' && error ? { error } : {}),
      },
    });
}

function extractFirebaseDownloadToken(metadata: Record<string, unknown> | undefined | null): string | null {
  if (!metadata) return null;
  const raw = (metadata as any).firebaseStorageDownloadTokens ?? (metadata as any)['firebaseStorageDownloadTokens'];
  if (!raw) return null;
  const token = String(raw)
    .split(',')
    .map((s) => s.trim())
    .find((s) => s.length > 0);
  return token || null;
}

function buildFirebaseDownloadUrl(bucketName: string, objectPath: string, token: string): string {
  return (
    'https://firebasestorage.googleapis.com/v0/b/' +
    bucketName +
    '/o/' +
    encodeURIComponent(objectPath) +
    '?alt=media&token=' +
    encodeURIComponent(token)
  );
}

async function resolveReadableRawVideoUrl(
  bucket: any,
  bucketName: string,
  objectPath: string,
  objectMetadata?: Record<string, unknown> | null
): Promise<string> {
  const tokenFromEvent = extractFirebaseDownloadToken(objectMetadata || undefined);
  if (tokenFromEvent) {
    return buildFirebaseDownloadUrl(bucketName, objectPath, tokenFromEvent);
  }

  // Try to derive the token from file metadata (Firebase uploads usually set it automatically).
  try {
    const [meta] = await bucket.file(objectPath).getMetadata();
    const tokenFromMeta = extractFirebaseDownloadToken((meta as any)?.metadata);
    if (tokenFromMeta) {
      return buildFirebaseDownloadUrl(bucketName, objectPath, tokenFromMeta);
    }
  } catch (err: any) {
    logger.warn('Failed to read object metadata for download token; will fall back', {
      bucketName,
      objectPath,
      error: err?.message || String(err),
    });
  }

  // Fall back to a short-lived signed URL. Some 2nd-gen runtimes may lack signBlob permission,
  // so keep this as a last resort.
  const [signedUrl] = await bucket.file(objectPath).getSignedUrl({
    version: 'v4',
    action: 'read',
    expires: Date.now() + 30 * 60 * 1000, // 30 minutes
  });
  return signedUrl;
}

function interpretCloudinaryError(error: any): CloudinaryErrorInfo | null {
  const httpCode = error?.http_code ?? error?.error?.http_code ?? error?.statusCode;
  const rawMessage = (error?.error?.message || error?.message || '').toString();
  const normalizedMessage = rawMessage.toLowerCase();
  const name = String(error?.name || '').toLowerCase();
  const looksCloudinary = Boolean(httpCode) || normalizedMessage.includes('cloudinary') || name.includes('cloudinary');
  if (!looksCloudinary) {
    return null;
  }

  const build = (userMessage: string, errorCode: string, retryable: boolean): CloudinaryErrorInfo => ({
    userMessage,
    errorCode,
    retryable,
  });

  if (httpCode === 429 || normalizedMessage.includes('rate limit') || normalizedMessage.includes('too many requests')) {
    return build(
      'Video uploads are temporarily rate limited. Please retry in a few minutes.',
      'CLOUDINARY_RATE_LIMIT',
      true
    );
  }

  if (httpCode === 400 && (normalizedMessage.includes('too large') || normalizedMessage.includes('file size'))) {
    return build('Video file is too large. Try uploading a shorter clip.', 'CLOUDINARY_FILE_TOO_LARGE', false);
  }

  if (
    httpCode === 400 &&
    (normalizedMessage.includes('unsupported') ||
      normalizedMessage.includes('invalid video') ||
      normalizedMessage.includes('format not supported'))
  ) {
    return build('Unsupported video format. Please upload an MP4 or MOV file.', 'CLOUDINARY_UNSUPPORTED_FORMAT', false);
  }

  if (
    httpCode === 401 ||
    httpCode === 403 ||
    normalizedMessage.includes('invalid credential') ||
    normalizedMessage.includes('invalid signature')
  ) {
    return build(
      'Video processing credentials are invalid. Please contact support.',
      'CLOUDINARY_AUTH_FAILURE',
      false
    );
  }

  if (httpCode && httpCode >= 500) {
    return build('Cloudinary is temporarily unavailable. Please retry shortly.', 'CLOUDINARY_UNAVAILABLE', true);
  }

  if (normalizedMessage.includes('timeout')) {
    return build('Cloudinary timed out while processing the video. Please retry.', 'CLOUDINARY_TIMEOUT', true);
  }

  return build(
    'Video processing failed due to a Cloudinary error. Please try again later.',
    `CLOUDINARY_${httpCode ?? 'ERROR'}`,
    true
  );
}

// Storage trigger for raw video uploads: raw-videos/{userId}/{videoId}.<ext>
export const processVideoUpload = onObjectFinalized(
  { bucket: resolvedBucket, region: 'us-central1', timeoutSeconds: 540, memory: '1GiB' },
  async (event: CloudEvent<StorageObjectData>) => {
  const object = event.data;
  const filePath = object.name ?? '';
  const contentType = object.contentType ?? '';

  if (!filePath) {
    logger.warn('No object.name provided, skipping');
    return;
  }

  // Only handle raw video uploads
  if (!filePath.startsWith('raw-videos/')) {
    logger.debug(`Ignoring non-raw video path: ${filePath}`);
    return;
  }

  // Validate it's a video MIME
  if (!contentType.startsWith('video/')) {
    logger.debug(`Ignoring non-video contentType: ${contentType}`);
    return;
  }

  // Parse userId and videoId from path raw-videos/{userId}/{videoId}.ext
  const segments = filePath.split('/');
  if (segments.length < 3) {
    logger.warn(`Unexpected raw video path: ${filePath}`);
    return;
  }
  const userId = segments[1];
  const filename = segments[2];
  const videoId = filename.split('.')[0];

  const maxAttempts = 3;
  const baseDelayMs = 1500; // simple exponential backoff base
  let attempt = 0;

  // Ensure Admin initialized before using any admin.* service.
  // BUGFIX: previously admin.storage().bucket(...) was called before initializeApp() on cold starts,
  // causing the trigger to crash immediately and leaving videos stuck in "processing".
  if (!admin.apps.length) {
    admin.initializeApp();
  }

  const bucketName = object.bucket;
  if (!bucketName) {
    logger.error('Storage event missing bucket name; cannot process upload', { filePath });
    return;
  }
  const bucket = admin.storage().bucket(bucketName);

  // Populated opportunistically from Firestore when available; used for notifications.
  let videoTitle: string | null = null;

  const run = withPerformanceMonitoring(async () => {
    const db = admin.firestore();

    // Resolve privacy from upload metadata first (fixes race when Firestore doc isn't written yet)
    const normalizePrivacy = (value?: string | null): string | undefined => {
      if (!value) return undefined;
      const normalized = value.toString().trim().toLowerCase();
      if (['public', 'private', 'followers-only'].includes(normalized)) {
        return normalized;
      }
      return undefined;
    };

    const metadata = object.metadata || {};
    // Custom metadata keys may come through in lowercase or the x-goog-meta- prefix; check both
    let privacy: string | undefined =
      normalizePrivacy((metadata as any)?.privacy) ||
      normalizePrivacy((metadata as any)['x-goog-meta-privacy']);

    if (!privacy) {
      try {
        const videoDoc = await db.collection('videos').doc(videoId).get();
        if (videoDoc.exists) {
          const data = videoDoc.data() as any;
          privacy = normalizePrivacy(data?.privacy);
          videoTitle = (data?.title as string | undefined) ?? null;
        } else {
          logger.warn(`Video document not found for ${videoId} before processing; defaulting to public`);
        }
      } catch (err: any) {
        logger.warn(`Could not read video privacy for ${videoId}; defaulting to public`, err);
      }
    }

    if (!privacy) {
      privacy = 'public';
    }

    // Check rate limit before processing
    const rateLimitResult = await checkRateLimit(userId, 'upload');
    if (!rateLimitResult.allowed) {
      logger.warn('Rate limit exceeded', {
        userId,
        action: 'upload',
        remaining: rateLimitResult.remaining,
        resetAt: rateLimitResult.resetAt,
        retryAfter: rateLimitResult.retryAfterSeconds,
      });

      // CRITICAL SECURITY FIX: Delete the rejected file from Storage to prevent bucket abuse
      // Without this, attackers can fill the bucket with rate-limited uploads
      const bucketName = object.bucket!;
      const bucket = admin.storage().bucket(bucketName);
      try {
        await bucket.file(filePath).delete();
        logger.info('Deleted rate-limited upload from Storage', {
          userId,
          videoId,
          filePath,
          reason: 'rate_limit_exceeded',
        });
      } catch (deleteError: any) {
        // Log error but continue with status update even if delete fails
        // This prevents blocking legitimate rate limit enforcement
        logger.error('Failed to delete rate-limited file from Storage', {
          filePath,
          userId,
          videoId,
          error: deleteError?.message || String(deleteError),
        });
      }

      // Format retry message with proper singular/plural
      const retrySeconds = rateLimitResult.retryAfterSeconds || 0;
      let retryMessage: string;

      if (retrySeconds > 60) {
        const minutes = Math.ceil(retrySeconds / 60);
        retryMessage = `${minutes} ${minutes === 1 ? 'minute' : 'minutes'}`;
      } else {
        retryMessage = `${retrySeconds} ${retrySeconds === 1 ? 'second' : 'seconds'}`;
      }

      await updateVideoStatus(videoId, {
        status: 'failed',
        error: `Rate limit exceeded. You can upload ${retryMessage} from now.`,
        errorCode: 'RATE_LIMIT_EXCEEDED',
      });
      return;
    }

    // Update Firestore status to processing as per spec (8.4)
    await updateVideoStatus(videoId, {
      status: 'processing',
      rawVideoStoragePath: filePath,
      rawVideoBucket: bucketName,
    } as any);

    // Prefer Firebase download-token URLs for Cloudinary pull uploads (works well in gen2 without signBlob).
    const readableUrl = await resolveReadableRawVideoUrl(
      bucket,
      bucketName,
      filePath,
      (object.metadata as any) || null
    );

    // Integrate Cloudinary SDK (8.5): start upload (HLS eager transform handled in util)
    const startedAt = Date.now();
    const result = await uploadVideoToCloudinary(readableUrl, videoId, privacy);
    const processingDurationMs = Date.now() - startedAt;
    logger.info('Cloudinary upload started/completed', {
      publicId: result.publicId,
      hlsUrl: result.hlsUrl,
      thumbnailUrl: result.thumbnailUrl,
      duration: result.duration,
    });
    // Step 8.6–8.7: Write processed details to Firestore and mark ready
    await updateVideoStatus(videoId, {
      hlsUrl: result.hlsUrl ?? null,
      thumbnailUrl: result.thumbnailUrl ?? null,
      durationSeconds: typeof result.duration === 'number' ? Math.round(result.duration) : null,
      status: 'ready',
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
      error: null,
      errorCode: null,
      lastErrorAt: null,
      processingDurationMs,
      cloudinaryPublicId: result.publicId ?? null,
      cloudinaryDeliveryType: result.deliveryType ?? 'upload',
    } as any);

    try {
      await createVideoProcessingNotification({
        ownerId: userId,
        videoId,
        status: 'ready',
        videoTitle,
      });
    } catch (notifyErr: any) {
      logger.warn('Failed to create video ready notification', {
        videoId,
        userId,
        error: notifyErr?.message || String(notifyErr),
      });
    }

    // Delete raw video once processing succeeds to avoid unbounded storage usage
    try {
      await bucket.file(filePath).delete();
      logger.info('Deleted raw video after successful processing', { filePath, videoId });
    } catch (deleteErr: any) {
      logger.warn('Failed to delete raw video after processing', {
        filePath,
        videoId,
        error: deleteErr?.message || String(deleteErr),
      });
    }

  }, 'processVideoUpload');

  while (attempt < maxAttempts) {
    try {
      await run();
      return; // success
    } catch (error: any) {
      attempt += 1;
      const errMsg = error?.message || String(error);
      const errCode = error?.code || error?.name || 'UNKNOWN';
      const cloudinaryDetails = interpretCloudinaryError(error);
      const isNonRetryable = cloudinaryDetails && !cloudinaryDetails.retryable;
      const userFacingMessage = cloudinaryDetails?.userMessage ?? errMsg;
      const userFacingCode = cloudinaryDetails?.errorCode ?? errCode;
      logger.error(`processVideoUpload attempt ${attempt} failed for ${videoId}`, error as any);
      // Update error fields for observability (8.8)
      try {
        await updateVideoStatus(videoId, {
          status: attempt >= maxAttempts ? 'failed' : 'processing',
          error: userFacingMessage,
          errorCode: userFacingCode,
          lastErrorAt: admin.firestore.FieldValue.serverTimestamp(),
        } as any);
      } catch { }

      if (isNonRetryable) {
        attempt = maxAttempts;
      }

      if (attempt >= maxAttempts) {
        try {
          await createVideoProcessingNotification({
            ownerId: userId,
            videoId,
            status: 'failed',
            videoTitle,
            error: userFacingMessage,
          });
        } catch (notifyErr: any) {
          logger.warn('Failed to create video failed notification', {
            videoId,
            userId,
            error: notifyErr?.message || String(notifyErr),
          });
        }

        // Clean up raw file immediately for non-retryable failures
        if (isNonRetryable) {
          try {
            await bucket.file(filePath).delete();
            logger.info('Deleted raw video after non-retryable failure', { filePath, videoId });
          } catch (deleteErr: any) {
            logger.warn('Failed to delete raw video after non-retryable failure', {
              filePath,
              videoId,
              error: deleteErr?.message || String(deleteErr),
            });
          }
        }
        break;
      }
      const delay = baseDelayMs * Math.pow(2, attempt - 1);
      await new Promise((res) => setTimeout(res, delay));
    }
  }
});

// Callable to retry processing for a given videoId by reading rawVideoStoragePath and re-enqueuing work inline.
export const retryProcessVideo = onCall({ region: 'us-central1', timeoutSeconds: 540, memory: '1GiB' }, async (request) => {
  return withPerformanceMonitoring(async () => {
    const auth = request.auth;
    const data = request.data as any;
    if (!auth) {
      throw new HttpsError('unauthenticated', 'Sign-in required');
    }
    const videoId = (data?.videoId as string | undefined)?.trim();
    if (!videoId) {
      throw new HttpsError('invalid-argument', 'videoId required');
    }

    if (!admin.apps.length) admin.initializeApp();
    const db = admin.firestore();
    const doc = await db.collection('videos').doc(videoId).get();
    if (!doc.exists) {
      throw new HttpsError('not-found', 'Video not found');
    }
    const dataMap = doc.data() as any;
    const ownerId = dataMap?.ownerId as string | undefined;
    const videoTitle = (dataMap?.title as string | undefined) ?? null;
    const rawPath = dataMap?.rawVideoStoragePath as string | undefined;
    const privacy = dataMap?.privacy as string | undefined;
    const rawBucket = dataMap?.rawVideoBucket as string | undefined;
    const rawVideoUrl = dataMap?.rawVideoUrl as string | undefined;
    if (!ownerId || !rawPath) {
      throw new HttpsError('failed-precondition', 'Missing raw video path');
    }
    // Only owner or admin can retry
    const isAdmin = !!auth.token?.admin;
    if (!isAdmin && auth.uid !== ownerId) {
      throw new HttpsError('permission-denied', 'Not allowed');
    }

    // Prepare: set status back to processing and clear error fields
    await updateVideoStatus(videoId, {
      status: 'processing',
      error: null,
      errorCode: null,
      lastErrorAt: null,
    } as any);

    // Read file from bucket and process using the same helper flow
    // Determine bucket for retries (prefer stored bucket; fallback to parsing rawVideoUrl).
    let resolvedRawBucket = rawBucket;
    if (!resolvedRawBucket && rawVideoUrl) {
      const match = rawVideoUrl.match(/https?:\/\/firebasestorage\.googleapis\.com\/v0\/b\/([^/]+)\/o\//i);
      if (match && match[1]) {
        resolvedRawBucket = match[1];
      }
    }
    const bucket = resolvedRawBucket ? admin.storage().bucket(resolvedRawBucket) : admin.storage().bucket();

    // Check if raw video file still exists before attempting processing
    const file = bucket.file(rawPath);
    const [exists] = await file.exists();
    if (!exists) {
      logger.error('Raw video file no longer exists for retry', {
        videoId,
        rawPath,
        userId: auth.uid,
      });

      const userFacingMessage = 'Raw video file no longer exists. Cannot retry processing. Please re-upload the video.';
      await updateVideoStatus(videoId, {
        status: 'failed',
        error: userFacingMessage,
        errorCode: 'RAW_FILE_DELETED',
        lastErrorAt: admin.firestore.FieldValue.serverTimestamp(),
      } as any);

      try {
        await createVideoProcessingNotification({
          ownerId,
          videoId,
          status: 'failed',
          videoTitle,
          error: userFacingMessage,
        });
      } catch (notifyErr: any) {
        logger.warn('Failed to create video failed notification (raw missing)', {
          videoId,
          ownerId,
          error: notifyErr?.message || String(notifyErr),
        });
      }

      throw new HttpsError(
        'failed-precondition',
        userFacingMessage
      );
    }

    // Prefer the existing Firebase download URL (has token) when available.
    // This avoids gen2 signBlob permission issues with GCS signed URLs.
    let readableUrl: string;
    if (rawVideoUrl && rawVideoUrl.includes('firebasestorage.googleapis.com') && rawVideoUrl.includes('token=')) {
      readableUrl = rawVideoUrl;
    } else {
      readableUrl = await resolveReadableRawVideoUrl(bucket, bucket.name, rawPath, null);
    }

    const startedAt = Date.now();
    try {
      const result = await uploadVideoToCloudinary(readableUrl, videoId, privacy);
      const processingDurationMs = Date.now() - startedAt;
      await updateVideoStatus(videoId, {
        hlsUrl: result.hlsUrl ?? null,
        thumbnailUrl: result.thumbnailUrl ?? null,
        durationSeconds: typeof result.duration === 'number' ? Math.round(result.duration) : null,
        status: 'ready',
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        error: null,
        errorCode: null,
        lastErrorAt: null,
        processingDurationMs,
        cloudinaryPublicId: result.publicId ?? null,
        cloudinaryDeliveryType: result.deliveryType ?? 'upload',
      } as any);

      try {
        await createVideoProcessingNotification({
          ownerId,
          videoId,
          status: 'ready',
          videoTitle,
        });
      } catch (notifyErr: any) {
        logger.warn('Failed to create video ready notification (retry)', {
          videoId,
          ownerId,
          error: notifyErr?.message || String(notifyErr),
        });
      }
      try {
        await bucket.file(rawPath).delete();
        logger.info('Deleted raw video after retry processing', { rawPath, videoId });
      } catch (cleanupErr: any) {
        logger.warn('Failed to delete raw video after retry processing', {
          rawPath,
          videoId,
          error: cleanupErr?.message || String(cleanupErr),
        });
      }
    } catch (err: any) {
      const cloudinaryDetails = interpretCloudinaryError(err);
      const userFacingMessage = cloudinaryDetails?.userMessage || err?.message || String(err);
      const userFacingCode = cloudinaryDetails?.errorCode || err?.code || err?.name || 'UNKNOWN';
      await updateVideoStatus(videoId, {
        status: 'failed',
        error: userFacingMessage,
        errorCode: userFacingCode,
        lastErrorAt: admin.firestore.FieldValue.serverTimestamp(),
      } as any);

      try {
        await createVideoProcessingNotification({
          ownerId,
          videoId,
          status: 'failed',
          videoTitle,
          error: userFacingMessage,
        });
      } catch (notifyErr: any) {
        logger.warn('Failed to create video failed notification (retry)', {
          videoId,
          ownerId,
          error: notifyErr?.message || String(notifyErr),
        });
      }
      throw new HttpsError('internal', userFacingMessage, { errorCode: userFacingCode });
    }

    return { success: true };
  }, 'retryProcessVideo')();
});
