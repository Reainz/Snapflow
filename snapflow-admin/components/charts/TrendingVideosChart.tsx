'use client';

import { useMemo, useState } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { TrendingVideo } from '@/lib/api/analytics';
import { ArrowUpDown, Flame } from 'lucide-react';

interface TrendingVideosChartProps {
  data: TrendingVideo[];
}

type SortField = 'engagement' | 'views' | 'likes' | 'shares';

export default function TrendingVideosChart({ data }: TrendingVideosChartProps) {
  const [sortBy, setSortBy] = useState<SortField>('engagement');

  const sorted = useMemo(() => {
    const copy = [...data];
    const scoreFor = (video: TrendingVideo) => video.engagementScore ?? 0;
    const fieldMap: Record<Exclude<SortField, 'engagement'>, keyof TrendingVideo> = {
      views: 'viewsCount',
      likes: 'likesCount',
      shares: 'sharesCount',
    };

    copy.sort((a, b) => {
      if (sortBy === 'engagement') {
        return scoreFor(b) - scoreFor(a);
      }
      const key = fieldMap[sortBy];
      return (b[key] as number) - (a[key] as number);
    });

    return copy;
  }, [data, sortBy]);

  return (
    <Card>
      <CardHeader className="flex flex-col gap-2 sm:flex-row sm:items-center sm:justify-between">
        <div>
          <CardTitle>Trending Videos</CardTitle>
          <CardDescription>Top performing videos by engagement</CardDescription>
        </div>
        <div className="flex items-center gap-2 text-sm">
          <ArrowUpDown className="h-4 w-4 text-muted-foreground" />
          <span className="text-muted-foreground">Sort by:</span>
          <select
            className="border rounded-md px-2 py-1 text-sm"
            value={sortBy}
            onChange={(e) => setSortBy(e.target.value as SortField)}
          >
            <option value="engagement">Engagement</option>
            <option value="views">Views</option>
            <option value="likes">Likes</option>
            <option value="shares">Shares</option>
          </select>
        </div>
      </CardHeader>
      <CardContent>
        {sorted.length === 0 ? (
          <div className="text-center text-muted-foreground py-12">
            No trending data available yet
          </div>
        ) : (
          <div className="overflow-x-auto">
            <table className="w-full text-sm">
              <thead className="bg-muted/50">
                <tr>
                  <th className="text-left p-3 font-medium">#</th>
                  <th className="text-left p-3 font-medium">Video</th>
                  <th className="text-left p-3 font-medium">Owner</th>
                  <th className="text-right p-3 font-medium">Views</th>
                  <th className="text-right p-3 font-medium">Likes</th>
                  <th className="text-right p-3 font-medium">Comments</th>
                  <th className="text-right p-3 font-medium">Shares</th>
                  <th className="text-right p-3 font-medium">Engagement</th>
                </tr>
              </thead>
              <tbody>
                {sorted.map((video, index) => (
                  <tr key={video.id} className={index % 2 === 0 ? 'bg-background' : 'bg-muted/20'}>
                    <td className="p-3 font-medium text-muted-foreground">{index + 1}</td>
                    <td className="p-3">
                      <div className="flex items-center gap-3">
                        <div className="w-14 h-9 bg-muted rounded overflow-hidden flex items-center justify-center">
                          {video.thumbnailUrl ? (
                            <img
                              src={video.thumbnailUrl}
                              alt={video.title}
                              className="w-full h-full object-cover"
                            />
                          ) : (
                            <Flame className="h-4 w-4 text-orange-500" />
                          )}
                        </div>
                        <div className="space-y-1">
                          <div className="font-semibold line-clamp-1">{video.title || 'Untitled'}</div>
                          {video.engagementScore !== undefined && (
                            <Badge variant="outline" className="text-xs">
                              {video.engagementScore.toFixed(1)} score
                            </Badge>
                          )}
                        </div>
                      </div>
                    </td>
                    <td className="p-3 text-muted-foreground">@{video.ownerUsername || 'unknown'}</td>
                    <td className="p-3 text-right">{video.viewsCount.toLocaleString()}</td>
                    <td className="p-3 text-right">{video.likesCount.toLocaleString()}</td>
                    <td className="p-3 text-right">{video.commentsCount.toLocaleString()}</td>
                    <td className="p-3 text-right">{video.sharesCount.toLocaleString()}</td>
                    <td className="p-3 text-right">
                      {video.engagementScore !== undefined ? video.engagementScore.toFixed(1) : '—'}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
