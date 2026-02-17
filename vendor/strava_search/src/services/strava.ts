import {
  type StravaActivity,
  type StravaTokenResponse,
  type StoredAuth,
  type StravaGear,
  type UpdatableActivity,
  type StravaAthlete,
  deriveLocationFromSegments,
} from '../types/strava';
import { saveAuth, getAuth, clearAuth } from './database';

const STRAVA_AUTH_URL = 'https://www.strava.com/oauth/authorize';
const STRAVA_TOKEN_URL = 'https://www.strava.com/oauth/token';
const STRAVA_API_URL = 'https://www.strava.com/api/v3';

// Environment variables (set via .env file or build-time)
const ENV_CLIENT_ID = import.meta.env.VITE_STRAVA_CLIENT_ID || '';
const ENV_CLIENT_SECRET = import.meta.env.VITE_STRAVA_CLIENT_SECRET || '';

// Credentials can be set via env vars or storage (user input takes precedence)
// Client ID uses localStorage (not sensitive), Client Secret uses sessionStorage (more secure)
let CLIENT_ID = localStorage.getItem('strava_client_id') || ENV_CLIENT_ID;
let CLIENT_SECRET = sessionStorage.getItem('strava_client_secret') || ENV_CLIENT_SECRET;

export function setStravaCredentials(clientId: string, clientSecret: string): void {
  CLIENT_ID = clientId;
  CLIENT_SECRET = clientSecret;
  localStorage.setItem('strava_client_id', clientId);
  // Use sessionStorage for client secret - reduces XSS exposure window
  // Secret is cleared when browser tab closes
  sessionStorage.setItem('strava_client_secret', clientSecret);
}

export function getStravaCredentials(): { clientId: string; clientSecret: string } {
  return { clientId: CLIENT_ID, clientSecret: CLIENT_SECRET };
}

export function hasStravaCredentials(): boolean {
  return Boolean(CLIENT_ID && CLIENT_SECRET);
}

function getRedirectUri(): string {
  // Use the current origin for the redirect
  return `${window.location.origin}${window.location.pathname}`;
}

export function generateAuthUrl(): string {
  const params = new URLSearchParams({
    client_id: CLIENT_ID,
    redirect_uri: getRedirectUri(),
    response_type: 'code',
    scope: 'read,activity:read_all,activity:write,profile:read_all',
    approval_prompt: 'auto',
  });

  return `${STRAVA_AUTH_URL}?${params.toString()}`;
}

export async function exchangeCodeForToken(code: string): Promise<StoredAuth> {
  const response = await fetch(STRAVA_TOKEN_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      client_id: CLIENT_ID,
      client_secret: CLIENT_SECRET,
      code,
      grant_type: 'authorization_code',
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Failed to exchange code: ${error}`);
  }

  const data: StravaTokenResponse = await response.json();

  const auth: StoredAuth = {
    accessToken: data.access_token,
    refreshToken: data.refresh_token,
    expiresAt: data.expires_at * 1000, // Convert to milliseconds
    athlete: data.athlete,
  };

  await saveAuth(auth);
  return auth;
}

export async function refreshAccessToken(refreshToken: string): Promise<StoredAuth> {
  const response = await fetch(STRAVA_TOKEN_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      client_id: CLIENT_ID,
      client_secret: CLIENT_SECRET,
      refresh_token: refreshToken,
      grant_type: 'refresh_token',
    }),
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Failed to refresh token: ${error}`);
  }

  const data: StravaTokenResponse = await response.json();

  const storedAuth = await getAuth();
  const auth: StoredAuth = {
    accessToken: data.access_token,
    refreshToken: data.refresh_token,
    expiresAt: data.expires_at * 1000,
    athlete: storedAuth?.athlete || data.athlete,
  };

  await saveAuth(auth);
  return auth;
}

async function getValidAccessToken(): Promise<string> {
  const auth = await getAuth();

  if (!auth) {
    throw new Error('Not authenticated');
  }

  // Check if token is expired or will expire in the next minute
  if (Date.now() >= auth.expiresAt - 60000) {
    const newAuth = await refreshAccessToken(auth.refreshToken);
    return newAuth.accessToken;
  }

  return auth.accessToken;
}

// Rate limit handling configuration
const MAX_RETRIES = 3;
const BASE_DELAY_MS = 1000;

async function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function apiRequest<T>(
  endpoint: string,
  options: RequestInit = {},
  retryCount: number = 0
): Promise<T> {
  const accessToken = await getValidAccessToken();

  const response = await fetch(`${STRAVA_API_URL}${endpoint}`, {
    ...options,
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
      ...options.headers,
    },
  });

  if (!response.ok) {
    if (response.status === 401) {
      await clearAuth();
      throw new Error('Session expired. Please log in again.');
    }

    // Handle rate limiting (429) with exponential backoff
    if (response.status === 429) {
      if (retryCount >= MAX_RETRIES) {
        throw new Error('Rate limit exceeded. Please wait a few minutes and try again.');
      }

      // Check for Retry-After header (Strava sometimes provides this)
      const retryAfter = response.headers.get('Retry-After');
      const delayMs = retryAfter
        ? parseInt(retryAfter, 10) * 1000
        : BASE_DELAY_MS * Math.pow(2, retryCount); // Exponential backoff: 1s, 2s, 4s

      console.warn(`Rate limited. Retrying in ${delayMs}ms (attempt ${retryCount + 1}/${MAX_RETRIES})`);
      await sleep(delayMs);
      return apiRequest<T>(endpoint, options, retryCount + 1);
    }

    const error = await response.text();
    throw new Error(`API request failed: ${error}`);
  }

  return response.json();
}

export async function getAthlete(): Promise<StravaAthlete> {
  return apiRequest<StravaAthlete>('/athlete');
}

export async function getAthleteGear(): Promise<StravaGear[]> {
  const athlete = await apiRequest<StravaAthlete & { bikes: StravaGear[]; shoes: StravaGear[] }>(
    '/athlete'
  );
  return [...(athlete.bikes || []), ...(athlete.shoes || [])];
}

interface ActivityTotals {
  count: number;
  distance: number;
  moving_time: number;
  elapsed_time: number;
  elevation_gain: number;
}

interface AthleteStats {
  all_ride_totals: ActivityTotals;
  all_run_totals: ActivityTotals;
  all_swim_totals: ActivityTotals;
}

export async function getAthleteStats(athleteId: number): Promise<number> {
  const stats = await apiRequest<AthleteStats>(`/athletes/${athleteId}/stats`);
  // Sum up all activity counts
  return (
    (stats.all_ride_totals?.count || 0) +
    (stats.all_run_totals?.count || 0) +
    (stats.all_swim_totals?.count || 0)
  );
}

export async function getActivities(
  page: number = 1,
  perPage: number = 100,
  before?: number,
  after?: number
): Promise<StravaActivity[]> {
  const params = new URLSearchParams({
    page: page.toString(),
    per_page: perPage.toString(),
  });

  if (before) {
    params.append('before', Math.floor(before / 1000).toString());
  }

  if (after) {
    params.append('after', Math.floor(after / 1000).toString());
  }

  return apiRequest<StravaActivity[]>(`/athlete/activities?${params.toString()}`);
}

export async function getActivity(id: number): Promise<StravaActivity> {
  const activity = await apiRequest<StravaActivity>(`/activities/${id}`);
  return deriveLocationFromSegments(activity);
}

export async function updateActivity(
  id: number,
  updates: UpdatableActivity
): Promise<StravaActivity> {
  // Send the update
  await apiRequest<StravaActivity>(`/activities/${id}`, {
    method: 'PUT',
    body: JSON.stringify(updates),
  });

  // Fetch full activity details (PUT response doesn't include photos, segment_efforts, etc.)
  return getActivity(id);
}

export interface GetAllActivitiesOptions {
  onProgress?: (loaded: number, total: number | null) => void;
  onBatch?: (activities: StravaActivity[], totalSoFar: number) => Promise<void>;
  after?: number;
}

export async function getAllActivities(
  onProgressOrOptions?: ((loaded: number, total: number | null) => void) | GetAllActivitiesOptions,
  after?: number
): Promise<StravaActivity[]> {
  // Support both old signature (onProgress, after) and new options object
  const options: GetAllActivitiesOptions = typeof onProgressOrOptions === 'function'
    ? { onProgress: onProgressOrOptions, after }
    : onProgressOrOptions || {};

  const allActivities: StravaActivity[] = [];
  let page = 1;
  const perPage = 100;

  while (true) {
    const activities = await getActivities(page, perPage, undefined, options.after);
    allActivities.push(...activities);

    // Call batch callback with the new batch
    if (options.onBatch && activities.length > 0) {
      await options.onBatch(activities, allActivities.length);
    }

    if (options.onProgress) {
      options.onProgress(allActivities.length, null);
    }

    if (activities.length < perPage) {
      break;
    }

    page++;

    // Small delay to avoid rate limiting
    await new Promise((resolve) => setTimeout(resolve, 100));
  }

  return allActivities;
}

export async function logout(): Promise<void> {
  await clearAuth();
}
