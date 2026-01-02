'use client';

import { useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useAuth } from '@/lib/hooks/useAuth';

export function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { user, isAdmin, loading } = useAuth();
  const router = useRouter();

  useEffect(() => {
    if (!loading && (!user || !isAdmin)) {
      router.push('/login');
    }
  }, [user, isAdmin, loading, router]);

  if (loading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-gray-900"></div>
      </div>
    );
  }

  if (!user || !isAdmin) {
    return (
      <div className="min-h-screen flex items-center justify-center text-red-600">
        You do not have access to this area.
      </div>
    );
  }

  return <>{children}</>;
}
