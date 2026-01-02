export interface DashboardStats {
  totalUsers: number;
  totalVideos: number;
  dailyActiveUsers: number;
  weeklyActiveUsers: number;
  monthlyActiveUsers: number;
  dauTrend: number;
  wauTrend: number;
  mauTrend: number;
}

export interface User {
  id: string;
  email: string;
  displayName: string;
  avatarUrl?: string;
  followersCount: number;
  followingCount: number;
  videosCount: number;
  createdAt: any;
}

export interface AdminSettings {
  autoRefreshInterval: number; // seconds
  dateFormat: string;
  theme: 'light' | 'dark' | 'system';
}

// Export Video from videos API
export type { Video } from '@/lib/api/videos';

// Export Analytics types from analytics API
export type {
  UserGrowthData,
  VideoUploadData,
  RetentionMetrics,
  SystemHealthMetrics,
} from '@/lib/api/analytics';

// Export Alert from alerts API
export type { Alert } from '@/lib/api/alerts';
