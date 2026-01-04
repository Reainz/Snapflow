import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getAdminSettings, updateAdminSettings } from '@/lib/api/settings';
import { AdminSettings } from '@/types/admin';

export function useAdminSettings(userId: string | undefined) {
  const queryClient = useQueryClient();

  const settingsQuery = useQuery<AdminSettings>({
    queryKey: ['admin-settings', userId],
    queryFn: () => {
      if (!userId) throw new Error('User ID is required for settings');
      return getAdminSettings(userId);
    },
    enabled: !!userId,
    staleTime: 60_000,
  });

  const updateMutation = useMutation({
    mutationFn: (settings: Partial<AdminSettings>) => {
      if (!userId) throw new Error('User ID is required for settings');
      return updateAdminSettings(userId, settings);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['admin-settings', userId] });
    },
  });

  return {
    settings: settingsQuery.data,
    isLoading: settingsQuery.isLoading,
    error: settingsQuery.error,
    refresh: settingsQuery.refetch,
    updateSettings: updateMutation.mutateAsync,
    isSaving: updateMutation.isPending,
  };
}
