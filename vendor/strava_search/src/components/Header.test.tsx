import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import { Header } from './Header';

const mockAthlete = { id: 12345, firstname: 'Test', lastname: 'User', profile_medium: '' };
const mockSyncState = { athleteId: 12345, lastSyncedAt: Date.now(), isInitialSyncComplete: true, oldestActivityDate: null };

vi.mock('../contexts/AuthContext', () => ({
  useAuth: vi.fn(() => ({
    athlete: mockAthlete,
    syncState: mockSyncState,
    logout: vi.fn(),
  })),
}));

vi.mock('../hooks/useActivitySync', () => ({
  useActivitySync: vi.fn(() => ({
    isSyncing: false,
    isFetchingFullData: false,
    syncRecent: vi.fn(),
    progress: null,
  })),
}));

describe('Header', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('progress display', () => {
    it('shows title when not working', () => {
      render(<Header onOpenSettings={() => {}} />);
      expect(screen.getByText('Strava Search')).toBeInTheDocument();
    });

    it('uses external fetchProgress prop when provided', async () => {
      const { useActivitySync } = await import('../hooks/useActivitySync');
      vi.mocked(useActivitySync).mockReturnValue({
        isSyncing: false,
        isFetchingFullData: false,
        syncRecent: vi.fn(),
        progress: { loaded: 0, total: 10, status: 'Hook progress' },
        syncAll: vi.fn(),
        fetchFullActivityData: vi.fn(),
        error: null,
        clearError: vi.fn(),
      });

      render(
        <Header
          onOpenSettings={() => {}}
          isFetchingFullData={true}
          fetchProgress={{ status: 'Fetching full data for this page: 5 of 10' }}
        />
      );

      // Should show external progress, not hook progress
      expect(screen.getByText('Fetching full data for this page: 5 of 10')).toBeInTheDocument();
      expect(screen.queryByText('Strava Search')).not.toBeInTheDocument();
    });

    it('uses hook state when external props not provided', async () => {
      const { useActivitySync } = await import('../hooks/useActivitySync');
      vi.mocked(useActivitySync).mockReturnValue({
        isSyncing: true,
        isFetchingFullData: false,
        syncRecent: vi.fn(),
        progress: { loaded: 50, total: 100, status: '50 of 100 activities synced' },
        syncAll: vi.fn(),
        fetchFullActivityData: vi.fn(),
        error: null,
        clearError: vi.fn(),
      });

      render(<Header onOpenSettings={() => {}} />);

      // Should show hook progress since no external props
      expect(screen.getByText('50 of 100 activities synced')).toBeInTheDocument();
    });

    it('prefers external isFetchingFullData over hook state', async () => {
      const { useActivitySync } = await import('../hooks/useActivitySync');
      vi.mocked(useActivitySync).mockReturnValue({
        isSyncing: false,
        isFetchingFullData: false, // Hook says not fetching
        syncRecent: vi.fn(),
        progress: null,
        syncAll: vi.fn(),
        fetchFullActivityData: vi.fn(),
        error: null,
        clearError: vi.fn(),
      });

      render(
        <Header
          onOpenSettings={() => {}}
          isFetchingFullData={true} // But external prop says fetching
          fetchProgress={{ status: 'External fetching status' }}
        />
      );

      // Should show progress because external prop says fetching
      expect(screen.getByText('External fetching status')).toBeInTheDocument();
    });
  });
});
