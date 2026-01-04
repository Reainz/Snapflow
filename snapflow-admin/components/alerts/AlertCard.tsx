import { AlertCircle, AlertTriangle, Info, CheckCircle } from 'lucide-react';
import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { Alert } from '@/lib/api/alerts';
import { formatDate } from '@/lib/utils';

interface AlertCardProps {
  alert: Alert;
  onAcknowledge: (id: string) => void;
  isAcknowledging: boolean;
  dateFormat?: string;
}

const severityConfig = {
  critical: {
    icon: AlertCircle,
    color: 'text-red-600',
    bgColor: 'bg-red-50',
    borderColor: 'border-red-200',
  },
  warning: {
    icon: AlertTriangle,
    color: 'text-orange-600',
    bgColor: 'bg-orange-50',
    borderColor: 'border-orange-200',
  },
  info: {
    icon: Info,
    color: 'text-blue-600',
    bgColor: 'bg-blue-50',
    borderColor: 'border-blue-200',
  },
};

export default function AlertCard({ alert, onAcknowledge, isAcknowledging, dateFormat = 'MM/DD/YYYY' }: AlertCardProps) {
  const config = severityConfig[alert.severity as keyof typeof severityConfig] || severityConfig.info;
  const Icon = config.icon;

  const createdValue = (alert as any).timestamp ?? (alert as any).createdAt;
  const createdLabel = createdValue ? formatDate(createdValue, dateFormat) : 'Unknown time';

  return (
    <Card
      className={`${alert.acknowledged ? 'opacity-50' : ''} ${config.borderColor} border-l-4 transition-opacity`}
    >
      <CardContent className="p-6">
        <div className="flex items-start justify-between gap-4">
          <div className="flex items-start gap-4 flex-1">
            <div className={`${config.bgColor} p-3 rounded-lg`}>
              <Icon className={`w-6 h-6 ${config.color}`} />
            </div>
            
            <div className="flex-1 space-y-3">
              <div className="flex items-center gap-2">
                <Badge variant={alert.acknowledged ? 'secondary' : 'default'} className="capitalize">
                  {alert.severity}
                </Badge>
                {alert.acknowledged && (
                  <Badge variant="outline" className="flex items-center gap-1">
                    <CheckCircle className="w-3 h-3" />
                    Acknowledged
                  </Badge>
                )}
              </div>

              <p className="text-lg font-semibold text-foreground">{alert.message}</p>

              <div className="grid grid-cols-2 gap-4 text-sm">
                <div>
                  <span className="text-muted-foreground">Type:</span>
                  <span className="ml-2 font-medium text-foreground">{alert.type}</span>
                </div>
                <div>
                  <span className="text-muted-foreground">Threshold:</span>
                  <span className="ml-2 font-medium text-foreground">{alert.threshold}%</span>
                </div>
                <div>
                  <span className="text-muted-foreground">Current Value:</span>
                  <span className="ml-2 font-medium text-foreground">{alert.currentValue}%</span>
                </div>
                <div>
                  <span className="text-muted-foreground">Created:</span>
                  <span className="ml-2 font-medium text-foreground">{createdLabel}</span>
                </div>
              </div>
            </div>
          </div>

          <Button
            onClick={() => onAcknowledge(alert.id)}
            disabled={alert.acknowledged || isAcknowledging}
            variant={alert.acknowledged ? 'outline' : 'default'}
            size="sm"
          >
            {alert.acknowledged ? 'Acknowledged' : 'Acknowledge'}
          </Button>
        </div>
      </CardContent>
    </Card>
  );
}
