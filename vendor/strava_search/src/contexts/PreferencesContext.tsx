import {
  createContext,
  useContext,
  useState,
  useMemo,
  useCallback,
  useEffect,
  type ReactNode,
} from 'react';
import { useAuth } from './AuthContext';
import { getDefaultUnits, type UnitSystem } from '../utils/units';

export type { UnitSystem };
export type DarkMode = 'light' | 'dark' | 'system';

interface StoredPreferences {
  units?: UnitSystem;
  autoEnrich?: boolean;
  darkMode?: DarkMode;
}

interface PreferencesContextType {
  units: UnitSystem;
  setUnits: (units: UnitSystem) => void;
  autoEnrich: boolean;
  setAutoEnrich: (autoEnrich: boolean) => void;
  darkMode: DarkMode;
  setDarkMode: (mode: DarkMode) => void;
  isDark: boolean;
}

const STORAGE_KEY = 'strava-search-preferences';

function getStoredPreferences(): StoredPreferences {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    return stored ? JSON.parse(stored) : {};
  } catch {
    return {};
  }
}

function storePreferences(prefs: StoredPreferences) {
  const current = getStoredPreferences();
  localStorage.setItem(STORAGE_KEY, JSON.stringify({ ...current, ...prefs }));
}

const PreferencesContext = createContext<PreferencesContextType | null>(null);

export function PreferencesProvider({ children }: { children: ReactNode }) {
  const { athlete } = useAuth();

  // Track if user has explicitly set units (stored in localStorage)
  // This allows us to derive units from athlete country until user makes a choice
  const [userSetUnits, setUserSetUnits] = useState<UnitSystem | null>(() => {
    const stored = getStoredPreferences();
    return stored.units ?? null;
  });

  const [autoEnrich, setAutoEnrichState] = useState<boolean>(() => {
    const stored = getStoredPreferences();
    return stored.autoEnrich ?? true;
  });

  const [darkMode, setDarkModeState] = useState<DarkMode>(() => {
    const stored = getStoredPreferences();
    return stored.darkMode ?? 'system';
  });

  // Resolve whether dark mode is active
  const isDark = useMemo(() => {
    if (darkMode === 'dark') return true;
    if (darkMode === 'light') return false;
    return window.matchMedia('(prefers-color-scheme: dark)').matches;
  }, [darkMode]);

  // Apply dark class to document and listen for system changes
  useEffect(() => {
    const apply = () => {
      let dark: boolean;
      if (darkMode === 'dark') dark = true;
      else if (darkMode === 'light') dark = false;
      else dark = window.matchMedia('(prefers-color-scheme: dark)').matches;

      document.documentElement.classList.toggle('dark', dark);
    };

    apply();

    if (darkMode === 'system') {
      const mq = window.matchMedia('(prefers-color-scheme: dark)');
      mq.addEventListener('change', apply);
      return () => mq.removeEventListener('change', apply);
    }
  }, [darkMode]);

  // Derive units: user preference takes priority, then athlete country, then browser locale
  const units = useMemo<UnitSystem>(() => {
    if (userSetUnits) {
      return userSetUnits;
    }
    return getDefaultUnits(athlete?.measurement_preference, athlete?.country);
  }, [userSetUnits, athlete?.measurement_preference, athlete?.country]);

  const setUnits = useCallback((newUnits: UnitSystem) => {
    setUserSetUnits(newUnits);
    storePreferences({ units: newUnits });
  }, []);

  const setAutoEnrich = useCallback((value: boolean) => {
    setAutoEnrichState(value);
    storePreferences({ autoEnrich: value });
  }, []);

  const setDarkMode = useCallback((mode: DarkMode) => {
    setDarkModeState(mode);
    storePreferences({ darkMode: mode });
  }, []);

  return (
    <PreferencesContext.Provider value={{ units, setUnits, autoEnrich, setAutoEnrich, darkMode, setDarkMode, isDark }}>
      {children}
    </PreferencesContext.Provider>
  );
}

// eslint-disable-next-line react-refresh/only-export-components
export function usePreferences(): PreferencesContextType {
  const context = useContext(PreferencesContext);
  if (!context) {
    throw new Error('usePreferences must be used within a PreferencesProvider');
  }
  return context;
}
