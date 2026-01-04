'use client';

import { Video } from '@/lib/api/videos';
import { Card, CardContent, CardFooter, CardHeader } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { CheckCircle2, XCircle, Eye, ThumbsUp, MessageSquare, Play } from 'lucide-react';
import { formatDate } from '@/lib/utils';

interface VideoCardProps {
  video: Video;
  onApprove: (videoId: string) => void;
  onRemove: (videoId: string) => void;
  onPreview: (video: Video) => void;
  dateFormat?: string;
  selected?: boolean;
  onToggleSelect?: (videoId: string) => void;
}

export function VideoCard({ video, onApprove, onRemove, onPreview, dateFormat = 'MM/DD/YYYY', selected = false, onToggleSelect }: VideoCardProps) {
  const formatDuration = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  return (
    <Card className="overflow-hidden">
      <CardHeader className="p-0">
        <div className="relative aspect-video bg-muted">
          {onToggleSelect && (
            <input
              type="checkbox"
              checked={selected}
              onChange={() => onToggleSelect?.(video.id)}
              className="absolute top-2 left-2 h-4 w-4 accent-blue-600 z-10"
            />
          )}
          {video.thumbnailUrl ? (
            <img
              src={video.thumbnailUrl}
              alt={video.title}
              className="w-full h-full object-cover"
            />
          ) : (
            <div className="w-full h-full flex items-center justify-center">
              <Play className="w-12 h-12 text-muted-foreground" />
            </div>
          )}
          <div className="absolute bottom-2 right-2 bg-black/70 text-white text-xs px-2 py-1 rounded">
            {formatDuration(video.durationSeconds)}
          </div>
          <Badge
            variant="destructive"
            className="absolute top-2 right-2"
          >
            Flagged
          </Badge>
        </div>
      </CardHeader>
      <CardContent className="p-4">
        <h3 className="font-semibold text-lg line-clamp-2 mb-2">
          {video.title}
        </h3>
        <p className="text-sm text-muted-foreground line-clamp-2 mb-3">
          {video.description}
        </p>
        <div className="flex items-center gap-2 text-sm text-muted-foreground mb-2">
          <span>@{video.ownerUsername || 'Unknown'}</span>
          <span>•</span>
          <span>{video.createdAt ? formatDate(video.createdAt.toDate(), dateFormat) : ''}</span>
        </div>
        <div className="flex items-center gap-4 text-sm text-muted-foreground">
          <div className="flex items-center gap-1">
            <Eye className="w-4 h-4" />
            <span>{video.viewsCount?.toLocaleString() || 0}</span>
          </div>
          <div className="flex items-center gap-1">
            <ThumbsUp className="w-4 h-4" />
            <span>{video.likesCount?.toLocaleString() || 0}</span>
          </div>
          <div className="flex items-center gap-1">
            <MessageSquare className="w-4 h-4" />
            <span>{video.commentsCount?.toLocaleString() || 0}</span>
          </div>
        </div>
      </CardContent>
      <CardFooter className="p-4 pt-0 flex gap-2">
        <Button
          variant="outline"
          size="sm"
          className="flex-1"
          onClick={() => onPreview(video)}
        >
          <Eye className="w-4 h-4 mr-2" />
          Preview
        </Button>
        <Button
          variant="default"
          size="sm"
          className="flex-1 bg-green-600 hover:bg-green-700"
          onClick={() => onApprove(video.id)}
        >
          <CheckCircle2 className="w-4 h-4 mr-2" />
          Approve
        </Button>
        <Button
          variant="destructive"
          size="sm"
          className="flex-1"
          onClick={() => onRemove(video.id)}
        >
          <XCircle className="w-4 h-4 mr-2" />
          Remove
        </Button>
      </CardFooter>
    </Card>
  );
}
