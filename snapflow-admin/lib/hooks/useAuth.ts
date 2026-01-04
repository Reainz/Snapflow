import { useState, useEffect } from 'react';
import { User, onAuthStateChanged, signInWithEmailAndPassword, signOut as firebaseSignOut } from 'firebase/auth';
import { auth } from '@/lib/firebase/config';
import { getIdTokenResult } from 'firebase/auth';

export function useAuth() {
  const [user, setUser] = useState<User | null>(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, async (user) => {
      setUser(user);
      
      if (user) {
        const idTokenResult = await user.getIdTokenResult(true);
        setIsAdmin(idTokenResult.claims.admin === true);
        const token = await user.getIdToken();
        await fetch('/api/auth/set-session', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ token }),
        });
      } else {
        setIsAdmin(false);
        await fetch('/api/auth/clear-session', { method: 'POST' });
      }
      
      setLoading(false);
    });

    return () => unsubscribe();
  }, []);

  const signIn = async (email: string, password: string) => {
    const result = await signInWithEmailAndPassword(auth, email, password);
    const idTokenResult = await result.user.getIdTokenResult(true);
    
    if (idTokenResult.claims.admin !== true) {
      await firebaseSignOut(auth);
      throw new Error('Access denied. Admin privileges required.');
    }
    const token = await result.user.getIdToken();
    await fetch('/api/auth/set-session', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token }),
    });
    
    return result;
  };

  const signOut = async () => {
    await fetch('/api/auth/clear-session', { method: 'POST' });
    await firebaseSignOut(auth);
  };

  return { user, isAdmin, loading, signIn, signOut };
}
