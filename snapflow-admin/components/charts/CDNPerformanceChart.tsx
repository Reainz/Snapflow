'use client';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { CDNMetrics } from '@/lib/api/analytics';
import { HardDrive, Download, Zap, TrendingUp } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { formatDate } from '@/lib/utils';

interface CDNPerformanceChartProps {
  data: CDNMetrics | null | undefined;
  dateFormat?: string;
}

export default function CDNPerformanceChart({ data, dateFormat = 'MM/DD/YYYY' }: CDNPerformanceChartProps) {
  if (!data || data.hasData === false) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>CDN Performance</CardTitle>
          <CardDescription>Content delivery network metrics</CardDescription>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">
            No CDN data available yet. Ensure analytics jobs are running and Cloudinary/Firebase metrics are collected.
          </p>
        </CardContent>
      </Card>
    );
  }

  const formatBandwidth = (gb: number): string => {
    if (gb >= 1) {
      return `${gb.toFixed(2)} GB`;
    }
    return `${(gb * 1024).toFixed(0)} MB`;
  };

  const formatResponseTime = (ms: number): string => {
    if (ms >= 1000) {
      return `${(ms / 1000).toFixed(2)}s`;
    }
    return `${ms.toFixed(0)}ms`;
  };

  const firebase = data.providers?.firebase_storage as any;
  const cloudinary = data.providers?.cloudinary as any;

  const hasCloudinaryBandwidth =
    typeof cloudinary?.bandwidthGB === 'number' && cloudinary.bandwidthGB > 0;
  const hasFirebaseBandwidth =
    typeof firebase?.bandwidthGB === 'number' && firebase.bandwidthGB > 0;

  const hasFirebaseLatencyData =
    typeof firebase?.averageResponseTimeMs === 'number' && firebase.averageResponseTimeMs > 0;
  const hasFirebasePeakData =
    typeof firebase?.peakBandwidthGB === 'number' && firebase.peakBandwidthGB > 0;
  const hasRequestData =
    (typeof data.downloadRequests === 'number' && data.downloadRequests > 0) ||
    (typeof firebase?.downloadRequests === 'number' && firebase.downloadRequests > 0) ||
    (typeof cloudinary?.downloadRequests === 'number' && cloudinary.downloadRequests > 0) ||
    (typeof cloudinary?.requests === 'number' && cloudinary.requests > 0);

  const requestCount = Math.max(
    typeof data.downloadRequests === 'number' ? data.downloadRequests : 0,
    typeof firebase?.downloadRequests === 'number' ? firebase.downloadRequests : 0,
    typeof cloudinary?.downloadRequests === 'number' ? cloudinary.downloadRequests : 0,
    typeof cloudinary?.requests === 'number' ? cloudinary.requests : 0
  );

  const bandwidthLabel =
    hasCloudinaryBandwidth && !hasFirebaseBandwidth
      ? 'Bandwidth (Cloudinary)'
      : hasCloudinaryBandwidth && hasFirebaseBandwidth
      ? 'Bandwidth (Combined)'
      : 'Bandwidth (24h)';

  const metricsCount =
    1 +
    (hasRequestData ? 1 : 0) +
    (hasFirebaseLatencyData ? 1 : 0) +
    (hasFirebasePeakData ? 1 : 0);

  const gridClass =
    metricsCount <= 1
      ? 'grid grid-cols-1 gap-6'
      : metricsCount === 2
      ? 'grid grid-cols-1 md:grid-cols-2 gap-6'
      : 'grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6';

  const showFirebaseProvider =
    !!firebase &&
    (typeof firebase?.bandwidthGB === 'number' && firebase.bandwidthGB > 0 ||
      typeof firebase?.downloadRequests === 'number' && firebase.downloadRequests > 0 ||
      typeof firebase?.averageResponseTimeMs === 'number' && firebase.averageResponseTimeMs > 0 ||
      typeof firebase?.peakBandwidthGB === 'number' && firebase.peakBandwidthGB > 0);

  const showCloudinaryProvider =
    !!cloudinary && (cloudinary?.dataAvailable === true || hasCloudinaryBandwidth);

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center gap-2">
          <CardTitle>CDN Performance</CardTitle>
          {data.isComputed && <Badge variant="outline">Computed</Badge>}
        </div>
        <CardDescription>
          Content delivery network bandwidth and performance metrics
          {data.lastUpdated && (
            <span className="text-xs text-muted-foreground ml-2">
              Updated {formatDate(data.lastUpdated, dateFormat)}
            </span>
          )}
        </CardDescription>
      </CardHeader>
      <CardContent>
        {data.isComputed && (
          <p className="text-xs text-muted-foreground mb-2">
            Data computed from available sources; pre-aggregated analytics unavailable.
          </p>
        )}
        <div className={gridClass}>
          <div className="flex items-center gap-3">
            <div className="rounded-full bg-blue-100 p-3">
              <HardDrive className="h-5 w-5 text-blue-600" />
            </div>
            <div>
              <p className="text-2xl font-bold">{formatBandwidth(data.bandwidthGB)}</p>
              <p className="text-sm text-muted-foreground">{bandwidthLabel}</p>
            </div>
          </div>

          {hasRequestData && (
            <div className="flex items-center gap-3">
              <div className="rounded-full bg-green-100 p-3">
                <Download className="h-5 w-5 text-green-600" />
              </div>
              <div>
                <p className="text-2xl font-bold">{requestCount.toLocaleString()}</p>
                <p className="text-sm text-muted-foreground">Requests</p>
              </div>
            </div>
          )}

          {hasFirebaseLatencyData && (
            <div className="flex items-center gap-3">
              <div className="rounded-full bg-purple-100 p-3">
                <Zap className="h-5 w-5 text-purple-600" />
              </div>
              <div>
                <p className="text-2xl font-bold">{formatResponseTime(data.averageResponseTimeMs)}</p>
                <p className="text-sm text-muted-foreground">Avg Response</p>
              </div>
            </div>
          )}

          {hasFirebasePeakData && (
            <div className="flex items-center gap-3">
              <div className="rounded-full bg-orange-100 p-3">
                <TrendingUp className="h-5 w-5 text-orange-600" />
              </div>
              <div>
                <p className="text-2xl font-bold">{formatBandwidth(data.peakBandwidthGB)}</p>
                <p className="text-sm text-muted-foreground">Peak Bandwidth</p>
              </div>
            </div>
          )}
        </div>

        {data.peakBandwidthTime && hasFirebasePeakData && (
          <div className="mt-6 p-4 bg-muted/50 rounded-lg">
            <p className="text-sm">
              <span className="font-semibold">Peak bandwidth occurred:</span>{' '}
              <span className="text-muted-foreground">
                {formatDate(data.peakBandwidthTime, dateFormat)}
              </span>
            </p>
          </div>
        )}

        {(hasRequestData || hasFirebaseLatencyData) && (
          <div className="mt-6 grid grid-cols-1 md:grid-cols-2 gap-4">
            {hasRequestData && requestCount > 0 && (
              <div className="p-4 border rounded-lg">
                <h4 className="text-sm font-semibold mb-2">Bandwidth Efficiency</h4>
                <p className="text-xs text-muted-foreground">
                  Average {((data.bandwidthGB * 1024 * 1024) / requestCount).toFixed(2)} KB per request
                </p>
              </div>
            )}

            {hasFirebaseLatencyData && (
              <div className="p-4 border rounded-lg">
                <h4 className="text-sm font-semibold mb-2">Response Time Status</h4>
                <p className="text-xs text-muted-foreground">
                  {data.averageResponseTimeMs < 200
                    ? 'Excellent - Under 200ms'
                    : data.averageResponseTimeMs < 500
                    ? 'Good - Under 500ms'
                    : 'Needs improvement - Over 500ms'}
                </p>
              </div>
            )}
          </div>
        )}

        {data.metricsCollectedAt && (
          <div className="mt-4 text-xs text-muted-foreground">
            Metrics collected at: {formatDate(data.metricsCollectedAt, dateFormat)}
          </div>
        )}

        {data.providers && (showFirebaseProvider || showCloudinaryProvider) && (
          <div className="mt-6 grid grid-cols-1 md:grid-cols-2 gap-4">
            {(['firebase_storage', 'cloudinary'] as const).map((key) => {
              const provider = data.providers?.[key] as any;
              if (!provider) return null;
              if (key === 'firebase_storage' && !showFirebaseProvider) return null;
              if (key === 'cloudinary' && !showCloudinaryProvider) return null;

              const providerRequests =
                provider.downloadRequests ?? provider.requests ?? null;
              return (
                <div key={key} className="p-4 border rounded-lg space-y-2">
                  <div className="flex items-center justify-between">
                    <span className="text-sm font-semibold capitalize">
                      {key.replace('_', ' ')}
                    </span>
                    <Badge variant="outline">Provider</Badge>
                  </div>
                  <p className="text-sm">
                    Bandwidth: {provider.bandwidthGB?.toFixed?.(2) ?? '0'} GB
                  </p>
                  {providerRequests !== null && (
                    <p className="text-sm">
                      Requests: {(providerRequests ?? 0).toLocaleString?.()}
                    </p>
                  )}
                  {provider.peakBandwidthTime && (
                    <p className="text-xs text-muted-foreground">
                      Peak: {formatDate(provider.peakBandwidthTime, dateFormat)}
                    </p>
                  )}
                </div>
              );
            })}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
