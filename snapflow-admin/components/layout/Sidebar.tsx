'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { LayoutDashboard, Users, Video, BarChart3, HardDrive, Bell, Settings } from 'lucide-react';

const menuItems = [
  { href: '/', label: 'Dashboard', icon: LayoutDashboard },
  { href: '/users', label: 'Users', icon: Users },
  { href: '/videos', label: 'Videos', icon: Video },
  { href: '/analytics', label: 'Analytics', icon: BarChart3 },
  { href: '/storage', label: 'Storage', icon: HardDrive },
  { href: '/alerts', label: 'Alerts', icon: Bell },
];

const bottomMenuItems = [
  { href: '/settings', label: 'Settings', icon: Settings },
];

export function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="w-64 bg-sidebar border-r border-sidebar-border min-h-screen flex flex-col">
      <div className="p-6">
        <h1 className="text-2xl font-bold text-sidebar-foreground">Snapflow Admin</h1>
      </div>
      <nav className="px-4 space-y-2 flex-1">
        {menuItems.map((item) => {
          const Icon = item.icon;
          const isActive = pathname === item.href;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center gap-3 px-4 py-3 rounded-lg transition-colors ${
                isActive
                  ? 'bg-sidebar-accent text-sidebar-primary'
                  : 'text-sidebar-foreground hover:bg-sidebar-accent'
              }`}
            >
              <Icon className="w-5 h-5" />
              <span className="font-medium">{item.label}</span>
            </Link>
          );
        })}
      </nav>
      <nav className="px-4 pb-4 space-y-2 border-t border-sidebar-border pt-4">
        {bottomMenuItems.map((item) => {
          const Icon = item.icon;
          const isActive = pathname === item.href;
          return (
            <Link
              key={item.href}
              href={item.href}
              className={`flex items-center gap-3 px-4 py-3 rounded-lg transition-colors ${
                isActive
                  ? 'bg-sidebar-accent text-sidebar-accent-foreground'
                  : 'text-sidebar-foreground hover:bg-sidebar-accent'
              }`}
            >
              <Icon className="w-5 h-5" />
              <span className="font-medium">{item.label}</span>
            </Link>
          );
        })}
      </nav>
    </aside>
  );
}
