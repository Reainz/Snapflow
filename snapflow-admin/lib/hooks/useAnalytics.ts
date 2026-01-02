import { useQuery } from '@tanstack/react-query';
import { 
  getUserGrowthData, 
  getVideoUploadData, 
  getRetentionMetrics, 
  getSystemHealth,
  getGeographicDistribution,
  getWatchTimeMetrics,
  getCDNMetrics,
  getAPIMetrics,
  getTrendingVideos,
  UserGrowthData,
  VideoUploadData,
  RetentionMetrics,
  SystemHealthMetrics,
  GeographicDistribution,
  WatchTimeMetrics,
  CDNMetrics,
  APIMetrics,
  TrendingVideo
} from '@/lib/api/analytics';

export function useAnalytics(startDate: Date, endDate: Date, autoRefreshSeconds: number = 30) {
  const refetchMs = Math.max(autoRefreshSeconds, 5) * 1000;
  
  // Shared query options for performance optimization
  const sharedOptions = {
    staleTime: 60000, // Data stays fresh for 1 minute
    gcTime: 300000, // Keep in cache for 5 minutes
    refetchOnWindowFocus: false,
  };

  // Query for user growth data
  const userGrowthQuery = useQuery({
    queryKey: ['user-growth', startDate.toISOString(), endDate.toISOString()],
    queryFn: () => getUserGrowthData(startDate, endDate),
    refetchInterval: refetchMs,
    ...sharedOptions,
  });

  // Query for video upload data
  const videoUploadsQuery = useQuery({
    queryKey: ['video-uploads', startDate.toISOString(), endDate.toISOString()],
    queryFn: () => getVideoUploadData(startDate, endDate),
    refetchInterval: refetchMs,
    ...sharedOptions,
  });

  // Query for retention metrics
  const retentionQuery = useQuery({
    queryKey: ['retention-metrics'],
    queryFn: getRetentionMetrics,
    refetchInterval: refetchMs,
    ...sharedOptions,
  });

  // Query for system health
  const systemHealthQuery = useQuery({
    queryKey: ['system-health'],
    queryFn: getSystemHealth,
    refetchInterval: refetchMs,
    ...sharedOptions,
  });

  // Query for geographic distribution
  const geographicQuery = useQuery({
    queryKey: ['geographic-distribution'],
    queryFn: getGeographicDistribution,
    refetchInterval: refetchMs,
    ...sharedOptions,
  });

  // Query for watch time metrics
  const watchTimeQuery = useQuery({
    queryKey: ['watch-time-metrics'],
    queryFn: getWatchTimeMetrics,
    refetchInterval: refetchMs,
    ...sharedOptions,
  });

  // Query for CDN metrics
  const cdnQuery = useQuery({
    queryKey: ['cdn-metrics'],
    queryFn: getCDNMetrics,
    refetchInterval: refetchMs,
    ...sharedOptions,
  });

  // Query for API metrics
  const apiQuery = useQuery({
    queryKey: ['api-metrics'],
    queryFn: getAPIMetrics,
    refetchInterval: refetchMs,
    ...sharedOptions,
  });

  // Query for trending videos (default by engagement)
  const trendingQuery = useQuery<TrendingVideo[]>({
    queryKey: ['trending-videos'],
    queryFn: () => getTrendingVideos(10, 'engagement'),
    refetchInterval: refetchMs,
    ...sharedOptions,
  });

  return {
    userGrowth: userGrowthQuery.data || [],
    videoUploads: videoUploadsQuery.data || [],
    retention: retentionQuery.data,
    systemHealth: systemHealthQuery.data,
    geographic: geographicQuery.data,
    watchTime: watchTimeQuery.data,
    cdn: cdnQuery.data,
    api: apiQuery.data,
    trendingVideos: trendingQuery.data || [],
    // Individual loading states for progressive rendering
    loadingStates: {
      userGrowth: userGrowthQuery.isLoading,
      videoUploads: videoUploadsQuery.isLoading,
      retention: retentionQuery.isLoading,
      systemHealth: systemHealthQuery.isLoading,
      geographic: geographicQuery.isLoading,
      watchTime: watchTimeQuery.isLoading,
      cdn: cdnQuery.isLoading,
      api: apiQuery.isLoading,
      trendingVideos: trendingQuery.isLoading,
    },
    isLoading: userGrowthQuery.isLoading || videoUploadsQuery.isLoading || retentionQuery.isLoading || systemHealthQuery.isLoading || geographicQuery.isLoading || watchTimeQuery.isLoading || cdnQuery.isLoading || apiQuery.isLoading || trendingQuery.isLoading,
    error: userGrowthQuery.error || videoUploadsQuery.error || retentionQuery.error || systemHealthQuery.error || geographicQuery.error || watchTimeQuery.error || cdnQuery.error || apiQuery.error || trendingQuery.error,
    refetch: () => {
      userGrowthQuery.refetch();
      videoUploadsQuery.refetch();
      retentionQuery.refetch();
      systemHealthQuery.refetch();
      geographicQuery.refetch();
      watchTimeQuery.refetch();
      cdnQuery.refetch();
      apiQuery.refetch();
      trendingQuery.refetch();
    },
  };
}
