'use client';

import { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { ArrowUpDown, ArrowUp, ArrowDown } from 'lucide-react';
import { BucketStats } from '@/lib/api/storage';

interface BucketBreakdownCardProps {
  bucketStats: {
    'raw-videos': BucketStats;
    'thumbnails': BucketStats;
    'captions': BucketStats;
    'profile-pictures': BucketStats;
    'other': BucketStats;
  };
  totalSizeGB: number;
}

type BucketType = keyof BucketBreakdownCardProps['bucketStats'];
type SortField = 'name' | 'count' | 'size' | 'percentage';
type SortDirection = 'asc' | 'desc';

interface BucketRow {
  name: string;
  displayName: string;
  count: number;
  sizeGB: number;
  percentage: number;
}

export function BucketBreakdownCard({ bucketStats, totalSizeGB }: BucketBreakdownCardProps) {
  const [sortField, setSortField] = useState<SortField>('size');
  const [sortDirection, setSortDirection] = useState<SortDirection>('desc');

  // Format bucket name for display
  const formatBucketName = (name: string): string => {
    return name
      .split('-')
      .map(word => word.charAt(0).toUpperCase() + word.slice(1))
      .join(' ');
  };

  // Convert bucket stats to row data
  const bucketRows: BucketRow[] = Object.entries(bucketStats).map(([name, stats]) => {
    const sizeGB = parseFloat(stats.sizeGB);
    const percentage = totalSizeGB > 0 ? (sizeGB / totalSizeGB) * 100 : 0;
    
    return {
      name,
      displayName: formatBucketName(name),
      count: stats.count,
      sizeGB,
      percentage,
    };
  });

  // Sort bucket rows
  const sortedRows = [...bucketRows].sort((a, b) => {
    let compareValue = 0;
    
    switch (sortField) {
      case 'name':
        compareValue = a.displayName.localeCompare(b.displayName);
        break;
      case 'count':
        compareValue = a.count - b.count;
        break;
      case 'size':
        compareValue = a.sizeGB - b.sizeGB;
        break;
      case 'percentage':
        compareValue = a.percentage - b.percentage;
        break;
    }
    
    return sortDirection === 'asc' ? compareValue : -compareValue;
  });

  // Toggle sort
  const handleSort = (field: SortField) => {
    if (sortField === field) {
      setSortDirection(sortDirection === 'asc' ? 'desc' : 'asc');
    } else {
      setSortField(field);
      setSortDirection('desc');
    }
  };

  // Render sort icon
  const SortIcon = ({ field }: { field: SortField }) => {
    if (sortField !== field) {
      return <ArrowUpDown className="w-4 h-4 text-muted-foreground" />;
    }
    return sortDirection === 'asc' 
      ? <ArrowUp className="w-4 h-4 text-blue-600" />
      : <ArrowDown className="w-4 h-4 text-blue-600" />;
  };

  // Handle empty data
  if (totalSizeGB === 0 || bucketRows.every(row => row.count === 0)) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Storage Breakdown by Bucket</CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-center text-muted-foreground py-8">
            No storage data available
          </p>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Storage Breakdown by Bucket</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="overflow-x-auto">
          <table className="w-full">
            <thead>
              <tr className="border-b border-border">
                <th 
                  className="text-left py-3 px-4 font-medium text-muted-foreground cursor-pointer hover:bg-muted"
                  onClick={() => handleSort('name')}
                >
                  <div className="flex items-center gap-2">
                    Bucket Type
                    <SortIcon field="name" />
                  </div>
                </th>
                <th 
                  className="text-right py-3 px-4 font-medium text-muted-foreground cursor-pointer hover:bg-muted"
                  onClick={() => handleSort('count')}
                >
                  <div className="flex items-center justify-end gap-2">
                    File Count
                    <SortIcon field="count" />
                  </div>
                </th>
                <th 
                  className="text-right py-3 px-4 font-medium text-muted-foreground cursor-pointer hover:bg-muted"
                  onClick={() => handleSort('size')}
                >
                  <div className="flex items-center justify-end gap-2">
                    Size (GB)
                    <SortIcon field="size" />
                  </div>
                </th>
                <th 
                  className="text-right py-3 px-4 font-medium text-muted-foreground cursor-pointer hover:bg-muted"
                  onClick={() => handleSort('percentage')}
                >
                  <div className="flex items-center justify-end gap-2">
                    Percentage
                    <SortIcon field="percentage" />
                  </div>
                </th>
              </tr>
            </thead>
            <tbody>
              {sortedRows.map((row) => (
                <tr 
                  key={row.name}
                  className="border-b border-border hover:bg-muted transition-colors"
                >
                  <td className="py-3 px-4 font-medium text-foreground">
                    {row.displayName}
                  </td>
                  <td className="py-3 px-4 text-right text-muted-foreground">
                    {row.count.toLocaleString()}
                  </td>
                  <td className="py-3 px-4 text-right text-muted-foreground">
                    {row.sizeGB.toFixed(2)}
                  </td>
                  <td className="py-3 px-4 text-right">
                    <div className="flex items-center justify-end gap-2">
                      <div className="flex-1 max-w-[100px] bg-muted rounded-full h-2">
                        <div 
                          className="bg-blue-500 h-2 rounded-full transition-all"
                          style={{ width: `${Math.min(row.percentage, 100)}%` }}
                        />
                      </div>
                      <span className="text-muted-foreground min-w-[50px] text-right">
                        {row.percentage.toFixed(1)}%
                      </span>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </CardContent>
    </Card>
  );
}
