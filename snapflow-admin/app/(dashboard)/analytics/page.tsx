'use client';

import { useState } from 'react';
import { useAnalytics } from '@/lib/hooks/useAnalytics';
import { useAdminSettings } from '@/lib/hooks/useAdminSettings';
import { useAuth } from '@/lib/hooks/useAuth';
import DateRangeSelector from '@/components/analytics/DateRangeSelector';
import UserGrowthChart from '@/components/charts/UserGrowthChart';
import VideoUploadsChart from '@/components/charts/VideoUploadsChart';
import RetentionMetricsCard from '@/components/charts/RetentionMetricsCard';
import SystemHealthCard from '@/components/charts/SystemHealthCard';
import GeographicDistributionChart from '@/components/charts/GeographicDistributionChart';
import WatchTimeChart from '@/components/charts/WatchTimeChart';
import CDNPerformanceChart from '@/components/charts/CDNPerformanceChart';
import APIMetricsChart from '@/components/charts/APIMetricsChart';
import TrendingVideosChart from '@/components/charts/TrendingVideosChart';
import { Skeleton } from '@/components/ui/skeleton';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';

// Helper function to get default dates
function getDefaultDates() {
  const end = new Date();
  const start = new Date();
  start.setDate(start.getDate() - 30);
  return { start, end };
}

// Reusable loading skeleton for chart cards
function ChartSkeleton({ height = 300 }: { height?: number }) {
  return (
    <Card>
      <CardContent className="pt-6">
        <Skeleton className={`h-[${height}px] w-full`} style={{ height }} />
      </CardContent>
    </Card>
  );
}

export default function AnalyticsPage() {
  // Initialize with a stable default that won't cause hydration mismatch
  const defaults = getDefaultDates();
  const [startDate, setStartDate] = useState(defaults.start);
  const [endDate, setEndDate] = useState(defaults.end);
  const { user } = useAuth();
  const { settings } = useAdminSettings(user?.uid);
  const refreshSeconds = settings?.autoRefreshInterval ?? 30;
  const dateFormat = settings?.dateFormat ?? 'MM/DD/YYYY';
  
  const { 
    userGrowth, videoUploads, retention, systemHealth, 
    geographic, watchTime, cdn, api, trendingVideos, 
    loadingStates 
  } = useAnalytics(startDate, endDate, refreshSeconds);

  const handleRangeChange = (start: Date, end: Date) => {
    setStartDate(start);
    setEndDate(end);
  };

  const handleExport = () => {
    const payload = {
      startDate,
      endDate,
      userGrowth,
      videoUploads,
      retention,
      systemHealth,
      geographic,
      watchTime,
      cdn,
      api,
      trendingVideos,
    };
    const blob = new Blob([JSON.stringify(payload, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = 'analytics-export.json';
    link.click();
    URL.revokeObjectURL(url);
  };

  return (
    <div className="p-6 space-y-6">
      {/* Page Header */}
      <div className="flex items-center justify-between">
        <h1 className="text-3xl font-bold">Analytics Dashboard</h1>
        <Button size="sm" onClick={handleExport}>Export JSON</Button>
      </div>
      
      {/* Date Range Selector */}
      <DateRangeSelector 
        startDate={startDate} 
        endDate={endDate} 
        onRangeChange={handleRangeChange} 
      />

      {/* Row 1: Charts - Progressive loading */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {loadingStates.userGrowth ? (
          <ChartSkeleton height={300} />
        ) : (
          <UserGrowthChart data={userGrowth} dateFormat={dateFormat} />
        )}
        {loadingStates.videoUploads ? (
          <ChartSkeleton height={300} />
        ) : (
          <VideoUploadsChart data={videoUploads} dateFormat={dateFormat} />
        )}
      </div>

      {/* Row 2: Metrics and Health - Progressive loading */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {loadingStates.retention ? (
          <ChartSkeleton height={200} />
        ) : retention ? (
          <RetentionMetricsCard 
            d1RetentionRate={retention.d1RetentionRate} 
            newUsersYesterday={retention.newUsersYesterday} 
            isComputed={retention.isComputed}
          />
        ) : (
          <Card>
            <CardContent className="pt-6">
              <div className="text-center text-muted-foreground py-8">
                No retention data available
              </div>
            </CardContent>
          </Card>
        )}
        {loadingStates.systemHealth ? (
          <ChartSkeleton height={200} />
        ) : (
          <SystemHealthCard systemHealth={systemHealth ?? null} />
        )}
      </div>

      {/* Row 3: Geographic Distribution - Progressive loading */}
      {loadingStates.geographic ? (
        <ChartSkeleton height={350} />
      ) : geographic ? (
        <GeographicDistributionChart data={geographic} />
      ) : (
        <Card>
          <CardContent className="pt-6">
            <div className="text-center text-muted-foreground py-8">
              No geographic data available yet
            </div>
          </CardContent>
        </Card>
      )}

      {/* Row 4: Watch Time Metrics - Progressive loading */}
      {loadingStates.watchTime ? (
        <ChartSkeleton height={300} />
      ) : (
        <WatchTimeChart data={watchTime} dateFormat={dateFormat} />
      )}

      {/* Row 5: CDN Performance - Progressive loading */}
      {loadingStates.cdn ? (
        <ChartSkeleton height={350} />
      ) : (
        <CDNPerformanceChart data={cdn} dateFormat={dateFormat} />
      )}

      {/* Row 6: API Performance - Progressive loading */}
      {loadingStates.api ? (
        <ChartSkeleton height={400} />
      ) : (
        <APIMetricsChart data={api} dateFormat={dateFormat} />
      )}

      {/* Row 7: Trending Videos - Progressive loading */}
      {loadingStates.trendingVideos ? (
        <ChartSkeleton height={300} />
      ) : (
        <TrendingVideosChart data={trendingVideos} />
      )}
    </div>
  );
}
