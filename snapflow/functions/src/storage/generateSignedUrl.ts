import { onCall, HttpsError } from 'firebase-functions/v2/https';
import * as admin from 'firebase-admin';
import { 
  isCloudinaryUrl, 
  extractPublicIdFromUrl, 
  generateSignedCloudinaryUrl,
  configureCloudinary,
  inferCloudinaryDeliveryTypeFromUrl
} from '../utils/cloudinary';

type LegacyStoragePath = {
  bucket: string;
  objectPath: string;
};

function isFirebaseStorageUrl(url: string): boolean {
  if (!url) return false;
  return url.includes('firebasestorage.googleapis.com') || url.includes('storage.googleapis.com') || url.startsWith('gs://');
}

function parseFirebaseStoragePath(hlsUrl: string): LegacyStoragePath | null {
  try {
    // Pattern 1: https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<object>?...
    const apiMatch = hlsUrl.match(/https?:\/\/firebasestorage\.googleapis\.com\/v0\/b\/([^/]+)\/o\/([^?]+)/i);
    if (apiMatch) {
      const bucket = apiMatch[1];
      const objectPath = decodeURIComponent(apiMatch[2]);
      return { bucket, objectPath };
    }

    // Pattern 2: https://storage.googleapis.com/<bucket>/<object>
    const storageMatch = hlsUrl.match(/https?:\/\/storage\.googleapis\.com\/([^/]+)\/(.+)/i);
    if (storageMatch) {
      const bucket = storageMatch[1];
      const objectPath = decodeURIComponent(storageMatch[2].split('?')[0]);
      return { bucket, objectPath };
    }

    // Pattern 3: gs://<bucket>/<object>
    if (hlsUrl.startsWith('gs://')) {
      const withoutScheme = hlsUrl.replace('gs://', '');
      const firstSlash = withoutScheme.indexOf('/');
      if (firstSlash > 0) {
        const bucket = withoutScheme.substring(0, firstSlash);
        const objectPath = withoutScheme.substring(firstSlash + 1);
        return { bucket, objectPath };
      }
    }
  } catch (err) {
    console.error('Failed to parse Firebase Storage URL', err);
  }
  return null;
}

/**
 * Generate signed URL for private video access
 * 
 * This function provides time-limited access to private videos by generating
 * signed URLs that expire after 1 hour. Access control is enforced based on
 * video privacy settings and follower relationships.
 * 
 * Privacy rules:
 * - public: No signed URL needed (direct access)
 * - private: Only video owner can access
 * - followers-only: Owner and followers can access
 */
export const generateSignedUrl = onCall(async (request) => {
  if (!admin.apps.length) {
    admin.initializeApp();
  }
  // Validate authentication
  if (!request.auth) {
    throw new HttpsError(
      'unauthenticated',
      'User must be authenticated to request signed URLs'
    );
  }

  const { videoId } = request.data;
  const userId = request.auth.uid;

  // Validate input
  if (!videoId || typeof videoId !== 'string') {
    throw new HttpsError(
      'invalid-argument',
      'videoId is required and must be a string'
    );
  }

  try {
    // Get video document
    const videoDoc = await admin.firestore()
      .collection('videos')
      .doc(videoId)
      .get();

    if (!videoDoc.exists) {
      throw new HttpsError(
        'not-found',
        `Video with ID ${videoId} not found`
      );
    }

    const videoData = videoDoc.data()!;
    const isAdmin = request.auth?.token?.admin === true;

    // Check if video requires signed URL
    if (videoData.privacy === 'public') {
      // Public videos don't need signed URLs
      return {
        signedUrl: videoData.hlsUrl,
        expiresAt: null,
        message: 'Public video - no signed URL needed'
      };
    }

    // Enforce access control for private/followers-only videos
    const isOwner = videoData.ownerId === userId;

    if (videoData.privacy === 'private') {
      // Only owner can access private videos
      if (!isOwner && !isAdmin) {
        throw new HttpsError(
          'permission-denied',
          'Only the video owner can access private videos'
        );
      }
    } else if (videoData.privacy === 'followers-only') {
      // Owner and followers can access
      if (!isOwner && !isAdmin) {
        // Check if user is following the video owner
        const followDoc = await admin.firestore()
          .collection('users')
          .doc(videoData.ownerId)
          .collection('followers')
          .doc(userId)
          .get();

        if (!followDoc.exists) {
          throw new HttpsError(
            'permission-denied',
            'You must follow the user to view this video'
          );
        }
      }
    }

    // Generate signed URL with 1 hour expiration (only needed for truly private videos).
    const hlsUrl = videoData.hlsUrl;
    
    // Check if URL is from Cloudinary or Firebase Storage
    if (isCloudinaryUrl(hlsUrl)) {
      // Handle Cloudinary URLs
      try {
        // Prefer stored delivery type; otherwise infer from URL for backward compatibility.
        // (New deployments default to 'upload' for private videos to avoid HLS segment auth issues.)
        const stored = (videoData.cloudinaryDeliveryType as string | undefined)?.toLowerCase();
        const deliveryType: 'upload' | 'authenticated' =
          stored === 'authenticated' || stored === 'upload'
            ? (stored as any)
            : inferCloudinaryDeliveryTypeFromUrl(hlsUrl);
        // Prefer publicId from Firestore document if available
        let publicId = videoData.cloudinaryPublicId;
        
        // Fallback: extract publicId from URL
        if (!publicId) {
          publicId = extractPublicIdFromUrl(hlsUrl);
          if (!publicId) {
            throw new Error('Could not extract publicId from Cloudinary URL');
          }
        }
        
        // Generate Cloudinary signed URL with 1 hour expiration
        const signedUrl = generateSignedCloudinaryUrl(publicId, 3600, deliveryType);
        const expirationTime = Date.now() + 3600 * 1000; // 1 hour from now
        
        console.log(`Generated Cloudinary signed URL for video ${videoId}, user ${userId}, publicId ${publicId}, expires at ${new Date(expirationTime).toISOString()}`);
        
        return {
          signedUrl,
          expiresAt: expirationTime,
          message: 'Cloudinary signed URL generated successfully'
        };
      } catch (cloudinaryError: any) {
        console.error('Error generating Cloudinary signed URL:', cloudinaryError);
        throw new HttpsError(
          'internal',
          `Failed to generate Cloudinary signed URL: ${cloudinaryError.message}`
        );
      }
    }

    // Legacy Flow A (Firebase Storage) fallback
    if (isFirebaseStorageUrl(hlsUrl)) {
      const parsed = parseFirebaseStoragePath(hlsUrl);
      if (!parsed) {
        console.error(`Could not parse Firebase Storage path from legacy URL for video ${videoId}: ${hlsUrl}`);
        throw new HttpsError(
          'failed-precondition',
          'Legacy Firebase Storage URL could not be parsed for signing.'
        );
      }

      try {
        const legacyBucket = admin.storage().bucket(parsed.bucket);
        const [signedUrl] = await legacyBucket.file(parsed.objectPath).getSignedUrl({
          version: 'v4',
          action: 'read',
          expires: Date.now() + 3600 * 1000, // 1 hour
        });

        console.log(`Generated legacy Firebase Storage signed URL for video ${videoId}, bucket ${parsed.bucket}, object ${parsed.objectPath}`);

        return {
          signedUrl,
          expiresAt: Date.now() + 3600 * 1000,
          message: 'Legacy Firebase Storage signed URL generated successfully'
        };
      } catch (storageError: any) {
        console.error('Error generating Firebase Storage signed URL:', storageError);
        throw new HttpsError(
          'internal',
          `Failed to generate legacy Firebase Storage signed URL: ${storageError.message}`
        );
      }
    }

    // Flow B only: if we reach here, the HLS URL is not a Cloudinary or Firebase Storage asset
    console.error(`Unexpected non-Cloudinary HLS URL for video ${videoId}: ${hlsUrl}`);
    throw new HttpsError(
      'failed-precondition',
      'HLS URL is not hosted on a supported backend. Check video processing configuration.'
    );

  } catch (error: any) {
    // Re-throw HttpsErrors as-is
    if (error instanceof HttpsError) {
      throw error;
    }

    // Log unexpected errors
    console.error('Error generating signed URL:', error);
    throw new HttpsError(
      'internal',
      `Failed to generate signed URL: ${error.message}`
    );
  }
});
