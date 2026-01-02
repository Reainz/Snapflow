'use client';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { BarChart, Bar, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer, Cell } from 'recharts';
import { GeographicDistribution } from '@/lib/api/analytics';
import { Badge } from '@/components/ui/badge';

interface GeographicDistributionChartProps {
  data: GeographicDistribution;
  showRegions?: boolean;
}

export default function GeographicDistributionChart({ 
  data, 
  showRegions = false 
}: GeographicDistributionChartProps) {
  // Top 10 countries or regions
  const displayData = showRegions 
    ? data.regions.slice(0, 10)
    : data.countries.slice(0, 10);

  // Format for chart
  const formattedData = displayData.map(item => ({
    name: showRegions 
      ? ('region' in item ? item.region : '') 
      : ('countryCode' in item ? item.countryCode : ''),
    users: item.count,
  }));

  // Color palette for bars
  const colors = [
    '#4F46E5', // Indigo
    '#7C3AED', // Purple
    '#EC4899', // Pink
    '#F59E0B', // Amber
    '#10B981', // Green
    '#3B82F6', // Blue
    '#EF4444', // Red
    '#8B5CF6', // Violet
    '#14B8A6', // Teal
    '#F97316', // Orange
  ];

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center gap-2">
          <CardTitle>Geographic Distribution</CardTitle>
          {data.isComputed && <Badge variant="outline">Computed</Badge>}
        </div>
        <CardDescription>
          {showRegions 
            ? `Users by region (${data.totalUsersWithGeoData} total with geo data)`
            : `Top 10 countries (${data.totalUsersWithGeoData} total with geo data)`
          }
        </CardDescription>
      </CardHeader>
      <CardContent>
        {data.isComputed && (
          <p className="text-xs text-muted-foreground mb-2">
            Data computed from user records; pre-aggregated analytics unavailable.
          </p>
        )}
        {formattedData.length > 0 ? (
          <ResponsiveContainer width="100%" height={350}>
            <BarChart data={formattedData} layout="vertical">
              <CartesianGrid strokeDasharray="3 3" />
              <XAxis type="number" tick={{ fontSize: 12 }} />
              <YAxis 
                type="category" 
                dataKey="name" 
                tick={{ fontSize: 12 }}
                width={80}
              />
              <Tooltip 
                formatter={(value: number) => [`${value} users`, 'Users']}
              />
              <Legend />
              <Bar 
                dataKey="users" 
                name="Users"
                radius={[0, 4, 4, 0]}
              >
                {formattedData.map((entry, index) => (
                  <Cell key={`cell-${index}`} fill={colors[index % colors.length]} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        ) : (
          <div className="flex items-center justify-center h-[350px] text-muted-foreground">
            No geographic data available yet
          </div>
        )}
      </CardContent>
    </Card>
  );
}
