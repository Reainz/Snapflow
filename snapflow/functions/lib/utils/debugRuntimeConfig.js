"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.debugRuntimeConfig = void 0;
const firebase_functions_1 = require("firebase-functions");
const https_1 = require("firebase-functions/v2/https");
/**
 * Temporary callable function to inspect FIREBASE_CONFIG at runtime.
 * Returns and logs the parsed config so you can confirm storageBucket.
 */
exports.debugRuntimeConfig = (0, https_1.onCall)(async () => {
    const raw = process.env.FIREBASE_CONFIG || '{}';
    firebase_functions_1.logger.info('FIREBASE_CONFIG_RAW', { raw });
    let parsed = {};
    try {
        parsed = JSON.parse(raw);
    }
    catch (error) {
        firebase_functions_1.logger.error('Failed to parse FIREBASE_CONFIG', error);
    }
    const storageBucket = parsed.storageBucket ?? null;
    const projectId = parsed.projectId ?? null;
    firebase_functions_1.logger.info('FIREBASE_CONFIG_PARSED', {
        storageBucket,
        projectId,
    });
    return {
        storageBucket,
        projectId,
    };
});
//# sourceMappingURL=debugRuntimeConfig.js.map