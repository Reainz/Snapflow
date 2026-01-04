'use client';

import { useQuery } from '@tanstack/react-query';
import { StorageAlertsCard } from '@/components/storage/StorageAlertsCard';
import { CloudinaryMetricsCard } from '@/components/storage/CloudinaryMetricsCard';
import { getStorageAlerts } from '@/lib/api/storage';
import { Alert } from '@/lib/api/alerts';
import { Skeleton } from '@/components/ui/skeleton';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Cloud, Info } from 'lucide-react';
import { useAdminSettings } from '@/lib/hooks/useAdminSettings';
import { useAuth } from '@/lib/hooks/useAuth';
import useSWR from 'swr';

export default function StoragePage() {
  const { user } = useAuth();
  const { settings } = useAdminSettings(user?.uid);
  const refreshSeconds = settings?.autoRefreshInterval ?? 30;
  const dateFormat = settings?.dateFormat ?? 'MM/DD/YYYY';
  
  // Fetch Cloudinary metrics directly
  const { data: cloudinaryMetrics, isLoading } = useSWR(
    '/api/metrics/cloudinary',
    (url) => fetch(url).then((r) => (r.ok ? r.json() : null)),
    { refreshInterval: Math.max(refreshSeconds, 5) * 1000 }
  );
  
  // Fetch storage alerts
  const { data: alerts = [] } = useQuery<Alert[]>({
    queryKey: ['storage-alerts'],
    queryFn: () => getStorageAlerts(false),
    refetchInterval: Math.max(refreshSeconds, 5) * 1000,
    staleTime: 30000,
    gcTime: 60000,
  });

  return (
    <div className="p-6 space-y-6">
      {/* Page Header */}
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-2">
          <Cloud className="h-8 w-8 text-primary" />
          <div>
            <h1 className="text-3xl font-bold">Storage & CDN</h1>
            <p className="text-sm text-muted-foreground">Cloudinary media storage and delivery metrics</p>
          </div>
        </div>
      </div>

      {/* Architecture Info Card */}
      <Card className="border-blue-200 bg-blue-50/50 dark:border-blue-900 dark:bg-blue-950/20">
        <CardHeader className="pb-3">
          <div className="flex items-center gap-2">
            <Info className="h-5 w-5 text-blue-600 dark:text-blue-400" />
            <CardTitle className="text-base text-blue-800 dark:text-blue-200">Flow B Architecture</CardTitle>
          </div>
        </CardHeader>
        <CardContent>
          <CardDescription className="text-blue-700 dark:text-blue-300">
            Snapflow uses Cloudinary for all video processing and storage. Raw uploads are temporarily stored in Firebase Storage, 
            then processed and moved to Cloudinary CDN for HLS streaming. This page shows your Cloudinary usage metrics.
          </CardDescription>
        </CardContent>
      </Card>

      {isLoading ? (
        <LoadingSkeletons />
      ) : (
        <>
          {/* Cloudinary Metrics - Main focus */}
          <CloudinaryMetricsCard metrics={cloudinaryMetrics} dateFormat={dateFormat} />

          {/* Storage Alerts */}
          <StorageAlertsCard alerts={alerts} />
        </>
      )}
    </div>
  );
}

function LoadingSkeletons() {
  return (
    <div className="space-y-6">
      {/* Cloudinary Card Skeleton */}
      <Card>
        <CardContent className="pt-6">
          <Skeleton className="h-[200px] w-full" />
        </CardContent>
      </Card>

      {/* Alerts Skeleton */}
      <Card>
        <CardContent className="pt-6">
          <Skeleton className="h-[150px] w-full" />
        </CardContent>
      </Card>
    </div>
  );
}
