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
exports.aggregateUserAnalytics = void 0;
const admin = __importStar(require("firebase-admin"));
const scheduler_1 = require("firebase-functions/v2/scheduler");
function startOfDay(d) {
    return new Date(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate());
}
async function getActiveUsersCount(db, start, end, field) {
    try {
        const snap = await db
            .collection('users')
            .where(field, '>=', admin.firestore.Timestamp.fromDate(start))
            .where(field, '<=', admin.firestore.Timestamp.fromDate(end))
            .count()
            .get();
        return snap.data().count || 0;
    }
    catch (error) {
        console.warn(`Field ${field} not available for active user count; falling back.`, error);
        return 0;
    }
}
exports.aggregateUserAnalytics = (0, scheduler_1.onSchedule)({ schedule: '0 2 * * *', timeZone: 'UTC' }, async () => {
    if (!admin.apps.length)
        admin.initializeApp();
    const db = admin.firestore();
    const now = new Date();
    const today = startOfDay(now);
    const dayMs = 24 * 60 * 60 * 1000;
    // DAU: prefer lastLoginAt, fallback to updatedAt
    const dauStart = new Date(now.getTime() - dayMs);
    let dau = await getActiveUsersCount(db, dauStart, now, 'lastLoginAt');
    if (dau === 0) {
        dau = await getActiveUsersCount(db, dauStart, now, 'updatedAt');
    }
    // WAU: last 7d
    const wauStart = new Date(now.getTime() - 7 * dayMs);
    let wau = await getActiveUsersCount(db, wauStart, now, 'lastLoginAt');
    if (wau === 0) {
        wau = await getActiveUsersCount(db, wauStart, now, 'updatedAt');
    }
    // MAU: last 30d
    const mauStart = new Date(now.getTime() - 30 * dayMs);
    let mau = await getActiveUsersCount(db, mauStart, now, 'lastLoginAt');
    if (mau === 0) {
        mau = await getActiveUsersCount(db, mauStart, now, 'updatedAt');
    }
    // Retention (naive, based on createdAt and activity windows)
    // Day 1 retention: users created yesterday and active today
    // Prefer lastLoginAt, fallback to updatedAt
    const createdYesterdayStart = new Date(startOfDay(new Date(now.getTime() - dayMs)).getTime());
    const createdYesterdayEnd = new Date(createdYesterdayStart.getTime() + dayMs - 1);
    const newUsersSnap = await db
        .collection('users')
        .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(createdYesterdayStart))
        .where('createdAt', '<=', admin.firestore.Timestamp.fromDate(createdYesterdayEnd))
        .get();
    const newUsers = newUsersSnap.docs.map((d) => d.id);
    let d1Retained = 0;
    if (newUsers.length) {
        // Try lastLoginAt first, fallback to updatedAt
        try {
            const todayActiveSnap = await db
                .collection('users')
                .where(admin.firestore.FieldPath.documentId(), 'in', newUsers.slice(0, 10)) // chunk if needed
                .where('lastLoginAt', '>=', admin.firestore.Timestamp.fromDate(dauStart))
                .get();
            d1Retained += todayActiveSnap.size;
        }
        catch (error) {
            // lastLoginAt not available, fallback to updatedAt
            console.warn('lastLoginAt not available for retention calculation; falling back to updatedAt.', error);
            const todayActiveSnap = await db
                .collection('users')
                .where(admin.firestore.FieldPath.documentId(), 'in', newUsers.slice(0, 10)) // chunk if needed
                .where('updatedAt', '>=', admin.firestore.Timestamp.fromDate(dauStart))
                .get();
            d1Retained += todayActiveSnap.size;
        }
        // Note: For >10 new users, additional chunks should be processed. Keeping simple for MVP.
    }
    const d1RetentionRate = newUsers.length > 0 ? d1Retained / newUsers.length : 0;
    // Geographic distribution aggregation
    const usersWithCountrySnap = await db
        .collection('users')
        .where('countryCode', '!=', null)
        .get();
    const countryMap = new Map();
    const regionMap = new Map();
    usersWithCountrySnap.docs.forEach((doc) => {
        const data = doc.data();
        const countryCode = data.countryCode;
        const region = data.region;
        if (countryCode) {
            countryMap.set(countryCode, (countryMap.get(countryCode) || 0) + 1);
        }
        if (region) {
            regionMap.set(region, (regionMap.get(region) || 0) + 1);
        }
    });
    const countries = Array.from(countryMap.entries()).map(([countryCode, count]) => ({
        countryCode,
        count,
    })).sort((a, b) => b.count - a.count); // Sort by count descending
    const regions = Array.from(regionMap.entries()).map(([region, count]) => ({
        region,
        count,
    })).sort((a, b) => b.count - a.count);
    await db.collection('analytics').add({
        type: 'user_metrics',
        period: 'daily',
        metrics: {
            dau,
            wau,
            mau,
            d1RetentionRate,
            newUsers: newUsers.length,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        date: admin.firestore.Timestamp.fromDate(today),
    });
    // Store geographic distribution separately for better querying
    await db.collection('analytics').add({
        type: 'geographic_distribution',
        period: 'daily',
        metrics: {
            countries,
            regions,
            totalUsersWithGeoData: usersWithCountrySnap.size,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        date: admin.firestore.Timestamp.fromDate(today),
    });
});
//# sourceMappingURL=userAnalytics.js.map