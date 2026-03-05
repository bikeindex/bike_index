import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, act } from '@testing-library/react';

const mockRefreshActivities = vi.fn();
const mockSyncAll = vi.fn();
const mockSyncEnriched = vi.fn();
const mockFetchFullActivityData = vi.fn();

let mockIsSyncing = false;
let mockIsFetchingFullData = false;

vi.mock('./contexts/AuthContext', () => ({
  useAuth: () => ({
    isLoading: false,
    isAuthenticated: true,
    athlete: { id: 12345 },
    syncState: { isInitialSyncComplete: true, lastSyncedAt: Date.now() },
  }),
}));

vi.mock('./contexts/PreferencesContext', () => ({
  usePreferences: () => ({ units: 'imperial', autoEnrich: false, darkMode: 'system' }),
}));

vi.mock('./hooks/useActivitySync', () => ({
  useActivitySync: () => ({
    isSyncing: mockIsSyncing,
    isFetchingFullData: mockIsFetchingFullData,
    progress: null,
    error: null,
    clearError: vi.fn(),
    syncAll: mockSyncAll,
    syncRecent: vi.fn(),
    syncEnriched: mockSyncEnriched,
    fetchFullActivityData: mockFetchFullActivityData,
  }),
}));

vi.mock('./hooks/useActivities', () => ({
  useActivities: () => ({
    activities: [],
    filteredActivities: [],
    gear: [],
    isLoading: false,
    error: null,
    clearError: vi.fn(),
    filters: { query: '', activityTypes: [], gearIds: [], noEquipment: false, dateFrom: null, dateTo: null, distanceFrom: null, distanceTo: null, elevationFrom: null, elevationTo: null, filtersExpanded: false, activityTypesExpanded: false, equipmentExpanded: false, updatePanelExpanded: false, mutedFilter: 'all', photoFilter: 'all', privateFilter: 'all', commuteFilter: 'all', trainerFilter: 'all', sufferScoreFrom: null, sufferScoreTo: null, kudosFrom: null, kudosTo: null, country: null, region: null, city: null, page: 1 },
    setFilters: vi.fn(),
    selectedIds: new Set(),
    setSelectedIds: vi.fn(),
    deselectAll: vi.fn(),
    updateSelectedActivities: vi.fn(),
    isUpdating: false,
    updateProgress: null,
    refreshActivities: mockRefreshActivities,
    activityTypes: [],
  }),
}));

vi.mock('./services/railsApi', () => ({
  getConfig: () => ({ proxyEndpoint: '', authUrl: '', hasActivityWrite: false, athleteId: '12345' }),
}));

// Stub child components to avoid their internal dependencies
vi.mock('./components/Header', () => ({ Header: () => <div data-testid="header" /> }));
vi.mock('./components/SearchFilters', () => ({ SearchFilters: () => <div /> }));
vi.mock('./components/ActivityList', () => ({ ActivityList: () => <div /> }));
vi.mock('./components/SettingsModal', () => ({ SettingsModal: () => null }));
vi.mock('./components/InitialSyncPrompt', () => ({ InitialSyncOverlay: () => null }));

import App from './App';

describe('Dashboard auto-refresh', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    vi.useFakeTimers();
    mockIsSyncing = false;
    mockIsFetchingFullData = false;
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('refreshes activities when isSyncing transitions from true to false', async () => {
    mockIsSyncing = true;

    const { rerender } = render(<App />);
    mockRefreshActivities.mockClear();

    // Sync completes
    mockIsSyncing = false;
    rerender(<App />);

    // The cleanup function should have called refreshActivities
    expect(mockRefreshActivities).toHaveBeenCalledWith(true);
  });

  it('refreshes activities when isFetchingFullData transitions from true to false', async () => {
    mockIsFetchingFullData = true;

    const { rerender } = render(<App />);
    mockRefreshActivities.mockClear();

    // Fetch completes
    mockIsFetchingFullData = false;
    rerender(<App />);

    expect(mockRefreshActivities).toHaveBeenCalledWith(true);
  });

  it('refreshes periodically during sync', async () => {
    mockIsSyncing = true;

    render(<App />);
    mockRefreshActivities.mockClear();

    // Advance 2 seconds — should trigger interval refresh
    act(() => { vi.advanceTimersByTime(2000); });
    expect(mockRefreshActivities).toHaveBeenCalledWith(true);

    mockRefreshActivities.mockClear();
    act(() => { vi.advanceTimersByTime(2000); });
    expect(mockRefreshActivities).toHaveBeenCalledWith(true);
  });
});
