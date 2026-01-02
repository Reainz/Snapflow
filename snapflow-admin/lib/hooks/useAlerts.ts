import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getActiveAlerts, getAllAlerts, acknowledgeAlert, Alert } from '@/lib/api/alerts';

export function useAlerts(showAll: boolean = false, autoRefreshSeconds: number = 30) {
  const queryClient = useQueryClient();
  const refetchMs = Math.max(autoRefreshSeconds, 5) * 1000;

  const { data: alerts, isLoading, error, refetch } = useQuery<Alert[]>({
    queryKey: ['alerts', showAll],
    queryFn: () => (showAll ? getAllAlerts(100) : getActiveAlerts(50)),
    staleTime: 60000, // Data stays fresh for 1 minute
    gcTime: 300000, // Keep in cache for 5 minutes
    refetchInterval: refetchMs,
    refetchOnWindowFocus: false,
  });

  const acknowledgeMutation = useMutation({
    mutationFn: acknowledgeAlert,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['alerts'] });
    },
  });

  return {
    alerts: alerts || [],
    isLoading,
    error,
    refetch,
    acknowledgeAlert: acknowledgeMutation.mutateAsync,
    isAcknowledging: acknowledgeMutation.isPending,
  };
}
