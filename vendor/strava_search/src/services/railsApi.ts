interface StravaSearchConfig {
  tokenEndpoint: string;
  proxyEndpoint: string;
  athleteId: string;
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
