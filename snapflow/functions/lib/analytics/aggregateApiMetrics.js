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
exports.aggregateAPIMetricsHourly = void 0;
const admin = __importStar(require("firebase-admin"));
const scheduler_1 = require("firebase-functions/v2/scheduler");
exports.aggregateAPIMetricsHourly = (0, scheduler_1.onSchedule)({ schedule: '0 * * * *', timeZone: 'UTC' }, async () => {
    if (!admin.apps.length)
        admin.initializeApp();
    const db = admin.firestore();
    const now = Date.now();
    const oneHourAgo = new Date(now - 60 * 60 * 1000);
    const apiMetricsSnap = await db
        .collection('api_metrics')
        .where('timestamp', '>=', admin.firestore.Timestamp.fromDate(oneHourAgo))
        .get();
    if (apiMetricsSnap.size === 0) {
        return;
    }
    const functionMetrics = new Map();
    apiMetricsSnap.forEach((doc) => {
        const data = doc.data();
        const functionName = data.functionName;
        const duration = data.durationMs;
        const status = data.status;
        if (!functionMetrics.has(functionName)) {
            functionMetrics.set(functionName, { durations: [], errors: 0, totalCalls: 0 });
        }
        const metrics = functionMetrics.get(functionName);
        metrics.durations.push(duration);
        metrics.totalCalls++;
        if (status === 'error') {
            metrics.errors++;
        }
    });
    const functions = [];
    let totalDurations = [];
    let totalErrors = 0;
    let totalCalls = 0;
    functionMetrics.forEach((metrics, functionName) => {
        const avgResponseTimeMs = metrics.durations.reduce((sum, d) => sum + d, 0) / metrics.durations.length;
        const sortedDurations = [...metrics.durations].sort((a, b) => a - b);
        const p95Index = Math.floor(sortedDurations.length * 0.95);
        const p95ResponseTimeMs = sortedDurations[p95Index] || avgResponseTimeMs;
        const errorRate = metrics.errors / metrics.totalCalls;
        functions.push({
            name: functionName,
            avgResponseTimeMs: Math.round(avgResponseTimeMs),
            errorRate: Math.round(errorRate * 1000) / 1000,
            totalCalls: metrics.totalCalls,
            p95ResponseTimeMs: Math.round(p95ResponseTimeMs),
            errors: metrics.errors,
        });
        totalDurations.push(...metrics.durations);
        totalErrors += metrics.errors;
        totalCalls += metrics.totalCalls;
    });
    const overallAvgResponseTime = totalDurations.length > 0
        ? Math.round(totalDurations.reduce((sum, d) => sum + d, 0) / totalDurations.length)
        : 0;
    const overallErrorRate = totalCalls > 0 ? Math.round((totalErrors / totalCalls) * 1000) / 1000 : 0;
    await db.collection('analytics').add({
        type: 'api_metrics',
        source: 'firestore_aggregation',
        period: 'hourly',
        metrics: {
            functions: functions.sort((a, b) => b.totalCalls - a.totalCalls),
            overallAvgResponseTime,
            overallErrorRate,
            totalCalls,
            totalErrors,
        },
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        windowStart: admin.firestore.Timestamp.fromDate(oneHourAgo),
        windowEnd: admin.firestore.Timestamp.fromMillis(now),
    });
});
//# sourceMappingURL=aggregateApiMetrics.js.map