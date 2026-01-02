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
Object.defineProperty(exports, "__esModule", { value: true });
exports.flagVideo = void 0;
const functions = __importStar(require("firebase-functions/v2/https"));
const admin = __importStar(require("firebase-admin"));
const rate_limiter_1 = require("../utils/rate-limiter");
const firestore_helpers_1 = require("../utils/firestore-helpers");
const v1_1 = require("firebase-functions/v1");
/**
 * Cloud Function: Flag Video
 *
 * HTTP Callable function for flagging inappropriate videos
 * Checks rate limit (10 flags per 24 hours) before allowing flag
 *
 * Parameters:
 * - videoId: string - ID of the video to flag
 *
 * Returns:
 * - success: boolean
 * - message: string
 *
 * Throws:
 * - unauthenticated: if user not logged in
 * - failed-precondition: if rate limit exceeded
 * - not-found: if video doesn't exist
 */
exports.flagVideo = functions.onCall(async (request) => {
    // Check authentication
    if (!request.auth) {
        throw new functions.HttpsError('unauthenticated', 'User must be authenticated to flag videos');
    }
    const userId = request.auth.uid;
    const { videoId } = request.data;
    // Validate input
    if (!videoId || typeof videoId !== 'string') {
        throw new functions.HttpsError('invalid-argument', 'videoId is required and must be a string');
    }
    const db = (0, firestore_helpers_1.getDb)();
    try {
        // Check rate limit for flag action (10 per 24 hours)
        const rateLimitResult = await (0, rate_limiter_1.checkRateLimit)(userId, 'flag');
        if (!rateLimitResult.allowed) {
            v1_1.logger.warn(`Rate limit exceeded for flag by user ${userId} on video ${videoId}`);
            // Calculate retry time
            const retryAfterMinutes = Math.ceil((rateLimitResult.retryAfterSeconds || 0) / 60);
            throw new functions.HttpsError('failed-precondition', `Flag limit reached. You can flag videos again in ${retryAfterMinutes} minutes.`, { retryAfterSeconds: rateLimitResult.retryAfterSeconds });
        }
        // Check if video exists
        const videoRef = db.collection('videos').doc(videoId);
        const videoDoc = await videoRef.get();
        if (!videoDoc.exists) {
            throw new functions.HttpsError('not-found', `Video ${videoId} not found`);
        }
        // Update video to flagged status
        await videoRef.update({
            status: 'flagged',
            flaggedAt: admin.firestore.FieldValue.serverTimestamp(),
            flaggedBy: userId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        // Create admin alert for moderation queue
        await db.collection('admin_alerts').add({
            type: 'content_flagged',
            action: 'flag',
            userId,
            resourceId: videoId,
            message: `Video ${videoId} flagged by user ${userId}`,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            severity: 'info',
            acknowledged: false,
        });
        v1_1.logger.info(`Video ${videoId} flagged by user ${userId}`);
        return {
            success: true,
            message: 'Video flagged successfully. Our moderation team will review it.',
        };
    }
    catch (error) {
        // Re-throw HttpsError as-is
        if (error instanceof functions.HttpsError) {
            throw error;
        }
        // Log and wrap other errors
        v1_1.logger.error('Error flagging video:', error);
        throw new functions.HttpsError('internal', 'Failed to flag video. Please try again later.');
    }
});
//# sourceMappingURL=flagVideo.js.map