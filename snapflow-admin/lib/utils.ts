import { clsx, type ClassValue } from "clsx"
import { twMerge } from "tailwind-merge"

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs))
}

type TimestampLike =
  | { toDate: () => Date }
  | { seconds: number; nanoseconds?: number }
  | { _seconds: number; _nanoseconds?: number };

function coerceDate(input: unknown): Date | null {
  if (!input) return null;

  if (input instanceof Date) {
    return Number.isNaN(input.getTime()) ? null : input;
  }

  if (typeof input === 'string' || typeof input === 'number') {
    const d = new Date(input);
    return Number.isNaN(d.getTime()) ? null : d;
  }

  if (typeof input === 'object') {
    const maybeTimestamp = input as Partial<TimestampLike>;
    if (typeof (maybeTimestamp as any).toDate === 'function') {
      const d = (maybeTimestamp as any).toDate();
      return d instanceof Date && !Number.isNaN(d.getTime()) ? d : null;
    }

    const seconds = (maybeTimestamp as any).seconds ?? (maybeTimestamp as any)._seconds;
    const nanoseconds = (maybeTimestamp as any).nanoseconds ?? (maybeTimestamp as any)._nanoseconds ?? 0;
    if (typeof seconds === 'number') {
      const ms = seconds * 1000 + Math.floor((typeof nanoseconds === 'number' ? nanoseconds : 0) / 1e6);
      const d = new Date(ms);
      return Number.isNaN(d.getTime()) ? null : d;
    }
  }

  return null;
}

export function formatDate(dateInput: unknown, format: string): string {
  const date = coerceDate(dateInput);
  if (!date) return '';
  const pad = (n: number) => n.toString().padStart(2, '0');
  const year = date.getFullYear();
  const month = pad(date.getMonth() + 1);
  const day = pad(date.getDate());

  switch (format) {
    case 'DD/MM/YYYY':
      return `${day}/${month}/${year}`;
    case 'YYYY-MM-DD':
      return `${year}-${month}-${day}`;
    case 'MM/DD/YYYY':
    default:
      return `${month}/${day}/${year}`;
  }
}
