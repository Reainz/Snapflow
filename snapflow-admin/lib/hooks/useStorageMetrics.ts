import { useQuery } from '@tanstack/react-query';
import { 
  getLatestStorageMetrics,
  getStorageMetricsHistory,
  StorageMetrics,
  StorageMetricsHistory
} from '@/lib/api/storage';

/**
 * Custom React Query hook for fetching storage metrics data.
 * 
 * @param startDate Start date for historical data (defaults to 30 days ago)
 * @param endDate End date for historical data (defaults to now)
 * @returns Object containing latest metrics, history, loading state, error, and refetch function
 */
export function useStorageMetrics(startDate?: Date, endDate?: Date, autoRefreshSeconds: number = 30) {
  // Default to last 30 days if not specified
  const start = startDate || new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  const end = endDate || new Date();
  const refetchMs = Math.max(autoRefreshSeconds, 5) * 1000;

  // Query for latest storage metrics
  const latestQuery = useQuery({
    queryKey: ['storage-metrics-latest'],
    queryFn: getLatestStorageMetrics,
    staleTime: 60000, // Data stays fresh for 1 minute
    gcTime: 300000, // Keep in cache for 5 minutes
    refetchInterval: refetchMs,
    refetchOnWindowFocus: false,
  });

  // Query for historical storage metrics
  const historyQuery = useQuery({
    queryKey: ['storage-metrics-history', start.toISOString(), end.toISOString()],
    queryFn: () => getStorageMetricsHistory(start, end),
    staleTime: 120000, // History data stays fresh for 2 minutes
    gcTime: 600000, // Keep in cache for 10 minutes
    refetchInterval: refetchMs,
    refetchOnWindowFocus: false,
  });

  return {
    latest: latestQuery.data || null,
    history: historyQuery.data || [],
    isLoading: latestQuery.isLoading || historyQuery.isLoading,
    error: latestQuery.error || historyQuery.error,
    refetch: () => {
      latestQuery.refetch();
      historyQuery.refetch();
    },
  };
}
