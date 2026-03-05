import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { getAthlete, getActivities, updateActivity, getAllActivities } from './strava';
import * as database from './database';
import * as railsApi from './railsApi';

// Mock the database module
vi.mock('./database', () => ({
  getAuth: vi.fn(),
  saveAuth: vi.fn(),
  clearAuth: vi.fn(),
}));

// Mock the railsApi module
vi.mock('./railsApi', () => ({
  getConfig: vi.fn(),
  exchangeSessionForToken: vi.fn(),
}));

const PROXY_ENDPOINT = '/api/strava_proxy';

describe('strava service', () => {
  const originalFetch = global.fetch;

  beforeEach(() => {
    global.fetch = vi.fn();
    // Set up config via mocked getConfig
    vi.mocked(railsApi.getConfig).mockReturnValue({
      tokenEndpoint: '/strava_search/token',
      proxyEndpoint: PROXY_ENDPOINT,
      athleteId: '12345',
    });
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

  describe('getAthlete', () => {
    it('returns athlete profile with gear', async () => {
      const mockAthlete = {
        id: 12345,
        username: 'testuser',
        firstname: 'Test',
        lastname: 'User',
        city: 'San Francisco',
        state: 'CA',
        country: 'US',
        profile: 'https://example.com/profile.jpg',
        profile_medium: 'https://example.com/profile_medium.jpg',
        bikes: [{ id: 'b123', name: 'My Bike', primary: true, distance: 5000, resource_state: 2 }],
        shoes: [{ id: 's456', name: 'My Shoes', primary: false, distance: 100, resource_state: 2 }],
      };

      (global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve(mockAthlete),
      });

      const result = await getAthlete();

      expect(result.id).toBe(12345);
      expect(result.bikes).toHaveLength(1);
      expect(result.bikes![0].name).toBe('My Bike');
      expect(result.shoes).toHaveLength(1);
      expect(global.fetch).toHaveBeenCalledWith(
        PROXY_ENDPOINT,
        expect.objectContaining({
          body: JSON.stringify({ url: 'athlete', method: 'GET' }),
        })
      );
    });
  });

  describe('updateActivity', () => {
    const mockActivityResponse = {
      strava_id: '17145907973',
      title: 'Baby hawk',
      activity_type: 'EBikeRide',
      sport_type: 'EBikeRide',
      distance_meters: 50274.8,
      moving_time_seconds: 9219,
      total_elevation_gain_meters: 701.0,
      average_speed: 5.453,
      start_date: '2025-05-31T17:02:13Z',
      start_date_in_zone: '2025-05-31T10:02:13',
      timezone: 'America/Los_Angeles',
      kudos_count: 12,
      gear_id: 'b14918050',
      private: false,
      commute: false,
      muted: false,
      enriched_at: '2026-02-01T00:00:00Z',
      pr_count: 4,
      device_name: 'Strava App',
      average_heartrate: 127.5,
      max_heartrate: 168,
      photos: {
        photo_url: 'https://dgtzuqphqg23d.cloudfront.net/example.jpg',
        photo_count: 4,
      },
      segment_locations: {
        locations: [
          { city: 'Mill Valley', region: 'CA', country: 'US' },
          { city: 'San Francisco', region: 'CA', country: 'US' },
          { city: 'Sausalito', region: 'CA', country: 'US' },
        ],
        regions: { California: 'CA' },
        countries: { 'United States': 'US' },
      },
    };

    // Mock both PUT (update) and GET (fetch full details) proxy calls
    const mockPutThenGet = () => {
      (global.fetch as ReturnType<typeof vi.fn>)
        .mockResolvedValueOnce({
          ok: true,
          json: () => Promise.resolve({ strava_id: '17145907973' }), // PUT returns minimal data
        })
        .mockResolvedValueOnce({
          ok: true,
          json: () => Promise.resolve(mockActivityResponse), // GET returns full data
        });
    };

    it('fetches full activity after update to get enriched data', async () => {
      mockPutThenGet();

      const result = await updateActivity(17145907973, { name: 'Updated Name' });

      // Verify both proxy calls were made
      expect(global.fetch).toHaveBeenCalledTimes(2);

      // Verify enriched fields are present from GET response
      expect(result.device_name).toBe('Strava App');
      expect(result.muted).toBe(false);
      expect(result.photos).toBeDefined();
      expect(result.photos?.photo_count).toBe(4);
      expect(result.photos?.photo_url).toContain('cloudfront.net');
    });

    it('includes segment locations in response', async () => {
      mockPutThenGet();

      const result = await updateActivity(17145907973, { commute: true });

      expect(result.segment_locations).toBeDefined();
      expect(result.segment_locations?.locations).toEqual([
        { city: 'Mill Valley', region: 'CA', country: 'US' },
        { city: 'San Francisco', region: 'CA', country: 'US' },
        { city: 'Sausalito', region: 'CA', country: 'US' },
      ]);
    });

    it('preserves all activity fields in response', async () => {
      mockPutThenGet();

      const result = await updateActivity(17145907973, { gear_id: 'b12345' });

      expect(result.strava_id).toBe('17145907973');
      expect(result.title).toBe('Baby hawk');
      expect(result.distance_meters).toBe(50274.8);
      expect(result.moving_time_seconds).toBe(9219);
      expect(result.sport_type).toBe('EBikeRide');
      expect(result.average_heartrate).toBe(127.5);
    });

    it('refreshes auth token and retries on 401', async () => {
      vi.mocked(railsApi.exchangeSessionForToken).mockResolvedValueOnce({
        access_token: 'new_token',
        expires_in: 7200,
        created_at: Math.floor(Date.now() / 1000),
        athlete_id: '12345',
      });

      (global.fetch as ReturnType<typeof vi.fn>)
        // PUT returns 401
        .mockResolvedValueOnce({
          ok: false,
          status: 401,
          text: () => Promise.resolve('Unauthorized'),
        })
        // PUT retry with new token succeeds
        .mockResolvedValueOnce({
          ok: true,
          json: () => Promise.resolve({ strava_id: '17145907973' }),
        })
        // GET full activity succeeds
        .mockResolvedValueOnce({
          ok: true,
          json: () => Promise.resolve(mockActivityResponse),
        });

      const result = await updateActivity(17145907973, { name: 'Updated Name' });

      // Should have exchanged session for a new token
      expect(railsApi.exchangeSessionForToken).toHaveBeenCalledTimes(1);
      // Should have saved the new auth
      expect(database.saveAuth).toHaveBeenCalled();
      // 3 fetch calls: original PUT (401), retry PUT, GET full activity
      expect(global.fetch).toHaveBeenCalledTimes(3);
      // Retry should use new token
      const retryCall = (global.fetch as ReturnType<typeof vi.fn>).mock.calls[1];
      expect(retryCall[1].headers.Authorization).toBe('Bearer new_token');
      // Should still return full activity data
      expect(result.strava_id).toBe('17145907973');
      expect(result.title).toBe('Baby hawk');
    });
  });

  describe('getActivities', () => {
    it('does not include per_page in the request URL', async () => {
      (global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve([]),
      });

      await getActivities(1);

      const call = (global.fetch as ReturnType<typeof vi.fn>).mock.calls[0];
      const body = JSON.parse(call[1].body);
      expect(body.url).not.toContain('per_page');
    });

    it('includes page parameter in the request URL', async () => {
      (global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
        ok: true,
        json: () => Promise.resolve([]),
      });

      await getActivities(3);

      const call = (global.fetch as ReturnType<typeof vi.fn>).mock.calls[0];
      const body = JSON.parse(call[1].body);
      expect(body.url).toContain('page=3');
      expect(body.url).not.toContain('per_page');
    });
  });

  describe('getAllActivities', () => {
    const createMockActivity = (id: number) => ({
      strava_id: String(id),
      title: `Activity ${id}`,
      distance_meters: 10000,
      moving_time_seconds: 3600,
      total_elevation_gain_meters: 100,
      activity_type: 'Ride',
      sport_type: 'Ride',
      start_date: '2024-01-15T10:00:00Z',
      start_date_in_zone: '2024-01-15T02:00:00Z',
    });

    const mockEmptyResponse = () => ({
      ok: true,
      json: () => Promise.resolve([]),
    });

    const mockPageResponse = (activities: unknown[]) => ({
      ok: true,
      json: () => Promise.resolve(activities),
    });

    it('fetches all pages in parallel when estimatedTotal is provided', async () => {
      // 350 activities = 2 pages at 200/page, plus 1 extra to detect end
      const page1 = Array.from({ length: 200 }, (_, i) => createMockActivity(i + 1));
      const page2 = Array.from({ length: 150 }, (_, i) => createMockActivity(i + 201));

      (global.fetch as ReturnType<typeof vi.fn>)
        .mockResolvedValueOnce(mockPageResponse(page1))
        .mockResolvedValueOnce(mockPageResponse(page2))
        .mockResolvedValueOnce(mockEmptyResponse());

      const onBatch = vi.fn();
      const onProgress = vi.fn();

      const result = await getAllActivities({ onBatch, onProgress, estimatedTotal: 350 });

      // ceil(350/200) + 1 = 3 pages fetched in parallel
      expect(global.fetch).toHaveBeenCalledTimes(3);

      expect(onBatch).toHaveBeenCalledTimes(2);
      expect(onBatch).toHaveBeenNthCalledWith(1, page1, 200);
      expect(onBatch).toHaveBeenNthCalledWith(2, page2, 350);

      expect(onProgress).toHaveBeenCalledTimes(2);

      expect(result).toHaveLength(350);
    });

    it('fetches only 1 page without estimatedTotal', async () => {
      const activities = [createMockActivity(1), createMockActivity(2)];

      (global.fetch as ReturnType<typeof vi.fn>)
        .mockResolvedValueOnce(mockPageResponse(activities));

      const result = await getAllActivities({});

      expect(global.fetch).toHaveBeenCalledTimes(1);
      expect(result).toHaveLength(2);
    });

    it('includes sequential page params in all parallel requests', async () => {
      const page1 = Array.from({ length: 200 }, (_, i) => createMockActivity(i + 1));

      (global.fetch as ReturnType<typeof vi.fn>)
        .mockResolvedValueOnce(mockPageResponse(page1))
        .mockResolvedValueOnce(mockEmptyResponse());

      await getAllActivities({ estimatedTotal: 200 });

      const calls = (global.fetch as ReturnType<typeof vi.fn>).mock.calls;
      expect(calls).toHaveLength(2);

      for (let i = 0; i < calls.length; i++) {
        const body = JSON.parse(calls[i][1].body);
        expect(body.url).toContain(`page=${i + 1}`);
      }
    });

    it('does not include per_page in any request', async () => {
      const page1 = Array.from({ length: 5 }, (_, i) => createMockActivity(i + 1));

      (global.fetch as ReturnType<typeof vi.fn>)
        .mockResolvedValueOnce(mockPageResponse(page1))
        .mockResolvedValueOnce(mockEmptyResponse());

      await getAllActivities({ estimatedTotal: 5 });

      for (const call of (global.fetch as ReturnType<typeof vi.fn>).mock.calls) {
        const body = JSON.parse(call[1].body);
        expect(body.url).not.toContain('per_page');
      }
    });

    it('supports legacy function signature (onProgress, after)', async () => {
      const activities = [createMockActivity(1), createMockActivity(2)];

      (global.fetch as ReturnType<typeof vi.fn>)
        .mockResolvedValueOnce(mockPageResponse(activities));

      const onProgress = vi.fn();
      const result = await getAllActivities(onProgress);

      expect(onProgress).toHaveBeenCalledWith(2, null);
      expect(result).toHaveLength(2);
    });

    it('does not call onBatch for empty pages', async () => {
      (global.fetch as ReturnType<typeof vi.fn>)
        .mockResolvedValueOnce(mockEmptyResponse());

      const onBatch = vi.fn();
      const result = await getAllActivities({ onBatch });

      expect(onBatch).not.toHaveBeenCalled();
      expect(result).toHaveLength(0);
    });

    it('passes after parameter to filter activities', async () => {
      const activities = [createMockActivity(1)];

      (global.fetch as ReturnType<typeof vi.fn>)
        .mockResolvedValueOnce(mockPageResponse(activities));

      const afterTimestamp = Date.now() - 86400000; // 1 day ago
      await getAllActivities({ after: afterTimestamp });

      const call = (global.fetch as ReturnType<typeof vi.fn>).mock.calls[0];
      const body = JSON.parse(call[1].body);
      expect(body.url).toContain(`after=${Math.floor(afterTimestamp / 1000)}`);
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
          json: () => Promise.resolve({ id: 12345, firstname: 'Test' }),
        });

      const resultPromise = getAthlete();

      // Advance past the 1s delay for first retry
      await vi.advanceTimersByTimeAsync(1000);

      const result = await resultPromise;

      expect(global.fetch).toHaveBeenCalledTimes(2);
      expect(result.id).toBe(12345);
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
          json: () => Promise.resolve({ id: 12345, firstname: 'Test' }),
        });

      const resultPromise = getAthlete();

      // Advance past the 1s Retry-After delay
      await vi.advanceTimersByTimeAsync(1000);

      const result = await resultPromise;

      expect(result.id).toBe(12345);
    });

    it('throws after max retries exceeded', async () => {
      // Return 429 for all attempts
      (global.fetch as ReturnType<typeof vi.fn>).mockResolvedValue({
        ok: false,
        status: 429,
        headers: new Headers(),
      });

      let error: Error | null = null;
      const resultPromise = getAthlete().catch((e) => {
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
