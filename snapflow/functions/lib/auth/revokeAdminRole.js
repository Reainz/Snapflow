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
exports.revokeAdminRole = void 0;
const admin = __importStar(require("firebase-admin"));
const functionsV1 = __importStar(require("firebase-functions/v1"));
// NOTE: Admin role management sticks with firebase-functions v1 because callable
// auth helpers and auth.user() triggers are only supported there. Migrating to v2
// would drop support for these auth integrations.
exports.revokeAdminRole = functionsV1.https.onCall(async (data, context) => {
    if (!context.auth || context.auth.token.admin !== true) {
        throw new functionsV1.https.HttpsError('permission-denied', 'Only admins can revoke admin access');
    }
    const userId = data?.userId;
    if (!userId) {
        throw new functionsV1.https.HttpsError('invalid-argument', 'userId is required');
    }
    try {
        if (!admin.apps.length)
            admin.initializeApp();
        await admin.auth().setCustomUserClaims(userId, { admin: false });
        const db = admin.firestore();
        await db.collection('users').doc(userId).set({
            isAdmin: false,
            adminRevokedAt: admin.firestore.FieldValue.serverTimestamp(),
            adminRevokedBy: context.auth.uid,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
        return { success: true, userId };
    }
    catch (err) {
        console.error('revokeAdminRole failed:', err);
        throw new functionsV1.https.HttpsError('internal', 'Failed to revoke admin access');
    }
});
//# sourceMappingURL=revokeAdminRole.js.map