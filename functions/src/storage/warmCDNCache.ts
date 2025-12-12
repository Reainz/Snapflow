import * as admin from 'firebase-admin';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';
import { logger } from 'firebase-functions';
import axios from 'axios';
import { generateSignedCloudinaryUrl } from '../utils/cloudinary';

/**
 * Warms CDN cache for trending videos by requesting their HLS manifests.
 * 
 * Triggers when a new trending video document is created in the trending_videos collection.
 * Each document in trending_videos contains: videoId, score, rank, and calculatedAt timestamp.
 * 
 * Fetches the video's HLS URL from the videos collection and makes an HTTP request 
 * to warm the CDN cache, ensuring faster first-view performance for trending content.
 * 
 * @param event - Firestore event with document snapshot containing videoId field
 */
export const warmCDNCache = onDocumentCreated(
  'trending_videos/{trendingId}',
  async (event) => {
    if (!admin.apps.length) {
      admin.initializeApp();
    }
    const snap = event.data;
    if (!snap) return;
    
    const trendingData = snap.data();
    
    // All documents in trending_videos collection are videos, no type check needed
    const videoId = trendingData.videoId;
    
    if (!videoId) {
      logger.error('Trending document missing videoId field');
      return;
    }
    
    try {
      // Get video HLS URL from Firestore
      const videoDoc = await admin.firestore()
        .collection('videos')
        .doc(videoId)
        .get();
      
      if (!videoDoc.exists) {
        logger.error(`Video document not found for trending item: ${videoId}`);
        return;
      }
      
      const videoData = videoDoc.data();
      const hlsUrl = videoData?.hlsUrl as string | undefined;
      const cloudinaryPublicId = videoData?.cloudinaryPublicId as string | undefined;
      const privacy = (videoData?.privacy as string | undefined)?.toLowerCase();
      const isPrivate = privacy === 'private' || privacy === 'followers-only';
      
      if (!hlsUrl) {
        logger.warn(`Video ${videoId} has no HLS URL, skipping CDN warming`);
        return;
      }

      let warmUrl = hlsUrl;

      if (isPrivate) {
        if (!cloudinaryPublicId) {
          logger.warn(`Video ${videoId} is ${privacy} but missing Cloudinary publicId. Skipping CDN warming.`);
          return;
        }
        try {
          warmUrl = generateSignedCloudinaryUrl(cloudinaryPublicId, 300, 'authenticated');
          logger.debug(`Generated signed URL for private video ${videoId}`);
        } catch (signErr: any) {
          logger.error('Failed to generate signed URL for private video warming', {
            videoId,
            error: signErr?.message || String(signErr),
          });
          return;
        }
      }
      
      // Warm CDN cache by requesting the manifest
      logger.info(`Warming CDN cache for trending video ${videoId}: ${warmUrl}`);
      
      await axios.get(warmUrl, {
        timeout: 5000,
        headers: {
          'User-Agent': 'Snapflow-CDN-Warmer/1.0',
        },
      });
      
      logger.info(`Successfully warmed CDN cache for video ${videoId}`);
      
      // Update trending document with cache warming timestamp
      await snap.ref.update({
        cacheWarmedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
    } catch (error: unknown) {
      const errorMessage = error instanceof Error ? error.message : 'Unknown error';
      logger.error(`Failed to warm CDN cache for video ${videoId}:`, errorMessage);
      
      // Update trending document with failure status
      await snap.ref.update({
        cacheWarmingFailed: true,
        cacheWarmingError: errorMessage,
      });
    }
  });
