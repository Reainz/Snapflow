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
exports.systemHealthCheck = void 0;
const admin = __importStar(require("firebase-admin"));
const scheduler_1 = require("firebase-functions/v2/scheduler");
// Enhanced health check runs every 15 minutes and stores additional metrics
exports.systemHealthCheck = (0, scheduler_1.onSchedule)({ schedule: '*/15 * * * *', timeZone: 'UTC' }, async () => {
    if (!admin.apps.length)
        admin.initializeApp();
    const db = admin.firestore();
    const now = Date.now();
    const oneHourAgo = new Date(now - 60 * 60 * 1000);
    const snap = await db
        .collection('videos')
        .where('updatedAt', '>=', admin.firestore.Timestamp.fromDate(oneHourAgo))
        .get();
    let ready = 0;
    let failed = 0;
    let processing = 0;
    for (const doc of snap.docs) {
        const s = doc.data().status || '';
        if (s === 'ready')
            ready++;
        else if (s === 'failed')
            failed++;
        else if (s === 'processing')
            processing++;
    }
    const total = ready + failed + processing;
    const successRate = total > 0 ? ready / total : 1;
    // Optional: approximate counts from Storage (can be expensive; limit results)
    let storageRawFilesCount = null;
    try {
        const bucket = admin.storage().bucket();
        const [files] = await bucket.getFiles({ prefix: 'raw-videos/', maxResults: 1000 });
        storageRawFilesCount = files.length;
    }
    catch {
        storageRawFilesCount = null;
    }
    await db.collection('analytics').add({
        type: 'system_health',
        period: 'quarter-hour',
        metrics: {
            processingSuccessRate: successRate,
            processingErrors: failed,
            processingInFlight: processing,
            videosUpdatedLastHour: total,
            storageRawFilesCount,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    // API metrics are aggregated independently by aggregateAPIMetricsHourly.
});
//# sourceMappingURL=systemHealthCheck.js.map