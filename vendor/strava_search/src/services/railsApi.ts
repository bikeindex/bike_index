interface StravaSearchConfig {
  tokenEndpoint: string;
  proxyEndpoint: string;
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

export async function fetchSyncStatus(): Promise<BackendSyncStatus | null> {
  const tokenResponse = await exchangeSessionForToken();
  return tokenResponse.sync_status ?? null;
}

interface TokenResponseWithSync extends TokenResponse {
  sync_status?: BackendSyncStatus;
}

export async function exchangeSessionForToken(): Promise<TokenResponseWithSync> {
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
