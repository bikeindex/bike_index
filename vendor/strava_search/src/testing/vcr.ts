/**
 * VCR-like recording system for Strava API responses.
 *
 * Usage:
 *
 * Recording mode (in browser console or dev tools):
 * ```
 * import { vcr } from './testing/vcr';
 * vcr.startRecording();
 * // ... make API calls ...
 * const cassette = vcr.stopRecording();
 * console.log(JSON.stringify(cassette, null, 2));
 * // Copy the output and save to a cassette file
 * ```
 *
 * Playback mode (in tests):
 * ```
 * import { vcr } from './testing/vcr';
 * import cassette from './cassettes/my-cassette.json';
 *
 * beforeEach(() => {
 *   vcr.loadCassette(cassette);
 * });
 *
 * afterEach(() => {
 *   vcr.eject();
 * });
 * ```
 */

export interface CassetteRequest {
  url: string;
  method: string;
  headers?: Record<string, string>;
  body?: string;
}

export interface CassetteResponse {
  status: number;
  statusText: string;
  headers: Record<string, string>;
  body: unknown;
}

export interface CassetteInteraction {
  request: CassetteRequest;
  response: CassetteResponse;
  recordedAt: string;
}

export interface Cassette {
  name: string;
  recordedAt: string;
  interactions: CassetteInteraction[];
}

// Patterns to sanitize from recorded data
const SENSITIVE_PATTERNS = [
  // OAuth tokens
  { pattern: /"access_token"\s*:\s*"[^"]+"/g, replacement: '"access_token": "[REDACTED]"' },
  { pattern: /"refresh_token"\s*:\s*"[^"]+"/g, replacement: '"refresh_token": "[REDACTED]"' },
  { pattern: /Bearer\s+[A-Za-z0-9\-_]+/g, replacement: 'Bearer [REDACTED]' },

  // Client credentials
  { pattern: /"client_id"\s*:\s*"?\d+"?/g, replacement: '"client_id": "[REDACTED]"' },
  { pattern: /"client_secret"\s*:\s*"[^"]+"/g, replacement: '"client_secret": "[REDACTED]"' },
  { pattern: /client_id=\d+/g, replacement: 'client_id=[REDACTED]' },
  { pattern: /client_secret=[^&\s]+/g, replacement: 'client_secret=[REDACTED]' },

  // Authorization code
  { pattern: /"code"\s*:\s*"[^"]+"/g, replacement: '"code": "[REDACTED]"' },
  { pattern: /code=[^&\s]+/g, replacement: 'code=[REDACTED]' },

  // Email addresses
  { pattern: /"email"\s*:\s*"[^"]+@[^"]+"/g, replacement: '"email": "[REDACTED]@example.com"' },

  // Profile URLs with athlete IDs (keep structure but anonymize ID)
  { pattern: /athletes\/\d+/g, replacement: 'athletes/[ATHLETE_ID]' },
];

// URL patterns to match for recording
const STRAVA_API_PATTERNS = [
  /^https:\/\/www\.strava\.com\/api\//,
  /^https:\/\/www\.strava\.com\/oauth\//,
];

function sanitizeString(str: string): string {
  let result = str;
  for (const { pattern, replacement } of SENSITIVE_PATTERNS) {
    result = result.replace(pattern, replacement);
  }
  return result;
}

function sanitizeObject(obj: unknown): unknown {
  if (obj === null || obj === undefined) {
    return obj;
  }

  if (typeof obj === 'string') {
    return sanitizeString(obj);
  }

  if (Array.isArray(obj)) {
    return obj.map(sanitizeObject);
  }

  if (typeof obj === 'object') {
    const sanitized: Record<string, unknown> = {};
    for (const [key, value] of Object.entries(obj as Record<string, unknown>)) {
      // Directly sanitize known sensitive keys
      if (['access_token', 'refresh_token', 'client_secret', 'code'].includes(key)) {
        sanitized[key] = '[REDACTED]';
      } else if (key === 'client_id') {
        sanitized[key] = '[REDACTED]';
      } else if (key === 'email' && typeof value === 'string') {
        sanitized[key] = '[REDACTED]@example.com';
      } else {
        sanitized[key] = sanitizeObject(value);
      }
    }
    return sanitized;
  }

  return obj;
}

function sanitizeHeaders(headers: Record<string, string>): Record<string, string> {
  const sanitized: Record<string, string> = {};
  for (const [key, value] of Object.entries(headers)) {
    if (key.toLowerCase() === 'authorization') {
      sanitized[key] = 'Bearer [REDACTED]';
    } else {
      sanitized[key] = sanitizeString(value);
    }
  }
  return sanitized;
}

function isStravaApiUrl(url: string): boolean {
  return STRAVA_API_PATTERNS.some((pattern) => pattern.test(url));
}

class VCR {
  private isRecording = false;
  private interactions: CassetteInteraction[] = [];
  private cassetteName = '';
  private loadedCassette: Cassette | null = null;
  private originalFetch: typeof fetch | null = null;

  /**
   * Start recording API interactions
   */
  startRecording(name: string = 'unnamed'): void {
    if (this.isRecording) {
      console.warn('VCR is already recording');
      return;
    }

    this.cassetteName = name;
    this.interactions = [];
    this.isRecording = true;
    this.originalFetch = window.fetch.bind(window);

    window.fetch = async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
      const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url;

      if (!isStravaApiUrl(url)) {
        return this.originalFetch!(input, init);
      }

      const method = init?.method || 'GET';
      const headers: Record<string, string> = {};

      if (init?.headers) {
        if (init.headers instanceof Headers) {
          init.headers.forEach((value, key) => {
            headers[key] = value;
          });
        } else if (Array.isArray(init.headers)) {
          init.headers.forEach(([key, value]) => {
            headers[key] = value;
          });
        } else {
          Object.assign(headers, init.headers);
        }
      }

      const requestBody = init?.body ? String(init.body) : undefined;

      // Make the actual request
      const response = await this.originalFetch!(input, init);

      // Clone the response so we can read it
      const clonedResponse = response.clone();
      const responseBody = await clonedResponse.json().catch(() => null);

      const responseHeaders: Record<string, string> = {};
      response.headers.forEach((value, key) => {
        responseHeaders[key] = value;
      });

      // Record the interaction (sanitized)
      const interaction: CassetteInteraction = {
        request: {
          url: sanitizeString(url),
          method,
          headers: sanitizeHeaders(headers),
          body: requestBody ? sanitizeString(requestBody) : undefined,
        },
        response: {
          status: response.status,
          statusText: response.statusText,
          headers: sanitizeHeaders(responseHeaders),
          body: sanitizeObject(responseBody),
        },
        recordedAt: new Date().toISOString(),
      };

      this.interactions.push(interaction);
      console.log(`[VCR] Recorded: ${method} ${url}`);

      return response;
    };

    console.log(`[VCR] Started recording cassette: ${name}`);
  }

  /**
   * Stop recording and return the cassette
   */
  stopRecording(): Cassette {
    if (!this.isRecording) {
      throw new Error('VCR is not recording');
    }

    this.isRecording = false;

    if (this.originalFetch) {
      window.fetch = this.originalFetch;
      this.originalFetch = null;
    }

    const cassette: Cassette = {
      name: this.cassetteName,
      recordedAt: new Date().toISOString(),
      interactions: this.interactions,
    };

    console.log(`[VCR] Stopped recording. Captured ${this.interactions.length} interactions.`);

    return cassette;
  }

  /**
   * Load a cassette for playback
   */
  loadCassette(cassette: Cassette): void {
    if (this.isRecording) {
      throw new Error('Cannot load cassette while recording');
    }

    this.loadedCassette = cassette;
    this.originalFetch = window.fetch.bind(window);

    window.fetch = async (input: RequestInfo | URL, init?: RequestInit): Promise<Response> => {
      const url = typeof input === 'string' ? input : input instanceof URL ? input.toString() : input.url;

      if (!isStravaApiUrl(url)) {
        return this.originalFetch!(input, init);
      }

      const method = init?.method || 'GET';

      // Find matching interaction
      const interaction = this.findMatchingInteraction(url, method);

      if (!interaction) {
        console.error(`[VCR] No matching interaction found for: ${method} ${url}`);
        throw new Error(`VCR: No recorded interaction found for ${method} ${url}`);
      }

      console.log(`[VCR] Replaying: ${method} ${url}`);

      // Create a fake response
      const responseBody = JSON.stringify(interaction.response.body);
      const headers = new Headers(interaction.response.headers);

      return new Response(responseBody, {
        status: interaction.response.status,
        statusText: interaction.response.statusText,
        headers,
      });
    };

    console.log(`[VCR] Loaded cassette: ${cassette.name} with ${cassette.interactions.length} interactions`);
  }

  /**
   * Eject the cassette and restore normal fetch behavior
   */
  eject(): void {
    if (this.originalFetch) {
      window.fetch = this.originalFetch;
      this.originalFetch = null;
    }

    this.loadedCassette = null;

    console.log('[VCR] Ejected cassette');
  }

  /**
   * Find a matching recorded interaction
   */
  private findMatchingInteraction(url: string, method: string): CassetteInteraction | null {
    if (!this.loadedCassette) return null;

    // Sanitize the URL for matching
    const sanitizedUrl = sanitizeString(url);

    // Try to find exact match first
    for (const interaction of this.loadedCassette.interactions) {
      if (interaction.request.method === method && interaction.request.url === sanitizedUrl) {
        return interaction;
      }
    }

    // Try matching without query params for some flexibility
    const urlWithoutParams = sanitizedUrl.split('?')[0];
    for (const interaction of this.loadedCassette.interactions) {
      const recordedUrlWithoutParams = interaction.request.url.split('?')[0];
      if (interaction.request.method === method && recordedUrlWithoutParams === urlWithoutParams) {
        return interaction;
      }
    }

    return null;
  }

  /**
   * Get the current state
   */
  getState(): { isRecording: boolean; hasLoadedCassette: boolean; interactionCount: number } {
    return {
      isRecording: this.isRecording,
      hasLoadedCassette: this.loadedCassette !== null,
      interactionCount: this.loadedCassette?.interactions.length || this.interactions.length,
    };
  }

  /**
   * Download a cassette as a JSON file
   */
  downloadCassette(cassette: Cassette): void {
    const blob = new Blob([JSON.stringify(cassette, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `${cassette.name}-${new Date().toISOString().split('T')[0]}.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
  }
}

// Export singleton instance
export const vcr = new VCR();

// Make available on window for console usage during development
if (typeof window !== 'undefined') {
  (window as unknown as { vcr: VCR }).vcr = vcr;
}
