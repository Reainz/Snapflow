'use client';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';
import { UserGrowthData } from '@/lib/api/analytics';
import { formatDate } from '@/lib/utils';

interface UserGrowthChartProps {
  data: UserGrowthData[];
  dateFormat?: string;
}

export default function UserGrowthChart({ data, dateFormat = 'MM/DD/YYYY' }: UserGrowthChartProps) {
  // Format date for display (MM/DD)
  const formattedData = data.map(item => ({
    ...item,
    displayDate: formatDate(new Date(item.date), dateFormat),
  }));

  return (
    <Card>
      <CardHeader>
        <CardTitle>User Growth</CardTitle>
        <CardDescription>New user registrations over time</CardDescription>
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
            />
            <Tooltip />
            <Legend />
            <Line 
              type="monotone" 
              dataKey="count" 
              stroke="#4F46E5" 
              strokeWidth={2}
              name="New Users"
              dot={{ fill: '#4F46E5' }}
            />
          </LineChart>
        </ResponsiveContainer>
      </CardContent>
    </Card>
  );
}
