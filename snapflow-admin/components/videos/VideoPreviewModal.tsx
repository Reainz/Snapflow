'use client';

import { useEffect, useMemo, useRef, useState } from 'react';
import { Video, getSignedVideoUrl } from '@/lib/api/videos';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Badge } from '@/components/ui/badge';
import { formatDate } from '@/lib/utils';
import Hls from 'hls.js';

interface VideoPreviewModalProps {
  video: Video | null;
  open: boolean;
  onClose: () => void;
  dateFormat?: string;
}

export function VideoPreviewModal({ video, open, onClose, dateFormat = 'MM/DD/YYYY' }: VideoPreviewModalProps) {
  const formatDuration = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const [previewUrl, setPreviewUrl] = useState<string | undefined>(video?.hlsUrl);
  const videoElRef = useRef<HTMLVideoElement | null>(null);

  const isHlsStream = useMemo(() => {
    const url = (previewUrl || '').toLowerCase();
    return url.includes('.m3u8');
  }, [previewUrl]);

  // Safari (and some iOS browsers) support HLS natively.
  const canPlayNativeHls = useMemo(() => {
    if (typeof document === 'undefined') return false;
    return document.createElement('video').canPlayType('application/vnd.apple.mpegurl') !== '';
  }, []);

  useEffect(() => {
    let cancelled = false;
    if (!video) return;

    setPreviewUrl(video.hlsUrl);

    const privacy = video.privacy?.toLowerCase();
    const needsSigned = privacy === 'private' || privacy === 'followers-only';
    if (!needsSigned) return;

    getSignedVideoUrl(video.id)
      .then((url) => {
        if (!cancelled && url) {
          setPreviewUrl(url);
        }
      })
      .catch((err) => {
        console.error('Failed to fetch signed URL for admin preview', err);
      });

    return () => {
      cancelled = true;
    };
  }, [video]);

  useEffect(() => {
    const el = videoElRef.current;
    if (!open || !el) return;
    if (!previewUrl) return;

    // If the browser supports HLS natively (Safari), let the <video> tag handle it.
    if (!isHlsStream || canPlayNativeHls) {
      return;
    }

    if (!Hls.isSupported()) {
      return;
    }

    const hls = new Hls({
      enableWorker: false, // avoid CSP worker-src requirements
    });

    hls.loadSource(previewUrl);
    hls.attachMedia(el);

    return () => {
      try {
        hls.destroy();
      } catch {
        // no-op
      }
    };
  }, [open, previewUrl, isHlsStream, canPlayNativeHls]);

  if (!video) return null;

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="max-w-4xl">
        <DialogHeader>
          <DialogTitle>{video.title}</DialogTitle>
          <DialogDescription>
            Video Details and Preview
          </DialogDescription>
        </DialogHeader>
        <div className="space-y-4">
          <div className="aspect-video bg-black rounded-lg overflow-hidden">
            {previewUrl ? (
              <video
                ref={videoElRef}
                src={isHlsStream && !canPlayNativeHls ? undefined : previewUrl}
                controls
                className="w-full h-full"
                poster={video.thumbnailUrl}
              />
            ) : video.thumbnailUrl ? (
              <img
                src={video.thumbnailUrl}
                alt={video.title}
                className="w-full h-full object-cover"
              />
            ) : (
              <div className="w-full h-full flex items-center justify-center text-white">
                <p>No preview available</p>
              </div>
            )}
          </div>

          <div className="space-y-3">
            <div>
              <h4 className="font-semibold mb-1">Description</h4>
              <p className="text-sm text-muted-foreground">{video.description || 'No description'}</p>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div>
                <h4 className="font-semibold text-sm mb-1">Owner</h4>
                <p className="text-sm text-muted-foreground">@{video.ownerUsername || 'Unknown'}</p>
              </div>
              <div>
                <h4 className="font-semibold text-sm mb-1">Status</h4>
                <Badge variant="destructive">{video.status}</Badge>
              </div>
              <div>
                <h4 className="font-semibold text-sm mb-1">Duration</h4>
                <p className="text-sm text-muted-foreground">{formatDuration(video.durationSeconds)}</p>
              </div>
              <div>
                <h4 className="font-semibold text-sm mb-1">Views</h4>
                <p className="text-sm text-muted-foreground">{video.viewsCount?.toLocaleString() || 0}</p>
              </div>
              <div>
                <h4 className="font-semibold text-sm mb-1">Likes</h4>
                <p className="text-sm text-muted-foreground">{video.likesCount?.toLocaleString() || 0}</p>
              </div>
              <div>
                <h4 className="font-semibold text-sm mb-1">Comments</h4>
                <p className="text-sm text-muted-foreground">{video.commentsCount?.toLocaleString() || 0}</p>
              </div>
              <div>
                <h4 className="font-semibold text-sm mb-1">Uploaded</h4>
                <p className="text-sm text-muted-foreground">
                  {video.createdAt ? formatDate(video.createdAt.toDate(), dateFormat) : ''}
                </p>
              </div>
              <div>
                <h4 className="font-semibold text-sm mb-1">Last Updated</h4>
                <p className="text-sm text-muted-foreground">
                  {video.updatedAt ? formatDate(video.updatedAt.toDate(), dateFormat) : ''}
                </p>
              </div>
            </div>
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}
