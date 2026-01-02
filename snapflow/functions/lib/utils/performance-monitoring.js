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
exports.withPerformanceMonitoring = withPerformanceMonitoring;
exports.flushPendingMetrics = flushPendingMetrics;
const admin = __importStar(require("firebase-admin"));
const firebase_functions_1 = require("firebase-functions");
/**
 * Batch buffer for API metrics (hourly batching to reduce Firestore writes)
 */
const metricsBuffer = [];
let lastFlushTime = Date.now();
const FLUSH_INTERVAL_MS = 60 * 60 * 1000; // 1 hour
/**
 * Log API metric to Firestore (batched hourly)
 */
async function logAPIMetric(functionName, durationMs, status, error) {
    const metric = {
        functionName,
        durationMs,
        status,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (error) {
        metric.errorCode = error.code || 'unknown';
        metric.errorMessage = error.message || String(error);
    }
    // Add to buffer
    metricsBuffer.push(metric);
    // Flush if interval exceeded or buffer is large
    const now = Date.now();
    if (now - lastFlushTime >= FLUSH_INTERVAL_MS || metricsBuffer.length >= 100) {
        await flushMetrics();
    }
}
/**
 * Flush metrics buffer to Firestore
 */
async function flushMetrics() {
    if (metricsBuffer.length === 0)
        return;
    try {
        const db = admin.firestore();
        const batch = db.batch();
        // Write all buffered metrics
        metricsBuffer.forEach((metric) => {
            const docRef = db.collection('api_metrics').doc();
            batch.set(docRef, metric);
        });
        await batch.commit();
        firebase_functions_1.logger.info(`Flushed ${metricsBuffer.length} API metrics to Firestore`);
        // Clear buffer
        metricsBuffer.length = 0;
        lastFlushTime = Date.now();
    }
    catch (error) {
        firebase_functions_1.logger.error('Failed to flush API metrics:', error);
        // Don't clear buffer on error - retry on next flush
    }
}
/**
 * Wraps a Cloud Function with performance monitoring
 *
 * @param fn - The async function to wrap
 * @param functionName - Name of the function for tracking
 * @returns Wrapped function with performance monitoring
 */
function withPerformanceMonitoring(fn, functionName) {
    return async (...args) => {
        const startTime = Date.now();
        try {
            const result = await fn(...args);
            const duration = Date.now() - startTime;
            // Log success metric
            await logAPIMetric(functionName, duration, 'success');
            firebase_functions_1.logger.info(`${functionName} completed in ${duration}ms`);
            return result;
        }
        catch (error) {
            const duration = Date.now() - startTime;
            // Log error metric
            await logAPIMetric(functionName, duration, 'error', error);
            firebase_functions_1.logger.error(`${functionName} failed after ${duration}ms:`, error);
            throw error;
        }
    };
}
/**
 * Force flush any pending metrics (useful for shutdown)
 */
async function flushPendingMetrics() {
    await flushMetrics();
}
//# sourceMappingURL=performance-monitoring.js.map