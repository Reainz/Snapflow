import { useQuery } from '@tanstack/react-query';
import { getUserDetails, UserDetails } from '@/lib/api/users';

export function useUserDetails(userId: string | null) {
  return useQuery<UserDetails>({
    queryKey: ['user-details', userId],
    queryFn: () => {
      if (!userId) throw new Error('User ID is required');
      return getUserDetails(userId);
    },
    enabled: !!userId,
    staleTime: 30_000,
  });
}
