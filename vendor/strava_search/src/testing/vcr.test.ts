import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { vcr, type Cassette } from './vcr';

describe('VCR Integration', () => {
  const originalFetch = global.fetch;

  beforeEach(() => {
    // Reset VCR state
    vcr.eject();
    global.fetch = vi.fn();
  });

  afterEach(() => {
    vcr.eject();
    global.fetch = originalFetch;
  });

  describe('Recording', () => {
    it('records Strava API calls and sanitizes sensitive data', async () => {
      const mockResponse = {
        id: 12345,
        access_token: 'super_secret_token_123',
        refresh_token: 'refresh_secret_456',
        client_id: '98765',
        email: 'test@example.com',
      };

      (global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
        ok: true,
        status: 200,
        statusText: 'OK',
        headers: new Headers({ 'content-type': 'application/json' }),
        clone: () => ({
          json: () => Promise.resolve(mockResponse),
        }),
        json: () => Promise.resolve(mockResponse),
      });

      vcr.startRecording('test-cassette');

      await fetch('https://www.strava.com/api/v3/athlete', {
        headers: { Authorization: 'Bearer my_secret_token' },
      });

      const cassette = vcr.stopRecording();

      expect(cassette.name).toBe('test-cassette');
      expect(cassette.interactions).toHaveLength(1);

      const interaction = cassette.interactions[0];

      // Check request sanitization
      expect(interaction.request.headers?.Authorization).toBe('Bearer [REDACTED]');

      // Check response sanitization
      const body = interaction.response.body as Record<string, unknown>;
      expect(body.access_token).toBe('[REDACTED]');
      expect(body.refresh_token).toBe('[REDACTED]');
      expect(body.client_id).toBe('[REDACTED]');
      expect(body.email).toBe('[REDACTED]@example.com');
    });

    it('does not record non-Strava API calls', async () => {
      (global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
        ok: true,
        status: 200,
        statusText: 'OK',
        json: () => Promise.resolve({ data: 'test' }),
      });

      vcr.startRecording('test-cassette');

      await fetch('https://api.example.com/data');

      const cassette = vcr.stopRecording();

      expect(cassette.interactions).toHaveLength(0);
    });
  });

  describe('Playback', () => {
    it('replays recorded responses for matching requests', async () => {
      const cassette: Cassette = {
        name: 'test-playback',
        recordedAt: new Date().toISOString(),
        interactions: [
          {
            request: {
              url: 'https://www.strava.com/api/v3/athlete',
              method: 'GET',
              headers: { Authorization: 'Bearer [REDACTED]' },
            },
            response: {
              status: 200,
              statusText: 'OK',
              headers: { 'content-type': 'application/json' },
              body: { id: 12345, firstname: 'Test', lastname: 'User' },
            },
            recordedAt: new Date().toISOString(),
          },
        ],
      };

      vcr.loadCassette(cassette);

      const response = await fetch('https://www.strava.com/api/v3/athlete', {
        headers: { Authorization: 'Bearer some_token' },
      });

      expect(response.status).toBe(200);
      const data = await response.json();
      expect(data.id).toBe(12345);
      expect(data.firstname).toBe('Test');
    });

    it('throws error when no matching interaction found', async () => {
      const cassette: Cassette = {
        name: 'empty-cassette',
        recordedAt: new Date().toISOString(),
        interactions: [],
      };

      vcr.loadCassette(cassette);

      await expect(
        fetch('https://www.strava.com/api/v3/athlete/activities')
      ).rejects.toThrow('No recorded interaction found');
    });

    it('passes through non-Strava requests during playback', async () => {
      const cassette: Cassette = {
        name: 'test',
        recordedAt: new Date().toISOString(),
        interactions: [],
      };

      (global.fetch as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: () => Promise.resolve({ external: true }),
      });

      vcr.loadCassette(cassette);

      // This should pass through to the original fetch
      const response = await fetch('https://api.example.com/data');
      expect(response.ok).toBe(true);
    });
  });

  describe('State management', () => {
    it('reports correct state', () => {
      expect(vcr.getState()).toEqual({
        isRecording: false,
        hasLoadedCassette: false,
        interactionCount: 0,
      });

      vcr.startRecording('test');
      expect(vcr.getState().isRecording).toBe(true);

      vcr.stopRecording();
      expect(vcr.getState().isRecording).toBe(false);
    });

    it('prevents loading cassette while recording', () => {
      vcr.startRecording('test');

      expect(() => {
        vcr.loadCassette({
          name: 'test',
          recordedAt: new Date().toISOString(),
          interactions: [],
        });
      }).toThrow('Cannot load cassette while recording');

      vcr.stopRecording();
    });
  });
});
