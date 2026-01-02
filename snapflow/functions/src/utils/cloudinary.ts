import { v2 as cloudinary } from 'cloudinary';
import { defineString } from 'firebase-functions/params';

// Define Cloudinary credentials as Firebase Functions parameters
// Values come from .env file during deployment or firebase.json env config
export const cloudinaryCloudName = defineString('CLOUDINARY_CLOUD_NAME');
export const cloudinaryApiKey = defineString('CLOUDINARY_API_KEY');
export const cloudinaryApiSecret = defineString('CLOUDINARY_API_SECRET');
export const cloudinaryPrivateDelivery = defineString('CLOUDINARY_PRIVATE_DELIVERY', {
  default: 'upload',
  description:
    "Delivery type for privacy='private'. Use 'upload' for reliable HLS playback; 'authenticated' can require segment-level signing depending on player/CDN.",
});
export const cloudinaryNotificationUrlParam = defineString('CLOUDINARY_NOTIFICATION_URL', {
  default: '',
  description: 'Absolute HTTPS endpoint Cloudinary should call for auto_transcription events.',
});

export type CloudinaryUploadResult = {
  hlsUrl?: string;
  thumbnailUrl?: string;
  duration?: number; // seconds
  publicId?: string;
  deliveryType?: 'upload' | 'authenticated';
};

let configured = false;
const firebaseConfig = process.env.FIREBASE_CONFIG ? JSON.parse(process.env.FIREBASE_CONFIG) : {};

function resolveCloudinaryNotificationUrl(): string {
  const configuredUrl = cloudinaryNotificationUrlParam.value()?.trim();
  if (configuredUrl) {
    return configuredUrl;
  }
  const projectId = process.env.GCLOUD_PROJECT || firebaseConfig.projectId;
  const region = firebaseConfig.locationId || 'us-central1';
  if (!projectId) {
    throw new Error(
      'CLOUDINARY_NOTIFICATION_URL not set and project ID is unavailable. Set the env parameter in .env.'
    );
  }
  return `https://${region}-${projectId}.cloudfunctions.net/processCaptions`;
}

export function configureCloudinary() {
  if (configured) return;
  
  // Get values from Firebase Functions v2 parameters
  const cloudName = cloudinaryCloudName.value();
  const apiKey = cloudinaryApiKey.value();
  const apiSecret = cloudinaryApiSecret.value();

  if (!cloudName || !apiKey || !apiSecret) {
    throw new Error(
      'Cloudinary credentials not set. Check .env file in functions directory.'
    );
  }

  cloudinary.config({
    cloud_name: cloudName,
    api_key: apiKey,
    api_secret: apiSecret,
    secure: true,
  });
  configured = true;
}

export function resolveCloudinaryDeliveryTypeForPrivacy(privacy?: string): 'upload' | 'authenticated' {
  const normalized = (privacy || '').trim().toLowerCase();
  if (normalized !== 'private') return 'upload';

  const configured = (cloudinaryPrivateDelivery.value() || '').trim().toLowerCase();
  return configured === 'authenticated' ? 'authenticated' : 'upload';
}

export function inferCloudinaryDeliveryTypeFromUrl(url: string | undefined | null): 'upload' | 'authenticated' {
  const u = (url || '').toString();
  // Cloudinary authenticated delivery URLs contain "/authenticated/" in the delivery type segment.
  return u.includes('/authenticated/') ? 'authenticated' : 'upload';
}

export async function uploadVideoToCloudinary(
  filePathOrUrl: string,
  videoId: string,
  privacy?: string
): Promise<CloudinaryUploadResult> {
  configureCloudinary();

  // "followers-only" access is enforced at the Firestore / API layer, so it uses standard delivery.
  // For "private", authenticated delivery is optional; default is "upload" for reliable HLS playback.
  const deliveryType = resolveCloudinaryDeliveryTypeForPrivacy(privacy);
  const accessMode = deliveryType === 'authenticated' ? 'authenticated' : 'public';
  const notificationUrl = resolveCloudinaryNotificationUrl();
  // Use a deterministic public_id so downstream webhooks can derive the Firestore videoId.
  // We include the videoId in both folder and filename to avoid collisions when unique_filename is true by default.
  // Example: snapflow/processed/<videoId>/<videoId>
  // Perform eager transformation to HLS and generate a poster frame
  // Note: streaming_profile must be the ONLY directive in the transformation
  const upload = await cloudinary.uploader.upload(filePathOrUrl, {
    resource_type: 'video',
    folder: `snapflow/processed/${videoId}`,
    public_id: videoId,
    type: deliveryType,
    access_mode: accessMode,
    eager: [
      {
        format: 'm3u8',
        streaming_profile: 'hd',
      },
      {
        format: 'jpg',
        transformation: [{ start_offset: '1' }, { width: 640, height: 360, crop: 'fill' }],
      },
    ],
    eager_async: false, // synchronous to simplify MVP
    // Enable auto-transcription for captions
    auto_transcription: true,
    // Webhook URL for caption processing completion
    notification_url: notificationUrl,
  } as any);

  const publicId = upload.public_id as string;

  // Build HLS and thumbnail URLs
  const hlsUrl = cloudinary.url(publicId, {
    resource_type: 'video',
    format: 'm3u8',
    type: deliveryType,
  });

  const thumbnailUrl = cloudinary.url(publicId, {
    resource_type: 'video',
    format: 'jpg',
    type: deliveryType,
    transformation: [{ start_offset: '1' }, { width: 640, height: 360, crop: 'fill' }],
  });

  const duration = (upload as any).duration as number | undefined;

  return { hlsUrl, thumbnailUrl, duration, publicId, deliveryType };
}

/**
 * Detects if a given URL is a Cloudinary URL
 * @param url - The URL to check
 * @returns true if the URL is a Cloudinary URL, false otherwise
 */
export function isCloudinaryUrl(url: string): boolean {
  if (!url) return false;
  
  const cloudName = process.env.CLOUDINARY_CLOUD_NAME;
  
  // Check for standard Cloudinary domain or the specific cloud name
  return url.includes('res.cloudinary.com') || 
         (cloudName ? url.includes(cloudName) : false);
}

/**
 * Extracts the publicId from a Cloudinary URL
 * Handles various URL formats with or without transformations
 * @param url - The Cloudinary URL
 * @returns The extracted publicId or null if extraction fails
 */
export function extractPublicIdFromUrl(url: string): string | null {
  if (!url || !isCloudinaryUrl(url)) return null;
  
  try {
    // Pattern: https://res.cloudinary.com/{cloud_name}/{resource_type}/upload/{version}/{transformations}/{public_id}.{format}
    // Or: https://res.cloudinary.com/{cloud_name}/{resource_type}/upload/{transformations}/{public_id}.{format}
    
    const uploadIndex = url.indexOf('/upload/');
    if (uploadIndex === -1) return null;
    
    // Get everything after '/upload/'
    const afterUpload = url.substring(uploadIndex + 8);
    
    // Remove query parameters if present
    const urlWithoutParams = afterUpload.split('?')[0];
    
    // Split by '/' to handle paths
    const parts = urlWithoutParams.split('/');
    
    if (parts.length === 0 || urlWithoutParams.trim() === '') return null;
    
    // Find the last part (should be the filename with extension)
    const lastPart = parts[parts.length - 1];
    
    if (!lastPart || lastPart.trim() === '') return null;
    
    // Remove the file extension (only the last extension)
    const lastDotIndex = lastPart.lastIndexOf('.');
    const withoutExtension = lastDotIndex > 0 ? lastPart.substring(0, lastDotIndex) : lastPart;
    
    // If there are multiple parts, reconstruct the path (handles folders)
    if (parts.length > 1) {
      // Skip version if present (starts with 'v' followed by numbers)
      let startIndex = 0;
      if (parts[0].match(/^v\d+$/)) {
        startIndex = 1;
      }
      
      // Skip transformations (contain commas or underscores like w_640,h_360,c_fill)
      while (startIndex < parts.length - 1) {
        const part = parts[startIndex];
        // Check if this is a transformation (contains underscores and commas)
        if (part.includes('_') && (part.includes(',') || part.match(/^[a-z]_/))) {
          startIndex++;
        } else {
          break;
        }
      }
      
      // Reconstruct the path excluding version and transformations
      const pathParts = parts.slice(startIndex, -1);
      const filename = withoutExtension;
      
      if (pathParts.length > 0) {
        return [...pathParts, filename].join('/');
      }
      return filename;
    }
    
    return withoutExtension;
  } catch (error) {
    console.error('Error extracting publicId from Cloudinary URL:', error);
    return null;
  }
}

/**
 * Generates a signed Cloudinary URL with expiration
 * @param publicId - The Cloudinary publicId of the video
 * @param expirationSeconds - Time until URL expires (default: 3600 = 1 hour)
 * @returns The signed Cloudinary URL
 */
export function generateSignedCloudinaryUrl(
  publicId: string,
  expirationSeconds: number = 3600,
  deliveryType: 'upload' | 'authenticated' = 'upload'
): string {
  configureCloudinary();
  
  if (!publicId) {
    throw new Error('PublicId is required to generate signed Cloudinary URL');
  }
  
  // Calculate expiration timestamp (Unix timestamp in seconds)
  const expiresAt = Math.floor(Date.now() / 1000) + expirationSeconds;
  
  // Generate signed URL with expiration
  // Cloudinary SDK automatically includes signature when sign_url is true
  const signedUrl = cloudinary.url(publicId, {
    resource_type: 'video',
    format: 'm3u8',
    sign_url: true,
    expires_at: expiresAt,
    secure: true,
    type: deliveryType,
  });
  
  return signedUrl;
}
