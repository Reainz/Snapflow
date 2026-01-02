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
exports.calculateTrendingVideos = void 0;
const admin = __importStar(require("firebase-admin"));
const scheduler_1 = require("firebase-functions/v2/scheduler");
exports.calculateTrendingVideos = (0, scheduler_1.onSchedule)({ schedule: '*/30 * * * *', timeZone: 'UTC' }, async () => {
    if (!admin.apps.length)
        admin.initializeApp();
    const db = admin.firestore();
    const now = new Date();
    const dayMs = 24 * 60 * 60 * 1000;
    // Consider last 7 days
    const since = new Date(now.getTime() - 7 * dayMs);
    const videosSnap = await db
        .collection('videos')
        .where('status', '==', 'ready')
        .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(since))
        .limit(500)
        .get();
    const scored = videosSnap.docs.map((d) => {
        const v = d.data();
        const createdAt = v.createdAt?.toDate() || since;
        const hoursSince = Math.max(1, (now.getTime() - createdAt.getTime()) / (60 * 60 * 1000));
        const likes = v.likesCount || 0;
        const comments = v.commentsCount || 0;
        const shares = v.sharesCount || 0;
        const base = likes + 2 * comments + 3 * shares;
        const decay = 1 / Math.pow(hoursSince, 0.5); // mild decay
        const score = base * decay;
        return { id: d.id, score };
    });
    scored.sort((a, b) => b.score - a.score);
    const top50 = scored.slice(0, 50);
    const batch = db.batch();
    // Clear existing trending_videos collection (truncate by deleting first 100 docs)
    const existing = await db.collection('trending_videos').limit(100).get();
    existing.docs.forEach((doc) => batch.delete(doc.ref));
    top50.forEach((t, idx) => {
        const ref = db.collection('trending_videos').doc();
        batch.set(ref, {
            videoId: t.id,
            score: t.score,
            rank: idx + 1,
            calculatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
    });
    await batch.commit();
});
//# sourceMappingURL=trendingContent.js.map