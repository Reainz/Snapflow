import { db } from '@/lib/firebase/config';
import {
  collection,
  query,
  where,
  orderBy,
  limit,
  getDocs,
  doc,
  updateDoc,
} from 'firebase/firestore';

export interface Alert {
  id: string;
  type: 'processing_failure' | 'storage_warning' | string;
  severity: 'critical' | 'warning' | 'info';
  message: string;
  threshold: number;
  currentValue: number;
  acknowledged: boolean;
  createdAt?: any; // Firestore Timestamp or ISO string
  timestamp?: any; // Firestore Timestamp (preferred ordering field)
}

/**
 * Get active (unacknowledged) alerts
 */
export async function getActiveAlerts(limitCount: number = 50): Promise<Alert[]> {
  const alertsRef = collection(db, 'admin_alerts');
  const q = query(
    alertsRef,
    where('acknowledged', '==', false),
    orderBy('timestamp', 'desc'),
    limit(limitCount)
  );

  const snapshot = await getDocs(q);
  return snapshot.docs.map((snap) => {
    const data = snap.data() as any;
    return {
      id: snap.id,
      ...data,
      timestamp: data.timestamp ?? data.createdAt ?? null,
      createdAt: data.createdAt ?? data.timestamp ?? null,
    } as Alert;
  });
}

/**
 * Get all alerts (acknowledged and unacknowledged)
 */
export async function getAllAlerts(limitCount: number = 100): Promise<Alert[]> {
  const alertsRef = collection(db, 'admin_alerts');
  const q = query(
    alertsRef,
    orderBy('timestamp', 'desc'),
    limit(limitCount)
  );

  const snapshot = await getDocs(q);
  return snapshot.docs.map((snap) => {
    const data = snap.data() as any;
    return {
      id: snap.id,
      ...data,
      timestamp: data.timestamp ?? data.createdAt ?? null,
      createdAt: data.createdAt ?? data.timestamp ?? null,
    } as Alert;
  });
}

/**
 * Acknowledge an alert (set acknowledged to true)
 */
export async function acknowledgeAlert(alertId: string): Promise<void> {
  const alertRef = doc(db, 'admin_alerts', alertId);
  await updateDoc(alertRef, {
    acknowledged: true,
    acknowledgedAt: new Date(),
  });
}
