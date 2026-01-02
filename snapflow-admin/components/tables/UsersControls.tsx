'use client';

import { Input } from '@/components/ui/input';
import { Button } from '@/components/ui/button';
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu';
import { Search, SortAsc } from 'lucide-react';

interface UsersControlsProps {
  searchQuery: string;
  onSearchChange: (query: string) => void;
  sortField: string;
  sortDescending: boolean;
  onSortChange: (field: string, descending: boolean) => void;
}

export function UsersControls({
  searchQuery,
  onSearchChange,
  sortField,
  sortDescending,
  onSortChange,
}: UsersControlsProps) {
  return (
    <div className="flex items-center gap-4">
      <div className="flex-1 relative">
        <Search className="absolute left-3 top-1/2 transform -translate-y-1/2 w-4 h-4 text-muted-foreground" />
        <Input
          placeholder="Search by username or email..."
          value={searchQuery}
          onChange={(e) => onSearchChange(e.target.value)}
          className="pl-10"
        />
      </div>
      <DropdownMenu>
        <DropdownMenuTrigger asChild>
          <Button variant="outline">
            <SortAsc className="w-4 h-4 mr-2" />
            Sort
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          <DropdownMenuItem onClick={() => onSortChange('createdAt', true)}>
            Newest First
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => onSortChange('createdAt', false)}>
            Oldest First
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => onSortChange('followersCount', true)}>
            Most Followers
          </DropdownMenuItem>
          <DropdownMenuItem onClick={() => onSortChange('videosCount', true)}>
            Most Videos
          </DropdownMenuItem>
        </DropdownMenuContent>
      </DropdownMenu>
    </div>
  );
}
