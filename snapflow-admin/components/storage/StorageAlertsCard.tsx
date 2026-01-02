'use client';

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { AlertCircle, AlertTriangle, Info } from 'lucide-react';
import { Alert } from '@/lib/api/alerts';
import Link from 'next/link';

interface StorageAlertsCardProps {
  alerts: Alert[];
}

export function StorageAlertsCard({ alerts }: StorageAlertsCardProps) {
  // Format timestamp to relative time
  const formatRelativeTime = (timestamp: any): string => {
    const date = timestamp?.toDate ? timestamp.toDate() : new Date(timestamp);
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffMins = Math.floor(diffMs / 60000);
    const diffHours = Math.floor(diffMs / 3600000);
    const diffDays = Math.floor(diffMs / 86400000);

    if (diffMins < 60) {
      return `${diffMins} minute${diffMins !== 1 ? 's' : ''} ago`;
    } else if (diffHours < 24) {
      return `${diffHours} hour${diffHours !== 1 ? 's' : ''} ago`;
    } else if (diffDays < 7) {
      return `${diffDays} day${diffDays !== 1 ? 's' : ''} ago`;
    } else {
      return date.toLocaleDateString();
    }
  };

  // Get severity badge classes
  const getSeverityClasses = (severity: string) => {
    switch (severity) {
      case 'critical':
        return {
          bg: 'bg-red-100',
          text: 'text-red-800',
          border: 'border-red-200',
          icon: AlertCircle,
        };
      case 'warning':
        return {
          bg: 'bg-yellow-100',
          text: 'text-yellow-800',
          border: 'border-yellow-200',
          icon: AlertTriangle,
        };
      default:
        return {
          bg: 'bg-blue-100',
          text: 'text-blue-800',
          border: 'border-blue-200',
          icon: Info,
        };
    }
  };

  // Handle empty state
  if (!alerts || alerts.length === 0) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>Storage Alerts</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="text-center py-8">
            <Info className="w-12 h-12 text-muted-foreground mx-auto mb-3" />
            <p className="text-muted-foreground">No active storage alerts</p>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between">
        <CardTitle>Storage Alerts</CardTitle>
        <Link 
          href="/alerts" 
          className="text-sm text-blue-600 hover:text-blue-700 font-medium"
        >
          View All →
        </Link>
      </CardHeader>
      <CardContent>
        <div className="space-y-3">
          {alerts.map((alert) => {
            const severityClasses = getSeverityClasses(alert.severity);
            const Icon = severityClasses.icon;

            return (
              <div
                key={alert.id}
                className={`p-4 rounded-lg border ${severityClasses.border} ${severityClasses.bg}`}
              >
                <div className="flex items-start gap-3">
                  <Icon className={`w-5 h-5 ${severityClasses.text} shrink-0 mt-0.5`} />
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between gap-2 mb-1">
                      <span 
                        className={`text-xs font-semibold uppercase ${severityClasses.text}`}
                      >
                        {alert.severity}
                      </span>
                      <span className="text-xs text-muted-foreground">
                        {formatRelativeTime(alert.createdAt)}
                      </span>
                    </div>
                    <p className={`text-sm font-medium ${severityClasses.text} mb-2`}>
                      {alert.message}
                    </p>
                    {alert.threshold !== undefined && alert.currentValue !== undefined && (
                      <div className="flex items-center gap-4 text-xs text-muted-foreground">
                        <span>
                          Threshold: <span className="font-semibold">{alert.threshold} GB</span>
                        </span>
                        <span>
                          Current: <span className="font-semibold">{alert.currentValue.toFixed(2)} GB</span>
                        </span>
                      </div>
                    )}
                  </div>
                </div>
              </div>
            );
          })}
        </div>
      </CardContent>
    </Card>
  );
}
