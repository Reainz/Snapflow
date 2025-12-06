export type NotificationType = 'like' | 'comment' | 'follow' | 'share';

export interface NotificationDocument {
  type: NotificationType;
  actorUserId: string;
  videoId?: string;
  commentId?: string;
  title?: string;
  body?: string;
  createdAt: FirebaseFirestore.Timestamp;
  read?: boolean;
  payload?: Record<string, unknown>;
}
