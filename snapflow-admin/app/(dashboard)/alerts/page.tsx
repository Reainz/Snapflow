'use client';

import { useState } from 'react';
import { useAlerts } from '@/lib/hooks/useAlerts';
import { useAdminSettings } from '@/lib/hooks/useAdminSettings';
import { useAuth } from '@/lib/hooks/useAuth';
import AlertCard from '@/components/alerts/AlertCard';
import AlertsFilter from '@/components/alerts/AlertsFilter';
import { Skeleton } from '@/components/ui/skeleton';
import { Card, CardContent } from '@/components/ui/card';
import { toast } from 'sonner';
import { Bell } from 'lucide-react';

function LoadingSkeletons() {
  return (
    <div className="space-y-4">
      {[1, 2, 3].map((i) => (
        <Card key={i}>
          <CardContent className="p-6">
            <div className="flex items-start gap-4">
              <Skeleton className="w-12 h-12 rounded-lg" />
              <div className="flex-1 space-y-3">
                <Skeleton className="h-5 w-24" />
                <Skeleton className="h-6 w-full" />
                <div className="grid grid-cols-2 gap-4">
                  <Skeleton className="h-4 w-32" />
                  <Skeleton className="h-4 w-32" />
                  <Skeleton className="h-4 w-32" />
                  <Skeleton className="h-4 w-32" />
                </div>
              </div>
              <Skeleton className="h-9 w-28" />
            </div>
          </CardContent>
        </Card>
      ))}
    </div>
  );
}

function EmptyState({ message }: { message: string }) {
  return (
    <Card>
      <CardContent className="flex flex-col items-center justify-center py-16">
        <div className="bg-muted p-6 rounded-full mb-4">
          <Bell className="w-12 h-12 text-muted-foreground" />
        </div>
        <p className="text-lg font-medium text-foreground mb-1">{message}</p>
        <p className="text-sm text-muted-foreground">
          System alerts will appear here when triggered
        </p>
      </CardContent>
    </Card>
  );
}

export default function AlertsPage() {
  const [showAll, setShowAll] = useState(false);
  const [severityFilter, setSeverityFilter] = useState<string>('all');

  const { user } = useAuth();
  const { settings } = useAdminSettings(user?.uid);
  const refreshSeconds = settings?.autoRefreshInterval ?? 30;
  const dateFormat = settings?.dateFormat ?? 'MM/DD/YYYY';

  const { alerts, isLoading, acknowledgeAlert, isAcknowledging } = useAlerts(showAll, refreshSeconds);

  const filteredAlerts = alerts.filter((alert) => {
    if (severityFilter === 'all') return true;
    return alert.severity === severityFilter;
  });

  const handleAcknowledge = async (alertId: string) => {
    try {
      await acknowledgeAlert(alertId);
      toast.success('Alert acknowledged successfully');
    } catch (error) {
      console.error('Failed to acknowledge alert:', error);
      toast.error('Failed to acknowledge alert');
    }
  };

  return (
    <div className="p-6 space-y-6">
      <div className="flex flex-col sm:flex-row items-start sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-3xl font-bold text-foreground">System Alerts</h1>
          <p className="text-sm text-muted-foreground mt-1">
            Monitor and manage system alerts and notifications
          </p>
        </div>
        <AlertsFilter
          showAll={showAll}
          severity={severityFilter}
          onShowAllChange={setShowAll}
          onSeverityChange={setSeverityFilter}
        />
      </div>

      {isLoading ? (
        <LoadingSkeletons />
      ) : filteredAlerts.length === 0 ? (
        <EmptyState message="No alerts found" />
      ) : (
        <div className="space-y-4">
          {filteredAlerts.map((alert) => (
            <AlertCard
              key={alert.id}
              alert={alert}
              onAcknowledge={handleAcknowledge}
              isAcknowledging={isAcknowledging}
              dateFormat={dateFormat}
            />
          ))}
        </div>
      )}
    </div>
  );
}
