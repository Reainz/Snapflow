import { collection, query, where, orderBy, limit, startAfter, getDocs, getDoc, doc, deleteDoc, updateDoc, DocumentSnapshot } from 'firebase/firestore';
import { db } from '@/lib/firebase/config';

export interface User {
  id: string;
  email: string;
  username: string;
  displayName: string;
  avatarUrl?: string;
  followersCount: number;
  followingCount: number;
  videosCount: number;
  isBanned?: boolean;
  createdAt: any;
}

export interface UserDetails extends User {
  bio?: string;
  website?: string;
  location?: string;
  joinedDate: Date;
  lastActive?: Date;
  totalVideos: number;
  totalLikes: number;
  isVerified?: boolean;
}

export interface UsersPage {
  users: User[];
  lastDoc: DocumentSnapshot | null;
  hasMore: boolean;
}

export async function getUsersPage(
  pageSize: number = 20,
  orderField: string = 'createdAt',
  descending: boolean = true,
  lastDoc: DocumentSnapshot | null = null
): Promise<UsersPage> {
  let q = query(
    collection(db, 'users'),
    orderBy(orderField, descending ? 'desc' : 'asc'),
    limit(pageSize)
  );

  if (lastDoc) {
    q = query(q, startAfter(lastDoc));
  }

  const snapshot = await getDocs(q);
  const users = snapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data()
  } as User));

  return {
    users,
    lastDoc: snapshot.docs[snapshot.docs.length - 1] || null,
    hasMore: snapshot.docs.length === pageSize,
  };
}

export async function searchUsers(searchQuery: string, limitCount: number = 20): Promise<User[]> {
  const searchLower = searchQuery.toLowerCase();

  const queries = [
    query(
      collection(db, 'users'),
      where('displayNameLower', '>=', searchLower),
      where('displayNameLower', '<=', searchLower + '\uf8ff'),
      limit(limitCount)
    ),
    query(
      collection(db, 'users'),
      where('email', '>=', searchQuery),
      where('email', '<=', searchQuery + '\uf8ff'),
      limit(limitCount)
    ),
    query(
      collection(db, 'users'),
      where('username', '>=', searchLower),
      where('username', '<=', searchLower + '\uf8ff'),
      limit(limitCount)
    ),
  ];

  const snapshots = await Promise.all(queries.map((q) => getDocs(q)));
  const seen = new Set<string>();
  const results: User[] = [];

  snapshots.forEach((snap) => {
    snap.docs.forEach((doc) => {
      if (!seen.has(doc.id)) {
        seen.add(doc.id);
        results.push({ id: doc.id, ...doc.data() } as User);
      }
    });
  });

  return results.slice(0, limitCount);
}

export async function banUser(userId: string): Promise<void> {
  await updateDoc(doc(db, 'users', userId), {
    isBanned: true,
    bannedAt: new Date(),
  });
}

export async function deleteUser(userId: string): Promise<void> {
  await deleteDoc(doc(db, 'users', userId));
  // Note: In production, you'd also need to delete user's videos, comments, etc.
  // This should be done via Cloud Function for atomicity
}

export async function getUserDetails(userId: string): Promise<UserDetails> {
  const snap = await getDoc(doc(db, 'users', userId));

  if (!snap.exists()) {
    throw new Error('User not found');
  }

  const data = snap.data();
  const createdAtTs = data.createdAt;
  const updatedAtTs = data.updatedAt;

  const joinedDate =
    typeof createdAtTs?.toDate === 'function' ? createdAtTs.toDate() : new Date();
  const lastActive =
    typeof updatedAtTs?.toDate === 'function' ? updatedAtTs.toDate() : undefined;

  return {
    id: snap.id,
    email: data.email,
    username: data.username,
    displayName: data.displayName,
    avatarUrl: data.avatarUrl,
    followersCount: data.followersCount || 0,
    followingCount: data.followingCount || 0,
    videosCount: data.videosCount || 0,
    isBanned: data.isBanned,
    createdAt: data.createdAt,
    bio: data.bio,
    website: data.website,
    location: data.location,
    joinedDate,
    lastActive,
    totalVideos: data.videosCount || 0,
    totalLikes: data.totalLikes || 0,
    isVerified: data.isVerified,
  };
}
