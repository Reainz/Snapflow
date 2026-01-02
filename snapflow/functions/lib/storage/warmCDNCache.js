"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.warmCDNCache = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const firebase_functions_1 = require("firebase-functions");
const axios_1 = __importDefault(require("axios"));
const cloudinary_1 = require("../utils/cloudinary");
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
exports.warmCDNCache = (0, firestore_1.onDocumentCreated)('trending_videos/{trendingId}', async (event) => {
    if (!admin.apps.length) {
        admin.initializeApp();
    }
    const snap = event.data;
    if (!snap)
        return;
    const trendingData = snap.data();
    // All documents in trending_videos collection are videos, no type check needed
    const videoId = trendingData.videoId;
    if (!videoId) {
        firebase_functions_1.logger.error('Trending document missing videoId field');
        return;
    }
    try {
        // Get video HLS URL from Firestore
        const videoDoc = await admin.firestore()
            .collection('videos')
            .doc(videoId)
            .get();
        if (!videoDoc.exists) {
            firebase_functions_1.logger.error(`Video document not found for trending item: ${videoId}`);
            return;
        }
        const videoData = videoDoc.data();
        const hlsUrl = videoData?.hlsUrl;
        const cloudinaryPublicId = videoData?.cloudinaryPublicId;
        const privacy = videoData?.privacy?.toLowerCase();
        const isPrivate = privacy === 'private' || privacy === 'followers-only';
        if (!hlsUrl) {
            firebase_functions_1.logger.warn(`Video ${videoId} has no HLS URL, skipping CDN warming`);
            return;
        }
        let warmUrl = hlsUrl;
        if (isPrivate) {
            if (!cloudinaryPublicId) {
                firebase_functions_1.logger.warn(`Video ${videoId} is ${privacy} but missing Cloudinary publicId. Skipping CDN warming.`);
                return;
            }
            try {
                warmUrl = (0, cloudinary_1.generateSignedCloudinaryUrl)(cloudinaryPublicId, 300, 'authenticated');
                firebase_functions_1.logger.debug(`Generated signed URL for private video ${videoId}`);
            }
            catch (signErr) {
                firebase_functions_1.logger.error('Failed to generate signed URL for private video warming', {
                    videoId,
                    error: signErr?.message || String(signErr),
                });
                return;
            }
        }
        // Warm CDN cache by requesting the manifest
        firebase_functions_1.logger.info(`Warming CDN cache for trending video ${videoId}: ${warmUrl}`);
        await axios_1.default.get(warmUrl, {
            timeout: 5000,
            headers: {
                'User-Agent': 'Snapflow-CDN-Warmer/1.0',
            },
        });
        firebase_functions_1.logger.info(`Successfully warmed CDN cache for video ${videoId}`);
        // Update trending document with cache warming timestamp
        await snap.ref.update({
            cacheWarmedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    catch (error) {
        const errorMessage = error instanceof Error ? error.message : 'Unknown error';
        firebase_functions_1.logger.error(`Failed to warm CDN cache for video ${videoId}:`, errorMessage);
        // Update trending document with failure status
        await snap.ref.update({
            cacheWarmingFailed: true,
            cacheWarmingError: errorMessage,
        });
    }
});
//# sourceMappingURL=warmCDNCache.js.map