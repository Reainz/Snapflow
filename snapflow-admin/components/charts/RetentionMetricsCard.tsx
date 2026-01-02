'use client';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { PieChart, Pie, Cell, ResponsiveContainer, Legend, Tooltip } from 'recharts';
import { Badge } from '@/components/ui/badge';

interface RetentionMetricsCardProps {
  d1RetentionRate: number;
  newUsersYesterday: number;
  isComputed?: boolean;
}

export default function RetentionMetricsCard({ d1RetentionRate, newUsersYesterday, isComputed }: RetentionMetricsCardProps) {
  const retentionData = [
    { name: 'Retained', value: d1RetentionRate },
    { name: 'Not Retained', value: 100 - d1RetentionRate },
  ];

  const COLORS = ['#10B981', '#E5E7EB'];

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center gap-2">
          <CardTitle>D1 Retention</CardTitle>
          {isComputed && <Badge variant="outline">Computed</Badge>}
        </div>
        <CardDescription>Day 1 user retention rate</CardDescription>
      </CardHeader>
      <CardContent>
        {isComputed && (
          <p className="text-xs text-muted-foreground mb-2">
            Data computed from raw sources; pre-aggregated analytics unavailable.
          </p>
        )}
        <div className="flex flex-col items-center space-y-4">
          <div className="text-4xl font-bold text-green-600">
            {d1RetentionRate.toFixed(1)}%
          </div>
          
          <ResponsiveContainer width="100%" height={200}>
            <PieChart>
              <Pie
                data={retentionData}
                cx="50%"
                cy="50%"
                innerRadius={60}
                outerRadius={80}
                paddingAngle={5}
                dataKey="value"
              >
                {retentionData.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={COLORS[index]} />
                ))}
              </Pie>
              <Tooltip formatter={(value: number) => `${value.toFixed(1)}%`} />
              <Legend />
            </PieChart>
          </ResponsiveContainer>
          
          <div className="text-center">
            <div className="text-sm text-muted-foreground">New users yesterday</div>
            <div className="text-2xl font-semibold">{newUsersYesterday.toLocaleString()}</div>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
