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
exports.cleanupRawVideos = void 0;
exports.runCleanupRawVideos = runCleanupRawVideos;
const admin = __importStar(require("firebase-admin"));
const scheduler_1 = require("firebase-functions/v2/scheduler");
const firebase_functions_1 = require("firebase-functions");
const FAILED_THRESHOLD_MS = 3 * 24 * 60 * 60 * 1000; // 3 days
const PROCESSING_THRESHOLD_MS = 7 * 24 * 60 * 60 * 1000; // 7 days
function ensureInitialized() {
    if (!admin.apps.length) {
        admin.initializeApp();
    }
}
function toMillis(value) {
    if (!value)
        return null;
    if (typeof value === 'number')
        return value;
    if (typeof value.toMillis === 'function')
        return value.toMillis();
    return null;
}
async function fetchVideoDoc(db, videoId) {
    try {
        const doc = await db.collection('videos').doc(videoId).get();
        return doc;
    }
    catch (error) {
        firebase_functions_1.logger.warn('Failed to fetch video document', { videoId, error });
        return null;
    }
}
async function fetchCandidates(db, status, field, cutoffMs) {
    const results = new Map();
    const cutoff = admin.firestore.Timestamp.fromMillis(cutoffMs);
    let lastDoc;
    const limit = 500;
    while (true) {
        let query = db
            .collection('videos')
            .where('status', '==', status)
            .where(field, '<=', cutoff)
            .orderBy(field)
            .limit(limit);
        if (lastDoc) {
            query = query.startAfter(lastDoc);
        }
        const snap = await query.get();
        if (snap.empty) {
            break;
        }
        for (const doc of snap.docs) {
            results.set(doc.id, doc.data());
        }
        if (snap.size < limit) {
            break;
        }
        lastDoc = snap.docs[snap.docs.length - 1];
    }
    return results;
}
async function deleteFileSafe(file, metrics) {
    try {
        const sizeString = file.metadata?.size ?? '0';
        const size = Number(sizeString);
        metrics.totalSizeFreedBytes += Number.isFinite(size) ? size : 0;
        await file.delete();
    }
    catch (error) {
        metrics.errors.push(error?.message || String(error));
        firebase_functions_1.logger.warn('Failed to delete raw video during cleanup', {
            filePath: file.name,
            error: error?.message || String(error),
        });
    }
}
async function runCleanupRawVideos() {
    ensureInitialized();
    const db = admin.firestore();
    const bucket = admin.storage().bucket();
    const nowMs = Date.now();
    const failedCutoffMs = nowMs - FAILED_THRESHOLD_MS;
    const processingCutoffMs = nowMs - PROCESSING_THRESHOLD_MS;
    // Preload candidates to avoid per-file Firestore lookups where possible
    const failedCandidates = await fetchCandidates(db, 'failed', 'lastErrorAt', failedCutoffMs);
    const processingCandidates = await fetchCandidates(db, 'processing', 'createdAt', processingCutoffMs);
    const metrics = {
        failedVideosDeleted: 0,
        orphanedFilesDeleted: 0,
        stuckProcessingDeleted: 0,
        totalSizeFreedBytes: 0,
        checkedFiles: 0,
        errors: [],
    };
    const cache = new Map();
    const [files] = await bucket.getFiles({ prefix: 'raw-videos/' });
    metrics.checkedFiles = files.length;
    for (const file of files) {
        const filePath = file.name || '';
        const segments = filePath.split('/');
        if (segments.length < 3) {
            continue;
        }
        const filename = segments[2];
        const videoId = filename.split('.')[0];
        // Resolve document (use pre-fetched maps first, then cache, then direct fetch)
        let docData = failedCandidates.get(videoId);
        if (docData === undefined) {
            docData = processingCandidates.get(videoId);
        }
        if (docData === undefined) {
            if (cache.has(videoId)) {
                docData = cache.get(videoId) ?? null;
            }
            else {
                const doc = await fetchVideoDoc(db, videoId);
                docData = doc?.exists ? doc.data() ?? null : null;
                cache.set(videoId, docData);
            }
        }
        if (!docData) {
            // Orphaned file - no Firestore document
            await deleteFileSafe(file, metrics);
            metrics.orphanedFilesDeleted += 1;
            continue;
        }
        const status = docData.status?.toLowerCase();
        // Safety: never delete if already ready
        if (status === 'ready') {
            continue;
        }
        if (status === 'failed') {
            const lastErrorAtMs = toMillis(docData.lastErrorAt);
            if (lastErrorAtMs !== null && lastErrorAtMs <= failedCutoffMs) {
                await deleteFileSafe(file, metrics);
                metrics.failedVideosDeleted += 1;
            }
            continue;
        }
        if (status === 'processing') {
            const createdAtMs = toMillis(docData.createdAt);
            if (createdAtMs !== null && createdAtMs <= processingCutoffMs) {
                await deleteFileSafe(file, metrics);
                metrics.stuckProcessingDeleted += 1;
            }
            continue;
        }
    }
    // Store analytics document for observability
    await db.collection('analytics').add({
        type: 'raw_video_cleanup_metrics',
        failedVideosDeleted: metrics.failedVideosDeleted,
        orphanedFilesDeleted: metrics.orphanedFilesDeleted,
        stuckProcessingDeleted: metrics.stuckProcessingDeleted,
        totalSizeFreedBytes: metrics.totalSizeFreedBytes,
        checkedFiles: metrics.checkedFiles,
        errors: metrics.errors,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        collectedAt: new Date().toISOString(),
    });
    firebase_functions_1.logger.info('Raw video cleanup completed', metrics);
}
exports.cleanupRawVideos = (0, scheduler_1.onSchedule)({
    schedule: '0 3 * * *',
    timeZone: 'UTC',
    memory: '512MiB',
    timeoutSeconds: 540,
    region: 'us-central1',
}, async () => {
    await runCleanupRawVideos();
});
//# sourceMappingURL=cleanupRawVideos.js.map