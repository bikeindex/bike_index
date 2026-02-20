import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { renderHook, act, waitFor } from '@testing-library/react';
import { useState, useCallback } from 'react';
import { useActivities } from './useActivities';
import type { StoredActivity, StoredGear } from '../services/database';
import type { SearchFilters } from '../types/strava';

// Create stable objects for mocks to avoid infinite re-render loops
const mockAthlete = { id: 12345, country: 'United States' };
const mockAuthState = {
  athlete: mockAthlete,
  isAuthenticated: true,
};
const mockPreferencesState = {
  units: 'metric' as const,
};

// Mock the hooks and services
vi.mock('../contexts/AuthContext', () => ({
  useAuth: vi.fn(() => mockAuthState),
}));

vi.mock('../contexts/PreferencesContext', () => ({
  usePreferences: vi.fn(() => mockPreferencesState),
}));

// Default filter values
const defaultFilters: SearchFilters = {
  query: '',
  activityTypes: [],
  gearIds: [],
  noEquipment: false,
  dateFrom: null,
  dateTo: null,
  distanceFrom: null,
  distanceTo: null,
  elevationFrom: null,
  elevationTo: null,
  activityTypesExpanded: true,
  equipmentExpanded: true,
  mutedFilter: 'all',
  photoFilter: 'all',
  privateFilter: 'all',
  commuteFilter: 'all',
  sufferScoreFrom: null,
  sufferScoreTo: null,
  kudosFrom: null,
  kudosTo: null,
  page: 1,
};

// Use real React state for the mock to ensure proper re-renders
vi.mock('./useUrlFilters', () => ({
  useUrlFilters: () => {
    const [filters, setFiltersState] = useState<SearchFilters>({ ...defaultFilters });
    const setFilters = useCallback((newFiltersOrFn: SearchFilters | ((prev: SearchFilters) => SearchFilters)) => {
      setFiltersState(newFiltersOrFn);
    }, []);
    return [filters, setFilters] as const;
  },
}));

// Mock database service
const mockActivities: StoredActivity[] = [];
const mockGear: StoredGear[] = [];

vi.mock('../services/database', () => ({
  getActivitiesForAthlete: vi.fn(() => Promise.resolve([...mockActivities])),
  getGearForAthlete: vi.fn(() => Promise.resolve([...mockGear])),
  updateActivityInDb: vi.fn(() => Promise.resolve()),
}));

vi.mock('../services/strava', () => ({
  updateActivity: vi.fn(() => Promise.resolve({})),
}));

// Helper to create mock activities
function createActivity(overrides: Partial<StoredActivity>): StoredActivity {
  return {
    id: Math.floor(Math.random() * 1000000),
    strava_id: '0',
    title: 'Test Activity',
    description: '',
    distance_meters: 10000, // 10 km
    moving_time_seconds: 3600,
    total_elevation_gain_meters: 100,
    activity_type: 'Ride',
    sport_type: 'Ride',
    start_date: '2024-01-15T10:00:00Z',
    start_date_in_zone: '2024-01-15T02:00:00Z',
    timezone: 'America/Los_Angeles',
    kudos_count: 0,
    commute: false,
    private: false,
    muted: false,
    enriched: true,
    average_speed: 2.78,
    pr_count: 0,
    athleteId: 12345,
    syncedAt: Date.now(),
    ...overrides,
  };
}

describe('useActivities', () => {
  beforeEach(() => {
    mockActivities.length = 0;
    mockGear.length = 0;
  });

  afterEach(() => {
    vi.clearAllMocks();
  });

  describe('filtering', () => {
    describe('text search filter', () => {
      it('filters by activity title', async () => {
        mockActivities.push(
          createActivity({ id: 1, title: 'Morning Run' }),
          createActivity({ id: 2, title: 'Evening Ride' }),
          createActivity({ id: 3, title: 'Morning Bike Ride' })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, query: 'morning' }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
        expect(result.current.filteredActivities.map((a) => a.id)).toEqual([1, 3]);
      });

      it('filters by description', async () => {
        mockActivities.push(
          createActivity({ id: 1, title: 'Activity 1', description: 'Great workout in the park' }),
          createActivity({ id: 2, title: 'Activity 2', description: 'Short commute' })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, query: 'park' }));
        });

        expect(result.current.filteredActivities).toHaveLength(1);
        expect(result.current.filteredActivities[0].id).toBe(1);
      });

      it('filters by segment_locations cities', async () => {
        mockActivities.push(
          createActivity({ id: 1, title: 'Activity 1', segment_locations: { cities: ['San Francisco'] } }),
          createActivity({ id: 2, title: 'Activity 2', segment_locations: { cities: ['Los Angeles'] } })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, query: 'san francisco' }));
        });

        expect(result.current.filteredActivities).toHaveLength(1);
        expect(result.current.filteredActivities[0].id).toBe(1);
      });

      it('filters by segment_locations states', async () => {
        mockActivities.push(
          createActivity({ id: 1, title: 'Activity 1', segment_locations: { states: ['California'] } }),
          createActivity({ id: 2, title: 'Activity 2', segment_locations: { states: ['Oregon'] } })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, query: 'california' }));
        });

        expect(result.current.filteredActivities).toHaveLength(1);
      });

      it('filters by device_name', async () => {
        mockActivities.push(
          createActivity({ id: 1, title: 'Activity 1', device_name: 'Garmin Edge 530' }),
          createActivity({ id: 2, title: 'Activity 2', device_name: 'Apple Watch' })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, query: 'garmin' }));
        });

        expect(result.current.filteredActivities).toHaveLength(1);
        expect(result.current.filteredActivities[0].id).toBe(1);
      });

      it('filters by segment locations', async () => {
        mockActivities.push(
          createActivity({
            id: 1,
            title: 'Activity 1',
            segment_locations: {
              cities: ['Mill Valley', 'Sausalito'],
              states: ['California'],
            },
          }),
          createActivity({ id: 2, title: 'Activity 2' })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, query: 'sausalito' }));
        });

        expect(result.current.filteredActivities).toHaveLength(1);
        expect(result.current.filteredActivities[0].id).toBe(1);
      });

      it('search is case insensitive', async () => {
        mockActivities.push(createActivity({ id: 1, title: 'MORNING RUN' }));

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, query: 'morning run' }));
        });

        expect(result.current.filteredActivities).toHaveLength(1);
      });
    });

    describe('activity type filter', () => {
      it('filters by single activity type', async () => {
        mockActivities.push(
          createActivity({ id: 1, sport_type: 'Ride' }),
          createActivity({ id: 2, sport_type: 'Run' }),
          createActivity({ id: 3, sport_type: 'Ride' })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, activityTypes: ['Ride'] }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
        expect(result.current.filteredActivities.every((a) => a.sport_type === 'Ride')).toBe(true);
      });

      it('filters by multiple activity types', async () => {
        mockActivities.push(
          createActivity({ id: 1, sport_type: 'Ride' }),
          createActivity({ id: 2, sport_type: 'Run' }),
          createActivity({ id: 3, sport_type: 'Swim' }),
          createActivity({ id: 4, sport_type: 'Walk' })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, activityTypes: ['Ride', 'Run'] }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
      });

      it('returns all activities when no type filter', async () => {
        mockActivities.push(
          createActivity({ id: 1, sport_type: 'Ride' }),
          createActivity({ id: 2, sport_type: 'Run' })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        expect(result.current.filteredActivities).toHaveLength(2);
      });
    });

    describe('gear filter', () => {
      it('filters by single gear', async () => {
        mockActivities.push(
          createActivity({ id: 1, gear_id: 'b123' }),
          createActivity({ id: 2, gear_id: 'b456' }),
          createActivity({ id: 3, gear_id: 'b123' })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, gearIds: ['b123'] }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
      });

      it('filters by multiple gear', async () => {
        mockActivities.push(
          createActivity({ id: 1, gear_id: 'b123' }),
          createActivity({ id: 2, gear_id: 'b456' }),
          createActivity({ id: 3, gear_id: 'b789' })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, gearIds: ['b123', 'b456'] }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
      });

      it('excludes activities without gear when gear filter is set', async () => {
        mockActivities.push(
          createActivity({ id: 1, gear_id: 'b123' }),
          createActivity({ id: 2, gear_id: undefined })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, gearIds: ['b123'] }));
        });

        expect(result.current.filteredActivities).toHaveLength(1);
      });
    });

    describe('noEquipment filter', () => {
      it('filters activities without gear', async () => {
        mockActivities.push(
          createActivity({ id: 1, gear_id: 'b123' }),
          createActivity({ id: 2, gear_id: undefined }),
          createActivity({ id: 3, gear_id: null as unknown as string | undefined })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, noEquipment: true }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
        expect(result.current.filteredActivities.every((a) => !a.gear_id)).toBe(true);
      });
    });

    describe('date range filter', () => {
      it('filters by dateFrom', async () => {
        mockActivities.push(
          createActivity({ id: 1, start_date_in_zone: '2024-01-10T10:00:00Z' }),
          createActivity({ id: 2, start_date_in_zone: '2024-01-15T10:00:00Z' }),
          createActivity({ id: 3, start_date_in_zone: '2024-01-20T10:00:00Z' })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, dateFrom: '2024-01-15' }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
        expect(result.current.filteredActivities.map((a) => a.id)).toEqual([3, 2]);
      });

      it('filters by dateTo', async () => {
        // Use dates with clear separation to avoid timezone issues
        mockActivities.push(
          createActivity({ id: 1, start_date_in_zone: '2024-01-05T12:00:00' }),
          createActivity({ id: 2, start_date_in_zone: '2024-01-10T12:00:00' }),
          createActivity({ id: 3, start_date_in_zone: '2024-01-20T12:00:00' })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        // Filter for activities on or before Jan 12
        act(() => {
          result.current.setFilters((prev) => ({ ...prev, dateTo: '2024-01-12' }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
        // Sorted by date descending
        expect(result.current.filteredActivities.map((a) => a.id)).toEqual([2, 1]);
      });

      it('filters by date range (both from and to)', async () => {
        mockActivities.push(
          createActivity({ id: 1, start_date_in_zone: '2024-01-10T10:00:00Z' }),
          createActivity({ id: 2, start_date_in_zone: '2024-01-15T10:00:00Z' }),
          createActivity({ id: 3, start_date_in_zone: '2024-01-20T10:00:00Z' }),
          createActivity({ id: 4, start_date_in_zone: '2024-01-25T10:00:00Z' })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({
            ...prev,
            dateFrom: '2024-01-14',
            dateTo: '2024-01-21',
          }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
        expect(result.current.filteredActivities.map((a) => a.id)).toEqual([3, 2]);
      });
    });

    describe('distance range filter (metric)', () => {
      it('filters by distanceFrom (km)', async () => {
        mockActivities.push(
          createActivity({ id: 1, distance_meters: 5000 }), // 5 km
          createActivity({ id: 2, distance_meters: 10000 }), // 10 km
          createActivity({ id: 3, distance_meters: 20000 }) // 20 km
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, distanceFrom: 10 }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
        // Order preserved from original array (filtered, not re-sorted)
        expect(result.current.filteredActivities.map((a) => a.id)).toEqual([2, 3]);
      });

      it('filters by distanceTo (km)', async () => {
        mockActivities.push(
          createActivity({ id: 1, distance_meters: 5000 }),
          createActivity({ id: 2, distance_meters: 10000 }),
          createActivity({ id: 3, distance_meters: 20000 })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, distanceTo: 10 }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
        expect(result.current.filteredActivities.map((a) => a.id)).toEqual([1, 2]);
      });

      it('filters by distance range', async () => {
        mockActivities.push(
          createActivity({ id: 1, distance_meters: 5000 }),
          createActivity({ id: 2, distance_meters: 10000 }),
          createActivity({ id: 3, distance_meters: 15000 }),
          createActivity({ id: 4, distance_meters: 25000 })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({
            ...prev,
            distanceFrom: 8,
            distanceTo: 20,
          }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
        expect(result.current.filteredActivities.map((a) => a.id)).toEqual([2, 3]);
      });
    });

    describe('elevation range filter', () => {
      it('filters by elevationFrom (meters)', async () => {
        mockActivities.push(
          createActivity({ id: 1, total_elevation_gain_meters: 50 }),
          createActivity({ id: 2, total_elevation_gain_meters: 100 }),
          createActivity({ id: 3, total_elevation_gain_meters: 200 })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, elevationFrom: 100 }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
        expect(result.current.filteredActivities.map((a) => a.id)).toEqual([2, 3]);
      });

      it('filters by elevationTo (meters)', async () => {
        mockActivities.push(
          createActivity({ id: 1, total_elevation_gain_meters: 50 }),
          createActivity({ id: 2, total_elevation_gain_meters: 100 }),
          createActivity({ id: 3, total_elevation_gain_meters: 200 })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, elevationTo: 100 }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
        expect(result.current.filteredActivities.map((a) => a.id)).toEqual([1, 2]);
      });
    });

    describe('muted filter', () => {
      it('filters muted activities only', async () => {
        mockActivities.push(
          createActivity({ id: 1, muted: true }),
          createActivity({ id: 2, muted: false }),
          createActivity({ id: 3, muted: false })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, mutedFilter: 'muted' }));
        });

        expect(result.current.filteredActivities).toHaveLength(1);
        expect(result.current.filteredActivities[0].id).toBe(1);
      });

      it('filters not muted activities only', async () => {
        mockActivities.push(
          createActivity({ id: 1, muted: true }),
          createActivity({ id: 2, muted: false }),
          createActivity({ id: 3, muted: false })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, mutedFilter: 'not_muted' }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
      });

      it('shows all activities when muted filter is all', async () => {
        mockActivities.push(
          createActivity({ id: 1, muted: true }),
          createActivity({ id: 2, muted: false })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, mutedFilter: 'all' }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
      });
    });

    describe('commute filter', () => {
      it('filters commute activities only', async () => {
        mockActivities.push(
          createActivity({ id: 1, commute: true }),
          createActivity({ id: 2, commute: false }),
          createActivity({ id: 3, commute: true })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, commuteFilter: 'commute' as const }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
        expect(result.current.filteredActivities.map((a) => a.id)).toEqual([1, 3]);
      });

      it('filters non-commute activities only', async () => {
        mockActivities.push(
          createActivity({ id: 1, commute: true }),
          createActivity({ id: 2, commute: false }),
          createActivity({ id: 3, commute: false })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, commuteFilter: 'not_commute' as const }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
        expect(result.current.filteredActivities.map((a) => a.id)).toEqual([2, 3]);
      });

      it('shows all activities when commute filter is all', async () => {
        mockActivities.push(
          createActivity({ id: 1, commute: true }),
          createActivity({ id: 2, commute: false })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        expect(result.current.filteredActivities).toHaveLength(2);
      });
    });

    describe('suffer score filter', () => {
      it('filters by sufferScoreFrom', async () => {
        mockActivities.push(
          createActivity({ id: 1, suffer_score: 10 }),
          createActivity({ id: 2, suffer_score: 50 }),
          createActivity({ id: 3, suffer_score: 100 })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, sufferScoreFrom: 50 }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
        expect(result.current.filteredActivities.map((a) => a.id)).toEqual([2, 3]);
      });

      it('filters by sufferScoreTo', async () => {
        mockActivities.push(
          createActivity({ id: 1, suffer_score: 10 }),
          createActivity({ id: 2, suffer_score: 50 }),
          createActivity({ id: 3, suffer_score: 100 })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, sufferScoreTo: 50 }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
        expect(result.current.filteredActivities.map((a) => a.id)).toEqual([1, 2]);
      });

      it('filters by suffer score range', async () => {
        mockActivities.push(
          createActivity({ id: 1, suffer_score: 10 }),
          createActivity({ id: 2, suffer_score: 50 }),
          createActivity({ id: 3, suffer_score: 75 }),
          createActivity({ id: 4, suffer_score: 150 })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({
            ...prev,
            sufferScoreFrom: 40,
            sufferScoreTo: 100,
          }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
        expect(result.current.filteredActivities.map((a) => a.id)).toEqual([2, 3]);
      });

      it('excludes activities without suffer_score when filter is set', async () => {
        mockActivities.push(
          createActivity({ id: 1, suffer_score: 50 }),
          createActivity({ id: 2, suffer_score: undefined }),
          createActivity({ id: 3 }) // no suffer_score field
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, sufferScoreFrom: 10 }));
        });

        expect(result.current.filteredActivities).toHaveLength(1);
        expect(result.current.filteredActivities[0].id).toBe(1);
      });
    });

    describe('kudos count filter', () => {
      it('filters by kudosFrom', async () => {
        mockActivities.push(
          createActivity({ id: 1, kudos_count: 0 }),
          createActivity({ id: 2, kudos_count: 5 }),
          createActivity({ id: 3, kudos_count: 20 })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, kudosFrom: 5 }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
        expect(result.current.filteredActivities.map((a) => a.id)).toEqual([2, 3]);
      });

      it('filters by kudosTo', async () => {
        mockActivities.push(
          createActivity({ id: 1, kudos_count: 0 }),
          createActivity({ id: 2, kudos_count: 5 }),
          createActivity({ id: 3, kudos_count: 20 })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, kudosTo: 5 }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
        expect(result.current.filteredActivities.map((a) => a.id)).toEqual([1, 2]);
      });

      it('filters by kudos range', async () => {
        mockActivities.push(
          createActivity({ id: 1, kudos_count: 0 }),
          createActivity({ id: 2, kudos_count: 5 }),
          createActivity({ id: 3, kudos_count: 10 }),
          createActivity({ id: 4, kudos_count: 25 })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({
            ...prev,
            kudosFrom: 3,
            kudosTo: 15,
          }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
        expect(result.current.filteredActivities.map((a) => a.id)).toEqual([2, 3]);
      });
    });

    describe('combined filters', () => {
      it('applies multiple filters together', async () => {
        mockActivities.push(
          createActivity({
            id: 1,
            title: 'Morning Run',
            sport_type: 'Run',
            distance_meters: 10000,
            start_date_in_zone: '2024-01-15T10:00:00Z',
          }),
          createActivity({
            id: 2,
            title: 'Evening Ride',
            sport_type: 'Ride',
            distance_meters: 20000,
            start_date_in_zone: '2024-01-15T10:00:00Z',
          }),
          createActivity({
            id: 3,
            title: 'Morning Ride',
            sport_type: 'Ride',
            distance_meters: 15000,
            start_date_in_zone: '2024-01-10T10:00:00Z',
          }),
          createActivity({
            id: 4,
            title: 'Morning Ride Long',
            sport_type: 'Ride',
            distance_meters: 25000,
            start_date_in_zone: '2024-01-15T10:00:00Z',
          })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        // Filter: Morning rides >= 15km on Jan 15
        act(() => {
          result.current.setFilters((prev) => ({
            ...prev,
            query: 'morning',
            activityTypes: ['Ride'],
            distanceFrom: 15,
            dateFrom: '2024-01-14',
          }));
        });

        expect(result.current.filteredActivities).toHaveLength(1);
        expect(result.current.filteredActivities[0].id).toBe(4);
      });
    });
  });

  describe('selection', () => {
    describe('selectAll', () => {
      it('selects all filtered activities', async () => {
        mockActivities.push(
          createActivity({ id: 1, sport_type: 'Ride' }),
          createActivity({ id: 2, sport_type: 'Run' }),
          createActivity({ id: 3, sport_type: 'Ride' })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        // Filter to only rides
        act(() => {
          result.current.setFilters((prev) => ({ ...prev, activityTypes: ['Ride'] }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);

        // Select all (should only select filtered)
        act(() => {
          result.current.selectAll();
        });

        expect(result.current.selectedIds.size).toBe(2);
        expect(result.current.selectedIds.has(1)).toBe(true);
        expect(result.current.selectedIds.has(3)).toBe(true);
        expect(result.current.selectedIds.has(2)).toBe(false);
      });
    });

    describe('deselectAll', () => {
      it('clears all selections', async () => {
        mockActivities.push(
          createActivity({ id: 1 }),
          createActivity({ id: 2 })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        // Select all
        act(() => {
          result.current.selectAll();
        });

        expect(result.current.selectedIds.size).toBe(2);

        // Deselect all
        act(() => {
          result.current.deselectAll();
        });

        expect(result.current.selectedIds.size).toBe(0);
      });
    });

    describe('deselect on filter change', () => {
      it('deselects activities that are filtered out', async () => {
        mockActivities.push(
          createActivity({ id: 1, sport_type: 'Run' }),
          createActivity({ id: 2, sport_type: 'Ride' }),
          createActivity({ id: 3, sport_type: 'Swim' })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        // Select the Run (1) and the Ride (2)
        act(() => {
          result.current.setSelectedIds(new Set([1, 2]));
        });
        expect(result.current.selectedIds).toEqual(new Set([1, 2]));

        // Filter to only Rides — Run should be deselected
        act(() => {
          result.current.setFilters((prev) => ({ ...prev, activityTypes: ['Ride'] }));
        });

        await waitFor(() => {
          expect(result.current.selectedIds).toEqual(new Set([2]));
        });
      });

      it('deselects all when no selected activities match filter', async () => {
        mockActivities.push(
          createActivity({ id: 1, sport_type: 'Run' }),
          createActivity({ id: 2, sport_type: 'Ride' }),
          createActivity({ id: 3, sport_type: 'Swim' })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setSelectedIds(new Set([1]));
        });

        // Filter to only Swims — Run should be deselected
        act(() => {
          result.current.setFilters((prev) => ({ ...prev, activityTypes: ['Swim'] }));
        });

        await waitFor(() => {
          expect(result.current.selectedIds).toEqual(new Set());
        });
      });

      it('keeps selection when filtered activities still include selected', async () => {
        mockActivities.push(
          createActivity({ id: 1, sport_type: 'Run' }),
          createActivity({ id: 2, sport_type: 'Ride' }),
          createActivity({ id: 3, sport_type: 'Swim' })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setSelectedIds(new Set([1]));
        });

        // Filter to Runs — selection should remain
        act(() => {
          result.current.setFilters((prev) => ({ ...prev, activityTypes: ['Run'] }));
        });

        await waitFor(() => {
          expect(result.current.filteredActivities.length).toBe(1);
        });
        expect(result.current.selectedIds).toEqual(new Set([1]));
      });
    });
  });

  describe('activity types extraction', () => {
    it('returns unique activity types from loaded activities', async () => {
      mockActivities.push(
        createActivity({ id: 1, sport_type: 'Ride' }),
        createActivity({ id: 2, sport_type: 'Run' }),
        createActivity({ id: 3, sport_type: 'Ride' }),
        createActivity({ id: 4, sport_type: 'Swim' })
      );

      const { result } = renderHook(() => useActivities());
      await waitFor(() => expect(result.current.isLoading).toBe(false));

      expect(result.current.activityTypes).toEqual(['Ride', 'Run', 'Swim']);
    });
  });

  describe('refreshActivities', () => {
    it('does not set isLoading during silent refresh', async () => {
      mockActivities.push(createActivity({ id: 1 }));

      const { result } = renderHook(() => useActivities());
      await waitFor(() => expect(result.current.isLoading).toBe(false));

      // Track isLoading states during silent refresh
      const loadingStates: boolean[] = [];
      const unsubscribe = setInterval(() => {
        loadingStates.push(result.current.isLoading);
      }, 1);

      await act(async () => {
        await result.current.refreshActivities(true);
      });

      clearInterval(unsubscribe);

      // Should never have been true during silent refresh
      expect(loadingStates.every(state => state === false)).toBe(true);
    });

    it('still updates activities during silent refresh', async () => {
      mockActivities.push(createActivity({ id: 1, title: 'Original' }));

      const { result } = renderHook(() => useActivities());
      await waitFor(() => expect(result.current.isLoading).toBe(false));

      expect(result.current.activities[0].title).toBe('Original');

      // Modify the mock data
      mockActivities.length = 0;
      mockActivities.push(createActivity({ id: 1, title: 'Updated' }));

      await act(async () => {
        await result.current.refreshActivities(true);
      });

      expect(result.current.activities[0].title).toBe('Updated');
    });
  });
});
