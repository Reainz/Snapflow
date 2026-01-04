import { collection, query, where, orderBy, limit, getDocs, Timestamp } from 'firebase/firestore';
import { db } from '@/lib/firebase/config';
import { auth } from '@/lib/firebase/config';
import { Alert } from './alerts';

// Types
export interface BucketStats {
  count: number;
  sizeGB: string;
  sizeMB: string;
}

export interface StorageMetrics {
  id: string;
  type: 'storage_metrics';
  totalSizeGB: number;
  totalSizeMB: number;
  totalFiles: number;
  bucketStats: {
    'raw-videos': BucketStats;
    'thumbnails': BucketStats;
    'captions': BucketStats;
    'profile-pictures': BucketStats;
    'other': BucketStats;
  };
  cloudinaryMetrics?: {
    bandwidthBytes: number;
    bandwidthGB: number;
    bandwidthLimitBytes: number | null;
    bandwidthLimitGB: number | null;
    storageBytes: number;
    storageGB: number;
    storageLimitBytes: number | null;
    storageLimitGB: number | null;
    requests: number | null;
    resourceCount: number | null;
    lastUpdated: string | null;
  } | null;
  timestamp: Date;
  collectedAt: string;
  isComputed?: boolean;
}

export interface StorageMetricsHistory {
  date: string;
  totalSizeGB: number;
  totalFiles: number;
  timestamp: Date;
}

/**
 * Get the most recent storage metrics document from Firestore.
 * Uses server-side API to bypass client security rules.
 * 
 * @returns Latest storage metrics or null if none found
 */
export async function getLatestStorageMetrics(): Promise<StorageMetrics | null> {
  try {
    // Get the current user's token for authentication
    const user = auth.currentUser;
    if (!user) {
      throw new Error('Not authenticated');
    }
    
    const token = await user.getIdToken();
    
    // Call server-side API that uses Firebase Admin SDK
    const response = await fetch('/api/metrics/storage', {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: 'Unknown error' }));
      throw new Error(error.error || 'Failed to load storage metrics');
    }

    const data = await response.json();
    
    return {
      ...data,
      timestamp: new Date(data.timestamp),
    };
  } catch (error) {
    console.error('Error fetching latest storage metrics:', error);
    throw error;
  }
}

/**
 * Get historical storage metrics for chart display.
 * Uses server-side API to bypass client security rules.
 * 
 * @param startDate Start date for historical data (defaults to 30 days ago)
 * @param endDate End date for historical data (defaults to now)
 * @returns Array of historical storage data points
 */
export async function getStorageMetricsHistory(
  startDate?: Date,
  endDate?: Date
): Promise<StorageMetricsHistory[]> {
  try {
    // Get the current user's token for authentication
    const user = auth.currentUser;
    if (!user) {
      throw new Error('Not authenticated');
    }
    
    const token = await user.getIdToken();
    
    // Default to last 30 days if not specified
    const start = startDate || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
    const end = endDate || new Date();
    
    // Call server-side API
    const response = await fetch(
      `/api/metrics/storage/history?start=${start.toISOString()}&end=${end.toISOString()}`,
      {
        method: 'GET',
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json',
        },
      }
    );

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: 'Unknown error' }));
      throw new Error(error.error || 'Failed to load storage history');
    }

    const data = await response.json();
    
    // Convert timestamp strings back to Date objects
    return data.map((item: any) => ({
      ...item,
      timestamp: new Date(item.timestamp),
    }));
  } catch (error) {
    console.error('Error fetching storage metrics history:', error);
    throw error;
  }
}

async function computeStorageMetricsFallback(
  cloudinaryFromCdn?: StorageMetrics['cloudinaryMetrics']
): Promise<StorageMetrics> {
  const timestamp = new Date();
  return {
    id: 'computed',
    type: 'storage_metrics',
    totalSizeGB: 0,
    totalSizeMB: 0,
    totalFiles: 0,
    bucketStats: {
      'raw-videos': { count: 0, sizeGB: '0.00', sizeMB: '0.00' },
      'thumbnails': { count: 0, sizeGB: '0.00', sizeMB: '0.00' },
      'captions': { count: 0, sizeGB: '0.00', sizeMB: '0.00' },
      'profile-pictures': { count: 0, sizeGB: '0.00', sizeMB: '0.00' },
      'other': { count: 0, sizeGB: '0.00', sizeMB: '0.00' },
    },
    cloudinaryMetrics: cloudinaryFromCdn ?? null,
    timestamp,
    collectedAt: timestamp.toISOString(),
    isComputed: true,
  };
}

async function getCloudinaryMetricsFromCdn(): Promise<StorageMetrics['cloudinaryMetrics']> {
  try {
    const snap = await getDocs(
      query(
        collection(db, 'analytics'),
        where('type', '==', 'cdn_metrics'),
        orderBy('timestamp', 'desc'),
        limit(1)
      )
    );
    if (snap.empty) return null;
    const data = snap.docs[0].data();
    const provider = data.providers?.cloudinary;
    if (!provider || provider.dataAvailable === false) return null;

    const toDate = (value: any) => (value?.toDate?.() ? value.toDate() : null);

    return {
      bandwidthBytes: provider.bandwidthBytes ?? null,
      bandwidthGB: provider.bandwidthGB ?? null,
      bandwidthLimitBytes: provider.bandwidthLimitBytes ?? null,
      bandwidthLimitGB: provider.bandwidthLimitGB ?? null,
      storageBytes: provider.storageBytes ?? 0,
      storageGB: provider.storageGB ?? 0,
      storageLimitBytes: provider.storageLimitBytes ?? null,
      storageLimitGB: provider.storageLimitGB ?? null,
      requests: provider.requests ?? null,
      resourceCount: provider.resourceCount ?? null,
      lastUpdated:
        toDate(provider.metricsCollectedAt)?.toISOString() ||
        toDate(provider.peakBandwidthTime)?.toISOString() ||
        provider.lastUpdated ||
        null,
    };
  } catch (error) {
    console.warn('Unable to hydrate Cloudinary metrics from CDN analytics.', error);
    return null;
  }
}

/**
 * Get storage alerts from admin_alerts collection.
 * Uses server-side API to bypass client security rules.
 * 
 * @param acknowledged Filter by acknowledged status (optional)
 * @returns Array of storage-related alerts
 */
export async function getStorageAlerts(acknowledged?: boolean): Promise<Alert[]> {
  try {
    // Get the current user's token for authentication
    const user = auth.currentUser;
    if (!user) {
      throw new Error('Not authenticated');
    }
    
    const token = await user.getIdToken();
    
    // Build URL with optional acknowledged filter
    let url = '/api/alerts/storage';
    if (acknowledged !== undefined) {
      url += `?acknowledged=${acknowledged}`;
    }
    
    // Call server-side API that uses Firebase Admin SDK
    const response = await fetch(url, {
      method: 'GET',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
    });

    if (!response.ok) {
      const error = await response.json().catch(() => ({ error: 'Unknown error' }));
      throw new Error(error.error || 'Failed to load storage alerts');
    }

    const alerts = await response.json();
    
    // Convert ISO date strings back to Date objects
    return alerts.map((alert: any) => ({
      ...alert,
      createdAt: alert.createdAt ? new Date(alert.createdAt) : null,
    }));
  } catch (error) {
    console.error('Error fetching storage alerts:', error);
    throw error;
  }
}

