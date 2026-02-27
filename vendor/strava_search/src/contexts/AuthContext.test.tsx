import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, waitFor, screen } from '@testing-library/react';
import { AuthProvider, useAuth } from './AuthContext';

const mockGetAuth = vi.fn();
const mockClearAllData = vi.fn();
const mockSaveAuth = vi.fn();
const mockGetSyncState = vi.fn();
const mockClearAuth = vi.fn();

vi.mock('../services/database', () => ({
  getAuth: (...args: unknown[]) => mockGetAuth(...args),
  clearAllData: (...args: unknown[]) => mockClearAllData(...args),
  clearAuth: (...args: unknown[]) => mockClearAuth(...args),
  saveAuth: (...args: unknown[]) => mockSaveAuth(...args),
  getSyncState: (...args: unknown[]) => mockGetSyncState(...args),
}));

const mockGetConfig = vi.fn();
const mockExchangeSessionForToken = vi.fn();

vi.mock('../services/railsApi', () => ({
  getConfig: (...args: unknown[]) => mockGetConfig(...args),
  exchangeSessionForToken: (...args: unknown[]) => mockExchangeSessionForToken(...args),
}));

vi.mock('../services/strava', () => ({
  getAthlete: vi.fn(() => Promise.reject(new Error('not needed'))),
}));

function TestConsumer() {
  const { isAuthenticated, isLoading, athlete, error } = useAuth();
  if (isLoading) return <div>loading</div>;
  if (error) return <div>error: {error}</div>;
  if (isAuthenticated && athlete) return <div>authenticated: {athlete.id}</div>;
  return <div>not authenticated</div>;
}

function renderWithProvider() {
  return render(
    <AuthProvider>
      <TestConsumer />
    </AuthProvider>
  );
}

const validToken = {
  access_token: 'token123',
  expires_in: 7200,
  created_at: Math.floor(Date.now() / 1000),
  athlete_id: '99999',
};

describe('AuthContext', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    mockGetSyncState.mockResolvedValue(undefined);
    mockSaveAuth.mockResolvedValue(undefined);
    mockClearAllData.mockResolvedValue(undefined);
    mockClearAuth.mockResolvedValue(undefined);
  });

  it('uses stored auth when athlete ID matches config', async () => {
    const storedAuth = {
      id: 12345,
      accessToken: 'stored-token',
      refreshToken: '',
      expiresAt: Date.now() + 3600000,
      athlete: { id: 12345, firstname: 'Test', lastname: 'User', username: '', city: '', state: '', country: '', profile: '', profile_medium: 'http://example.com/avatar.jpg' },
    };

    mockGetAuth.mockResolvedValue(storedAuth);
    mockGetConfig.mockReturnValue({ athleteId: '12345', tokenEndpoint: '', proxyEndpoint: '', hasActivityWrite: false, authUrl: '' });

    renderWithProvider();

    await waitFor(() => {
      expect(screen.getByText('authenticated: 12345')).toBeInTheDocument();
    });

    expect(mockClearAllData).not.toHaveBeenCalled();
    expect(mockExchangeSessionForToken).not.toHaveBeenCalled();
  });

  it('clears database and re-authenticates when athlete ID mismatches config', async () => {
    const storedAuth = {
      id: 11111,
      accessToken: 'old-token',
      refreshToken: '',
      expiresAt: Date.now() + 3600000,
      athlete: { id: 11111, firstname: 'Old', lastname: 'User', username: '', city: '', state: '', country: '', profile: '', profile_medium: '' },
    };

    mockGetAuth.mockResolvedValue(storedAuth);
    mockGetConfig.mockReturnValue({ athleteId: '99999', tokenEndpoint: '', proxyEndpoint: '', hasActivityWrite: false, authUrl: '' });
    mockExchangeSessionForToken.mockResolvedValue(validToken);

    renderWithProvider();

    await waitFor(() => {
      expect(screen.getByText('authenticated: 99999')).toBeInTheDocument();
    });

    expect(mockClearAllData).toHaveBeenCalled();
    expect(mockExchangeSessionForToken).toHaveBeenCalled();
  });

  it('exchanges session for token when no stored auth exists', async () => {
    mockGetAuth.mockResolvedValue(undefined);
    mockGetConfig.mockReturnValue({ athleteId: '99999', tokenEndpoint: '', proxyEndpoint: '', hasActivityWrite: false, authUrl: '' });
    mockExchangeSessionForToken.mockResolvedValue(validToken);

    renderWithProvider();

    await waitFor(() => {
      expect(screen.getByText('authenticated: 99999')).toBeInTheDocument();
    });

    expect(mockClearAllData).not.toHaveBeenCalled();
    expect(mockExchangeSessionForToken).toHaveBeenCalled();
  });
});
