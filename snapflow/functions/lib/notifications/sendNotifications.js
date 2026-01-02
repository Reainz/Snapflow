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
exports.sendPushNotification = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const firebase_functions_1 = require("firebase-functions");
const performance_monitoring_1 = require("../utils/performance-monitoring");
if (!admin.apps.length) {
    admin.initializeApp();
}
/**
 * Sends an FCM push notification when a new notification doc is created under users/{userId}/notifications/{id}
 */
exports.sendPushNotification = (0, firestore_1.onDocumentCreated)('users/{userId}/notifications/{notificationId}', async (event) => {
    await (0, performance_monitoring_1.withPerformanceMonitoring)(async () => {
        try {
            const userId = event.params.userId;
            const snap = event.data;
            if (!snap)
                return;
            const data = snap.data();
            if (!data)
                return;
            // Fetch recipient's FCM token from users/{userId}.fcmToken
            const db = admin.firestore();
            const userDoc = await db.collection('users').doc(userId).get();
            const user = userDoc.data();
            const fcmToken = user?.fcmToken;
            if (!fcmToken) {
                firebase_functions_1.logger.debug(`No fcmToken for user ${userId}, skipping push.`);
                return;
            }
            const title = data.title || defaultTitle(data.type);
            const body = data.body || defaultBody(data.type);
            await admin.messaging().send({
                token: fcmToken,
                notification: {
                    title,
                    body,
                },
                data: {
                    type: data.type,
                    actorUserId: data.actorUserId,
                    videoId: data.videoId ?? '',
                    commentId: data.commentId ?? '',
                    route: data.payload?.route ?? '',
                },
            });
        }
        catch (e) {
            firebase_functions_1.logger.error('sendPushNotification failed', e);
        }
    }, 'sendPushNotification')();
});
function defaultTitle(type) {
    switch (type) {
        case 'like':
            return 'New Like';
        case 'comment':
            return 'New Comment';
        case 'follow':
            return 'New Follower';
        case 'share':
            return 'Video Shared';
        case 'video':
            return 'Video update';
        default:
            return 'Notification';
    }
}
function defaultBody(type) {
    switch (type) {
        case 'like':
            return 'Someone liked your video.';
        case 'comment':
            return 'Someone commented on your video.';
        case 'follow':
            return 'You have a new follower.';
        case 'share':
            return 'Your video was shared.';
        case 'video':
            return 'Your video status was updated.';
        default:
            return 'You have a new notification.';
    }
}
//# sourceMappingURL=sendNotifications.js.map