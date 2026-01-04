import * as admin from 'firebase-admin';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { MetricServiceClient } from '@google-cloud/monitoring';

/**
 * Internal handler function for collecting API metrics.
 * Exported separately for testing purposes.
 */
export async function collectAPIMetricsHandler() {
  console.log('Starting API metrics collection from Google Cloud Monitoring API...');
  if (!admin.apps.length) {
    admin.initializeApp();
  }
  
  const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || 'snapflow-4577d';
  const region = 'us-central1'; // Default Firebase Functions region
  
  // List of all Cloud Functions to monitor
  const functionNames = [
    // HTTP Callable Functions
    'retryProcessVideo',
    'retryProcessCaptions',
    'generateSignedUrl',
    'flagVideo',
    'ensureAdminRole',
    'revokeAdminRole',
    'assignAdminRole',
    
    // HTTP Request Functions
    'processCaptions', // HTTP function (onRequest) for Cloudinary webhook
    
    // Event-Triggered Functions
    'processVideoUpload',
    'sendPushNotification',
    'warmCDNCache',
    'onLikeCreate',
    'onCommentCreate',
    'onFollowCreate',
    
    // Scheduled Functions
    'aggregateUserAnalytics',
    'aggregateVideoAnalytics',
    'calculateTrendingVideos',
    'monitorStorageUsage',
    'collectCDNMetrics',
    'checkSystemAlerts',
    'systemHealthCheck',
    'aggregateAPIMetricsHourly',
  ];
  
  try {
    // Initialize Google Cloud Monitoring client
    const monitoring = new MetricServiceClient();
    
    // Calculate time range: last 24 hours
    const now = new Date();
    const yesterday = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    
    const interval = {
      endTime: {
        seconds: Math.floor(now.getTime() / 1000),
      },
      startTime: {
        seconds: Math.floor(yesterday.getTime() / 1000),
      },
    };
    
    console.log(`Querying metrics for project: ${projectId}, region: ${region}`);
    console.log(`Time range: ${yesterday.toISOString()} to ${now.toISOString()}`);
    console.log(`Monitoring ${functionNames.length} Cloud Functions`);
    
    const functionMetrics: Array<{
      name: string;
      avgResponseTimeMs: number;
      errorRate: number;
      totalCalls: number;
      p95ResponseTimeMs: number;
      errors: number;
    }> = [];
    
    // Collect metrics for each function
    for (const functionName of functionNames) {
      console.log(`\n--- Processing function: ${functionName} ---`);
      
      let totalCalls = 0;
      let errors = 0;
      let avgResponseTimeMs = 0;
      let p95ResponseTimeMs = 0;
      
      try {
        // Metric 1: Execution count
        const executionCountFilter = `
          metric.type="cloudfunctions.googleapis.com/function/execution_count" AND
          resource.type="cloud_function" AND
          resource.labels.function_name="${functionName}" AND
          resource.labels.region="${region}"
        `;
        
        try {
          const [executionCountResults] = await monitoring.listTimeSeries({
            name: `projects/${projectId}`,
            filter: executionCountFilter,
            interval: interval,
            aggregation: {
              alignmentPeriod: { seconds: 3600 }, // 1 hour
              perSeriesAligner: 'ALIGN_SUM',
              crossSeriesReducer: 'REDUCE_SUM',
            },
          });
          
          if (executionCountResults && executionCountResults.length > 0) {
            for (const series of executionCountResults) {
              if (series.points) {
                for (const point of series.points) {
                  if (point.value && point.value.int64Value) {
                    totalCalls += parseInt(String(point.value.int64Value));
                  }
                }
              }
            }
          } else {
            console.log(`  No execution count data available (function may not have been invoked)`);
          }
          console.log(`  Total calls: ${totalCalls}`);
        } catch (error) {
          console.warn(`  Failed to fetch execution count for ${functionName}:`, error instanceof Error ? error.message : String(error));
          // Continue with totalCalls = 0
        }
        
        // Metric 2: Error count
        const errorCountFilter = `
          metric.type="cloudfunctions.googleapis.com/function/error_count" AND
          resource.type="cloud_function" AND
          resource.labels.function_name="${functionName}" AND
          resource.labels.region="${region}"
        `;
        
        try {
          const [errorCountResults] = await monitoring.listTimeSeries({
            name: `projects/${projectId}`,
            filter: errorCountFilter,
            interval: interval,
            aggregation: {
              alignmentPeriod: { seconds: 3600 }, // 1 hour
              perSeriesAligner: 'ALIGN_SUM',
              crossSeriesReducer: 'REDUCE_SUM',
            },
          });
          
          if (errorCountResults && errorCountResults.length > 0) {
            for (const series of errorCountResults) {
              if (series.points) {
                for (const point of series.points) {
                  if (point.value && point.value.int64Value) {
                    errors += parseInt(String(point.value.int64Value));
                  }
                }
              }
            }
          } else {
            console.log(`  No error count data available (no errors recorded)`);
          }
          console.log(`  Errors: ${errors}`);
        } catch (error) {
          console.warn(`  Failed to fetch error count for ${functionName}:`, error instanceof Error ? error.message : String(error));
          // Continue with errors = 0
        }
        
        // Metric 3: Execution times (for average and p95)
        const executionTimesFilter = `
          metric.type="cloudfunctions.googleapis.com/function/execution_times" AND
          resource.type="cloud_function" AND
          resource.labels.function_name="${functionName}" AND
          resource.labels.region="${region}"
        `;
        
        try {
          // Get average execution time
          const [avgExecutionResults] = await monitoring.listTimeSeries({
            name: `projects/${projectId}`,
            filter: executionTimesFilter,
            interval: interval,
            aggregation: {
              alignmentPeriod: { seconds: 3600 }, // 1 hour
              // execution_times is a distribution metric; ALIGN_MEAN returns a doubleValue (seconds)
              perSeriesAligner: 'ALIGN_MEAN',
            },
          });
          
          let totalDuration = 0;
          let durationPoints = 0;
          
          if (avgExecutionResults && avgExecutionResults.length > 0) {
            for (const series of avgExecutionResults) {
              if (series.points) {
                for (const point of series.points) {
                  if (point.value && point.value.doubleValue !== undefined && point.value.doubleValue !== null) {
                    // Convert from seconds to milliseconds
                    totalDuration += point.value.doubleValue * 1000;
                    durationPoints++;
                  }
                }
              }
            }
          }
          
          if (durationPoints > 0) {
            avgResponseTimeMs = totalDuration / durationPoints;
          } else {
            console.log(`  No average response time data available`);
          }
          console.log(`  Avg response time: ${avgResponseTimeMs.toFixed(2)} ms`);
          
          // Get p95 execution time
          const [p95ExecutionResults] = await monitoring.listTimeSeries({
            name: `projects/${projectId}`,
            filter: executionTimesFilter,
            interval: interval,
            aggregation: {
              alignmentPeriod: { seconds: 3600 }, // 1 hour
              // For distribution metrics, use aligner percentiles (returns doubleValue in seconds)
              perSeriesAligner: 'ALIGN_PERCENTILE_95',
            },
          });
          
          let p95Duration = 0;
          let p95Points = 0;
          
          if (p95ExecutionResults && p95ExecutionResults.length > 0) {
            for (const series of p95ExecutionResults) {
              if (series.points) {
                for (const point of series.points) {
                  if (point.value && point.value.doubleValue !== undefined && point.value.doubleValue !== null) {
                    // Convert from seconds to milliseconds
                    p95Duration += point.value.doubleValue * 1000;
                    p95Points++;
                  }
                }
              }
            }
          }
          
          if (p95Points > 0) {
            p95ResponseTimeMs = p95Duration / p95Points;
          } else {
            console.log(`  No p95 response time data available`);
          }
          console.log(`  P95 response time: ${p95ResponseTimeMs.toFixed(2)} ms`);

          const maxReasonableMs = 15 * 60 * 1000; // 15 minutes
          if (!Number.isFinite(avgResponseTimeMs) || avgResponseTimeMs < 0 || avgResponseTimeMs > maxReasonableMs) {
            console.warn(`  ??  Invalid avg response time (${avgResponseTimeMs}); clamping to 0`);
            avgResponseTimeMs = 0;
          }
          if (!Number.isFinite(p95ResponseTimeMs) || p95ResponseTimeMs < 0 || p95ResponseTimeMs > maxReasonableMs) {
            console.warn(`  ??  Invalid p95 response time (${p95ResponseTimeMs}); clamping to 0`);
            p95ResponseTimeMs = 0;
          }
          
        } catch (error) {
          console.warn(`  Failed to fetch execution times for ${functionName}:`, error instanceof Error ? error.message : String(error));
          // Continue with avgResponseTimeMs = 0 and p95ResponseTimeMs = 0
        }
        
        // Calculate error rate (handle division by zero)
        const errorRate = totalCalls > 0 ? parseFloat((errors / totalCalls).toFixed(3)) : 0;
        console.log(`  Error rate: ${(errorRate * 100).toFixed(1)}%`);
        
        // Store function metrics (round all values to prevent floating point issues)
        functionMetrics.push({
          name: functionName,
          avgResponseTimeMs: parseFloat(avgResponseTimeMs.toFixed(2)),
          errorRate: errorRate,
          totalCalls: totalCalls,
          p95ResponseTimeMs: parseFloat(p95ResponseTimeMs.toFixed(2)),
          errors: errors,
        });
        
        // Log warning for functions with zero invocations in last 24 hours
        if (totalCalls === 0) {
          console.warn(`  ⚠️  Function has zero invocations in the last 24 hours`);
        }
        
        // Log warning for functions with high error rates
        if (errorRate > 0.05 && totalCalls > 10) { // > 5% error rate with significant traffic
          console.warn(`  ⚠️  High error rate detected: ${(errorRate * 100).toFixed(1)}%`);
        }
        
      } catch (error) {
        console.error(`  Error collecting metrics for ${functionName}:`, error);
        // Continue with other functions even if one fails
        // Store zero metrics for failed function to maintain data consistency
        functionMetrics.push({
          name: functionName,
          avgResponseTimeMs: 0,
          errorRate: 0,
          totalCalls: 0,
          p95ResponseTimeMs: 0,
          errors: 0,
        });
      }
    }
    
    console.log(`\n--- Metrics collection complete for ${functionMetrics.length} functions ---`);
    
    // Calculate overall metrics with proper edge case handling
    let overallTotalCalls = 0;
    let overallTotalErrors = 0;
    let overallTotalDuration = 0;
    let functionsWithCalls = 0;
    
    for (const metric of functionMetrics) {
      overallTotalCalls += metric.totalCalls;
      overallTotalErrors += metric.errors;
      if (metric.totalCalls > 0) {
        // Weight average response time by number of calls
        overallTotalDuration += metric.avgResponseTimeMs * metric.totalCalls;
        functionsWithCalls++;
      }
    }
    
    // Calculate weighted average response time (handle zero calls edge case)
    const overallAvgResponseTime = overallTotalCalls > 0 
      ? parseFloat((overallTotalDuration / overallTotalCalls).toFixed(2))
      : 0;
    
    // Calculate overall error rate (handle zero calls edge case)
    const overallErrorRate = overallTotalCalls > 0 
      ? parseFloat((overallTotalErrors / overallTotalCalls).toFixed(3))
      : 0;
    
    // Log warnings for edge cases
    if (overallTotalCalls === 0) {
      console.warn('\n⚠️  WARNING: No API calls detected across all Cloud Functions in the last 24 hours');
    }
    
    if (functionsWithCalls === 0) {
      console.warn('\n⚠️  WARNING: No Cloud Functions had any activity in the last 24 hours');
    }
    
    // Store API metrics in Firestore analytics collection
    // Data structure matches APIMetrics interface from snapflow-admin/lib/api/analytics.ts
    // Interface requires: functions[], overallAvgResponseTime, overallErrorRate, totalCalls, totalErrors, lastUpdated
    const metricsData = {
      functions: functionMetrics,
      overallAvgResponseTime: overallAvgResponseTime,
      overallErrorRate: overallErrorRate,
      totalCalls: overallTotalCalls,
      totalErrors: overallTotalErrors,
      lastUpdated: admin.firestore.Timestamp.fromDate(now),
    };
    
    // Validate metrics data before storing
    if (!Array.isArray(metricsData.functions) || metricsData.functions.length === 0) {
      console.error('⚠️  WARNING: No function metrics collected');
    }
    
    // Validate each function metric has required fields
    for (const funcMetric of metricsData.functions) {
      if (!funcMetric.name || 
          typeof funcMetric.avgResponseTimeMs !== 'number' ||
          typeof funcMetric.errorRate !== 'number' ||
          typeof funcMetric.totalCalls !== 'number' ||
          typeof funcMetric.p95ResponseTimeMs !== 'number' ||
          typeof funcMetric.errors !== 'number') {
        console.error(`⚠️  WARNING: Invalid metric structure for function: ${funcMetric.name}`);
      }
    }
    
    const apiMetricsDoc = {
      type: 'api_metrics',
      source: 'cloud_monitoring',
      period: 'daily',
      metrics: metricsData, // Nested structure for admin dashboard query (data.metrics)
      // Flatten metrics for easier querying and backward compatibility
      ...metricsData,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      timestamp: admin.firestore.Timestamp.fromDate(now),
      collectedAt: now.toISOString(),
    };
    
    await admin.firestore().collection('analytics').add(apiMetricsDoc);
    
    console.log('✅ API metrics successfully saved to Firestore analytics collection');
    
    console.log('\n=== API Metrics Summary ===');
    console.log(`Total functions monitored: ${functionNames.length}`);
    console.log(`Total API calls (24h): ${overallTotalCalls}`);
    console.log(`Total errors: ${overallTotalErrors}`);
    console.log(`Overall avg response time: ${overallAvgResponseTime.toFixed(2)} ms`);
    console.log(`Overall error rate: ${(overallErrorRate * 100).toFixed(2)}%`);
    console.log(`Functions with activity: ${functionsWithCalls}/${functionNames.length}`);
    console.log('API metrics saved to Firestore');
    console.log('===========================\n');
    
  } catch (error: unknown) {
    console.error('API metrics collection failed:', error);
    
    // Create error alert
    const errorMessage = error instanceof Error ? error.message : 'Unknown error';
    const errorString = error instanceof Error ? error.toString() : String(error);
    await admin.firestore().collection('admin_alerts').add({
      type: 'api_metrics_error',
      severity: 'error',
      message: `API metrics collection failed: ${errorMessage}`,
      error: errorString,
      acknowledged: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: new Date().toISOString(),
    });
    
    throw error;
  }
}

/**
 * Scheduled function to collect Cloud Functions performance metrics from Google Cloud Monitoring API.
 * Runs daily at 3:30 AM UTC to gather execution counts, response times, error rates, and p95 latency
 * for all deployed Cloud Functions.
 * 
 * Stores aggregated metrics in Firestore analytics collection for admin dashboard visualization.
 */
export const collectAPIMetrics = onSchedule({ 
  schedule: '30 3 * * *', 
  timeZone: 'UTC' 
}, collectAPIMetricsHandler);
