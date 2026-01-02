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
exports.retryProcessCaptions = exports.processCaptions = void 0;
const admin = __importStar(require("firebase-admin"));
const firebase_functions_1 = require("firebase-functions");
const https_1 = require("firebase-functions/v2/https");
const cloudinary_1 = require("cloudinary");
const node_fetch_1 = __importDefault(require("node-fetch"));
const crypto_1 = __importDefault(require("crypto"));
const performance_monitoring_1 = require("../utils/performance-monitoring");
const cloudinary_2 = require("../utils/cloudinary");
// Cloudinary webhook handler for auto_transcription completion
exports.processCaptions = (0, https_1.onRequest)({ region: 'us-central1' }, async (req, res) => {
    await (0, performance_monitoring_1.withPerformanceMonitoring)(async () => {
        if (req.method !== 'POST') {
            res.status(405).send('Method Not Allowed');
            return;
        }
        const signature = req.header('X-Cld-Signature');
        const timestamp = req.header('X-Cld-Timestamp');
        const apiSecret = cloudinary_2.cloudinaryApiSecret.value();
        const rawBodyBuffer = req.rawBody;
        const rawBody = rawBodyBuffer ? rawBodyBuffer.toString('utf8') : null;
        // Verify Cloudinary webhook signature when possible, but don't block caption processing
        // if the platform doesn't provide rawBody (common misconfiguration).
        if (signature && timestamp && apiSecret && rawBody) {
            const candidates = [
                // Variant used by some Cloudinary notification examples.
                crypto_1.default.createHash('sha1').update(`payload=${rawBody}&timestamp=${timestamp}${apiSecret}`).digest('hex'),
                // Fallback variants (different canonicalization).
                crypto_1.default.createHash('sha1').update(`${rawBody}${timestamp}${apiSecret}`).digest('hex'),
                crypto_1.default.createHash('sha1').update(`payload=${encodeURIComponent(rawBody)}&timestamp=${timestamp}${apiSecret}`).digest('hex'),
            ];
            const matches = candidates.some((expected) => {
                if (expected.length !== signature.length)
                    return false;
                try {
                    return crypto_1.default.timingSafeEqual(Buffer.from(expected), Buffer.from(signature));
                }
                catch {
                    return false;
                }
            });
            if (!matches) {
                firebase_functions_1.logger.error('Invalid Cloudinary webhook signature', {
                    received: signature,
                });
                res.status(401).send('Unauthorized');
                return;
            }
        }
        else {
            firebase_functions_1.logger.warn('Skipping Cloudinary webhook signature verification (missing inputs)', {
                hasSignature: !!signature,
                hasTimestamp: !!timestamp,
                hasApiSecret: !!apiSecret,
                hasRawBody: !!rawBody,
            });
        }
        const notification = req.body;
        firebase_functions_1.logger.info('Received Cloudinary notification:', notification);
        if (notification.info_kind !== 'auto_transcription') {
            firebase_functions_1.logger.debug('Not an auto_transcription notification, ignoring');
            res.status(200).send('OK');
            return;
        }
        if (notification.info_status !== 'complete') {
            firebase_functions_1.logger.debug('Transcription status is ' + notification.info_status + ', ignoring');
            res.status(200).send('OK');
            return;
        }
        const publicId = notification.public_id;
        if (!publicId) {
            firebase_functions_1.logger.error('No public_id in notification');
            res.status(400).send('Missing public_id');
            return;
        }
        try {
            const { videoId, captionUrl } = await generateCaptionsFromCloudinary(publicId);
            res.status(200).send({ success: true, videoId, captionUrl });
        }
        catch (error) {
            firebase_functions_1.logger.error('Error processing captions:', error);
            res.status(500).send({ error: error.message });
        }
    }, 'processCaptions')();
});
exports.retryProcessCaptions = (0, https_1.onCall)(async (request) => {
    const auth = request.auth;
    if (!auth) {
        throw new https_1.HttpsError('unauthenticated', 'Sign-in required');
    }
    const videoId = request.data?.videoId?.trim();
    if (!videoId) {
        throw new https_1.HttpsError('invalid-argument', 'videoId is required');
    }
    if (!admin.apps.length) {
        admin.initializeApp();
    }
    const doc = await admin.firestore().collection('videos').doc(videoId).get();
    if (!doc.exists) {
        throw new https_1.HttpsError('not-found', 'Video not found');
    }
    const data = doc.data();
    const ownerId = data?.ownerId;
    const publicId = data?.cloudinaryPublicId;
    if (!publicId) {
        throw new https_1.HttpsError('failed-precondition', 'Cloudinary publicId missing for this video');
    }
    const isAdmin = !!auth.token?.admin;
    const isOwner = ownerId ? ownerId === auth.uid : false;
    if (!isAdmin && !isOwner) {
        throw new https_1.HttpsError('permission-denied', 'You are not allowed to retry captions for this video');
    }
    try {
        const { captionUrl } = await generateCaptionsFromCloudinary(publicId, videoId);
        return { success: true, videoId, captionUrl };
    }
    catch (error) {
        firebase_functions_1.logger.error('retryProcessCaptions failed', { videoId, error: error?.message || error });
        throw new https_1.HttpsError('internal', error?.message || 'Failed to regenerate captions');
    }
});
async function generateCaptionsFromCloudinary(publicId, explicitVideoId) {
    if (!publicId) {
        throw new Error('publicId is required');
    }
    if (!admin.apps.length) {
        admin.initializeApp();
    }
    (0, cloudinary_2.configureCloudinary)();
    const videoId = explicitVideoId ?? extractVideoIdFromPublicId(publicId);
    if (!videoId) {
        throw new Error('Could not determine videoId from public_id');
    }
    firebase_functions_1.logger.info('Processing captions for videoId: ' + videoId + ', publicId: ' + publicId);
    // Determine delivery type from stored hlsUrl when available (backward compatible).
    let deliveryType = 'upload';
    try {
        const doc = await admin.firestore().collection('videos').doc(videoId).get();
        const hlsUrl = doc.data()?.hlsUrl;
        if (hlsUrl) {
            deliveryType = (0, cloudinary_2.inferCloudinaryDeliveryTypeFromUrl)(hlsUrl);
        }
    }
    catch (_) {
        // Best-effort only.
    }
    // Some accounts deliver transcripts as a raw resource; others expose it under the video resource.
    // Try raw first, then fall back to video if needed.
    const transcriptCandidates = [
        cloudinary_1.v2.url(publicId, {
            resource_type: 'raw',
            format: 'transcript',
            type: deliveryType,
            sign_url: deliveryType === 'authenticated',
            expires_at: Math.floor(Date.now() / 1000) + 60 * 10,
        }),
        cloudinary_1.v2.url(publicId, {
            resource_type: 'video',
            format: 'transcript',
            type: deliveryType,
            sign_url: deliveryType === 'authenticated',
            expires_at: Math.floor(Date.now() / 1000) + 60 * 10,
        }),
    ];
    let transcriptResponse = null;
    let lastFetchError = null;
    for (const transcriptUrl of transcriptCandidates) {
        firebase_functions_1.logger.info('Fetching transcript from:', transcriptUrl);
        const res = await (0, node_fetch_1.default)(transcriptUrl);
        if (res.ok) {
            transcriptResponse = res;
            break;
        }
        lastFetchError = `${res.status} ${res.statusText}`;
    }
    if (!transcriptResponse) {
        throw new Error('Failed to fetch transcript: ' + (lastFetchError || 'unknown'));
    }
    const transcriptData = (await transcriptResponse.json());
    firebase_functions_1.logger.info('Transcript data received:', { wordCount: transcriptData.data?.length || 0 });
    const vttContent = convertToVTT(transcriptData);
    const bucket = admin.storage().bucket();
    const vttFilePath = 'captions/' + videoId + '.vtt';
    const file = bucket.file(vttFilePath);
    const downloadToken = crypto_1.default.randomUUID();
    await file.save(vttContent, {
        resumable: false,
        metadata: {
            contentType: 'text/vtt',
            cacheControl: 'private, max-age=86400',
            metadata: {
                firebaseStorageDownloadTokens: downloadToken,
            },
        },
    });
    firebase_functions_1.logger.info('VTT file uploaded to Firebase Storage:', vttFilePath);
    const captionUrl = 'https://firebasestorage.googleapis.com/v0/b/' +
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
    firebase_functions_1.logger.info('Video updated with caption URL:', { videoId, captionUrl });
    return { videoId, captionUrl };
}
function extractVideoIdFromPublicId(publicId) {
    if (!publicId)
        return null;
    const segments = publicId
        .split('/')
        .map((s) => s.trim())
        .filter((s) => s.length > 0);
    if (segments.length === 0)
        return null;
    // Prefer the last segment if present.
    const last = segments[segments.length - 1];
    if (last.length > 0)
        return last;
    // Fallback: try the parent segment (folder name).
    if (segments.length >= 2) {
        return segments[segments.length - 2];
    }
    return null;
}
// Convert Cloudinary transcript JSON to WebVTT format
function convertToVTT(transcriptData) {
    const lines = ['WEBVTT', ''];
    // Extract transcript entries (Cloudinary format has data array with word-level timing)
    const data = transcriptData.data || [];
    if (data.length === 0) {
        firebase_functions_1.logger.warn('Transcript data is empty');
        return lines.join('\n');
    }
    // Group words into subtitle chunks (max 12 words or 3 seconds)
    const maxWordsPerChunk = 12;
    const maxDurationSeconds = 3;
    let currentChunk = [];
    let chunkIndex = 1;
    for (let i = 0; i < data.length; i++) {
        const word = data[i];
        currentChunk.push(word);
        // Check if we should finalize this chunk
        const shouldFinalize = currentChunk.length >= maxWordsPerChunk ||
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
function formatVTTTime(seconds) {
    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const secs = Math.floor(seconds % 60);
    const millis = Math.floor((seconds % 1) * 1000);
    return padZero(hours, 2) + ':' + padZero(minutes, 2) + ':' + padZero(secs, 2) + '.' + padZero(millis, 3);
}
function padZero(num, length) {
    return num.toString().padStart(length, '0');
}
//# sourceMappingURL=processCaptions.js.map