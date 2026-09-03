import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { Header } from './Header';

const mockSyncRecent = vi.fn();
const mockAthlete = { id: 12345, firstname: 'Test', lastname: 'User', profile_medium: '' };
const mockSyncState = { athleteId: 12345, lastSyncedAt: Date.now(), isInitialSyncComplete: true, oldestActivityDate: null };

vi.mock('../contexts/AuthContext', () => ({
  useAuth: vi.fn(() => ({
    athlete: mockAthlete,
    syncState: mockSyncState,
  })),
}));

vi.mock('../hooks/useActivitySync', () => ({
  useActivitySync: vi.fn(() => ({
    isSyncing: false,
    isFetchingFullData: false,
    syncRecent: mockSyncRecent,
    progress: null,
    syncAll: vi.fn(),
    fetchFullActivityData: vi.fn(),
    error: null,
    clearError: vi.fn(),
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

    it('renders mobile sync status row when syncState exists', () => {
      render(<Header onOpenSettings={() => {}} />);
      // Both desktop (hidden sm:block) and mobile (sm:hidden) sync status elements exist
      const syncElements = screen.getAllByText(/Last synced:/);
      expect(syncElements.length).toBe(2);
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

  describe('dropdown menu', () => {
    it('opens dropdown when avatar button is clicked', () => {
      render(<Header onOpenSettings={() => {}} />);
      expect(screen.queryByText('Settings')).not.toBeInTheDocument();

      const avatarButton = screen.getByRole('button');
      fireEvent.click(avatarButton);

      expect(screen.getByText('Settings')).toBeInTheDocument();
      expect(screen.getByText('Sync')).toBeInTheDocument();
    });

    it('closes dropdown when avatar button is clicked again', () => {
      render(<Header onOpenSettings={() => {}} />);
      const avatarButton = screen.getByRole('button');

      fireEvent.click(avatarButton);
      expect(screen.getByText('Settings')).toBeInTheDocument();

      fireEvent.click(avatarButton);
      expect(screen.queryByText('Settings')).not.toBeInTheDocument();
    });

    it('closes dropdown when clicking outside', () => {
      render(<Header onOpenSettings={() => {}} />);
      const avatarButton = screen.getByRole('button');

      fireEvent.click(avatarButton);
      expect(screen.getByText('Settings')).toBeInTheDocument();

      fireEvent.mouseDown(document.body);
      expect(screen.queryByText('Settings')).not.toBeInTheDocument();
    });

    it('calls onOpenSettings when Settings is clicked', () => {
      const onOpenSettings = vi.fn();
      render(<Header onOpenSettings={onOpenSettings} />);

      fireEvent.click(screen.getByRole('button'));
      fireEvent.click(screen.getByText('Settings'));

      expect(onOpenSettings).toHaveBeenCalled();
    });

    it('calls syncRecent when Sync is clicked', async () => {
      const { useActivitySync } = await import('../hooks/useActivitySync');
      const syncRecent = vi.fn();
      vi.mocked(useActivitySync).mockReturnValue({
        isSyncing: false,
        isFetchingFullData: false,
        syncRecent,
        progress: null,
        syncAll: vi.fn(),
        fetchFullActivityData: vi.fn(),
        error: null,
        clearError: vi.fn(),
      });

      render(<Header onOpenSettings={() => {}} />);

      fireEvent.click(screen.getByRole('button'));
      fireEvent.click(screen.getByText('Sync'));

      expect(syncRecent).toHaveBeenCalled();
    });

    it('does not show logout in dropdown', () => {
      render(<Header onOpenSettings={() => {}} />);

      fireEvent.click(screen.getByRole('button'));

      expect(screen.queryByText('Logout')).not.toBeInTheDocument();
    });

    it('disables Sync button when working', async () => {
      const { useActivitySync } = await import('../hooks/useActivitySync');
      vi.mocked(useActivitySync).mockReturnValue({
        isSyncing: true,
        isFetchingFullData: false,
        syncRecent: vi.fn(),
        progress: { loaded: 50, total: 100, status: 'Syncing...' },
        syncAll: vi.fn(),
        fetchFullActivityData: vi.fn(),
        error: null,
        clearError: vi.fn(),
      });

      render(<Header onOpenSettings={() => {}} />);
      fireEvent.click(screen.getByRole('button'));

      // "Syncing..." appears in both header progress and dropdown button; find the disabled button
      const syncButtons = screen.getAllByText('Syncing...');
      const dropdownSyncButton = syncButtons.map(el => el.closest('button')).find(btn => btn?.disabled);
      expect(dropdownSyncButton).toBeDisabled();
    });
  });

  describe('athlete display', () => {
    it('shows fallback icon when no profile image', () => {
      render(<Header onOpenSettings={() => {}} />);
      // With empty profile_medium, should render User icon (svg) instead of img
      expect(screen.queryByRole('img')).not.toBeInTheDocument();
    });

    it('shows profile image when available', async () => {
      const { useAuth } = await import('../contexts/AuthContext');
      vi.mocked(useAuth).mockReturnValue({
        athlete: { ...mockAthlete, profile_medium: 'https://example.com/avatar.jpg' },
        syncState: mockSyncState,
      } as ReturnType<typeof useAuth>);

      render(<Header onOpenSettings={() => {}} />);
      const img = screen.getByRole('img');
      expect(img).toHaveAttribute('src', 'https://example.com/avatar.jpg');
      expect(img).toHaveAttribute('alt', 'Test');
    });

    it('shows athlete name on desktop', () => {
      render(<Header onOpenSettings={() => {}} />);
      expect(screen.getByText('Test User')).toBeInTheDocument();
    });
  });
});
