'use client';

import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { formatDate } from '@/lib/utils';

type CloudinaryMetrics = {
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

interface CloudinaryMetricsCardProps {
  metrics: CloudinaryMetrics;
  dateFormat?: string;
}

export function CloudinaryMetricsCard({ metrics, dateFormat = 'MM/DD/YYYY' }: CloudinaryMetricsCardProps) {
  if (!metrics) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Cloudinary Metrics</CardTitle>
          <CardDescription>Storage and bandwidth usage for processed media</CardDescription>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">No Cloudinary metrics available</p>
        </CardContent>
      </Card>
    );
  }

  const bandwidthUsed = metrics.bandwidthGB ?? 0;
  const storageUsed = metrics.storageGB ?? 0;
  const bandwidthLimit = metrics.bandwidthLimitGB ?? null;
  const storageLimit = metrics.storageLimitGB ?? null;

  const percent = (used: number, limit: number | null) => {
    if (!limit || limit <= 0) return null;
    return Math.min(100, (used / limit) * 100);
  };

  const bandwidthPct = percent(bandwidthUsed, bandwidthLimit);
  const storagePct = percent(storageUsed, storageLimit);

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center gap-2">
          <CardTitle>Cloudinary Metrics</CardTitle>
          <Badge variant="outline">Flow B</Badge>
        </div>
        <CardDescription>Processed HLS storage and CDN usage</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <Metric label="Bandwidth Used" value={`${bandwidthUsed.toFixed(2)} GB`} sub={bandwidthLimit ? `Limit: ${bandwidthLimit.toFixed(2)} GB` : 'No limit'} />
          <Metric label="Storage Used" value={`${storageUsed.toFixed(2)} GB`} sub={storageLimit ? `Limit: ${storageLimit.toFixed(2)} GB` : 'No limit'} />
          <Metric label="Requests" value={metrics.requests?.toLocaleString() ?? 'N/A'} />
          <Metric label="Assets" value={metrics.resourceCount?.toLocaleString() ?? 'N/A'} />
        </div>

        {(bandwidthPct !== null || storagePct !== null) && (
          <div className="space-y-3">
            {bandwidthPct !== null && <Progress label="Bandwidth" percent={bandwidthPct} />}
            {storagePct !== null && <Progress label="Storage" percent={storagePct} />}
          </div>
        )}

        {metrics.lastUpdated && (
          <p className="text-xs text-muted-foreground">
            Last Updated: {new Date(metrics.lastUpdated).toLocaleString(undefined, { dateStyle: 'short', timeStyle: 'short' })}
          </p>
        )}
      </CardContent>
    </Card>
  );
}

function Metric({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return (
    <div className="p-3 border rounded-md">
      <div className="text-xs text-muted-foreground">{label}</div>
      <div className="text-lg font-semibold">{value}</div>
      {sub && <div className="text-xs text-muted-foreground">{sub}</div>}
    </div>
  );
}

function Progress({ label, percent }: { label: string; percent: number }) {
  return (
    <div className="flex items-center gap-3">
      <span className="text-xs text-muted-foreground w-20">{label}</span>
      <div className="flex-1 bg-muted rounded-full h-2">
        <div className="h-2 rounded-full bg-blue-600" style={{ width: `${percent}%` }} />
      </div>
      <span className="text-xs text-muted-foreground min-w-[40px] text-right">{percent.toFixed(0)}%</span>
    </div>
  );
}
