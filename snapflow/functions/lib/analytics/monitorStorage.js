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
exports.collectCDNMetrics = exports.monitorStorageUsage = void 0;
const admin = __importStar(require("firebase-admin"));
const scheduler_1 = require("firebase-functions/v2/scheduler");
const monitoring_1 = require("@google-cloud/monitoring");
const cloudinary_1 = require("cloudinary");
const cloudinary_2 = require("../utils/cloudinary");
async function fetchCloudinaryUsageSummary() {
    try {
        (0, cloudinary_2.configureCloudinary)();
    }
    catch (configError) {
        console.warn('Cloudinary credentials missing, skipping usage metrics.');
        return null;
    }
    try {
        const usage = await cloudinary_1.v2.api.usage();
        const usageRoot = usage?.usage ?? usage ?? {};
        const numberOrNull = (value) => {
            if (typeof value === 'number' && !Number.isNaN(value))
                return value;
            if (typeof value === 'string') {
                const parsed = Number(value);
                return Number.isNaN(parsed) ? null : parsed;
            }
            return null;
        };
        const bandwidthSection = usageRoot.bandwidth ?? usage?.bandwidth ?? {};
        const storageSection = usageRoot.storage ?? usage?.storage ?? {};
        const requestsSection = usageRoot.requests ?? usage?.requests ?? {};
        const resourcesSection = usageRoot.resources ?? usageRoot.objects ?? usage?.resources ?? usage?.objects ?? {};
        return {
            bandwidthBytes: numberOrNull(bandwidthSection.usage) ?? 0,
            bandwidthLimitBytes: numberOrNull(bandwidthSection.limit),
            storageBytes: numberOrNull(storageSection.usage) ?? 0,
            storageLimitBytes: numberOrNull(storageSection.limit),
            requests: numberOrNull(requestsSection.usage),
            resourceCount: numberOrNull(resourcesSection.usage ??
                resourcesSection.count ??
                resourcesSection.total ??
                resourcesSection) ?? null,
            usageUpdatedAt: usage?.last_updated ||
                usageRoot?.last_updated ||
                usage?.generated_at ||
                usageRoot?.generated_at ||
                null,
        };
    }
    catch (error) {
        console.warn('Failed to fetch Cloudinary usage metrics', error);
        return null;
    }
}
/**
 * Monitors storage usage across all buckets and generates daily metrics.
 *
 * Runs daily at 2 AM UTC via Cloud Scheduler.
 * Calculates total storage size, categorizes files by bucket type,
 * stores metrics in Firestore analytics collection, and creates admin alerts
 * if storage exceeds thresholds.
 *
 * Storage buckets monitored:
 * - raw-videos: Temporary raw uploads (lifecycle: 7 days + scheduled cleanup for failed/orphaned/stuck)
 * - thumbnails: Video thumbnails
 * - captions: VTT subtitle files
 * - profile-pictures: User profile images
 * Additionally, collects Cloudinary usage stats for Flow B (HLS on Cloudinary CDN).
 */
exports.monitorStorageUsage = (0, scheduler_1.onSchedule)({ schedule: '0 2 * * *', timeZone: 'UTC' }, async () => {
    console.log('Starting storage usage monitoring...');
    if (!admin.apps.length) {
        admin.initializeApp();
    }
    const bucket = admin.storage().bucket();
    let totalSize = 0;
    let totalFiles = 0;
    const bucketStats = {
        'raw-videos': { count: 0, size: 0 },
        'thumbnails': { count: 0, size: 0 },
        'captions': { count: 0, size: 0 },
        'profile-pictures': { count: 0, size: 0 },
        'other': { count: 0, size: 0 },
    };
    try {
        // Get all files from the bucket
        const [files] = await bucket.getFiles();
        console.log(`Processing ${files.length} files...`);
        files.forEach(file => {
            const size = parseInt(String(file.metadata.size || '0'));
            totalSize += size;
            totalFiles++;
            // Categorize by bucket prefix
            let categorized = false;
            for (const prefix of ['raw-videos', 'thumbnails', 'captions', 'profile-pictures']) {
                if (file.name.startsWith(prefix)) {
                    bucketStats[prefix].count++;
                    bucketStats[prefix].size += size;
                    categorized = true;
                    break;
                }
            }
            // Uncategorized files go to 'other'
            if (!categorized) {
                bucketStats['other'].count++;
                bucketStats['other'].size += size;
            }
        });
        const totalSizeGB = totalSize / (1024 ** 3);
        const totalSizeMB = totalSize / (1024 ** 2);
        console.log(`Storage analysis complete: ${totalSizeGB.toFixed(2)} GB, ${totalFiles} files`);
        // Convert bucket stats to GB for readability
        const bucketStatsGB = {};
        for (const [key, stats] of Object.entries(bucketStats)) {
            bucketStatsGB[key] = {
                count: stats.count,
                sizeGB: (stats.size / (1024 ** 3)).toFixed(2),
                sizeMB: (stats.size / (1024 ** 2)).toFixed(2),
            };
        }
        const cloudinaryUsage = await fetchCloudinaryUsageSummary();
        const bytesToGB = (bytes) => parseFloat((bytes / (1024 ** 3)).toFixed(3));
        const cloudinaryMetrics = cloudinaryUsage
            ? {
                bandwidthBytes: cloudinaryUsage.bandwidthBytes,
                bandwidthGB: bytesToGB(cloudinaryUsage.bandwidthBytes),
                bandwidthLimitBytes: cloudinaryUsage.bandwidthLimitBytes,
                bandwidthLimitGB: cloudinaryUsage.bandwidthLimitBytes !== null
                    ? bytesToGB(cloudinaryUsage.bandwidthLimitBytes)
                    : null,
                storageBytes: cloudinaryUsage.storageBytes,
                storageGB: bytesToGB(cloudinaryUsage.storageBytes),
                storageLimitBytes: cloudinaryUsage.storageLimitBytes,
                storageLimitGB: cloudinaryUsage.storageLimitBytes !== null
                    ? bytesToGB(cloudinaryUsage.storageLimitBytes)
                    : null,
                requests: cloudinaryUsage.requests,
                resourceCount: cloudinaryUsage.resourceCount,
                lastUpdated: cloudinaryUsage.usageUpdatedAt,
            }
            : null;
        // Store metrics in Firestore analytics collection
        await admin.firestore().collection('analytics').add({
            type: 'storage_metrics',
            totalSizeGB: parseFloat(totalSizeGB.toFixed(2)),
            totalSizeMB: parseFloat(totalSizeMB.toFixed(2)),
            totalFiles,
            bucketStats: bucketStatsGB,
            cloudinaryMetrics,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            collectedAt: new Date().toISOString(),
        });
        console.log('Storage metrics saved to Firestore');
        // Create alerts based on thresholds
        const alerts = [];
        // Alert if total storage exceeds 100 GB
        if (totalSizeGB > 100) {
            alerts.push({
                severity: 'warning',
                message: `Storage usage: ${totalSizeGB.toFixed(2)} GB exceeds 100 GB threshold`,
                threshold: 100,
            });
        }
        // Alert if total storage exceeds 500 GB (critical)
        if (totalSizeGB > 500) {
            alerts.push({
                severity: 'critical',
                message: `Storage usage: ${totalSizeGB.toFixed(2)} GB exceeds 500 GB critical threshold`,
                threshold: 500,
            });
        }
        // Alert if raw-videos folder has too many files (should be auto-deleted)
        if (bucketStats['raw-videos'].count > 1000) {
            alerts.push({
                severity: 'warning',
                message: `Raw videos folder has ${bucketStats['raw-videos'].count} files. Lifecycle policies may not be working.`,
                threshold: 1000,
            });
        }
        if (cloudinaryUsage) {
            const percentOf = (usageBytes, limitBytes) => {
                if (!limitBytes || limitBytes <= 0)
                    return null;
                return (usageBytes / limitBytes) * 100;
            };
            const bandwidthPercent = percentOf(cloudinaryUsage.bandwidthBytes, cloudinaryUsage.bandwidthLimitBytes);
            const storagePercent = percentOf(cloudinaryUsage.storageBytes, cloudinaryUsage.storageLimitBytes);
            if (bandwidthPercent && bandwidthPercent >= 95) {
                alerts.push({
                    severity: 'critical',
                    message: `Cloudinary bandwidth usage at ${bandwidthPercent.toFixed(1)}% of plan limit`,
                    threshold: Math.round(bandwidthPercent),
                });
            }
            else if (bandwidthPercent && bandwidthPercent >= 80) {
                alerts.push({
                    severity: 'warning',
                    message: `Cloudinary bandwidth usage at ${bandwidthPercent.toFixed(1)}% of plan limit`,
                    threshold: Math.round(bandwidthPercent),
                });
            }
            if (storagePercent && storagePercent >= 95) {
                alerts.push({
                    severity: 'critical',
                    message: `Cloudinary storage usage at ${storagePercent.toFixed(1)}% of plan limit`,
                    threshold: Math.round(storagePercent),
                });
            }
            else if (storagePercent && storagePercent >= 80) {
                alerts.push({
                    severity: 'warning',
                    message: `Cloudinary storage usage at ${storagePercent.toFixed(1)}% of plan limit`,
                    threshold: Math.round(storagePercent),
                });
            }
        }
        // Create admin alerts if any thresholds exceeded
        for (const alert of alerts) {
            await admin.firestore().collection('admin_alerts').add({
                type: 'storage_warning',
                severity: alert.severity,
                message: alert.message,
                threshold: alert.threshold,
                totalSizeGB: parseFloat(totalSizeGB.toFixed(2)),
                totalFiles,
                bucketStats: bucketStatsGB,
                acknowledged: false,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                createdAt: new Date().toISOString(),
            });
            console.log(`Created ${alert.severity} alert: ${alert.message}`);
        }
        // Log summary
        console.log('=== Storage Monitoring Summary ===');
        console.log(`Total Storage: ${totalSizeGB.toFixed(2)} GB (${totalSizeMB.toFixed(2)} MB)`);
        console.log(`Total Files: ${totalFiles}`);
        console.log('Breakdown by bucket:');
        for (const [key, stats] of Object.entries(bucketStatsGB)) {
            console.log(`  ${key}: ${stats.count} files, ${stats.sizeGB} GB`);
        }
        if (cloudinaryMetrics) {
            console.log(`Cloudinary Bandwidth (30d): ${cloudinaryMetrics.bandwidthGB} GB${cloudinaryMetrics.bandwidthLimitGB
                ? ` of ${cloudinaryMetrics.bandwidthLimitGB} GB`
                : ''}`);
            console.log(`Cloudinary Storage: ${cloudinaryMetrics.storageGB} GB${cloudinaryMetrics.storageLimitGB ? ` of ${cloudinaryMetrics.storageLimitGB} GB` : ''}`);
            console.log(`Cloudinary Requests (30d): ${cloudinaryMetrics.requests ?? 'unknown'} | Resources: ${cloudinaryMetrics.resourceCount ?? 'unknown'}`);
        }
        else {
            console.log('Cloudinary metrics: unavailable (credentials missing or API error).');
        }
        console.log(`Alerts created: ${alerts.length}`);
        console.log('==================================');
    }
    catch (error) {
        console.error('Storage monitoring failed:', error);
        // Create error alert
        const errorMessage = error instanceof Error ? error.message : 'Unknown error';
        const errorString = error instanceof Error ? error.toString() : String(error);
        await admin.firestore().collection('admin_alerts').add({
            type: 'storage_monitoring_error',
            severity: 'error',
            message: `Storage monitoring job failed: ${errorMessage}`,
            error: errorString,
            acknowledged: false,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            createdAt: new Date().toISOString(),
        });
        throw error;
    }
});
/**
 * Collects CDN bandwidth and performance metrics for Flow B delivery.
 *
 * Runs daily at 2:30 AM UTC via Cloud Scheduler (30 minutes after storage monitoring).
 * Data sources:
 * - Firebase Storage CDN: Google Cloud Monitoring API
 *   - storage.googleapis.com/api/request_count (download requests)
 *   - storage.googleapis.com/network/sent_bytes_count (bandwidth)
 *   - storage.googleapis.com/api/request_latencies (response times)
 * - Cloudinary CDN: Cloudinary Admin API (bandwidth + request counts)
 *   - Latency metrics are not available from Cloudinary Admin API
 *
 * Stores aggregated metrics in Firestore analytics collection with type 'cdn_metrics'.
 * This data powers the CDN Performance dashboard in the admin panel.
 *
 * Cost: FREE - Google Cloud Monitoring API provides 1M read calls/month free tier,
 * this function runs ~30 times/month (well under limit).
 */
exports.collectCDNMetrics = (0, scheduler_1.onSchedule)({ schedule: '30 2 * * *', timeZone: 'UTC' }, async () => {
    console.log('Starting CDN metrics collection from Google Cloud Monitoring API...');
    if (!admin.apps.length) {
        admin.initializeApp();
    }
    const firebaseConfig = process.env.FIREBASE_CONFIG ? JSON.parse(process.env.FIREBASE_CONFIG) : {};
    const projectId = process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || firebaseConfig.projectId || 'snapflow-4577d';
    const bucketName = firebaseConfig.storageBucket ||
        `${projectId}.firebasestorage.app` ||
        `${projectId}.appspot.com`;
    try {
        // Initialize Google Cloud Monitoring client
        const monitoring = new monitoring_1.MetricServiceClient();
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
        console.log(`Querying metrics for project: ${projectId}, bucket: ${bucketName}`);
        console.log(`Time range: ${yesterday.toISOString()} to ${now.toISOString()}`);
        // Metric 1: Request count (download requests)
        const requestCountFilter = `
        metric.type="storage.googleapis.com/api/request_count" AND
        resource.type="gcs_bucket" AND
        resource.labels.bucket_name="${bucketName}" AND
        metric.labels.method="ReadObject"
      `;
        let downloadRequests = 0;
        try {
            const [requestCountResults] = await monitoring.listTimeSeries({
                name: `projects/${projectId}`,
                filter: requestCountFilter,
                interval: interval,
                aggregation: {
                    alignmentPeriod: { seconds: 3600 }, // 1 hour
                    perSeriesAligner: 'ALIGN_SUM',
                    crossSeriesReducer: 'REDUCE_SUM',
                },
            });
            // Sum all data points
            if (requestCountResults && requestCountResults.length > 0) {
                for (const series of requestCountResults) {
                    if (series.points) {
                        for (const point of series.points) {
                            if (point.value && point.value.int64Value) {
                                downloadRequests += parseInt(String(point.value.int64Value));
                            }
                        }
                    }
                }
            }
            console.log(`Download requests: ${downloadRequests}`);
        }
        catch (error) {
            console.warn('Failed to fetch request count metrics:', error);
        }
        // Metric 2: Bandwidth (bytes sent)
        const bandwidthFilter = `
        metric.type="storage.googleapis.com/network/sent_bytes_count" AND
        resource.type="gcs_bucket" AND
        resource.labels.bucket_name="${bucketName}"
      `;
        let bandwidthBytes = 0;
        let peakBandwidthBytes = 0;
        let peakBandwidthTime = null;
        try {
            const [bandwidthResults] = await monitoring.listTimeSeries({
                name: `projects/${projectId}`,
                filter: bandwidthFilter,
                interval: interval,
                aggregation: {
                    alignmentPeriod: { seconds: 3600 }, // 1 hour
                    perSeriesAligner: 'ALIGN_SUM',
                    crossSeriesReducer: 'REDUCE_SUM',
                },
            });
            // Sum all data points and track peak
            if (bandwidthResults && bandwidthResults.length > 0) {
                for (const series of bandwidthResults) {
                    if (series.points) {
                        for (const point of series.points) {
                            if (point.value && point.value.int64Value) {
                                const bytes = parseInt(String(point.value.int64Value));
                                bandwidthBytes += bytes;
                                // Track peak bandwidth
                                if (bytes > peakBandwidthBytes) {
                                    peakBandwidthBytes = bytes;
                                    if (point.interval && point.interval.endTime && point.interval.endTime.seconds) {
                                        peakBandwidthTime = new Date(parseInt(String(point.interval.endTime.seconds)) * 1000);
                                    }
                                }
                            }
                        }
                    }
                }
            }
            console.log(`Total bandwidth: ${(bandwidthBytes / (1024 ** 3)).toFixed(2)} GB`);
            console.log(`Peak bandwidth: ${(peakBandwidthBytes / (1024 ** 3)).toFixed(2)} GB at ${peakBandwidthTime?.toISOString() || 'unknown'}`);
        }
        catch (error) {
            console.warn('Failed to fetch bandwidth metrics:', error);
        }
        // Metric 3: Response time / latencies
        const latencyFilter = `
        metric.type="storage.googleapis.com/api/request_latencies" AND
        resource.type="gcs_bucket" AND
        resource.labels.bucket_name="${bucketName}" AND
        metric.labels.method="ReadObject"
      `;
        let averageResponseTimeMs = 0;
        let totalLatencyPoints = 0;
        try {
            const [latencyResults] = await monitoring.listTimeSeries({
                name: `projects/${projectId}`,
                filter: latencyFilter,
                interval: interval,
                aggregation: {
                    alignmentPeriod: { seconds: 3600 }, // 1 hour
                    perSeriesAligner: 'ALIGN_DELTA',
                    crossSeriesReducer: 'REDUCE_MEAN',
                },
            });
            // Calculate average latency
            if (latencyResults && latencyResults.length > 0) {
                for (const series of latencyResults) {
                    if (series.points) {
                        for (const point of series.points) {
                            if (point.value && point.value.doubleValue !== undefined && point.value.doubleValue !== null) {
                                averageResponseTimeMs += point.value.doubleValue;
                                totalLatencyPoints++;
                            }
                        }
                    }
                }
            }
            if (totalLatencyPoints > 0) {
                averageResponseTimeMs = averageResponseTimeMs / totalLatencyPoints;
            }
            console.log(`Average response time: ${averageResponseTimeMs.toFixed(2)} ms`);
        }
        catch (error) {
            console.warn('Failed to fetch latency metrics:', error);
        }
        const bandwidthGB = bandwidthBytes / (1024 ** 3);
        const peakBandwidthGB = peakBandwidthBytes / (1024 ** 3);
        const bytesToGB = (bytes) => parseFloat((bytes / (1024 ** 3)).toFixed(3));
        const cloudinaryUsage = await fetchCloudinaryUsageSummary();
        if (!cloudinaryUsage) {
            console.warn('Cloudinary CDN metrics unavailable (Admin API returned null).');
            await admin.firestore().collection('admin_alerts').add({
                type: 'cdn_metrics_warning',
                severity: 'warning',
                message: 'Cloudinary CDN metrics unavailable; review Cloudinary Admin API credentials or rate limits.',
                acknowledged: false,
                timestamp: admin.firestore.FieldValue.serverTimestamp(),
                createdAt: new Date().toISOString(),
            });
        }
        const cloudinaryBandwidthGB = cloudinaryUsage ? bytesToGB(cloudinaryUsage.bandwidthBytes) : 0;
        const firebaseBandwidthGB = parseFloat(bandwidthGB.toFixed(3));
        const totalBandwidthBytes = bandwidthBytes + (cloudinaryUsage?.bandwidthBytes ?? 0);
        const totalBandwidthGB = parseFloat((firebaseBandwidthGB + cloudinaryBandwidthGB).toFixed(3));
        const totalRequests = downloadRequests + (cloudinaryUsage?.requests ?? 0);
        const cloudinaryProviderMetrics = cloudinaryUsage
            ? {
                bandwidthBytes: cloudinaryUsage.bandwidthBytes,
                bandwidthGB: cloudinaryBandwidthGB,
                bandwidthLimitBytes: cloudinaryUsage.bandwidthLimitBytes,
                bandwidthLimitGB: cloudinaryUsage.bandwidthLimitBytes !== null
                    ? bytesToGB(cloudinaryUsage.bandwidthLimitBytes)
                    : null,
                requests: cloudinaryUsage.requests,
                resourceCount: cloudinaryUsage.resourceCount,
                lastUpdated: cloudinaryUsage.usageUpdatedAt,
                dataAvailable: true,
                dataSource: 'cloudinary_admin_api',
            }
            : {
                bandwidthBytes: null,
                bandwidthGB: null,
                bandwidthLimitBytes: null,
                bandwidthLimitGB: null,
                requests: null,
                resourceCount: null,
                lastUpdated: null,
                dataAvailable: false,
                dataSource: 'cloudinary_admin_api',
            };
        const cdnMetrics = {
            type: 'cdn_metrics',
            period: 'daily',
            providers: {
                firebase_storage: {
                    bandwidthBytes,
                    bandwidthGB: firebaseBandwidthGB,
                    downloadRequests,
                    averageResponseTimeMs: parseFloat(averageResponseTimeMs.toFixed(2)),
                    peakBandwidthGB: parseFloat(peakBandwidthGB.toFixed(3)),
                    peakBandwidthTime: peakBandwidthTime ? admin.firestore.Timestamp.fromDate(peakBandwidthTime) : null,
                    metricsCollectedAt: admin.firestore.Timestamp.fromDate(now),
                    dataSource: 'google_cloud_monitoring',
                },
                cloudinary: cloudinaryProviderMetrics,
            },
            totalBandwidthBytes,
            totalBandwidthGB,
            totalRequests,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            collectedAt: now.toISOString(),
        };
        await admin.firestore().collection('analytics').add(cdnMetrics);
        console.log('CDN metrics saved to Firestore');
        console.log('=== CDN Metrics Summary ===');
        console.log('Firebase Storage CDN:');
        console.log(`  Bandwidth (24h): ${firebaseBandwidthGB.toFixed(3)} GB`);
        console.log(`  Download Requests: ${downloadRequests}`);
        console.log(`  Average Response Time: ${averageResponseTimeMs.toFixed(2)} ms`);
        console.log(`  Peak Bandwidth: ${peakBandwidthGB.toFixed(3)} GB at ${peakBandwidthTime?.toISOString() || 'N/A'}`);
        if (cloudinaryUsage) {
            console.log('Cloudinary CDN:');
            console.log(`  Bandwidth (30d): ${cloudinaryBandwidthGB.toFixed(3)} GB`);
            console.log(`  Requests (30d): ${cloudinaryUsage.requests ?? 'N/A'}`);
        }
        else {
            console.log('Cloudinary CDN: metrics unavailable (see warning above).');
        }
        console.log(`Total Combined Bandwidth: ${totalBandwidthGB.toFixed(3)} GB`);
        console.log('===========================');
    }
    catch (error) {
        console.error('CDN metrics collection failed:', error);
        // Create error alert
        const errorMessage = error instanceof Error ? error.message : 'Unknown error';
        const errorString = error instanceof Error ? error.toString() : String(error);
        await admin.firestore().collection('admin_alerts').add({
            type: 'cdn_metrics_error',
            severity: 'error',
            message: `CDN metrics collection failed: ${errorMessage}`,
            error: errorString,
            acknowledged: false,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            createdAt: new Date().toISOString(),
        });
        throw error;
    }
});
//# sourceMappingURL=monitorStorage.js.map