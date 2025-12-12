import * as admin from 'firebase-admin';
import { logger } from 'firebase-functions';

/**
 * Interface for API metric data
 */
interface APIMetric {
  functionName: string;
  durationMs: number;
  status: 'success' | 'error';
  errorCode?: string;
  errorMessage?: string;
  timestamp: admin.firestore.FieldValue;
}

/**
 * Batch buffer for API metrics (hourly batching to reduce Firestore writes)
 */
const metricsBuffer: APIMetric[] = [];
let lastFlushTime = Date.now();
const FLUSH_INTERVAL_MS = 60 * 60 * 1000; // 1 hour

/**
 * Log API metric to Firestore (batched hourly)
 */
async function logAPIMetric(
  functionName: string,
  durationMs: number,
  status: 'success' | 'error',
  error?: any
): Promise<void> {
  const metric: APIMetric = {
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
async function flushMetrics(): Promise<void> {
  if (metricsBuffer.length === 0) return;

  try {
    const db = admin.firestore();
    const batch = db.batch();

    // Write all buffered metrics
    metricsBuffer.forEach((metric) => {
      const docRef = db.collection('api_metrics').doc();
      batch.set(docRef, metric);
    });

    await batch.commit();
    logger.info(`Flushed ${metricsBuffer.length} API metrics to Firestore`);

    // Clear buffer
    metricsBuffer.length = 0;
    lastFlushTime = Date.now();
  } catch (error) {
    logger.error('Failed to flush API metrics:', error);
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
export function withPerformanceMonitoring<T>(
  fn: (...args: any[]) => Promise<T>,
  functionName: string
): (...args: any[]) => Promise<T> {
  return async (...args: any[]): Promise<T> => {
    const startTime = Date.now();
    
    try {
      const result = await fn(...args);
      const duration = Date.now() - startTime;
      
      // Log success metric
      await logAPIMetric(functionName, duration, 'success');
      
      logger.info(`${functionName} completed in ${duration}ms`);
      return result;
    } catch (error) {
      const duration = Date.now() - startTime;
      
      // Log error metric
      await logAPIMetric(functionName, duration, 'error', error);
      
      logger.error(`${functionName} failed after ${duration}ms:`, error);
      throw error;
    }
  };
}

/**
 * Force flush any pending metrics (useful for shutdown)
 */
export async function flushPendingMetrics(): Promise<void> {
  await flushMetrics();
}
