interface StravaSearchConfig {
  tokenEndpoint: string;
  proxyEndpoint: string;
  syncStatusEndpoint: string;
  activitiesEndpoint: string;
  athleteId: string;
  hasActivityWrite: boolean;
  authUrl: string;
}

interface TokenResponse {
  access_token: string;
  expires_in: number;
  created_at: number;
  athlete_id: string;
}

declare global {
  interface Window {
    stravaSearchConfig: StravaSearchConfig;
  }
}

export function getConfig(): StravaSearchConfig {
  return window.stravaSearchConfig;
}

function getCsrfToken(): string {
  return document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || '';
}

export interface BackendSyncStatus {
  status: 'pending' | 'syncing' | 'synced' | 'error';
  activities_downloaded_count: number;
  athlete_activity_count: number | null;
  progress_percent: number;
}

import type { StravaActivity, StravaGear } from '../types/strava';

export interface BackendActivitiesResponse {
  activities: StravaActivity[];
  gear: StravaGear[];
}

export async function fetchSyncStatus(): Promise<BackendSyncStatus> {
  const config = getConfig();
  const response = await fetch(config.syncStatusEndpoint, {
    credentials: 'same-origin',
  });
  if (!response.ok) {
    throw new Error(`Sync status check failed: ${response.status}`);
  }
  return response.json();
}

export async function fetchActivitiesFromBackend(): Promise<BackendActivitiesResponse> {
  const config = getConfig();
  const response = await fetch(config.activitiesEndpoint, {
    credentials: 'same-origin',
  });
  if (!response.ok) {
    throw new Error(`Activities fetch failed: ${response.status}`);
  }
  return response.json();
}

export async function exchangeSessionForToken(): Promise<TokenResponse> {
  const config = getConfig();
  const response = await fetch(config.tokenEndpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': getCsrfToken(),
    },
    credentials: 'same-origin',
  });

  if (!response.ok) {
    const data = await response.json();
    throw new Error(data.error || `Token exchange failed: ${response.status}`);
  }

  return response.json();
}
