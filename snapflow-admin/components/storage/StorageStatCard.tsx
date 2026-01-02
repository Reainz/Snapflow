import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { LucideIcon } from 'lucide-react';

interface StorageStatCardProps {
  title: string;
  value: string | number;
  subtitle?: string;
  icon: LucideIcon;
  color?: 'blue' | 'green' | 'purple' | 'teal' | 'indigo' | 'orange';
}

export function StorageStatCard({ 
  title, 
  value, 
  subtitle, 
  icon: Icon, 
  color = 'blue' 
}: StorageStatCardProps) {
  const colorClasses = {
    blue: 'bg-blue-500',
    green: 'bg-green-500',
    purple: 'bg-purple-500',
    teal: 'bg-teal-500',
    indigo: 'bg-indigo-500',
    orange: 'bg-orange-500',
  };

  // Format value if it's a number
  const displayValue = typeof value === 'number' 
    ? value.toLocaleString() 
    : value;

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between pb-2">
        <CardTitle className="text-sm font-medium text-muted-foreground">{title}</CardTitle>
        <div className={`p-2 rounded-lg ${colorClasses[color]}`}>
          <Icon className="w-4 h-4 text-white" />
        </div>
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold text-foreground">
          {displayValue}
        </div>
        {subtitle && (
          <p className="text-sm text-muted-foreground mt-2">
            {subtitle}
          </p>
        )}
      </CardContent>
    </Card>
  );
}
