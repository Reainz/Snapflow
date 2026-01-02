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
exports.assignAdminRole = void 0;
const admin = __importStar(require("firebase-admin"));
const functionsV1 = __importStar(require("firebase-functions/v1"));
const allowlist_1 = require("./allowlist");
// NOTE: Auth user lifecycle triggers (auth.user().onCreate) are only available in
// the firebase-functions v1 namespace today, so these auth helpers intentionally
// use functionsV1 rather than the v2 API used elsewhere in the codebase.
exports.assignAdminRole = functionsV1.auth.user().onCreate(async (user) => {
    try {
        if (!admin.apps.length)
            admin.initializeApp();
        const email = (user.email || '').toLowerCase();
        const uid = user.uid;
        if (!email) {
            console.log(`User ${uid} has no email, skipping admin assignment.`);
            return;
        }
        // Idempotency: if claim already set, skip
        const record = await admin.auth().getUser(uid);
        if (record.customClaims?.admin === true) {
            console.log(`User ${uid} (${email}) already has admin claim. Skipping.`);
            return;
        }
        const { allowed: shouldBeAdmin, reason } = (0, allowlist_1.checkAdminAllowed)(email);
        if (!shouldBeAdmin) {
            console.log(`User ${uid} (${email}) did not match admin criteria.`);
            return;
        }
        // Set custom claims
        await admin.auth().setCustomUserClaims(uid, { admin: true });
        console.log(`Admin claim set for ${uid} (${email}) via ${reason}.`);
        // Best-effort Firestore update (do not block function on failure)
        try {
            const db = admin.firestore();
            await db.collection('users').doc(uid).set({
                isAdmin: true,
                adminGrantedAt: admin.firestore.FieldValue.serverTimestamp(),
                adminGrantReason: reason,
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
            }, { merge: true });
        }
        catch (firestoreErr) {
            console.error('Failed to update Firestore user admin fields:', firestoreErr);
        }
    }
    catch (err) {
        console.error('assignAdminRole failed:', err);
        // Do not throw; user creation should not be blocked by this function.
    }
});
//# sourceMappingURL=assignAdminRole.js.map