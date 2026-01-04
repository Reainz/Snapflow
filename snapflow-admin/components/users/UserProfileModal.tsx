'use client';

import { useUserDetails } from '@/lib/hooks/useUserDetails';
import { Badge } from '@/components/ui/badge';
import { Button } from '@/components/ui/button';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogDescription } from '@/components/ui/dialog';
import { Avatar, AvatarFallback, AvatarImage } from '@/components/ui/avatar';
import { Separator } from '@/components/ui/separator';
import { Skeleton } from '@/components/ui/skeleton';
import { Calendar, Globe2, Link as LinkIcon, MapPin, ShieldCheck, UserX } from 'lucide-react';

interface UserProfileModalProps {
  userId: string | null;
  open: boolean;
  onClose: () => void;
  onBan: (userId: string) => Promise<void> | void;
  onDelete: (userId: string) => Promise<void> | void;
  isProcessing?: boolean;
}

export function UserProfileModal({
  userId,
  open,
  onClose,
  onBan,
  onDelete,
  isProcessing = false,
}: UserProfileModalProps) {
  const { data: user, isLoading, error } = useUserDetails(userId);

  const handleBan = () => {
    if (user) onBan(user.id);
  };

  const handleDelete = () => {
    if (user) onDelete(user.id);
  };

  return (
    <Dialog open={open} onOpenChange={onClose}>
      <DialogContent className="max-w-2xl">
        <DialogHeader>
          <DialogTitle>User Profile</DialogTitle>
          <DialogDescription>View account information and status</DialogDescription>
        </DialogHeader>

        {isLoading ? (
          <LoadingState />
        ) : error ? (
          <div className="text-destructive text-sm">Failed to load user details</div>
        ) : user ? (
          <div className="space-y-6">
            <div className="flex items-start gap-4">
              <Avatar className="h-16 w-16">
                <AvatarImage src={user.avatarUrl} alt={user.displayName} />
                <AvatarFallback>
                  {user.displayName?.charAt(0)?.toUpperCase() || user.username?.charAt(0)?.toUpperCase() || 'U'}
                </AvatarFallback>
              </Avatar>
              <div className="flex-1 space-y-2">
                <div className="flex items-center gap-2">
                  <h3 className="text-xl font-semibold">{user.displayName}</h3>
                  {user.isVerified && <Badge variant="outline" className="flex items-center gap-1"><ShieldCheck className="h-3 w-3" /> Verified</Badge>}
                  {user.isBanned && <Badge variant="destructive">Banned</Badge>}
                </div>
                <p className="text-sm text-muted-foreground">@{user.username}</p>
                <p className="text-sm text-muted-foreground">{user.email}</p>
                <div className="flex flex-wrap gap-2 text-xs text-muted-foreground">
                  <span className="flex items-center gap-1"><Calendar className="h-3 w-3" /> Joined {user.joinedDate.toLocaleDateString()}</span>
                  {user.lastActive && <span className="flex items-center gap-1"><Globe2 className="h-3 w-3" /> Last active {user.lastActive.toLocaleString()}</span>}
                </div>
              </div>
            </div>

            <Separator />

            <div className="grid grid-cols-2 gap-4">
              <Stat label="Followers" value={user.followersCount} />
              <Stat label="Following" value={user.followingCount} />
              <Stat label="Videos" value={user.totalVideos} />
              <Stat label="Total Likes" value={user.totalLikes} />
            </div>

            <div className="space-y-3">
              {user.bio && (
                <div>
                  <h4 className="text-sm font-semibold mb-1">Bio</h4>
                  <p className="text-sm text-muted-foreground whitespace-pre-line">{user.bio}</p>
                </div>
              )}
              <div className="flex flex-wrap gap-4 text-sm text-muted-foreground">
                {user.website && (
                  <span className="flex items-center gap-1">
                    <LinkIcon className="h-4 w-4" />
                    <a href={user.website} target="_blank" rel="noreferrer" className="text-primary hover:underline">
                      {user.website}
                    </a>
                  </span>
                )}
                {user.location && (
                  <span className="flex items-center gap-1">
                    <MapPin className="h-4 w-4" />
                    {user.location}
                  </span>
                )}
              </div>
            </div>

            <Separator />

            <div className="flex items-center justify-end gap-3">
              <Button variant="outline" onClick={onClose}>Close</Button>
              {!user.isBanned && (
                <Button
                  variant="secondary"
                  onClick={handleBan}
                  disabled={isProcessing}
                  className="gap-2"
                >
                  <UserX className="h-4 w-4" />
                  Ban User
                </Button>
              )}
              <Button
                variant="destructive"
                onClick={handleDelete}
                disabled={isProcessing}
              >
                Delete User
              </Button>
            </div>
          </div>
        ) : null}
      </DialogContent>
    </Dialog>
  );
}

function Stat({ label, value }: { label: string; value: number }) {
  return (
    <div className="p-3 rounded-md border">
      <div className="text-xs text-muted-foreground">{label}</div>
      <div className="text-lg font-semibold">{value.toLocaleString()}</div>
    </div>
  );
}

function LoadingState() {
  return (
    <div className="space-y-4">
      <div className="flex items-center gap-3">
        <Skeleton className="h-16 w-16 rounded-full" />
        <div className="space-y-2 flex-1">
          <Skeleton className="h-4 w-40" />
          <Skeleton className="h-4 w-24" />
          <Skeleton className="h-3 w-32" />
        </div>
      </div>
      <div className="grid grid-cols-2 gap-3">
        {[...Array(4)].map((_, i) => (
          <Skeleton key={i} className="h-16 w-full" />
        ))}
      </div>
      <Skeleton className="h-20 w-full" />
    </div>
  );
}
