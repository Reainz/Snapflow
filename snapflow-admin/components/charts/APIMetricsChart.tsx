'use client';

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { APIMetrics } from '@/lib/api/analytics';
import { Activity, AlertCircle, Clock, TrendingUp } from 'lucide-react';
import { Badge } from '@/components/ui/badge';
import { formatDate } from '@/lib/utils';

interface APIMetricsChartProps {
  data: APIMetrics | null | undefined;
  dateFormat?: string;
}

export default function APIMetricsChart({ data, dateFormat = 'MM/DD/YYYY' }: APIMetricsChartProps) {
  if (!data || data.hasData === false) {
    return (
      <Card>
        <CardHeader>
          <CardTitle>API Performance</CardTitle>
          <CardDescription>No API metrics available</CardDescription>
        </CardHeader>
        <CardContent>
          <p className="text-sm text-muted-foreground">
            API performance data will appear here once functions are called and analytics collection runs.
          </p>
        </CardContent>
      </Card>
    );
  }

  const formatResponseTime = (ms: number): string => {
    if (ms < 1000) return `${ms}ms`;
    return `${(ms / 1000).toFixed(2)}s`;
  };

  const splitResponseTime = (ms: number): { value: string; unit: 'ms' | 's' } => {
    if (ms < 1000) return { value: `${Math.round(ms)}`, unit: 'ms' };
    return { value: `${(ms / 1000).toFixed(2)}`, unit: 's' };
  };

  const getResponseTimeColor = (ms: number): string => {
    if (ms < 200) return 'text-green-600';
    if (ms < 500) return 'text-yellow-600';
    return 'text-red-600';
  };

  const getErrorRateColor = (rate: number): string => {
    if (rate < 0.01) return 'text-green-600';
    if (rate < 0.05) return 'text-yellow-600';
    return 'text-red-600';
  };

  const kpiValueClass = 'text-3xl font-bold leading-none tabular-nums';
  const kpiUnitClass = 'text-base font-semibold leading-none';

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center gap-2">
          <CardTitle>API Performance</CardTitle>
          {data.isComputed && <Badge variant="outline">Computed</Badge>}
        </div>
        <CardDescription>
          {data.lastUpdated
            ? `Last updated: ${formatDate(data.lastUpdated, dateFormat)}`
            : 'Real-time API metrics'}
        </CardDescription>
      </CardHeader>
      <CardContent>
        {data.isComputed && (
          <p className="text-xs text-muted-foreground mb-2">
            Data computed from available sources; pre-aggregated analytics unavailable.
          </p>
        )}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-4 mb-6">
          <div className="flex flex-col space-y-1 p-4 rounded-lg bg-blue-50 dark:bg-blue-950/30">
            <div className="flex items-center gap-2">
              <Clock className="h-4 w-4 text-blue-600" />
              <span className="text-xs font-medium text-muted-foreground">Avg Response Time</span>
            </div>
            {(() => {
              const { value, unit } = splitResponseTime(data.overallAvgResponseTime);
              return (
                <span className={`${kpiValueClass} text-blue-600`}>
                  {value}
                  <span className={`${kpiUnitClass} ml-1 text-blue-600`}>{unit}</span>
                </span>
              );
            })()}
          </div>

          <div className="flex flex-col space-y-1 p-4 rounded-lg bg-red-50 dark:bg-red-950/30">
            <div className="flex items-center gap-2">
              <AlertCircle className="h-4 w-4 text-red-600" />
              <span className="text-xs font-medium text-muted-foreground">Error Rate</span>
            </div>
            <span className={`${kpiValueClass} text-red-600`}>
              {(data.overallErrorRate * 100).toFixed(2)}
              <span className={`${kpiUnitClass} ml-1 text-red-600`}>%</span>
            </span>
          </div>

          <div className="flex flex-col space-y-1 p-4 rounded-lg bg-green-50 dark:bg-green-950/30">
            <div className="flex items-center gap-2">
              <Activity className="h-4 w-4 text-green-600" />
              <span className="text-xs font-medium text-muted-foreground">Total Calls</span>
            </div>
            <span className={`${kpiValueClass} text-green-600`}>
              {data.totalCalls.toLocaleString()}
            </span>
          </div>

          <div className="flex flex-col space-y-1 p-4 rounded-lg bg-orange-50 dark:bg-orange-950/30">
            <div className="flex items-center gap-2">
              <TrendingUp className="h-4 w-4 text-orange-600" />
              <span className="text-xs font-medium text-muted-foreground">Total Errors</span>
            </div>
            <span className={`${kpiValueClass} text-orange-600`}>
              {data.totalErrors.toLocaleString()}
            </span>
          </div>
        </div>

        <div className="space-y-2">
          <h3 className="text-sm font-medium">Function Performance</h3>
          <div className="rounded-md border">
            <table className="w-full text-sm">
              <thead className="bg-muted/50">
                <tr className="border-b">
                  <th className="text-left p-3 font-medium">Function</th>
                  <th className="text-right p-3 font-medium">Calls</th>
                  <th className="text-right p-3 font-medium">Avg Time</th>
                  <th className="text-right p-3 font-medium">P95 Time</th>
                  <th className="text-right p-3 font-medium">Errors</th>
                  <th className="text-right p-3 font-medium">Error Rate</th>
                </tr>
              </thead>
              <tbody>
                {data.functions.length === 0 ? (
                  <tr>
                    <td colSpan={6} className="text-center p-4 text-muted-foreground">
                      No function metrics available
                    </td>
                  </tr>
                ) : (
                  data.functions.map((fn, index) => (
                    <tr key={fn.name} className={index % 2 === 0 ? 'bg-background' : 'bg-muted/20'}>
                      <td className="p-3 font-mono text-xs">{fn.name}</td>
                      <td className="p-3 text-right">{fn.totalCalls.toLocaleString()}</td>
                      <td className={`p-3 text-right ${getResponseTimeColor(fn.avgResponseTimeMs)}`}>
                        {formatResponseTime(fn.avgResponseTimeMs)}
                      </td>
                      <td className={`p-3 text-right ${getResponseTimeColor(fn.p95ResponseTimeMs)}`}>
                        {formatResponseTime(fn.p95ResponseTimeMs)}
                      </td>
                      <td className="p-3 text-right text-red-600">{fn.errors}</td>
                      <td className={`p-3 text-right ${getErrorRateColor(fn.errorRate)}`}>
                        {(fn.errorRate * 100).toFixed(2)}%
                      </td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </div>

        <div className="mt-4 p-4 rounded-lg bg-muted/50 space-y-2">
          <h3 className="text-sm font-medium">Performance Insights</h3>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-2 text-sm">
            <div>
              <span className="text-muted-foreground">Response Time Status: </span>
              {data.overallAvgResponseTime < 200 ? (
                <span className="text-green-600 font-medium">Excellent (&lt;200ms)</span>
              ) : data.overallAvgResponseTime < 500 ? (
                <span className="text-yellow-600 font-medium">Good (&lt;500ms)</span>
              ) : (
                <span className="text-red-600 font-medium">Needs Improvement (&gt;500ms)</span>
              )}
            </div>
            <div>
              <span className="text-muted-foreground">Error Rate Status: </span>
              {data.overallErrorRate < 0.01 ? (
                <span className="text-green-600 font-medium">Excellent (&lt;1%)</span>
              ) : data.overallErrorRate < 0.05 ? (
                <span className="text-yellow-600 font-medium">Acceptable (&lt;5%)</span>
              ) : (
                <span className="text-red-600 font-medium">High Error Rate (&gt;5%)</span>
              )}
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
