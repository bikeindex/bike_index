import {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
  type ReactNode,
} from 'react';
import type { StravaAthlete, StoredAuth } from '../types/strava';
import {
  getAuth,
  clearAuth as clearAuthDb,
  clearAllData,
  saveAuth,
  getSyncState,
  type SyncState,
} from '../services/database';
import { getConfig, exchangeSessionForToken } from '../services/railsApi';
import { getAthlete } from '../services/strava';

interface AuthContextType {
  isAuthenticated: boolean;
  isLoading: boolean;
  athlete: StravaAthlete | null;
  syncState: SyncState | null;
  error: string | null;
  logout: () => Promise<void>;
  refreshSyncState: () => Promise<void>;
}

const AuthContext = createContext<AuthContextType | null>(null);

export function AuthProvider({ children }: { children: ReactNode }) {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [isLoading, setIsLoading] = useState(true);
  const [athlete, setAthlete] = useState<StravaAthlete | null>(null);
  const [syncState, setSyncState] = useState<SyncState | null>(null);
  const [error, setError] = useState<string | null>(null);

  const refreshSyncState = useCallback(async () => {
    if (athlete) {
      const state = await getSyncState(athlete.id);
      setSyncState(state || null);
    }
  }, [athlete]);

  const checkAuth = useCallback(async () => {
    try {
      let auth = await getAuth();
      const config = getConfig();
      const configAthleteId = parseInt(config.athleteId, 10);

      // Clear all data if stored athlete doesn't match the signed-in user
      if (auth && auth.athlete.id !== configAthleteId) {
        await clearAllData();
        auth = undefined;
      }

      if (auth && Date.now() < auth.expiresAt - 60000) {
        // Valid token in IndexedDB
        setAthlete(auth.athlete);
        setIsAuthenticated(true);
        const state = await getSyncState(auth.athlete.id);
        setSyncState(state || null);

        // Refresh athlete profile in the background if it's missing
        if (!auth.athlete.profile_medium) {
          getAthlete().then(async (freshAthlete) => {
            const updatedAuth = { ...auth, athlete: freshAthlete };
            await saveAuth(updatedAuth);
            setAthlete(freshAthlete);
          }).catch(() => {}); // Silently ignore
        }
        return;
      }

      // No valid token — exchange session for a new one
      const tokenResponse = await exchangeSessionForToken();

      const newAuth: StoredAuth = {
        accessToken: tokenResponse.access_token,
        refreshToken: '',
        expiresAt: (tokenResponse.created_at + tokenResponse.expires_in) * 1000,
        athlete: auth?.athlete || { id: configAthleteId, username: '', firstname: '', lastname: '', city: '', state: '', country: '', profile: '', profile_medium: '' },
      };
      await saveAuth(newAuth);
      setAthlete(newAuth.athlete);
      setIsAuthenticated(true);

      const state = await getSyncState(newAuth.athlete.id);
      setSyncState(state || null);

      // Fetch real athlete profile from Strava
      try {
        const freshAthlete = await getAthlete();
        const updatedAuth = { ...newAuth, athlete: freshAthlete };
        await saveAuth(updatedAuth);
        setAthlete(freshAthlete);
      } catch {
        // Silently ignore — will use placeholder
      }
    } catch (err) {
      console.error('Auth check failed:', err);
      setError(err instanceof Error ? err.message : 'Auth check failed');
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    checkAuth();
  }, [checkAuth]);

  const logout = useCallback(async () => {
    await clearAuthDb();
    setIsAuthenticated(false);
    setAthlete(null);
    setSyncState(null);
    setError(null);
  }, []);

  return (
    <AuthContext.Provider
      value={{
        isAuthenticated,
        isLoading,
        athlete,
        syncState,
        error,
        logout,
        refreshSyncState,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
}

// eslint-disable-next-line react-refresh/only-export-components
export function useAuth(): AuthContextType {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
}
