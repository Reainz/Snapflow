'use client';

import { useEffect, useState, useRef } from 'react';
import { useAuth } from '@/lib/hooks/useAuth';
import { useAdminSettings } from '@/lib/hooks/useAdminSettings';
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Separator } from '@/components/ui/separator';
import { Badge } from '@/components/ui/badge';
import { toast } from 'sonner';
import { useTheme } from 'next-themes';

const REFRESH_OPTIONS = [15, 30, 60, 120, 300];
const DATE_FORMAT_OPTIONS = ['MM/DD/YYYY', 'DD/MM/YYYY', 'YYYY-MM-DD'];

export default function SettingsPage() {
  const { user, signOut } = useAuth();
  const { settings, isLoading, isSaving, error, updateSettings } = useAdminSettings(user?.uid);
  const { setTheme: applyTheme } = useTheme();
  const [mounted, setMounted] = useState(false);
  const hasInitialized = useRef(false);

  const [autoRefreshInterval, setAutoRefreshInterval] = useState(30);
  const [dateFormat, setDateFormat] = useState('MM/DD/YYYY');
  const [theme, setTheme] = useState<'light' | 'dark' | 'system'>('system');

  // Prevent hydration mismatch
  useEffect(() => {
    setMounted(true);
  }, []);

  // Only initialize form values from settings once on initial load
  useEffect(() => {
    if (settings && !hasInitialized.current) {
      setAutoRefreshInterval(settings.autoRefreshInterval);
      setDateFormat(settings.dateFormat);
      setTheme(settings.theme);
      applyTheme(settings.theme);
      hasInitialized.current = true;
    }
  }, [settings, applyTheme]);

  const handleSave = async () => {
    if (!user) return;
    try {
      await updateSettings({
        autoRefreshInterval,
        dateFormat,
        theme,
      });
      toast.success('Settings saved');
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : 'Failed to save settings';
      toast.error(message);
    }
  };

  return (
    <div className="p-6 space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-foreground">Settings</h1>
        <p className="text-sm text-muted-foreground mt-1">
          Manage your admin account and dashboard preferences
        </p>
      </div>

      {/* Admin Profile Section */}
      <Card>
        <CardHeader>
          <CardTitle>Admin Profile</CardTitle>
          <CardDescription>Your admin account information</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <label className="text-sm font-medium text-foreground">Email Address</label>
            <p className="text-sm text-foreground bg-muted px-3 py-2 rounded-md">
              {user?.email || 'Not available'}
            </p>
          </div>
          <div className="space-y-2">
            <label className="text-sm font-medium text-foreground">User ID</label>
            <p className="text-sm text-foreground bg-muted px-3 py-2 rounded-md font-mono">
              {user?.uid || 'Not available'}
            </p>
          </div>
          <div className="space-y-2">
            <label className="text-sm font-medium text-foreground">Role</label>
            <div>
              <Badge variant="default" className="bg-blue-600">
                Administrator
              </Badge>
            </div>
          </div>
          <Separator />
          <Button variant="destructive" onClick={signOut} className="w-full sm:w-auto">
            Sign Out
          </Button>
        </CardContent>
      </Card>

      {/* Dashboard Preferences Section */}
      <Card>
        <CardHeader>
          <CardTitle>Dashboard Preferences</CardTitle>
          <CardDescription>Customize your admin dashboard experience</CardDescription>
        </CardHeader>
        <CardContent className="space-y-6">
          <div className="space-y-2">
            <label className="text-sm font-medium text-foreground">Auto-refresh Interval</label>
            <select
              className="border border-input rounded-md px-3 py-2 text-sm w-full bg-background text-foreground"
              value={autoRefreshInterval}
              onChange={(e) => setAutoRefreshInterval(Number(e.target.value))}
              disabled={isLoading || isSaving}
            >
              {REFRESH_OPTIONS.map((seconds) => (
                <option key={seconds} value={seconds}>
                  {seconds} seconds
                </option>
              ))}
            </select>
            <p className="text-xs text-muted-foreground">
              Controls how often dashboard data auto-refreshes.
            </p>
          </div>
          <Separator />
          <div className="space-y-2">
            <label className="text-sm font-medium text-foreground">Date Format</label>
            <select
              className="border border-input rounded-md px-3 py-2 text-sm w-full bg-background text-foreground"
              value={dateFormat}
              onChange={(e) => setDateFormat(e.target.value)}
              disabled={isLoading || isSaving}
            >
              {DATE_FORMAT_OPTIONS.map((format) => (
                <option key={format} value={format}>
                  {format}
                </option>
              ))}
            </select>
            <p className="text-xs text-muted-foreground">
              Dates across charts and tables will use this format.
            </p>
          </div>
          <Separator />
          <div className="space-y-2">
            <label className="text-sm font-medium text-foreground">Theme</label>
            <div className="flex gap-4">
              {(['light', 'dark', 'system'] as const).map((value) => (
                <label key={value} className="flex items-center gap-2 text-sm text-foreground cursor-pointer">
                  <input
                    type="radio"
                    name="theme"
                    value={value}
                    checked={mounted ? theme === value : value === 'system'}
                    onChange={() => {
                      setTheme(value);
                      applyTheme(value);
                    }}
                    disabled={isLoading || isSaving}
                    className="accent-primary"
                  />
                  <span className="capitalize">{value}</span>
                </label>
              ))}
            </div>
            <p className="text-xs text-muted-foreground">
              Choose between light, dark, or system theme preference.
            </p>
          </div>
          {error && (
            <p className="text-sm text-destructive">
              Failed to load settings. Displaying defaults.
            </p>
          )}
          <div className="flex justify-end">
            <Button onClick={handleSave} disabled={isLoading || isSaving || !user}>
              {isSaving ? 'Saving...' : 'Save Settings'}
            </Button>
          </div>
        </CardContent>
      </Card>

      {/* System Information Section */}
      <Card>
        <CardHeader>
          <CardTitle>System Information</CardTitle>
          <CardDescription>Admin dashboard version and configuration</CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <div className="space-y-2">
            <label className="text-sm font-medium text-foreground">Dashboard Version</label>
            <p className="text-sm text-foreground">1.0.0</p>
          </div>
          <Separator />
          <div className="space-y-2">
            <label className="text-sm font-medium text-foreground">Firebase Project</label>
            <p className="text-sm text-foreground font-mono">
              {process.env.NEXT_PUBLIC_FIREBASE_PROJECT_ID || 'snapflow-4577d'}
            </p>
          </div>
          <Separator />
          <div className="space-y-2">
            <label className="text-sm font-medium text-foreground">Environment</label>
            <Badge variant="outline">
              {process.env.NODE_ENV === 'production' ? 'Production' : 'Development'}
            </Badge>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
