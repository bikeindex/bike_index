import { describe, it, expect, vi, beforeEach } from 'vitest';
import { renderHook, act, waitFor } from '@testing-library/react';
import { useActivitySync } from './useActivitySync';

// Create stable mock objects
const mockAthlete = { id: 12345, firstname: 'Test', lastname: 'User' };

vi.mock('../contexts/AuthContext', () => ({
  useAuth: vi.fn(() => ({
    athlete: mockAthlete,
    refreshSyncState: vi.fn(),
  })),
}));

vi.mock('../services/strava', () => ({
  getAthleteGear: vi.fn(() => Promise.resolve([])),
  getAthleteStats: vi.fn(() => Promise.resolve(100)),
  getAllActivities: vi.fn(() => Promise.resolve([])),
  getActivity: vi.fn(() => Promise.resolve({ id: 1, name: 'Test', muted: false })),
  fetchEnrichedSince: vi.fn(() => Promise.resolve([])),
}));

vi.mock('../services/database', () => ({
  saveGear: vi.fn(() => Promise.resolve()),
  saveActivities: vi.fn(() => Promise.resolve()),
  updateSyncState: vi.fn(() => Promise.resolve()),
  getSyncState: vi.fn(() => Promise.resolve({ athleteId: 12345, lastSyncedAt: Date.now() })),
  getActivitiesForAthlete: vi.fn(() => Promise.resolve([])),
  getActivityById: vi.fn(() => Promise.resolve(undefined)),
}));

describe('useActivitySync', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('error handling', () => {
    it('clears error when clearError is called', async () => {
      const { getAthleteGear } = await import('../services/strava');
      vi.mocked(getAthleteGear).mockRejectedValueOnce(new Error('API Error'));

      const { result } = renderHook(() => useActivitySync());

      // Trigger sync to get an error
      await act(async () => {
        await result.current.syncRecent();
      });

      expect(result.current.error).toBe('API Error');

      // Clear the error
      act(() => {
        result.current.clearError();
      });

      expect(result.current.error).toBeNull();
    });

    it('clears previous error when starting a new sync', async () => {
      const { getAthleteGear } = await import('../services/strava');

      // First call fails
      vi.mocked(getAthleteGear).mockRejectedValueOnce(new Error('First error'));

      const { result } = renderHook(() => useActivitySync());

      // Trigger sync to get an error
      await act(async () => {
        await result.current.syncRecent();
      });

      expect(result.current.error).toBe('First error');

      // Second call succeeds
      vi.mocked(getAthleteGear).mockResolvedValueOnce([]);

      // Start another sync - error should be cleared immediately
      act(() => {
        result.current.syncRecent();
      });

      // Error should be cleared when sync starts
      await waitFor(() => {
        expect(result.current.error).toBeNull();
      });
    });
  });

  describe('syncRecent error handling', () => {
    it('sets error when syncRecent fails', async () => {
      const { getAthleteGear } = await import('../services/strava');
      vi.mocked(getAthleteGear).mockRejectedValueOnce(new Error('Network error'));

      const { result } = renderHook(() => useActivitySync());

      await act(async () => {
        await result.current.syncRecent();
      });

      expect(result.current.error).toBe('Network error');
      expect(result.current.isSyncing).toBe(false);
    });
  });

  describe('syncEnriched', () => {
    it('passes max enriched_at timestamp to fetchEnrichedSince', async () => {
      const { fetchEnrichedSince } = await import('../services/strava');
      const { getActivitiesForAthlete } = await import('../services/database');

      const enrichedAt1 = '2026-02-20T10:00:00Z';
      const enrichedAt2 = '2026-02-22T15:30:00Z';
      const enrichedAt3 = null;

      vi.mocked(getActivitiesForAthlete).mockResolvedValueOnce([
        { id: 1, enriched_at: enrichedAt1, athleteId: 12345, syncedAt: Date.now() },
        { id: 2, enriched_at: enrichedAt2, athleteId: 12345, syncedAt: Date.now() },
        { id: 3, enriched_at: enrichedAt3, athleteId: 12345, syncedAt: Date.now() },
      ] as never);

      const { result } = renderHook(() => useActivitySync());

      await act(async () => {
        await result.current.syncEnriched();
      });

      const expectedTimestamp = Math.floor(new Date(enrichedAt2).getTime() / 1000);
      expect(fetchEnrichedSince).toHaveBeenCalledWith(expectedTimestamp);
    });

    it('sets error when syncEnriched fails', async () => {
      const { getActivitiesForAthlete } = await import('../services/database');
      vi.mocked(getActivitiesForAthlete).mockRejectedValueOnce(new Error('Database error'));

      const { result } = renderHook(() => useActivitySync());

      await act(async () => {
        await result.current.syncEnriched();
      });

      expect(result.current.error).toBe('Database error');
    });

    it('passes 0 when no activities have enriched_at', async () => {
      const { fetchEnrichedSince } = await import('../services/strava');
      const { getActivitiesForAthlete } = await import('../services/database');

      vi.mocked(getActivitiesForAthlete).mockResolvedValueOnce([
        { id: 1, enriched_at: null, athleteId: 12345, syncedAt: Date.now() },
        { id: 2, enriched_at: null, athleteId: 12345, syncedAt: Date.now() },
      ] as never);

      const { result } = renderHook(() => useActivitySync());

      await act(async () => {
        await result.current.syncEnriched();
      });

      expect(fetchEnrichedSince).toHaveBeenCalledWith(0);
    });
  });

  describe('fetchFullActivityData', () => {
    it('skips activities that already have full data', async () => {
      const { getActivity } = await import('../services/strava');
      const { getActivityById, saveActivities } = await import('../services/database');

      // Activity 1 already has full data (enriched_at set)
      // Activity 2 does not have full data (enriched_at null)
      // Activity 3 does not exist in DB
      vi.mocked(getActivityById)
        .mockResolvedValueOnce({ id: 1, name: 'Enriched', enriched_at: '2026-02-01T00:00:00Z', athleteId: 12345, syncedAt: Date.now() } as never)
        .mockResolvedValueOnce({ id: 2, name: 'Not enriched', enriched_at: null, athleteId: 12345, syncedAt: Date.now() } as never)
        .mockResolvedValueOnce(undefined);

      vi.mocked(getActivity).mockResolvedValue({ id: 2, name: 'Full data' } as never);

      const { result } = renderHook(() => useActivitySync());

      await act(async () => {
        await result.current.fetchFullActivityData([1, 2, 3]);
      });

      // Should only fetch activity 2 (activity 1 already enriched, activity 3 doesn't exist)
      expect(getActivity).toHaveBeenCalledTimes(1);
      expect(getActivity).toHaveBeenCalledWith(2);
      expect(saveActivities).toHaveBeenCalledTimes(1);
    });

    it('sets error when some activity fetches fail', async () => {
      const { getActivity } = await import('../services/strava');
      const { getActivityById } = await import('../services/database');

      vi.mocked(getActivityById)
        .mockResolvedValueOnce({ id: 1, enriched_at: null, athleteId: 12345, syncedAt: Date.now() } as never)
        .mockResolvedValueOnce({ id: 2, enriched_at: null, athleteId: 12345, syncedAt: Date.now() } as never)
        .mockResolvedValueOnce({ id: 3, enriched_at: null, athleteId: 12345, syncedAt: Date.now() } as never);

      vi.mocked(getActivity)
        .mockResolvedValueOnce({ id: 1 } as never)
        .mockRejectedValueOnce(new Error('Not found'))
        .mockRejectedValueOnce(new Error('Server error'));

      const { result } = renderHook(() => useActivitySync());

      await act(async () => {
        await result.current.fetchFullActivityData([1, 2, 3]);
      });

      expect(result.current.error).toBe('Failed to fetch 2 of 3 activities');
      expect(result.current.isFetchingFullData).toBe(false);
    });

    it('does nothing when all activities already have full data', async () => {
      const { getActivity } = await import('../services/strava');
      const { getActivityById, saveActivities } = await import('../services/database');

      // All activities already have full data (enriched_at set)
      vi.mocked(getActivityById)
        .mockResolvedValueOnce({ id: 1, name: 'Enriched 1', enriched_at: '2026-02-01T00:00:00Z', athleteId: 12345, syncedAt: Date.now() } as never)
        .mockResolvedValueOnce({ id: 2, name: 'Enriched 2', enriched_at: '2026-02-01T00:00:00Z', athleteId: 12345, syncedAt: Date.now() } as never);

      const { result } = renderHook(() => useActivitySync());

      await act(async () => {
        await result.current.fetchFullActivityData([1, 2]);
      });

      // Should not fetch any activities
      expect(getActivity).not.toHaveBeenCalled();
      expect(saveActivities).not.toHaveBeenCalled();
      expect(result.current.isFetchingFullData).toBe(false);
    });
  });
});
