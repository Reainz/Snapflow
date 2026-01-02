import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { TrendingUp, TrendingDown } from 'lucide-react';
import { LucideIcon } from 'lucide-react';

interface StatCardProps {
  title: string;
  value: number;
  trend?: number;
  icon: LucideIcon;
  color?: string;
}

export function StatCard({ title, value, trend, icon: Icon, color = 'blue' }: StatCardProps) {
  const hasTrend = trend !== undefined;
  const isPositive = trend && trend > 0;
  const isNeutral = trend === 0;
  
  const colorClasses = {
    blue: 'bg-blue-500',
    green: 'bg-green-500',
    purple: 'bg-purple-500',
    teal: 'bg-teal-500',
    indigo: 'bg-indigo-500',
  };

  // Determine trend color and icon
  const getTrendColor = () => {
    if (isPositive) return 'text-green-500';
    if (isNeutral) return 'text-muted-foreground';
    return 'text-red-500';
  };

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <CardTitle className="text-sm font-medium text-muted-foreground">{title}</CardTitle>
        <div className={`p-2 rounded-lg ${colorClasses[color as keyof typeof colorClasses] || colorClasses.blue}`}>
          <Icon className="w-4 h-4 text-white" />
        </div>
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold text-foreground">
          {value.toLocaleString()}
        </div>
        {hasTrend && (
          <div className="flex items-center gap-1 mt-2">
            {isPositive ? (
              <TrendingUp className="w-4 h-4 text-green-600" />
            ) : isNeutral ? (
              <span className="w-4 h-4 text-muted-foreground">—</span>
            ) : (
              <TrendingDown className="w-4 h-4 text-red-600" />
            )}
            <span className={`text-sm font-medium ${getTrendColor()}`}>
              {Math.abs(trend).toFixed(1)}%
            </span>
            <span className="text-sm text-muted-foreground">vs previous</span>
          </div>
        )}
      </CardContent>
    </Card>
  );
}
