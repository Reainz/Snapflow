'use client';

import { useEffect, useState } from 'react';
import { useVideos } from '@/lib/hooks/useVideos';
import { VideoCard } from '@/components/videos/VideoCard';
import { VideoPreviewModal } from '@/components/videos/VideoPreviewModal';
import { Video } from '@/lib/api/videos';
import { Skeleton } from '@/components/ui/skeleton';
import { toast } from 'sonner';
import { AlertCircle } from 'lucide-react';
import { useAdminSettings } from '@/lib/hooks/useAdminSettings';
import { useAuth } from '@/lib/hooks/useAuth';
import { formatDate } from '@/lib/utils';
import { Button } from '@/components/ui/button';

export default function VideosPage() {
  const { user } = useAuth();
  const { settings } = useAdminSettings(user?.uid);
  const refreshSeconds = settings?.autoRefreshInterval ?? 30;
  const dateFormat = settings?.dateFormat ?? 'MM/DD/YYYY';

  const [scope, setScope] = useState<'flagged' | 'moderation'>('flagged');
  const [search, setSearch] = useState('');
  const [page, setPage] = useState(1);
  const pageSize = 12;
  const { videos, hasMore, isLoading, approveVideo, removeVideo, loadNextPage, resetPagination } = useVideos(refreshSeconds, scope, search, pageSize);
  const [previewVideo, setPreviewVideo] = useState<Video | null>(null);
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());

  useEffect(() => {
    resetPagination();
    setPage(1);
  }, [scope, search]); // resetPagination is stable via useCallback

  const handleApprove = async (videoId: string) => {
    if (!confirm('Are you sure you want to approve this video?')) return;

    try {
      await approveVideo(videoId);
      toast.success('Video approved successfully');
    } catch (error) {
      toast.error('Failed to approve video');
    }
  };

  const handleRemove = async (videoId: string) => {
    if (!confirm('Are you sure you want to remove this video? This action will hide it from users.')) return;

    try {
      await removeVideo(videoId);
      toast.success('Video removed successfully');
    } catch (error) {
      toast.error('Failed to remove video');
    }
  };

  const handlePreview = (video: Video) => {
    setPreviewVideo(video);
  };

  const toggleSelect = (videoId: string) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(videoId)) {
        next.delete(videoId);
      } else {
        next.add(videoId);
      }
      return next;
    });
  };

  const handleBulkApprove = async () => {
    if (selectedIds.size === 0) return;
    if (!confirm(`Approve ${selectedIds.size} video(s)?`)) return;
    try {
      await Promise.all(Array.from(selectedIds).map((id) => approveVideo(id)));
      toast.success('Selected videos approved');
      setSelectedIds(new Set());
    } catch {
      toast.error('Failed to approve selected videos');
    }
  };

  const handleBulkRemove = async () => {
    if (selectedIds.size === 0) return;
    if (!confirm(`Remove ${selectedIds.size} video(s)?`)) return;
    try {
      await Promise.all(Array.from(selectedIds).map((id) => removeVideo(id)));
      toast.success('Selected videos removed');
      setSelectedIds(new Set());
    } catch {
      toast.error('Failed to remove selected videos');
    }
  };

  if (isLoading) {
    return (
      <div className="space-y-6">
        <h1 className="text-3xl font-bold">Content Moderation</h1>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {[...Array(6)].map((_, i) => (
            <Skeleton key={i} className="h-96" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-foreground">Content Moderation</h1>
        <p className="text-muted-foreground mt-1">
          Review and moderate videos by status (flagged, failed, processing)
        </p>
      </div>

      <div className="flex items-center gap-3 text-sm text-foreground">
        <label htmlFor="moderation-scope" className="font-medium">
          View
        </label>
        <select
          id="moderation-scope"
          className="border rounded-md px-3 py-2 text-sm"
          value={scope}
          onChange={(e) => setScope(e.target.value as 'flagged' | 'moderation')}
        >
          <option value="flagged">Flagged only</option>
          <option value="moderation">Flagged + Failed + Processing + Ready</option>
        </select>
        <input
          type="text"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search by title or owner"
          className="border rounded-md px-3 py-2 text-sm flex-1"
        />
      </div>

      {videos.length === 0 ? (
        <div className="text-center py-12 bg-muted rounded-lg border border-dashed">
          <AlertCircle className="w-12 h-12 text-muted-foreground mx-auto mb-4" />
          <h3 className="text-lg font-semibold text-foreground mb-2">No videos found</h3>
          <p className="text-muted-foreground">
            {scope === 'flagged'
              ? 'All flagged videos have been reviewed.'
              : 'No flagged/failed/processing videos at this time.'}
          </p>
        </div>
      ) : (
        <>
          <div className="flex items-center justify-between">
            <p className="text-sm text-muted-foreground">
              {videos.length} video{videos.length !== 1 ? 's' : ''} pending review ({scope})
            </p>
            <div className="flex gap-2">
              <Button variant="default" size="sm" onClick={handleBulkApprove} disabled={selectedIds.size === 0}>
                Approve Selected
              </Button>
              <Button variant="destructive" size="sm" onClick={handleBulkRemove} disabled={selectedIds.size === 0}>
                Remove Selected
              </Button>
            </div>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {videos.map((video) => (
              <VideoCard
                key={video.id}
                video={video}
                onApprove={handleApprove}
                onRemove={handleRemove}
                onPreview={handlePreview}
                selected={selectedIds.has(video.id)}
                onToggleSelect={toggleSelect}
                dateFormat={dateFormat}
              />
            ))}
          </div>
            <div className="flex justify-between items-center pt-2 text-sm text-muted-foreground">
              <span>Page {page}</span>
              <div className="space-x-2">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => {
                    resetPagination();
                    setPage(1);
                  }}
                  disabled={page === 1 || isLoading}
                >
                  Prev
                </Button>
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => {
                    loadNextPage();
                    setPage((p) => p + 1);
                  }}
                  disabled={isLoading || !hasMore}
                >
                  Next
                </Button>
              </div>
            </div>
        </>
      )}

      <VideoPreviewModal
        video={previewVideo}
        open={!!previewVideo}
        onClose={() => setPreviewVideo(null)}
        dateFormat={dateFormat}
      />
    </div>
  );
}
