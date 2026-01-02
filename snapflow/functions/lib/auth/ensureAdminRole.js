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
exports.ensureAdminRole = void 0;
const admin = __importStar(require("firebase-admin"));
const functionsV1 = __importStar(require("firebase-functions/v1"));
const allowlist_1 = require("./allowlist");
// HTTPS callable: ensure admin role for existing accounts that match the allow-list.
// Returns { applied: boolean, reason?: string }
// NOTE: We keep this callable on the firebase-functions v1 surface because it needs
// access to the auth.user() trigger ecosystem/v1 callable auth helpers that are not
// yet available in v2.
exports.ensureAdminRole = functionsV1.https.onCall(async (_data, context) => {
    try {
        if (!admin.apps.length)
            admin.initializeApp();
        if (!context.auth) {
            throw new functionsV1.https.HttpsError('unauthenticated', 'Must be authenticated.');
        }
        const uid = context.auth.uid;
        const email = context.auth.token.email?.toLowerCase() || '';
        if (!email) {
            throw new functionsV1.https.HttpsError('failed-precondition', 'No email on account.');
        }
        // Idempotency: if already admin, short-circuit
        const record = await admin.auth().getUser(uid);
        if (record.customClaims?.admin === true) {
            return { applied: false, reason: 'already_admin' };
        }
        const { allowed, reason } = (0, allowlist_1.checkAdminAllowed)(email);
        if (!allowed) {
            return { applied: false, reason: 'not_allowed' };
        }
        await admin.auth().setCustomUserClaims(uid, { admin: true });
        // Best-effort Firestore audit
        try {
            const db = admin.firestore();
            await db.collection('users').doc(uid).set({
                isAdmin: true,
                adminGrantedAt: admin.firestore.FieldValue.serverTimestamp(),
                adminGrantReason: reason,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        catch (e) {
            console.error('ensureAdminRole: Firestore update failed', e);
        }
        return { applied: true, reason };
    }
    catch (err) {
        console.error('ensureAdminRole failed:', err);
        if (err instanceof functionsV1.https.HttpsError)
            throw err;
        throw new functionsV1.https.HttpsError('internal', err?.message || 'Unknown error');
    }
});
//# sourceMappingURL=ensureAdminRole.js.map