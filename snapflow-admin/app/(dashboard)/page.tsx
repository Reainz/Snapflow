'use client';

import { useStats } from '@/lib/hooks/useStats';
import { StatCard } from '@/components/stats/StatCard';
import { Users, Video, Zap, Calendar, CalendarDays } from 'lucide-react';
import { Skeleton } from '@/components/ui/skeleton';

export default function DashboardPage() {
  const { data: stats, isLoading, error } = useStats();

  if (isLoading) {
    return (
      <div className="space-y-6">
        <h1 className="text-3xl font-bold text-foreground">Dashboard Overview</h1>
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-6">
          {[...Array(5)].map((_, i) => (
            <Skeleton key={i} className="h-32" />
          ))}
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="text-center py-12">
        <p className="text-red-600">Failed to load dashboard stats</p>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-foreground">Dashboard Overview</h1>
        <p className="text-muted-foreground mt-1">Monitor your platform&apos;s key metrics</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-5 gap-6">
        <StatCard
          title="Total Users"
          value={stats?.totalUsers || 0}
          icon={Users}
          color="indigo"
        />
        <StatCard
          title="Total Videos"
          value={stats?.totalVideos || 0}
          icon={Video}
          color="purple"
        />
        <StatCard
          title="Daily Active Users"
          value={stats?.dailyActiveUsers || 0}
          trend={stats?.dauTrend}
          icon={Zap}
          color="teal"
        />
        <StatCard
          title="Weekly Active Users"
          value={stats?.weeklyActiveUsers || 0}
          trend={stats?.wauTrend}
          icon={Calendar}
          color="blue"
        />
        <StatCard
          title="Monthly Active Users"
          value={stats?.monthlyActiveUsers || 0}
          trend={stats?.mauTrend}
          icon={CalendarDays}
          color="green"
        />
      </div>
    </div>
  );
}
