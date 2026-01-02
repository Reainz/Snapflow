import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';

interface AlertsFilterProps {
  showAll: boolean;
  severity: string;
  onShowAllChange: (showAll: boolean) => void;
  onSeverityChange: (severity: string) => void;
}

export default function AlertsFilter({
  showAll,
  severity,
  onShowAllChange,
  onSeverityChange,
}: AlertsFilterProps) {
  const severityOptions = [
    { value: 'all', label: 'All' },
    { value: 'critical', label: 'Critical' },
    { value: 'warning', label: 'Warning' },
    { value: 'info', label: 'Info' },
  ];

  return (
    <div className="flex flex-col sm:flex-row items-start sm:items-center gap-4">
      {/* Active/All Toggle */}
      <div className="flex items-center gap-2">
        <span className="text-sm text-muted-foreground font-medium">Show:</span>
        <div className="flex gap-1 border rounded-lg p-1">
          <Button
            size="sm"
            variant={!showAll ? 'default' : 'ghost'}
            onClick={() => onShowAllChange(false)}
            className="h-8"
          >
            Active Only
          </Button>
          <Button
            size="sm"
            variant={showAll ? 'default' : 'ghost'}
            onClick={() => onShowAllChange(true)}
            className="h-8"
          >
            All Alerts
          </Button>
        </div>
      </div>

      {/* Severity Filter */}
      <div className="flex items-center gap-2">
        <span className="text-sm text-muted-foreground font-medium">Severity:</span>
        <div className="flex gap-2">
          {severityOptions.map((option) => (
            <Badge
              key={option.value}
              variant={severity === option.value ? 'default' : 'outline'}
              className="cursor-pointer px-3 py-1"
              onClick={() => onSeverityChange(option.value)}
            >
              {option.label}
            </Badge>
          ))}
        </div>
      </div>
    </div>
  );
}
