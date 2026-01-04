import { useQuery } from '@tanstack/react-query';
import { getDashboardStats } from '@/lib/api/stats';

export function useStats() {
  return useQuery({
    queryKey: ['dashboard-stats'],
    queryFn: getDashboardStats,
    staleTime: 60000, // Data stays fresh for 1 minute
    gcTime: 300000, // Keep in cache for 5 minutes (formerly cacheTime)
    refetchInterval: 30000, // Refresh every 30 seconds
    refetchOnWindowFocus: false, // Don't refetch on window focus
  });
}
