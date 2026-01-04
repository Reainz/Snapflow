import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getUsersPage, searchUsers, banUser, deleteUser, User, UsersPage } from '@/lib/api/users';
import { useState, useEffect } from 'react';
import { DocumentSnapshot } from 'firebase/firestore';

export function useUsers(
  orderField: string = 'createdAt',
  descending: boolean = true,
  searchQuery: string = '',
  autoRefreshSeconds: number = 30
) {
  const [lastDoc, setLastDoc] = useState<DocumentSnapshot | null>(null);
  const [accumulatedUsers, setAccumulatedUsers] = useState<User[]>([]);
  const queryClient = useQueryClient();
  const refetchMs = Math.max(autoRefreshSeconds, 5) * 1000;

  const { data, isLoading, error, refetch } = useQuery<UsersPage>({
    queryKey: ['users', orderField, descending, searchQuery, lastDoc],
    queryFn: async () => {
      if (searchQuery.trim()) {
        const users = await searchUsers(searchQuery);
        return { users, lastDoc: null, hasMore: false };
      }
      return getUsersPage(20, orderField, descending, lastDoc);
    },
    staleTime: 30000, // Data stays fresh for 30 seconds
    gcTime: 300000, // Keep in cache for 5 minutes
    refetchInterval: searchQuery.trim() ? undefined : refetchMs,
    refetchOnWindowFocus: false,
  });

  // Handle data updates (replaces onSuccess in React Query v5)
  useEffect(() => {
    if (!data) return;
    setAccumulatedUsers((prev) => {
      if (!lastDoc) {
        // Initial page or reset
        return data.users;
      }
      // Append new page while avoiding duplicate ids
      const existingIds = new Set(prev.map((u) => u.id));
      const merged = [...prev];
      data.users.forEach((u) => {
        if (!existingIds.has(u.id)) {
          merged.push(u);
        }
      });
      return merged;
    });
  }, [data, lastDoc]);

  const banMutation = useMutation({
    mutationFn: banUser,
  });

  const deleteMutation = useMutation({
    mutationFn: deleteUser,
  });

  // Handle mutation success (replaces onSuccess in React Query v5)
  useEffect(() => {
    if (banMutation.isSuccess) {
      queryClient.invalidateQueries({ queryKey: ['users'] });
    }
  }, [banMutation.isSuccess, queryClient]);

  useEffect(() => {
    if (deleteMutation.isSuccess) {
      queryClient.invalidateQueries({ queryKey: ['users'] });
    }
  }, [deleteMutation.isSuccess, queryClient]);

  const loadNextPage = () => {
    if (data?.lastDoc) {
      setLastDoc(data.lastDoc);
    }
  };

  const resetPagination = () => {
    setLastDoc(null);
    setAccumulatedUsers([]);
  };

  return {
    users: searchQuery.trim() ? data?.users || [] : accumulatedUsers,
    hasMore: data?.hasMore || false,
    isLoading,
    error,
    loadNextPage,
    resetPagination,
    refetch,
    banUser: banMutation.mutateAsync,
    deleteUser: deleteMutation.mutateAsync,
    isBanning: banMutation.isPending,
    isDeleting: deleteMutation.isPending,
  };
}
