'use client';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { StorageMetricsHistory } from '@/lib/api/storage';
import { formatDate } from '@/lib/utils';

interface StorageUsageChartProps {
  data: StorageMetricsHistory[];
  dateFormat?: string;
}

export default function StorageUsageChart({ data, dateFormat = 'MM/DD/YYYY' }: StorageUsageChartProps) {
  // Format date for display (MM/DD)
  const formattedData = data.map(item => ({
    ...item,
    displayDate: formatDate(new Date(item.date), dateFormat),
  }));

  return (
    <Card>
      <CardHeader>
        <CardTitle>Storage Usage Over Time</CardTitle>
        <CardDescription>Total storage consumption trend</CardDescription>
      </CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={formattedData}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis 
              dataKey="displayDate" 
              tick={{ fontSize: 12 }}
            />
            <YAxis 
              tick={{ fontSize: 12 }}
              label={{ value: 'Storage (GB)', angle: -90, position: 'insideLeft' }}
            />
            <Tooltip 
              formatter={(value: number) => `${value.toFixed(2)} GB`}
              labelFormatter={(label) => `Date: ${label}`}
            />
            <Legend />
            <Line 
              type="monotone" 
              dataKey="totalSizeGB" 
              stroke="#3B82F6" 
              strokeWidth={2}
              name="Storage (GB)"
              dot={{ fill: '#3B82F6' }}
            />
          </LineChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  );
}
