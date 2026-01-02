import { useEffect, useRef } from 'react';
import { useTheme } from 'next-themes';
import { useAdminSettings } from '@/lib/hooks/useAdminSettings';
import { useAuth } from '@/lib/hooks/useAuth';

export function useThemeSync() {
  const { user } = useAuth();
  const { settings } = useAdminSettings(user?.uid);
  const { setTheme } = useTheme();
  const hasInitialized = useRef(false);

  // Only sync theme on initial settings load, not on every change
  useEffect(() => {
    if (settings?.theme && !hasInitialized.current) {
      setTheme(settings.theme);
      hasInitialized.current = true;
    }
  }, [settings?.theme, setTheme]);
}
