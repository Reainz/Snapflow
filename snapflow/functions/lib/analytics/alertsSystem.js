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
exports.checkSystemAlerts = void 0;
const admin = __importStar(require("firebase-admin"));
const scheduler_1 = require("firebase-functions/v2/scheduler");
exports.checkSystemAlerts = (0, scheduler_1.onSchedule)({ schedule: '*/15 * * * *', timeZone: 'UTC' }, async () => {
    if (!admin.apps.length)
        admin.initializeApp();
    const db = admin.firestore();
    const now = Date.now();
    const oneHourAgo = new Date(now - 60 * 60 * 1000);
    const videosSnap = await db
        .collection('videos')
        .where('updatedAt', '>=', admin.firestore.Timestamp.fromDate(oneHourAgo))
        .get();
    let ready = 0;
    let failed = 0;
    for (const doc of videosSnap.docs) {
        const s = doc.data().status || '';
        if (s === 'ready')
            ready++;
        else if (s === 'failed')
            failed++;
    }
    const total = ready + failed;
    const failureRate = total > 0 ? failed / total : 0;
    // Storage usage approximation
    let storageRawFilesCount = null;
    try {
        const bucket = admin.storage().bucket();
        const [files] = await bucket.getFiles({ prefix: 'raw-videos/', maxResults: 2000 });
        storageRawFilesCount = files.length;
    }
    catch {
        storageRawFilesCount = null;
    }
    const alerts = [];
    if (failureRate > 0.1) {
        alerts.push({
            type: 'processing_failure',
            severity: 'critical',
            message: `Processing failure rate ${Math.round(failureRate * 100)}% exceeds 10%`,
            threshold: 0.1,
            currentValue: failureRate,
        });
    }
    if ((storageRawFilesCount ?? 0) > 10000) {
        alerts.push({
            type: 'storage_warning',
            severity: 'warning',
            message: `Raw videos objects count ${(storageRawFilesCount ?? 0)} exceeds 10k (approx)`,
            threshold: 10000,
            currentValue: storageRawFilesCount ?? 0,
        });
    }
    const batch = db.batch();
    for (const a of alerts) {
        const ref = db.collection('admin_alerts').doc();
        batch.set(ref, {
            ...a,
            acknowledged: false,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    }
    if (alerts.length)
        await batch.commit();
});
//# sourceMappingURL=alertsSystem.js.map