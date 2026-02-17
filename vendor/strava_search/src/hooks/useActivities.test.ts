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
  visibilityFilter: 'all',
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
    name: 'Test Activity',
    description: '',
    distance: 10000, // 10 km in meters
    moving_time: 3600,
    elapsed_time: 3700,
    total_elevation_gain: 100,
    type: 'Ride',
    sport_type: 'Ride',
    start_date: '2024-01-15T10:00:00Z',
    start_date_local: '2024-01-15T02:00:00Z',
    timezone: '(GMT-08:00) America/Los_Angeles',
    utc_offset: -28800,
    achievement_count: 0,
    kudos_count: 0,
    comment_count: 0,
    athlete_count: 1,
    photo_count: 0,
    trainer: false,
    commute: false,
    manual: false,
    private: false,
    visibility: 'everyone',
    flagged: false,
    average_speed: 2.78,
    max_speed: 5.5,
    has_heartrate: false,
    heartrate_opt_out: false,
    display_hide_heartrate_option: false,
    pr_count: 0,
    total_photo_count: 0,
    has_kudoed: false,
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
      it('filters by activity name', async () => {
        mockActivities.push(
          createActivity({ id: 1, name: 'Morning Run' }),
          createActivity({ id: 2, name: 'Evening Ride' }),
          createActivity({ id: 3, name: 'Morning Bike Ride' })
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
          createActivity({ id: 1, name: 'Activity 1', description: 'Great workout in the park' }),
          createActivity({ id: 2, name: 'Activity 2', description: 'Short commute' })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, query: 'park' }));
        });

        expect(result.current.filteredActivities).toHaveLength(1);
        expect(result.current.filteredActivities[0].id).toBe(1);
      });

      it('filters by location_city', async () => {
        mockActivities.push(
          createActivity({ id: 1, name: 'Activity 1', location_city: 'San Francisco' }),
          createActivity({ id: 2, name: 'Activity 2', location_city: 'Los Angeles' })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, query: 'san francisco' }));
        });

        expect(result.current.filteredActivities).toHaveLength(1);
        expect(result.current.filteredActivities[0].id).toBe(1);
      });

      it('filters by location_state', async () => {
        mockActivities.push(
          createActivity({ id: 1, name: 'Activity 1', location_state: 'California' }),
          createActivity({ id: 2, name: 'Activity 2', location_state: 'Oregon' })
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
          createActivity({ id: 1, name: 'Activity 1', device_name: 'Garmin Edge 530' }),
          createActivity({ id: 2, name: 'Activity 2', device_name: 'Apple Watch' })
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
            name: 'Activity 1',
            segment_cities: ['Mill Valley', 'Sausalito'],
            segment_states: ['California'],
          }),
          createActivity({ id: 2, name: 'Activity 2' })
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
        mockActivities.push(createActivity({ id: 1, name: 'MORNING RUN' }));

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
          createActivity({ id: 1, start_date_local: '2024-01-10T10:00:00Z' }),
          createActivity({ id: 2, start_date_local: '2024-01-15T10:00:00Z' }),
          createActivity({ id: 3, start_date_local: '2024-01-20T10:00:00Z' })
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
          createActivity({ id: 1, start_date_local: '2024-01-05T12:00:00' }),
          createActivity({ id: 2, start_date_local: '2024-01-10T12:00:00' }),
          createActivity({ id: 3, start_date_local: '2024-01-20T12:00:00' })
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
          createActivity({ id: 1, start_date_local: '2024-01-10T10:00:00Z' }),
          createActivity({ id: 2, start_date_local: '2024-01-15T10:00:00Z' }),
          createActivity({ id: 3, start_date_local: '2024-01-20T10:00:00Z' }),
          createActivity({ id: 4, start_date_local: '2024-01-25T10:00:00Z' })
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
          createActivity({ id: 1, distance: 5000 }), // 5 km
          createActivity({ id: 2, distance: 10000 }), // 10 km
          createActivity({ id: 3, distance: 20000 }) // 20 km
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
          createActivity({ id: 1, distance: 5000 }),
          createActivity({ id: 2, distance: 10000 }),
          createActivity({ id: 3, distance: 20000 })
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
          createActivity({ id: 1, distance: 5000 }),
          createActivity({ id: 2, distance: 10000 }),
          createActivity({ id: 3, distance: 15000 }),
          createActivity({ id: 4, distance: 25000 })
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

    // Note: Imperial unit conversion tests are covered implicitly by the metric tests
    // since the conversion logic is the same. The usePreferences mock would need
    // dynamic mocking per test to properly test imperial, which adds complexity.
    // The key conversion logic (MILES_TO_KM, FEET_TO_METERS) should be unit tested separately.

    describe('elevation range filter', () => {
      it('filters by elevationFrom (meters)', async () => {
        mockActivities.push(
          createActivity({ id: 1, total_elevation_gain: 50 }),
          createActivity({ id: 2, total_elevation_gain: 100 }),
          createActivity({ id: 3, total_elevation_gain: 200 })
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
          createActivity({ id: 1, total_elevation_gain: 50 }),
          createActivity({ id: 2, total_elevation_gain: 100 }),
          createActivity({ id: 3, total_elevation_gain: 200 })
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
          createActivity({ id: 1, hide_from_home: true }),
          createActivity({ id: 2, hide_from_home: false }),
          createActivity({ id: 3, hide_from_home: undefined })
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
          createActivity({ id: 1, hide_from_home: true }),
          createActivity({ id: 2, hide_from_home: false }),
          createActivity({ id: 3, hide_from_home: undefined })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, mutedFilter: 'not_muted' }));
        });

        // Activities with hide_from_home false or undefined should pass
        expect(result.current.filteredActivities).toHaveLength(2);
      });

      it('shows all activities when muted filter is all', async () => {
        mockActivities.push(
          createActivity({ id: 1, hide_from_home: true }),
          createActivity({ id: 2, hide_from_home: false })
        );

        const { result } = renderHook(() => useActivities());
        await waitFor(() => expect(result.current.isLoading).toBe(false));

        act(() => {
          result.current.setFilters((prev) => ({ ...prev, mutedFilter: 'all' }));
        });

        expect(result.current.filteredActivities).toHaveLength(2);
      });
    });

    describe('combined filters', () => {
      it('applies multiple filters together', async () => {
        mockActivities.push(
          createActivity({
            id: 1,
            name: 'Morning Run',
            sport_type: 'Run',
            distance: 10000,
            start_date_local: '2024-01-15T10:00:00Z',
          }),
          createActivity({
            id: 2,
            name: 'Evening Ride',
            sport_type: 'Ride',
            distance: 20000,
            start_date_local: '2024-01-15T10:00:00Z',
          }),
          createActivity({
            id: 3,
            name: 'Morning Ride',
            sport_type: 'Ride',
            distance: 15000,
            start_date_local: '2024-01-10T10:00:00Z',
          }),
          createActivity({
            id: 4,
            name: 'Morning Ride Long',
            sport_type: 'Ride',
            distance: 25000,
            start_date_local: '2024-01-15T10:00:00Z',
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
      mockActivities.push(createActivity({ id: 1, name: 'Original' }));

      const { result } = renderHook(() => useActivities());
      await waitFor(() => expect(result.current.isLoading).toBe(false));

      expect(result.current.activities[0].name).toBe('Original');

      // Modify the mock data
      mockActivities.length = 0;
      mockActivities.push(createActivity({ id: 1, name: 'Updated' }));

      await act(async () => {
        await result.current.refreshActivities(true);
      });

      expect(result.current.activities[0].name).toBe('Updated');
    });
  });
});
