import {
  type StravaActivity,
  type StoredAuth,
  type StravaGear,
  type UpdatableActivity,
  type StravaAthlete,
} from '../types/strava';
import { saveAuth, getAuth, clearAuth } from './database';
import { getConfig, exchangeSessionForToken } from './railsApi';

// Rate limit handling configuration
const MAX_RETRIES = 3;
const BASE_DELAY_MS = 1000;

async function sleep(ms: number): Promise<void> {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function refreshToken(): Promise<StoredAuth> {
  const auth = await getAuth();
  const tokenResponse = await exchangeSessionForToken();
  const newAuth: StoredAuth = {
    accessToken: tokenResponse.access_token,
    refreshToken: '',
    expiresAt: (tokenResponse.created_at + tokenResponse.expires_in) * 1000,
    athlete: auth?.athlete ?? { id: 0, username: '', firstname: '', lastname: '', city: '', state: '', country: '', profile: '', profile_medium: '' },
  };
  await saveAuth(newAuth);
  return newAuth;
}

async function getValidAccessToken(): Promise<string> {
  const auth = await getAuth();

  if (!auth) {
    throw new Error('Not authenticated');
  }

  // Check if token is expired or will expire in the next minute
  if (Date.now() >= auth.expiresAt - 60000) {
    const newAuth = await refreshToken();
    return newAuth.accessToken;
  }

  return auth.accessToken;
}

async function apiRequest<T>(
  endpoint: string,
  options: RequestInit = {},
  retryCount: number = 0
): Promise<T> {
  const accessToken = await getValidAccessToken();
  const config = getConfig();

  // Strip leading slash for the proxy url param
  const url = endpoint.startsWith('/') ? endpoint.slice(1) : endpoint;
  const method = (options.method || 'GET').toUpperCase();

  const proxyBody: Record<string, unknown> = { url, method };
  if (options.body && (method === 'PUT' || method === 'POST')) {
    proxyBody.body = JSON.parse(options.body as string);
  }

  const response = await fetch(config.proxyEndpoint, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(proxyBody),
  });

  if (!response.ok) {
    if (response.status === 401) {
      // Try re-exchanging the session for a new token
      try {
        const newAuth = await refreshToken();
        // Retry with new token (re-read from auth to avoid stale closure)
        const retryResponse = await fetch(config.proxyEndpoint, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${newAuth.accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify(proxyBody),
        });
        if (retryResponse.ok) {
          return retryResponse.json();
        }
      } catch {
        // Refresh failed
      }
      await clearAuth();
      throw new Error('Session expired. Please log in again.');
    }

    // Handle rate limiting (429) with exponential backoff
    if (response.status === 429) {
      if (retryCount >= MAX_RETRIES) {
        throw new Error('Rate limit exceeded. Please wait a few minutes and try again.');
      }

      const retryAfter = response.headers.get('Retry-After');
      const delayMs = retryAfter
        ? parseInt(retryAfter, 10) * 1000
        : BASE_DELAY_MS * Math.pow(2, retryCount);

      console.warn(`Rate limited. Retrying in ${delayMs}ms (attempt ${retryCount + 1}/${MAX_RETRIES})`);
      await sleep(delayMs);
      return apiRequest<T>(endpoint, options, retryCount + 1);
    }

    const error = await response.text();
    throw new Error(`API request failed: ${error}`);
  }

  return response.json();
}

export interface BackendSyncStatus {
  status: 'pending' | 'syncing' | 'synced' | 'error';
  activities_downloaded_count: number;
  athlete_activity_count: number | null;
  progress_percent: number;
}

export async function fetchSyncStatus(): Promise<BackendSyncStatus | null> {
  const accessToken = await getValidAccessToken();
  const config = getConfig();

  const response = await fetch(config.proxyEndpoint, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ sync_status: true }),
  });

  if (!response.ok) return null;

  const data = await response.json();
  return data.sync_status ?? null;
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
  return apiRequest<StravaActivity>(`/activities/${id}`);
}

export async function updateActivity(
  id: number,
  updates: UpdatableActivity
): Promise<StravaActivity> {
  await apiRequest<StravaActivity>(`/activities/${id}`, {
    method: 'PUT',
    body: JSON.stringify(updates),
  });

  // Fetch full activity details (PUT response doesn't include all fields)
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
  const options: GetAllActivitiesOptions = typeof onProgressOrOptions === 'function'
    ? { onProgress: onProgressOrOptions, after }
    : onProgressOrOptions || {};

  const allActivities: StravaActivity[] = [];
  let page = 1;
  const perPage = 100;

  while (true) {
    const activities = await getActivities(page, perPage, undefined, options.after);
    allActivities.push(...activities);

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

export async function fetchEnrichedSince(enrichedSince: number): Promise<StravaActivity[]> {
  return apiRequest<StravaActivity[]>(`/athlete/activities?enriched_since=${enrichedSince}`);
}

export async function logout(): Promise<void> {
  await clearAuth();
}
