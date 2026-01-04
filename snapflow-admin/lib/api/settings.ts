import { AdminSettings } from '@/types/admin';

const DEFAULT_SETTINGS: AdminSettings = {
  autoRefreshInterval: 30,
  dateFormat: 'MM/DD/YYYY',
  theme: 'system',
};

export async function getAdminSettings(userId: string): Promise<AdminSettings> {
  try {
    // Get auth token from Firebase
    const { auth } = await import('@/lib/firebase/config');
    const user = auth.currentUser;
    if (!user) {
      return DEFAULT_SETTINGS;
    }
    
    const token = await user.getIdToken();
    const res = await fetch('/api/settings', {
      headers: {
        'Authorization': `Bearer ${token}`,
      },
    });
    
    if (!res.ok) {
      console.error('Failed to fetch settings:', res.status);
      return DEFAULT_SETTINGS;
    }
    
    return await res.json();
  } catch (error) {
    console.error('Error fetching settings:', error);
    return DEFAULT_SETTINGS;
  }
}

export async function updateAdminSettings(
  userId: string,
  settings: Partial<AdminSettings>
): Promise<void> {
  // Get auth token from Firebase
  const { auth } = await import('@/lib/firebase/config');
  const user = auth.currentUser;
  if (!user) {
    throw new Error('Not authenticated');
  }
  
  const token = await user.getIdToken();
  const res = await fetch('/api/settings', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(settings),
  });
  
  if (!res.ok) {
    const error = await res.json().catch(() => ({ error: 'Failed to save settings' }));
    throw new Error(error.error || 'Failed to save settings');
  }
}
