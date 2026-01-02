'use client';

import { ProtectedRoute } from '@/components/layout/ProtectedRoute';
import { Sidebar } from '@/components/layout/Sidebar';
import { Header } from '@/components/layout/Header';
import { useThemeSync } from '@/lib/hooks/useThemeSync';

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  useThemeSync();
  return (
    <ProtectedRoute>
      <div className="flex min-h-screen bg-background">
        <Sidebar />
        <div className="flex-1 flex flex-col">
          <Header />
          <main className="flex-1 p-6 bg-muted/50">
            {children}
          </main>
        </div>
      </div>
    </ProtectedRoute>
  );
}
