import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { getAthleteStats, updateActivity, getAllActivities } from './strava';
import * as database from './database';
import babyHawkCassette from '../testing/cassettes/baby_hawk.json';

// Mock the database module
vi.mock('./database', () => ({
  getAuth: vi.fn(),
  saveAuth: vi.fn(),
  clearAuth: vi.fn(),
}));

describe('strava service', () => {
  const originalFetch = global.fetch;

  beforeEach(() => {
    global.fetch = vi.fn();
    // Mock authenticated state
    vi.mocked(database.getAuth).mockResolvedValue({
      accessToken: 'test_token',
      refreshToken: 'test_refresh',
      expiresAt: Date.now() + 3600000, // 1 hour from now
      athlete: { id: 12345, firstname: 'Test', lastname: 'User' },
    });
  });

  afterEach(() => {
    global.fetch = originalFetch;
    vi.resetAllMocks();
  });

  describe('getAthleteStats', () => {
    it('returns total count of activities from athlete stats', async () => {
      const mockStats = {
        all_ride_totals: { count: 150, distance: 5000, moving_time: 1000, elapsed_time: 1100, elevation_gain: 500 },
        all_run_totals: { count: 75, distance: 300, moving_time: 500, elapsed_time: 550, elevation_gain: 100 },
        all_swim_totals: { count: 25, distance: 50, moving_time: 200, elapsed_time: 220, elevation_gain: 0 },
      };

      (global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockStats),
      });

      const total = await getAthleteStats(12345);

      expect(total).toBe(250); // 150 + 75 + 25
      expect(global.fetch).toHaveBeenCalledWith(
        'https://www.strava.com/api/v3/athletes/12345/stats',
        expect.objectContaining({
          headers: expect.objectContaining({
            Authorization: 'Bearer test_token',
          }),
        })
      );
    });

    it('handles missing activity totals gracefully', async () => {
      const mockStats = {
        all_ride_totals: { count: 100, distance: 5000, moving_time: 1000, elapsed_time: 1100, elevation_gain: 500 },
        all_run_totals: null,
        all_swim_totals: undefined,
      };

      (global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockStats),
      });

      const total = await getAthleteStats(12345);

      expect(total).toBe(100); // Only ride totals available
    });

    it('returns 0 when all totals are missing', async () => {
      const mockStats = {};

      (global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockStats),
      });

      const total = await getAthleteStats(12345);

      expect(total).toBe(0);
    });
  });

  describe('updateActivity', () => {
    const babyHawkResponse = babyHawkCassette.interactions[0].response.body;

    // Mock both PUT (update) and GET (fetch full details) calls
    const mockPutThenGet = () => {
      (global.fetch as ReturnType<typeof vi.fn>)
        .mockResolvedValueOnce({
          ok: true,
          json: () => Promise.resolve({ id: 17145907973 }), // PUT returns minimal data
        })
        .mockResolvedValueOnce({
          ok: true,
          json: () => Promise.resolve(babyHawkResponse), // GET returns full data
        });
    };

    it('fetches full activity after update to get enriched data', async () => {
      mockPutThenGet();

      const result = await updateActivity(17145907973, { name: 'Updated Name' });

      // Verify both PUT and GET were called
      expect(global.fetch).toHaveBeenCalledTimes(2);

      // Verify enriched fields are present from GET response
      expect(result.device_name).toBe('Strava App');
      expect(result.hide_from_home).toBe(false);
      expect(result.photos).toBeDefined();
      expect(result.photos?.count).toBe(4);
      expect(result.photos?.primary?.urls['600']).toContain('cloudfront.net');
    });

    it('includes segment efforts for location derivation', async () => {
      mockPutThenGet();

      const result = await updateActivity(17145907973, { commute: true });

      // Verify segment efforts are present for location derivation
      expect(result.segment_efforts).toBeDefined();
      expect(result.segment_efforts?.length).toBeGreaterThan(0);

      // Check that segment locations are derived
      expect(result.segment_cities).toBeDefined();
      expect(result.segment_states).toBeDefined();
      expect(result.segment_countries).toBeDefined();

      // Verify specific locations from baby_hawk cassette
      expect(result.segment_cities).toContain('Mill Valley');
      expect(result.segment_cities).toContain('San Francisco');
      expect(result.segment_cities).toContain('Sausalito');
      expect(result.segment_states).toContain('California');
    });

    it('derives primary location from segments when activity location is null', async () => {
      mockPutThenGet();

      const result = await updateActivity(17145907973, { trainer: false });

      // baby_hawk has null location_city/state/country at activity level
      // but should derive from segment efforts
      expect(result.location_city).toBeDefined();
      expect(result.location_state).toBe('California');
    });

    it('preserves all activity fields in response', async () => {
      mockPutThenGet();

      const result = await updateActivity(17145907973, { gear_id: 'b12345' });

      // Verify core activity fields are preserved
      expect(result.id).toBe(17145907973);
      expect(result.name).toBe('Baby hawk');
      expect(result.distance).toBe(50274.8);
      expect(result.moving_time).toBe(9219);
      expect(result.sport_type).toBe('EBikeRide');
      expect(result.average_heartrate).toBe(127.5);
      expect(result.total_photo_count).toBe(4);
      expect(result.calories).toBe(1462);
    });
  });

  describe('getAllActivities', () => {
    const createMockActivity = (id: number) => ({
      id,
      name: `Activity ${id}`,
      distance: 10000,
      moving_time: 3600,
      elapsed_time: 3700,
      total_elevation_gain: 100,
      type: 'Ride',
      sport_type: 'Ride',
      start_date: '2024-01-15T10:00:00Z',
      start_date_local: '2024-01-15T02:00:00Z',
    });

    it('calls onBatch callback for each page of activities', async () => {
      const page1 = Array.from({ length: 100 }, (_, i) => createMockActivity(i + 1));
      const page2 = Array.from({ length: 50 }, (_, i) => createMockActivity(i + 101));

      (global.fetch as ReturnType<typeof vi.fn>)
        .mockResolvedValueOnce({
          ok: true,
          json: () => Promise.resolve(page1),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: () => Promise.resolve(page2),
        });

      const onBatch = vi.fn();
      const onProgress = vi.fn();

      const result = await getAllActivities({
        onBatch,
        onProgress,
      });

      // Should have fetched 2 pages
      expect(global.fetch).toHaveBeenCalledTimes(2);

      // onBatch should be called twice with each batch
      expect(onBatch).toHaveBeenCalledTimes(2);
      expect(onBatch).toHaveBeenNthCalledWith(1, page1, 100);
      expect(onBatch).toHaveBeenNthCalledWith(2, page2, 150);

      // onProgress should be called twice
      expect(onProgress).toHaveBeenCalledTimes(2);
      expect(onProgress).toHaveBeenNthCalledWith(1, 100, null);
      expect(onProgress).toHaveBeenNthCalledWith(2, 150, null);

      // Should return all activities
      expect(result).toHaveLength(150);
    });

    it('supports legacy function signature (onProgress, after)', async () => {
      const activities = [createMockActivity(1), createMockActivity(2)];

      (global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(activities),
      });

      const onProgress = vi.fn();
      const result = await getAllActivities(onProgress);

      expect(onProgress).toHaveBeenCalledWith(2, null);
      expect(result).toHaveLength(2);
    });

    it('does not call onBatch for empty pages', async () => {
      (global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve([]),
      });

      const onBatch = vi.fn();
      const result = await getAllActivities({ onBatch });

      expect(onBatch).not.toHaveBeenCalled();
      expect(result).toHaveLength(0);
    });

    it('passes after parameter to filter activities', async () => {
      const activities = [createMockActivity(1)];

      (global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(activities),
      });

      const afterTimestamp = Date.now() - 86400000; // 1 day ago
      await getAllActivities({ after: afterTimestamp });

      expect(global.fetch).toHaveBeenCalledWith(
        expect.stringContaining(`after=${Math.floor(afterTimestamp / 1000)}`),
        expect.anything()
      );
    });
  });

  describe('rate limiting', () => {
    beforeEach(() => {
      vi.useFakeTimers();
    });

    afterEach(() => {
      vi.useRealTimers();
    });

    it('retries on 429 with exponential backoff', async () => {
      // First call returns 429, second call succeeds
      (global.fetch as ReturnType<typeof vi.fn>)
        .mockResolvedValueOnce({
          ok: false,
          status: 429,
          headers: new Headers(),
        })
        .mockResolvedValueOnce({
          ok: true,
          json: () => Promise.resolve({ all_ride_totals: { count: 10 } }),
        });

      const resultPromise = getAthleteStats(12345);

      // Advance past the 1s delay for first retry
      await vi.advanceTimersByTimeAsync(1000);

      const result = await resultPromise;

      expect(global.fetch).toHaveBeenCalledTimes(2);
      expect(result).toBe(10);
    });

    it('respects Retry-After header', async () => {
      const headers = new Headers();
      headers.set('Retry-After', '1'); // 1 second

      (global.fetch as ReturnType<typeof vi.fn>)
        .mockResolvedValueOnce({
          ok: false,
          status: 429,
          headers,
        })
        .mockResolvedValueOnce({
          ok: true,
          json: () => Promise.resolve({ all_ride_totals: { count: 5 } }),
        });

      const resultPromise = getAthleteStats(12345);

      // Advance past the 1s Retry-After delay
      await vi.advanceTimersByTimeAsync(1000);

      const result = await resultPromise;

      expect(result).toBe(5);
    });

    it('throws after max retries exceeded', async () => {
      // Return 429 for all attempts
      (global.fetch as ReturnType<typeof vi.fn>).mockResolvedValue({
        ok: false,
        status: 429,
        headers: new Headers(),
      });

      let error: Error | null = null;
      const resultPromise = getAthleteStats(12345).catch((e) => {
        error = e;
      });

      // Advance through all retry delays: 1s + 2s + 4s = 7s
      await vi.advanceTimersByTimeAsync(7000);

      await resultPromise;

      expect(error).not.toBeNull();
      expect(error!.message).toContain('Rate limit exceeded');

      // Should have tried 4 times (1 initial + 3 retries)
      expect(global.fetch).toHaveBeenCalledTimes(4);
    });
  });
});
