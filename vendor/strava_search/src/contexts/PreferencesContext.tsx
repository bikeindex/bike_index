import {
  createContext,
  useContext,
  useState,
  useMemo,
  useCallback,
  type ReactNode,
} from 'react';
import { useAuth } from './AuthContext';
import { getDefaultUnits, type UnitSystem } from '../utils/units';

export type { UnitSystem };

interface StoredPreferences {
  units?: UnitSystem;
  autoEnrich?: boolean;
}

interface PreferencesContextType {
  units: UnitSystem;
  setUnits: (units: UnitSystem) => void;
  autoEnrich: boolean;
  setAutoEnrich: (autoEnrich: boolean) => void;
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

  return (
    <PreferencesContext.Provider value={{ units, setUnits, autoEnrich, setAutoEnrich }}>
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
