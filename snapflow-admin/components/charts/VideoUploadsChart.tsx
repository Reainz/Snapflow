'use client';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { VideoUploadData } from '@/lib/api/analytics';
import { formatDate } from '@/lib/utils';

interface VideoUploadsChartProps {
  data: VideoUploadData[];
  dateFormat?: string;
}

export default function VideoUploadsChart({ data, dateFormat = 'MM/DD/YYYY' }: VideoUploadsChartProps) {
  // Format date for display (MM/DD)
  const formattedData = data.map(item => ({
    ...item,
    displayDate: formatDate(new Date(item.date), dateFormat),
  }));

  return (
    <Card>
      <CardHeader>
        <CardTitle>Video Uploads</CardTitle>
        <CardDescription>Daily video uploads over time</CardDescription>
      </CardHeader>
      <CardContent>
        <ResponsiveContainer width="100%" height={300}>
          <BarChart data={formattedData}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis 
              dataKey="displayDate" 
              tick={{ fontSize: 12 }}
            />
            <YAxis 
              tick={{ fontSize: 12 }}
            />
            <Tooltip />
            <Legend />
            <Bar 
              dataKey="count" 
              fill="#7C3AED" 
              name="Videos Uploaded"
              radius={[4, 4, 0, 0]}
            />
          </BarChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  );
}
