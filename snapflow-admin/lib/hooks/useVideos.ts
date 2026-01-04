import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { getModerationVideosPage, searchVideosByTitleOrOwner, approveVideo, removeVideo, Video, ModerationPage } from '@/lib/api/videos';
import { useEffect, useState, useCallback } from 'react';
import { DocumentSnapshot } from 'firebase/firestore';

export function useVideos(
  autoRefreshSeconds: number = 30,
  scope: 'flagged' | 'moderation' = 'flagged',
  search: string = '',
  pageSize: number = 20
) {
  const queryClient = useQueryClient();
  const refetchMs = Math.max(autoRefreshSeconds, 5) * 1000;
  const [cursor, setCursor] = useState<{ ref: DocumentSnapshot | null; token: number }>({
    ref: null,
    token: 0,
  });

  useEffect(() => {
    setCursor({ ref: null, token: 0 });
  }, [scope, search]);

  const { data, isLoading, error, refetch } = useQuery<ModerationPage | Video[]>({
    queryKey: ['videos', scope, search, cursor.token, pageSize],
    queryFn: () =>
      search.trim()
        ? searchVideosByTitleOrOwner(search, pageSize * 3) // search remains client-side over a small window
        : getModerationVideosPage(
            pageSize,
            scope === 'flagged' ? ['flagged'] : ['flagged', 'failed', 'processing', 'ready'],
            cursor.ref
          ),
    staleTime: 30000, // Data stays fresh for 30 seconds
    gcTime: 300000, // Keep in cache for 5 minutes
    refetchInterval: refetchMs,
    refetchOnWindowFocus: false,
  });

  const approveMutation = useMutation({
    mutationFn: approveVideo,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['videos'] });
    },
  });

  const removeMutation = useMutation({
    mutationFn: removeVideo,
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['videos'] });
    },
  });

  const videos = Array.isArray(data) ? data : data?.videos || [];
  const hasMore = Array.isArray(data) ? false : data?.hasMore || false;

  const loadNextPage = () => {
    if (!Array.isArray(data) && data?.lastDoc) {
      setCursor({ ref: data.lastDoc, token: Date.now() });
    }
  };

  const resetPagination = useCallback(() => {
    setCursor({ ref: null, token: 0 });
  }, []);

  return {
    videos,
    hasMore,
    isLoading,
    error,
    refetch,
    loadNextPage,
    resetPagination,
    approveVideo: approveMutation.mutateAsync,
    removeVideo: removeMutation.mutateAsync,
    isApproving: approveMutation.isPending,
    isRemoving: removeMutation.isPending,
  };
}
