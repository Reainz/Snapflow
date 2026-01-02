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
exports.checkRateLimit = checkRateLimit;
const admin = __importStar(require("firebase-admin"));
const firestore_helpers_1 = require("./firestore-helpers");
const firebase_functions_1 = require("firebase-functions");
const RATE_LIMITS = {
    upload: { limit: 5, window: 'hourly' },
    comment: { limit: 20, window: 'hourly' },
    like: { limit: 100, window: 'hourly' },
    follow: { limit: 30, window: 'hourly' },
    share: { limit: 50, window: 'hourly' },
    flag: { limit: 10, window: 'daily' },
};
function generateBucket(window) {
    const now = new Date();
    if (window === 'hourly') {
        const year = now.getUTCFullYear();
        const month = String(now.getUTCMonth() + 1).padStart(2, '0');
        const day = String(now.getUTCDate()).padStart(2, '0');
        const hour = String(now.getUTCHours()).padStart(2, '0');
        return `${year}-${month}-${day}-${hour}`;
    }
    else {
        return now.toISOString().split('T')[0];
    }
}
function getResetTimestamp(window) {
    const now = Date.now();
    if (window === 'hourly') {
        const nextHour = new Date(now);
        nextHour.setUTCHours(nextHour.getUTCHours() + 1, 0, 0, 0);
        return nextHour.getTime();
    }
    else {
        const nextDay = new Date(now);
        nextDay.setUTCDate(nextDay.getUTCDate() + 1);
        nextDay.setUTCHours(0, 0, 0, 0);
        return nextDay.getTime();
    }
}
async function checkRateLimit(userId, action) {
    const config = RATE_LIMITS[action];
    const db = (0, firestore_helpers_1.getDb)();
    const docRef = db.collection('rate_limits').doc(userId);
    const currentBucket = generateBucket(config.window);
    const resetAt = getResetTimestamp(config.window);
    try {
        return await db.runTransaction(async (transaction) => {
            const doc = await transaction.get(docRef);
            const data = doc.data();
            const actionData = data?.[action] || { count: 0, bucket: currentBucket, resetAt };
            if (actionData.bucket !== currentBucket) {
                actionData.count = 0;
                actionData.bucket = currentBucket;
                actionData.resetAt = resetAt;
            }
            if (actionData.count >= config.limit) {
                const retryAfter = Math.ceil((resetAt - Date.now()) / 1000);
                return {
                    allowed: false,
                    remaining: 0,
                    resetAt,
                    retryAfterSeconds: retryAfter,
                };
            }
            actionData.count += 1;
            const ttl = Date.now() + 30 * 24 * 60 * 60 * 1000;
            transaction.set(docRef, {
                userId,
                [action]: actionData,
                lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
                ttl: admin.firestore.Timestamp.fromMillis(ttl),
            }, { merge: true });
            return {
                allowed: true,
                remaining: config.limit - actionData.count,
                resetAt: actionData.resetAt,
            };
        });
    }
    catch (error) {
        firebase_functions_1.logger.error('Rate limit check failed', { userId, action, error });
        return {
            allowed: true,
            remaining: config.limit,
            resetAt,
        };
    }
}
//# sourceMappingURL=rate-limiter.js.map