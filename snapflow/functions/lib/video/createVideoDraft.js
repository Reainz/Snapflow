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
exports.createVideoDraft = void 0;
const https_1 = require("firebase-functions/v2/https");
const admin = __importStar(require("firebase-admin"));
// Callable function used by the mobile client to create the initial
// "video draft" document. This bypasses Firestore security rules by
// using the Admin SDK, while still enforcing that the caller is the
// owner of the video.
exports.createVideoDraft = (0, https_1.onCall)(async (request) => {
    if (!request.auth) {
        throw new https_1.HttpsError('unauthenticated', 'Authentication required.');
    }
    const uid = request.auth.uid;
    const { videoId, data } = request.data;
    if (!videoId || typeof videoId !== 'string') {
        throw new https_1.HttpsError('invalid-argument', 'videoId is required and must be a string.');
    }
    if (!data || typeof data !== 'object') {
        throw new https_1.HttpsError('invalid-argument', 'data payload is required.');
    }
    // Enforce ownership on the server side.
    if (data['ownerId'] !== uid) {
        throw new https_1.HttpsError('permission-denied', 'Caller must be the owner of the video.');
    }
    if (!admin.apps.length) {
        admin.initializeApp();
    }
    const db = admin.firestore();
    const now = admin.firestore.FieldValue.serverTimestamp();
    const ref = db.collection('videos').doc(videoId);
    await db.runTransaction(async (tx) => {
        const existing = await tx.get(ref);
        const existingData = existing.exists ? existing.data() : null;
        // Prevent a late draft write from clobbering processed fields (race with processVideoUpload).
        // If the server-side pipeline already finished (status=ready or processed fields exist),
        // do not allow the draft payload to downgrade status back to "processing".
        const alreadyProcessed = existingData?.status === 'ready' ||
            !!existingData?.hlsUrl ||
            !!existingData?.processedAt;
        const payload = {
            ...data,
            ownerId: uid,
            updatedAt: now,
        };
        // Persist the bucket name to make retries resilient when FIREBASE_CONFIG is missing storageBucket.
        const rawVideoUrl = data['rawVideoUrl'] ?? '';
        const bucketMatch = rawVideoUrl.match(/https?:\/\/firebasestorage\.googleapis\.com\/v0\/b\/([^/]+)\/o\//i);
        if (bucketMatch && bucketMatch[1]) {
            payload.rawVideoBucket = bucketMatch[1];
        }
        // Only set createdAt when missing (processing-created docs might not have it yet).
        if (!existingData?.createdAt) {
            payload.createdAt = now;
        }
        if (alreadyProcessed) {
            delete payload.status;
        }
        // Always merge to preserve any fields written by Cloud Functions (hlsUrl, processedAt, etc).
        tx.set(ref, payload, { merge: true });
    });
    return { success: true };
});
//# sourceMappingURL=createVideoDraft.js.map