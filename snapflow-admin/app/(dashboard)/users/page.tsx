'use client';

import { useState } from 'react';
import { useUsers } from '@/lib/hooks/useUsers';
import { UsersTable } from '@/components/tables/UsersTable';
import { UsersControls } from '@/components/tables/UsersControls';
import { Button } from '@/components/ui/button';
import { Skeleton } from '@/components/ui/skeleton';
import { toast } from 'sonner';
import { UserProfileModal } from '@/components/users/UserProfileModal';
import { useAdminSettings } from '@/lib/hooks/useAdminSettings';
import { useAuth } from '@/lib/hooks/useAuth';

export default function UsersPage() {
  const [sortField, setSortField] = useState('createdAt');
  const [sortDescending, setSortDescending] = useState(true);
  const [searchQuery, setSearchQuery] = useState('');
  const [selectedUserId, setSelectedUserId] = useState<string | null>(null);
  const { user } = useAuth();
  const { settings } = useAdminSettings(user?.uid);
  const refreshSeconds = settings?.autoRefreshInterval ?? 30;
  const dateFormat = settings?.dateFormat ?? 'MM/DD/YYYY';
  const [page, setPage] = useState(1);

  const {
    users,
    hasMore,
    isLoading,
    loadNextPage,
    resetPagination,
    banUser,
    deleteUser,
    isBanning,
    isDeleting,
  } = useUsers(sortField, sortDescending, searchQuery, refreshSeconds);

  const handleSortChange = (field: string, descending: boolean) => {
    setSortField(field);
    setSortDescending(descending);
    resetPagination();
    setPage(1);
  };

  const handleSearchChange = (query: string) => {
    setSearchQuery(query);
    resetPagination();
    setPage(1);
  };

  const handleBanUser = async (userId: string) => {
    if (!confirm('Are you sure you want to ban this user?')) return;
    
    try {
      await banUser(userId);
      toast.success('User banned successfully');
    } catch (error) {
      toast.error('Failed to ban user');
    }
  };

  const handleDeleteUser = async (userId: string) => {
    if (!confirm('Are you sure you want to delete this user? This action cannot be undone.')) return;
    
    try {
      await deleteUser(userId);
      toast.success('User deleted successfully');
    } catch (error) {
      toast.error('Failed to delete user');
    }
  };

  const handleViewUser = (userId: string) => {
    setSelectedUserId(userId);
  };

  if (isLoading && users.length === 0) {
    return (
      <div className="space-y-6">
        <h1 className="text-3xl font-bold">User Management</h1>
        <div className="space-y-4">
          {[...Array(5)].map((_, i) => (
            <Skeleton key={i} className="h-16" />
          ))}
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-foreground">User Management</h1>
        <p className="text-muted-foreground mt-1">Manage platform users and permissions</p>
        <p className="text-sm text-muted-foreground">Page {page}</p>
      </div>

      <UsersControls
        searchQuery={searchQuery}
        onSearchChange={handleSearchChange}
        sortField={sortField}
        sortDescending={sortDescending}
        onSortChange={handleSortChange}
      />

      <UsersTable
        users={users}
        onBan={handleBanUser}
        onDelete={handleDeleteUser}
        onView={handleViewUser}
        dateFormat={dateFormat}
      />

      {hasMore && (
        <div className="flex justify-center">
          <Button onClick={loadNextPage} disabled={isLoading}>
            {isLoading ? 'Loading...' : 'Load More'}
          </Button>
          {!isLoading && (
            <Button variant="outline" className="ml-2" onClick={() => setPage((p) => p + 1)}>
              Next Page
            </Button>
          )}
        </div>
      )}

      {users.length === 0 && !isLoading && (
        <div className="text-center py-12">
          <p className="text-muted-foreground">No users found</p>
        </div>
      )}

      <UserProfileModal
        userId={selectedUserId}
        open={!!selectedUserId}
        onClose={() => setSelectedUserId(null)}
        onBan={handleBanUser}
        onDelete={handleDeleteUser}
        isProcessing={isBanning || isDeleting}
      />
    </div>
  );
}
