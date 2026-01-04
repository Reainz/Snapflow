import { collection, query, where, orderBy, limit, getDocs, updateDoc, doc, Timestamp, startAfter, DocumentSnapshot } from 'firebase/firestore';
import { getFunctions, httpsCallable, Functions } from 'firebase/functions';
import { app, db } from '@/lib/firebase/config';

export interface Video {
  id: string;
  title: string;
  description: string;
  ownerId: string;
  ownerUsername?: string;
  thumbnailUrl?: string;
  hlsUrl?: string;
  cloudinaryPublicId?: string;
  privacy?: string;
  status: 'processing' | 'ready' | 'flagged' | 'removed' | 'failed';
  durationSeconds: number;
  viewsCount: number;
  likesCount: number;
  commentsCount: number;
  createdAt: any;
  updatedAt: any;
}

export async function getFlaggedVideos(limitCount: number = 20): Promise<Video[]> {
  try {
    const q = query(
      collection(db, 'videos'),
      where('status', '==', 'flagged'),
      orderBy('updatedAt', 'desc'),
      limit(limitCount)
    );

    const snapshot = await getDocs(q);
    return snapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    } as Video));
  } catch (error) {
    console.error('Error fetching flagged videos:', error);
    return [];
  }
}

export async function getModerationVideos(
  limitCount: number = 20,
  statuses: Array<Video['status']> = ['flagged', 'failed', 'processing', 'ready']
): Promise<Video[]> {
  try {
    // Firestore doesn't support "in" with orderBy on different field without index; keep simple and use 'in' on status.
    const q = query(
      collection(db, 'videos'),
      where('status', 'in', statuses.slice(0, 10)),
      orderBy('updatedAt', 'desc'),
      limit(limitCount)
    );

    const snapshot = await getDocs(q);
    return snapshot.docs.map((doc) => ({
      id: doc.id,
      ...doc.data(),
    } as Video));
  } catch (error) {
    console.error('Error fetching moderation videos:', error);
    return [];
  }
}

export async function searchVideosByTitleOrOwner(
  search: string,
  limitCount: number = 30,
  statuses: Array<Video['status']> = ['flagged', 'failed', 'processing', 'ready']
): Promise<Video[]> {
  // Lightweight client-side filter after pulling a small window of recent items.
  const base = await getModerationVideos(limitCount, statuses);
  const term = search.trim().toLowerCase();
  if (!term) return base;
  return base.filter((v) => {
    const title = (v.title || '').toLowerCase();
    const owner = (v.ownerUsername || '').toLowerCase();
    return title.includes(term) || owner.includes(term);
  });
}

export async function paginateModerationVideos(
  pageSize: number,
  page: number = 1,
  statuses: Array<Video['status']> = ['flagged', 'failed', 'processing', 'ready']
): Promise<Video[]> {
  // Simple slide-window pagination: fetch a larger slice and slice client-side (sufficient for thesis/demo).
  const slice = await getModerationVideos(pageSize * page, statuses);
  const start = (page - 1) * pageSize;
  return slice.slice(start, start + pageSize);
}

export interface ModerationPage {
  videos: Video[];
  lastDoc: DocumentSnapshot | null;
  hasMore: boolean;
}

export async function getModerationVideosPage(
  pageSize: number = 20,
  statuses: Array<Video['status']> = ['flagged', 'failed', 'processing', 'ready'],
  lastDoc: DocumentSnapshot | null = null
): Promise<ModerationPage> {
  try {
    let q = query(
      collection(db, 'videos'),
      where('status', 'in', statuses.slice(0, 10)),
      orderBy('updatedAt', 'desc'),
      limit(pageSize)
    );
    if (lastDoc) {
      q = query(q, startAfter(lastDoc));
    }

    const snapshot = await getDocs(q);
    const videos = snapshot.docs.map((d) => ({ id: d.id, ...d.data() } as Video));
    return {
      videos,
      lastDoc: snapshot.docs[snapshot.docs.length - 1] || null,
      hasMore: snapshot.docs.length === pageSize,
    };
  } catch (error) {
    console.error('Error fetching moderation videos page:', error);
    return { videos: [], lastDoc: null, hasMore: false };
  }
}

export async function approveVideo(videoId: string): Promise<void> {
  await updateDoc(doc(db, 'videos', videoId), {
    status: 'ready',
    updatedAt: Timestamp.now(),
  });
}

export async function removeVideo(videoId: string): Promise<void> {
  await updateDoc(doc(db, 'videos', videoId), {
    status: 'removed',
    updatedAt: Timestamp.now(),
  });
}

// Fetches a signed HLS URL for private/followers-only videos using the callable function.
// Requires the caller to be authenticated (admin claim bypasses owner/follower checks).
let functionsInstance: Functions | null = null;
function getFunctionsClient(): Functions {
  if (!functionsInstance) {
    functionsInstance = getFunctions(app, 'us-central1');
  }
  return functionsInstance;
}

export async function getSignedVideoUrl(videoId: string): Promise<string> {
  try {
    const callable = httpsCallable(getFunctionsClient(), 'generateSignedUrl');
    const result = await callable({ videoId });
    const data = result.data as any;
    return (data?.signedUrl || data?.signed_url || '') as string;
  } catch (error) {
    console.error('Failed to get signed video URL:', error);
    return '';
  }
}
