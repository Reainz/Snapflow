'use client';

import { Card, CardContent } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Calendar } from 'lucide-react';

interface DateRangeSelectorProps {
  startDate: Date;
  endDate: Date;
  onRangeChange: (start: Date, end: Date) => void;
}

export default function DateRangeSelector({ startDate, endDate, onRangeChange }: DateRangeSelectorProps) {
  const formatDateForInput = (date: Date): string => {
    return date.toISOString().split('T')[0];
  };

  const handleStartDateChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const newStart = new Date(e.target.value);
    if (newStart < endDate) {
      onRangeChange(newStart, endDate);
    }
  };

  const handleEndDateChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const newEnd = new Date(e.target.value);
    if (newEnd > startDate) {
      onRangeChange(startDate, newEnd);
    }
  };

  const setQuickRange = (days: number) => {
    const end = new Date();
    const start = new Date();
    start.setDate(start.getDate() - days);
    onRangeChange(start, end);
  };

  return (
    <Card>
      <CardContent className="pt-6">
        <div className="flex flex-col lg:flex-row gap-4 items-end">
          {/* Date Inputs */}
          <div className="flex gap-4 flex-1">
            <div className="flex-1">
              <Label htmlFor="start-date" className="text-sm font-medium">
                Start Date
              </Label>
              <div className="relative mt-1">
                <Input
                  id="start-date"
                  type="date"
                  value={formatDateForInput(startDate)}
                  onChange={handleStartDateChange}
                  max={formatDateForInput(endDate)}
                  className="pl-10"
                />
                <Calendar className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              </div>
            </div>

            <div className="flex-1">
              <Label htmlFor="end-date" className="text-sm font-medium">
                End Date
              </Label>
              <div className="relative mt-1">
                <Input
                  id="end-date"
                  type="date"
                  value={formatDateForInput(endDate)}
                  onChange={handleEndDateChange}
                  min={formatDateForInput(startDate)}
                  max={formatDateForInput(new Date())}
                  className="pl-10"
                />
                <Calendar className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-muted-foreground" />
              </div>
            </div>
          </div>

          {/* Quick Select Buttons */}
          <div className="flex gap-2">
            <Button
              variant="outline"
              size="sm"
              onClick={() => setQuickRange(7)}
            >
              Last 7 Days
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setQuickRange(30)}
            >
              Last 30 Days
            </Button>
            <Button
              variant="outline"
              size="sm"
              onClick={() => setQuickRange(90)}
            >
              Last 90 Days
            </Button>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
