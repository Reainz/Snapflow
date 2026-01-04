import { auth } from '@/lib/firebase/config';
import { DashboardStats } from '@/types/admin';

export async function getDashboardStats(): Promise<DashboardStats> {
  // Get the current user's token for authentication
  const user = auth.currentUser;
  if (!user) {
    throw new Error('Not authenticated');
  }
  
  const token = await user.getIdToken();
  
  // Call server-side API that uses Firebase Admin SDK
  const response = await fetch('/api/stats', {
    method: 'GET',
    headers: {
      'Authorization': `Bearer ${token}`,
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    const error = await response.json().catch(() => ({ error: 'Unknown error' }));
    throw new Error(error.error || 'Failed to load dashboard stats');
  }

  return response.json();
}

