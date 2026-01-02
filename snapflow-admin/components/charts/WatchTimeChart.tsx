'use client';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { WatchTimeMetrics } from '@/lib/api/analytics';
import { Play, Clock, CheckCircle2 } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { formatDate } from '@/lib/utils';

interface WatchTimeChartProps {
  data: WatchTimeMetrics | null | undefined;
  dateFormat?: string;
}

export default function WatchTimeChart({ data, dateFormat = 'MM/DD/YYYY' }: WatchTimeChartProps) {
  if (!data) {
    return (
      <Card>
        <CardHeader>
          <div className="flex items-center gap-2">
            <CardTitle>Average Watch Time</CardTitle>
          </div>
          <CardDescription>Video watch time metrics</CardDescription>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">No watch time data available</p>
        </CardContent>
      </Card>
    );
  }

  const formatTime = (seconds: number): string => {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const completionPercentage = Math.round(data.completionRate * 100);

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center gap-2">
          <CardTitle>Average Watch Time</CardTitle>
          {data.isComputed && <Badge variant="outline">Computed</Badge>}
        </div>
        <CardDescription>
          Video engagement metrics
          {data.lastUpdated && (
            <span className="text-xs text-muted-foreground ml-2">
              Updated {formatDate(data.lastUpdated, dateFormat)}
            </span>
          )}
        </CardDescription>
      </CardHeader>
      <CardContent>
        {data.isComputed && (
          <p className="text-xs text-muted-foreground mb-2">
            Data computed from available sources; pre-aggregated analytics unavailable.
          </p>
        )}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="flex items-center gap-3">
            <div className="rounded-full bg-blue-100 p-3">
              <Clock className="h-5 w-5 text-blue-600" />
            </div>
            <div>
              <p className="text-2xl font-bold">{formatTime(data.averageWatchTimeSeconds)}</p>
              <p className="text-sm text-muted-foreground">Avg Watch Time</p>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <div className="rounded-full bg-green-100 p-3">
              <CheckCircle2 className="h-5 w-5 text-green-600" />
            </div>
            <div>
              <p className="text-2xl font-bold">{completionPercentage}%</p>
              <p className="text-sm text-muted-foreground">Completion Rate</p>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <div className="rounded-full bg-purple-100 p-3">
              <Play className="h-5 w-5 text-purple-600" />
            </div>
            <div>
              <p className="text-2xl font-bold">{data.totalWatchEvents.toLocaleString()}</p>
              <p className="text-sm text-muted-foreground">Total Views</p>
            </div>
          </div>
        </div>

        {data.averageWatchTimePerVideo && data.averageWatchTimePerVideo.length > 0 && (
          <div className="mt-8">
            <h4 className="text-sm font-semibold mb-4">Top Videos by Watch Time</h4>
            <div className="space-y-3">
              {data.averageWatchTimePerVideo.slice(0, 5).map((video, index) => (
                <div key={video.videoId} className="flex items-center justify-between">
                  <div className="flex items-center gap-2 flex-1">
                    <span className="text-sm font-medium text-muted-foreground w-6">
                      #{index + 1}
                    </span>
                    <span className="text-xs font-mono truncate flex-1">
                      {video.videoId}
                    </span>
                  </div>
                  <div className="flex items-center gap-4">
                    <span className="text-sm text-muted-foreground">
                      {video.totalViews} views
                    </span>
                    <span className="text-sm font-semibold min-w-[60px] text-right">
                      {formatTime(video.avgWatchTime)}
                    </span>
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
