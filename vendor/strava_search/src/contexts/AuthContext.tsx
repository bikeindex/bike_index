import {
  createContext,
  useContext,
  useState,
  useEffect,
  useCallback,
  type ReactNode,
} from 'react';
import type { StravaAthlete } from '../types/strava';
import {
  getAuth,
  clearAuth as clearAuthDb,
  getSyncState,
  type SyncState,
} from '../services/database';
import {
  exchangeCodeForToken,
  hasStravaCredentials,
  refreshAccessToken,
} from '../services/strava';

interface AuthContextType {
  isAuthenticated: boolean;
  isLoading: boolean;
  athlete: StravaAthlete | null;
  syncState: SyncState | null;
  error: string | null;
  login: () => void;
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
      const auth = await getAuth();

      if (auth) {
        // Check if token needs refresh
        if (Date.now() >= auth.expiresAt - 60000) {
          try {
            const newAuth = await refreshAccessToken(auth.refreshToken);
            setAthlete(newAuth.athlete);
            setIsAuthenticated(true);

            const state = await getSyncState(newAuth.athlete.id);
            setSyncState(state || null);
          } catch {
            // Refresh failed, clear auth
            await clearAuthDb();
            setIsAuthenticated(false);
            setAthlete(null);
            setSyncState(null);
          }
        } else {
          setAthlete(auth.athlete);
          setIsAuthenticated(true);

          const state = await getSyncState(auth.athlete.id);
          setSyncState(state || null);
        }
      }
    } catch (err) {
      console.error('Auth check failed:', err);
      setError(err instanceof Error ? err.message : 'Auth check failed');
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Handle OAuth callback
  useEffect(() => {
    const handleCallback = async () => {
      const urlParams = new URLSearchParams(window.location.search);
      const code = urlParams.get('code');
      const errorParam = urlParams.get('error');

      if (errorParam) {
        setError(`OAuth error: ${errorParam}`);
        // Clean up URL
        window.history.replaceState({}, '', window.location.pathname);
        setIsLoading(false);
        return;
      }

      if (code) {
        try {
          const auth = await exchangeCodeForToken(code);
          setAthlete(auth.athlete);
          setIsAuthenticated(true);
          setError(null);

          const state = await getSyncState(auth.athlete.id);
          setSyncState(state || null);
        } catch (err) {
          setError(err instanceof Error ? err.message : 'Failed to authenticate');
        } finally {
          // Clean up URL
          window.history.replaceState({}, '', window.location.pathname);
          setIsLoading(false);
        }
        return;
      }

      // No OAuth callback, check existing auth
      await checkAuth();
    };

    handleCallback();
  }, [checkAuth]);

  const login = useCallback(() => {
    if (!hasStravaCredentials()) {
      setError('Please configure your Strava API credentials first');
      return;
    }

    // Import dynamically to avoid circular dependency
    import('../services/strava').then(({ generateAuthUrl }) => {
      window.location.href = generateAuthUrl();
    });
  }, []);

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
        login,
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
