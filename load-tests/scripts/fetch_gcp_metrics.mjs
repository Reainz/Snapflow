// Fetch Google Cloud Monitoring metrics for auto-scaling benchmark analysis
// Usage: node fetch_gcp_metrics.mjs --start-time="2026-01-05T12:00:00Z" --end-time="2026-01-05T13:00:00Z"

import process from 'node:process';
import { MetricServiceClient } from '@google-cloud/monitoring';

const PROJECT_ID = process.env.FIREBASE_PROJECT_ID || process.env.GCLOUD_PROJECT || 'snapflow-4577d';
const REGION = 'us-central1';

/**
 * Parse command line arguments
 */
function parseArgs() {
  const args = {};
  for (let i = 0; i < process.argv.length; i++) {
    if (process.argv[i].startsWith('--')) {
      const key = process.argv[i].slice(2);
      const value = process.argv[i + 1];
      if (value && !value.startsWith('--')) {
        args[key] = value;
      } else {
        args[key] = true;
      }
    }
  }
  return args;
}

/**
 * Fetch Cloud Functions execution metrics
 */
async function fetchCloudFunctionsMetrics(monitoring, startTime, endTime) {
  const functionNames = [
    'ensureAdminRole',
    'generateSignedUrl',
    'retryProcessVideo',
    'processVideoUpload',
    'sendPushNotification',
  ];

  const metrics = {
    executionCount: {},
    executionTime: {},
    errorCount: {},
    concurrentExecutions: {},
  };

  for (const functionName of functionNames) {
    try {
      // Execution count
      const executionCountFilter = `
        metric.type="cloudfunctions.googleapis.com/function/execution_count" AND
        resource.type="cloud_function" AND
        resource.labels.function_name="${functionName}" AND
        resource.labels.region="${REGION}"
      `;

      const [executionCountResults] = await monitoring.listTimeSeries({
        name: `projects/${PROJECT_ID}`,
        filter: executionCountFilter,
        interval: {
          startTime: { seconds: Math.floor(startTime.getTime() / 1000) },
          endTime: { seconds: Math.floor(endTime.getTime() / 1000) },
        },
        aggregation: {
          alignmentPeriod: { seconds: 60 }, // 1-minute intervals
          perSeriesAligner: 'ALIGN_RATE',
          crossSeriesReducer: 'REDUCE_SUM',
        },
      });

      let totalExecutions = 0;
      if (executionCountResults && executionCountResults.length > 0) {
        for (const series of executionCountResults) {
          if (series.points) {
            for (const point of series.points) {
              if (point.value?.int64Value) {
                totalExecutions += parseInt(String(point.value.int64Value));
              }
            }
          }
        }
      }
      metrics.executionCount[functionName] = totalExecutions;

      // Average execution time
      const executionTimeFilter = `
        metric.type="cloudfunctions.googleapis.com/function/execution_times" AND
        resource.type="cloud_function" AND
        resource.labels.function_name="${functionName}" AND
        resource.labels.region="${REGION}"
      `;

      const [executionTimeResults] = await monitoring.listTimeSeries({
        name: `projects/${PROJECT_ID}`,
        filter: executionTimeFilter,
        interval: {
          startTime: { seconds: Math.floor(startTime.getTime() / 1000) },
          endTime: { seconds: Math.floor(endTime.getTime() / 1000) },
        },
        aggregation: {
          alignmentPeriod: { seconds: 60 },
          perSeriesAligner: 'ALIGN_MEAN',
          crossSeriesReducer: 'REDUCE_MEAN',
        },
      });

      let avgExecutionTime = 0;
      if (executionTimeResults && executionTimeResults.length > 0) {
        const times = [];
        for (const series of executionTimeResults) {
          if (series.points) {
            for (const point of series.points) {
              if (point.value?.doubleValue) {
                times.push(point.value.doubleValue);
              }
            }
          }
        }
        if (times.length > 0) {
          avgExecutionTime = times.reduce((a, b) => a + b, 0) / times.length;
        }
      }
      metrics.executionTime[functionName] = avgExecutionTime;

      // Error count
      const errorCountFilter = `
        metric.type="cloudfunctions.googleapis.com/function/error_count" AND
        resource.type="cloud_function" AND
        resource.labels.function_name="${functionName}" AND
        resource.labels.region="${REGION}"
      `;

      const [errorCountResults] = await monitoring.listTimeSeries({
        name: `projects/${PROJECT_ID}`,
        filter: errorCountFilter,
        interval: {
          startTime: { seconds: Math.floor(startTime.getTime() / 1000) },
          endTime: { seconds: Math.floor(endTime.getTime() / 1000) },
        },
        aggregation: {
          alignmentPeriod: { seconds: 60 },
          perSeriesAligner: 'ALIGN_RATE',
          crossSeriesReducer: 'REDUCE_SUM',
        },
      });

      let totalErrors = 0;
      if (errorCountResults && errorCountResults.length > 0) {
        for (const series of errorCountResults) {
          if (series.points) {
            for (const point of series.points) {
              if (point.value?.int64Value) {
                totalErrors += parseInt(String(point.value.int64Value));
              }
            }
          }
        }
      }
      metrics.errorCount[functionName] = totalErrors;

      // Concurrent executions (peak)
      const concurrentFilter = `
        metric.type="cloudfunctions.googleapis.com/function/execution_count" AND
        resource.type="cloud_function" AND
        resource.labels.function_name="${functionName}" AND
        resource.labels.region="${REGION}"
      `;

      const [concurrentResults] = await monitoring.listTimeSeries({
        name: `projects/${PROJECT_ID}`,
        filter: concurrentFilter,
        interval: {
          startTime: { seconds: Math.floor(startTime.getTime() / 1000) },
          endTime: { seconds: Math.floor(endTime.getTime() / 1000) },
        },
        aggregation: {
          alignmentPeriod: { seconds: 60 },
          perSeriesAligner: 'ALIGN_MAX',
          crossSeriesReducer: 'REDUCE_MAX',
        },
      });

      let maxConcurrent = 0;
      if (concurrentResults && concurrentResults.length > 0) {
        for (const series of concurrentResults) {
          if (series.points) {
            for (const point of series.points) {
              if (point.value?.int64Value) {
                maxConcurrent = Math.max(maxConcurrent, parseInt(String(point.value.int64Value)));
              }
            }
          }
        }
      }
      metrics.concurrentExecutions[functionName] = maxConcurrent;

    } catch (error) {
      console.warn(`Failed to fetch metrics for ${functionName}:`, error.message);
    }
  }

  return metrics;
}

/**
 * Fetch Firestore metrics
 */
async function fetchFirestoreMetrics(monitoring, startTime, endTime) {
  const metrics = {
    documentReads: 0,
    documentWrites: 0,
    documentDeletes: 0,
  };

  try {
    // Document reads
    const readFilter = `
      metric.type="firestore.googleapis.com/document/read_count" AND
      resource.type="firestore_database"
    `;

    const [readResults] = await monitoring.listTimeSeries({
      name: `projects/${PROJECT_ID}`,
      filter: readFilter,
      interval: {
        startTime: { seconds: Math.floor(startTime.getTime() / 1000) },
        endTime: { seconds: Math.floor(endTime.getTime() / 1000) },
      },
      aggregation: {
        alignmentPeriod: { seconds: 60 },
        perSeriesAligner: 'ALIGN_RATE',
        crossSeriesReducer: 'REDUCE_SUM',
      },
    });

    if (readResults && readResults.length > 0) {
      for (const series of readResults) {
        if (series.points) {
          for (const point of series.points) {
            if (point.value?.int64Value) {
              metrics.documentReads += parseInt(String(point.value.int64Value));
            }
          }
        }
      }
    }

    // Document writes
    const writeFilter = `
      metric.type="firestore.googleapis.com/document/write_count" AND
      resource.type="firestore_database"
    `;

    const [writeResults] = await monitoring.listTimeSeries({
      name: `projects/${PROJECT_ID}`,
      filter: writeFilter,
      interval: {
        startTime: { seconds: Math.floor(startTime.getTime() / 1000) },
        endTime: { seconds: Math.floor(endTime.getTime() / 1000) },
      },
      aggregation: {
        alignmentPeriod: { seconds: 60 },
        perSeriesAligner: 'ALIGN_RATE',
        crossSeriesReducer: 'REDUCE_SUM',
      },
    });

    if (writeResults && writeResults.length > 0) {
      for (const series of writeResults) {
        if (series.points) {
          for (const point of series.points) {
            if (point.value?.int64Value) {
              metrics.documentWrites += parseInt(String(point.value.int64Value));
            }
          }
        }
      }
    }

  } catch (error) {
    console.warn('Failed to fetch Firestore metrics:', error.message);
  }

  return metrics;
}

/**
 * Fetch Cloud Run metrics (if admin dashboard is deployed on Cloud Run)
 */
async function fetchCloudRunMetrics(monitoring, startTime, endTime) {
  const metrics = {
    requestCount: 0,
    instanceCount: 0,
    requestLatency: 0,
  };

  // Note: This assumes admin dashboard might be on Cloud Run
  // Adjust service name if different
  const serviceName = 'snapflow-admin'; // Adjust if needed

  try {
    // Request count
    const requestFilter = `
      metric.type="run.googleapis.com/request_count" AND
      resource.type="cloud_run_revision" AND
      resource.labels.service_name="${serviceName}"
    `;

    const [requestResults] = await monitoring.listTimeSeries({
      name: `projects/${PROJECT_ID}`,
      filter: requestFilter,
      interval: {
        startTime: { seconds: Math.floor(startTime.getTime() / 1000) },
        endTime: { seconds: Math.floor(endTime.getTime() / 1000) },
      },
      aggregation: {
        alignmentPeriod: { seconds: 60 },
        perSeriesAligner: 'ALIGN_RATE',
        crossSeriesReducer: 'REDUCE_SUM',
      },
    });

    if (requestResults && requestResults.length > 0) {
      for (const series of requestResults) {
        if (series.points) {
          for (const point of series.points) {
            if (point.value?.int64Value) {
              metrics.requestCount += parseInt(String(point.value.int64Value));
            }
          }
        }
      }
    }

    // Instance count (scaling indicator)
    const instanceFilter = `
      metric.type="run.googleapis.com/container/instance_count" AND
      resource.type="cloud_run_revision" AND
      resource.labels.service_name="${serviceName}"
    `;

    const [instanceResults] = await monitoring.listTimeSeries({
      name: `projects/${PROJECT_ID}`,
      filter: instanceFilter,
      interval: {
        startTime: { seconds: Math.floor(startTime.getTime() / 1000) },
        endTime: { seconds: Math.floor(endTime.getTime() / 1000) },
      },
      aggregation: {
        alignmentPeriod: { seconds: 60 },
        perSeriesAligner: 'ALIGN_MAX',
        crossSeriesReducer: 'REDUCE_MAX',
      },
    });

    if (instanceResults && instanceResults.length > 0) {
      let maxInstances = 0;
      for (const series of instanceResults) {
        if (series.points) {
          for (const point of series.points) {
            if (point.value?.int64Value) {
              maxInstances = Math.max(maxInstances, parseInt(String(point.value.int64Value)));
            }
          }
        }
      }
      metrics.instanceCount = maxInstances;
    }

  } catch (error) {
    console.warn('Failed to fetch Cloud Run metrics (may not be applicable):', error.message);
  }

  return metrics;
}

/**
 * Main function
 */
async function main() {
  const args = parseArgs();

  if (!args['start-time'] || !args['end-time']) {
    console.error('Usage: node fetch_gcp_metrics.mjs --start-time="ISO8601" --end-time="ISO8601"');
    console.error('Example: node fetch_gcp_metrics.mjs --start-time="2026-01-05T12:00:00Z" --end-time="2026-01-05T13:00:00Z"');
    process.exit(1);
  }

  const startTime = new Date(args['start-time']);
  const endTime = new Date(args['end-time']);

  if (isNaN(startTime.getTime()) || isNaN(endTime.getTime())) {
    console.error('Invalid date format. Use ISO8601 format (e.g., 2026-01-05T12:00:00Z)');
    process.exit(1);
  }

  console.log(`Fetching GCP metrics for project: ${PROJECT_ID}`);
  console.log(`Time range: ${startTime.toISOString()} to ${endTime.toISOString()}`);

  try {
    const monitoring = new MetricServiceClient();

    console.log('\n📊 Fetching Cloud Functions metrics...');
    const cloudFunctionsMetrics = await fetchCloudFunctionsMetrics(monitoring, startTime, endTime);

    console.log('\n📊 Fetching Firestore metrics...');
    const firestoreMetrics = await fetchFirestoreMetrics(monitoring, startTime, endTime);

    console.log('\n📊 Fetching Cloud Run metrics...');
    const cloudRunMetrics = await fetchCloudRunMetrics(monitoring, startTime, endTime);

    const report = {
      projectId: PROJECT_ID,
      timeRange: {
        start: startTime.toISOString(),
        end: endTime.toISOString(),
        durationSeconds: Math.floor((endTime - startTime) / 1000),
      },
      cloudFunctions: cloudFunctionsMetrics,
      firestore: firestoreMetrics,
      cloudRun: cloudRunMetrics,
      timestamp: new Date().toISOString(),
    };

    // Output JSON to stdout
    console.log('\n✅ Metrics collected successfully!\n');
    console.log(JSON.stringify(report, null, 2));

  } catch (error) {
    console.error('❌ Error fetching metrics:', error.message);
    console.error(error.stack);
    process.exit(1);
  }
}

main().catch((err) => {
  console.error('Fatal error:', err);
  process.exit(1);
});
