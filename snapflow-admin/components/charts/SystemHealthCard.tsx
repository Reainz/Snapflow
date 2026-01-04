'use client';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Activity, AlertTriangle, Clock, HardDrive } from 'lucide-react';
import { SystemHealthMetrics } from '@/lib/api/analytics';

interface SystemHealthCardProps {
  systemHealth: SystemHealthMetrics | null;
}

export default function SystemHealthCard({ systemHealth }: SystemHealthCardProps) {
  if (!systemHealth) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>System Health</CardTitle>
          <CardDescription>Processing and system metrics</CardDescription>
        </CardHeader>
        <CardContent>
          <div className="text-center text-muted-foreground py-8">
            No system health data available
          </div>
        </CardContent>
      </Card>
    );
  }

  const successRate = systemHealth.processingSuccessRate;
  const getHealthColor = () => {
    if (successRate >= 95) return 'bg-green-500';
    if (successRate >= 80) return 'bg-orange-500';
    return 'bg-red-500';
  };

  const getHealthStatus = () => {
    if (successRate >= 95) return 'Healthy';
    if (successRate >= 80) return 'Warning';
    return 'Critical';
  };

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center gap-2">
          <CardTitle>System Health</CardTitle>
          <Badge variant="outline">
            {systemHealth.dataSource === 'analytics'
              ? 'Live analytics'
              : systemHealth.isComputed
              ? 'Computed fallback'
              : 'Live'}
          </Badge>
        </div>
        <CardDescription>Processing and system metrics</CardDescription>
      </CardHeader>
      <CardContent>
        {systemHealth.isComputed && (
          <p className="text-xs text-muted-foreground mb-2">
            {systemHealth.message ||
              'Data computed from current video statuses and alerts; pre-aggregated analytics unavailable.'}
          </p>
        )}
        {systemHealth.hasData === false && (
          <p className="text-xs text-destructive mb-2">
            No recent system health data available; verify analytics job is running.
          </p>
        )}
        <div className="space-y-4">
          {/* Health Status */}
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Activity className="h-5 w-5 text-muted-foreground" />
              <span className="text-sm font-medium">Status</span>
            </div>
            <Badge className={getHealthColor()}>
              {getHealthStatus()}
            </Badge>
          </div>

          {/* Success Rate */}
          <div className="flex items-center justify-between">
            <span className="text-sm text-muted-foreground">Success Rate</span>
            <span className="text-2xl font-bold">{successRate.toFixed(1)}%</span>
          </div>

          {/* Processing Errors */}
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <AlertTriangle className="h-5 w-5 text-orange-500" />
              <span className="text-sm text-muted-foreground">Errors (last hour)</span>
            </div>
            <span className="text-lg font-semibold">{systemHealth.processingErrors}</span>
          </div>

          {/* In-Flight Processing */}
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Clock className="h-5 w-5 text-blue-500" />
              <span className="text-sm text-muted-foreground">In-Flight (last hour)</span>
            </div>
            <span className="text-lg font-semibold">{systemHealth.processingInFlight}</span>
          </div>

          {/* Alerts */}
          {systemHealth.alertsLastHour !== undefined && (
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <AlertTriangle className="h-5 w-5 text-amber-500" />
                <span className="text-sm text-muted-foreground">Alerts (last {systemHealth.windowMinutes ?? 60}m)</span>
              </div>
              <span className="text-lg font-semibold">{systemHealth.alertsLastHour}</span>
            </div>
          )}

          {/* Storage Files (Optional) */}
          {systemHealth.storageRawFilesCount !== undefined && (
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <HardDrive className="h-5 w-5 text-purple-500" />
                <span className="text-sm text-muted-foreground">Storage Files</span>
              </div>
              <span className="text-lg font-semibold">
                {systemHealth.storageRawFilesCount.toLocaleString()}
              </span>
            </div>
          )}

          {/* Cloudinary Jobs */}
          {systemHealth.cloudinaryJobs && (
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <AlertTriangle className="h-5 w-5 text-amber-500" />
                <span className="text-sm text-muted-foreground">Cloudinary Jobs</span>
              </div>
              <span className="text-sm text-muted-foreground">
                Active: {systemHealth.cloudinaryJobs.activeJobs} | Failed: {systemHealth.cloudinaryJobs.failedJobs}
              </span>
            </div>
          )}

          {/* Cloud Functions */}
          {systemHealth.cloudFunctionsHealth && (
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Activity className="h-5 w-5 text-muted-foreground" />
                <span className="text-sm text-muted-foreground">Functions Health</span>
              </div>
              <span className="text-sm font-semibold">
                {systemHealth.cloudFunctionsHealth.healthy ? 'Healthy' : `Errors: ${systemHealth.cloudFunctionsHealth.recentErrors}`}
              </span>
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  );
}
