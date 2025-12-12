import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';

type FunctionMetricAccumulator = {
  durations: number[];
  errors: number;
  totalCalls: number;
};

export const aggregateAPIMetricsHourly = onSchedule({ schedule: '0 * * * *', timeZone: 'UTC' }, async () => {
  if (!admin.apps.length) admin.initializeApp();
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

  const functionMetrics = new Map<string, FunctionMetricAccumulator>();

  apiMetricsSnap.forEach((doc) => {
    const data = doc.data();
    const functionName = data.functionName as string;
    const duration = data.durationMs as number;
    const status = data.status as 'success' | 'error';

    if (!functionMetrics.has(functionName)) {
      functionMetrics.set(functionName, { durations: [], errors: 0, totalCalls: 0 });
    }

    const metrics = functionMetrics.get(functionName)!;
    metrics.durations.push(duration);
    metrics.totalCalls++;
    if (status === 'error') {
      metrics.errors++;
    }
  });

  const functions: Array<{
    name: string;
    avgResponseTimeMs: number;
    errorRate: number;
    totalCalls: number;
    p95ResponseTimeMs: number;
    errors: number;
  }> = [];

  let totalDurations: number[] = [];
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

  const overallAvgResponseTime =
    totalDurations.length > 0
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
