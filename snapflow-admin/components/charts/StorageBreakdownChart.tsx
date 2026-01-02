'use client';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { PieChart, Pie, Cell, ResponsiveContainer, Legend, Tooltip } from 'recharts';
import { BucketStats } from '@/lib/api/storage';

interface StorageBreakdownChartProps {
  bucketStats: {
    'raw-videos': BucketStats;
    'thumbnails': BucketStats;
    'captions': BucketStats;
    'profile-pictures': BucketStats;
    'other': BucketStats;
  };
  totalSizeGB: number;
}

// Define colors for each bucket type
const BUCKET_COLORS: Record<string, string> = {
  'raw-videos': '#EF4444',       // Red
  'thumbnails': '#10B981',       // Green
  'captions': '#F59E0B',         // Orange
  'profile-pictures': '#8B5CF6', // Purple
  'other': '#6B7280',            // Gray
};

export default function StorageBreakdownChart({ bucketStats, totalSizeGB }: StorageBreakdownChartProps) {
  // Transform bucket stats into chart data
  const chartData = Object.entries(bucketStats).map(([bucketType, stats]) => {
    const sizeGB = parseFloat(stats.sizeGB);
    const percentage = totalSizeGB > 0 ? (sizeGB / totalSizeGB) * 100 : 0;
    
    return {
      name: bucketType
        .split('-')
        .map(word => word.charAt(0).toUpperCase() + word.slice(1))
        .join(' '),
      value: sizeGB,
      count: stats.count,
      percentage: percentage,
      color: BUCKET_COLORS[bucketType] || '#6B7280',
    };
  }).filter(item => item.value > 0); // Only show buckets with data

  // Custom tooltip to show detailed information
  const CustomTooltip = ({ active, payload }: any) => {
    if (active && payload && payload.length) {
      const data = payload[0].payload;
      return (
        <div className="bg-popover text-popover-foreground p-3 border border-border rounded-lg shadow-lg">
          <p className="font-semibold text-sm mb-1">{data.name}</p>
          <p className="text-xs text-muted-foreground">Size: {data.value.toFixed(2)} GB</p>
          <p className="text-xs text-muted-foreground">Files: {data.count.toLocaleString()}</p>
          <p className="text-xs text-muted-foreground">Percentage: {data.percentage.toFixed(1)}%</p>
        </div>
      );
    }
    return null;
  };

  // Custom legend with more details
  const CustomLegend = ({ payload }: any) => {
    return (
      <div className="flex flex-col space-y-1 mt-4">
        {payload.map((entry: any, index: number) => (
          <div key={`legend-${index}`} className="flex items-center justify-between text-xs">
            <div className="flex items-center">
              <div 
                className="w-3 h-3 rounded-sm mr-2" 
                style={{ backgroundColor: entry.color }}
              />
              <span>{entry.value}</span>
            </div>
            <span className="text-muted-foreground ml-2">
              {entry.payload.percentage.toFixed(1)}%
            </span>
          </div>
        ))}
      </div>
    );
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle>Storage Breakdown by Type</CardTitle>
        <CardDescription>Distribution of storage across bucket types</CardDescription>
      </CardHeader>
      <CardContent>
        {chartData.length > 0 ? (
          <ResponsiveContainer width="100%" height={300}>
            <PieChart>
              <Pie
                data={chartData}
                cx="50%"
                cy="50%"
                labelLine={false}
                label={(entry: any) => `${entry.percentage.toFixed(1)}%`}
                outerRadius={80}
                fill="#8884d8"
                dataKey="value"
              >
                {chartData.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={entry.color} />
                ))}
              </Pie>
              <Tooltip content={<CustomTooltip />} />
              <Legend content={<CustomLegend />} />
            </PieChart>
          </ResponsiveContainer>
        ) : (
          <div className="flex items-center justify-center h-[300px] text-muted-foreground">
            No storage data available
          </div>
        )}
      </CardContent>
    </Card>
  );
}
