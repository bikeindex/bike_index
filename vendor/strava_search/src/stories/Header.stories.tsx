import type { Meta, StoryObj } from '@storybook/react';
import { useState } from 'react';
import { RefreshCw, LogOut, User, Settings, ChevronDown } from 'lucide-react';
import { mockAthlete, mockSyncState } from './mocks';
import { formatTimeAgo, formatDateTimeTitle } from '../utils/formatters';

// Presentational Header component for stories (doesn't use hooks)
interface HeaderStoryProps {
  athlete: typeof mockAthlete | null;
  syncState: typeof mockSyncState | null;
  isSyncing: boolean;
  progressStatus?: string;
  onOpenSettings: () => void;
  onSync: () => void;
  onLogout: () => void;
}

function HeaderStory({
  athlete,
  syncState,
  isSyncing,
  progressStatus,
  onOpenSettings,
  onSync,
  onLogout,
}: HeaderStoryProps) {
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);

  const handleSettingsClick = () => {
    setIsDropdownOpen(false);
    onOpenSettings();
  };

  const handleSyncClick = () => {
    setIsDropdownOpen(false);
    onSync();
  };

  const handleLogoutClick = () => {
    setIsDropdownOpen(false);
    onLogout();
  };

  return (
    <header className="bg-[#fc4c02] text-white shadow-lg">
      <div className="max-w-7xl mx-auto px-4 py-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            {isSyncing && progressStatus ? (
              <div className="flex items-center gap-2 text-sm font-bold">
                <RefreshCw className="w-4 h-4 animate-spin" />
                <span>{progressStatus}</span>
              </div>
            ) : (
              <h1 className="text-xl font-bold">Strava Search</h1>
            )}
          </div>

          <div className="flex items-center gap-4">
            {syncState && (
              <span
                className="text-sm text-white/80 hidden sm:block"
                title={formatDateTimeTitle(new Date(syncState.lastSyncedAt).toISOString())}
              >
                Last synced: {formatTimeAgo(new Date(syncState.lastSyncedAt).toISOString())}
              </span>
            )}

            {athlete && (
              <div className="relative">
                <button
                  onClick={() => setIsDropdownOpen(!isDropdownOpen)}
                  className="flex items-center gap-2 px-2 py-1 hover:bg-white/20 rounded-md transition-colors"
                >
                  {athlete.profile_medium ? (
                    <img
                      src={athlete.profile_medium}
                      alt={athlete.firstname}
                      className="w-8 h-8 rounded-full"
                    />
                  ) : (
                    <User className="w-8 h-8 p-1 bg-white/20 rounded-full" />
                  )}
                  <span className="hidden md:block font-medium">
                    {athlete.firstname} {athlete.lastname}
                  </span>
                  <ChevronDown className={`w-4 h-4 transition-transform ${isDropdownOpen ? 'rotate-180' : ''}`} />
                </button>

                {isDropdownOpen && (
                  <div className="absolute right-0 mt-2 w-48 bg-white rounded-md shadow-lg py-1 z-50">
                    <button
                      onClick={handleSettingsClick}
                      className="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                    >
                      <Settings className="w-4 h-4" />
                      Settings
                    </button>
                    <button
                      onClick={handleSyncClick}
                      disabled={isSyncing}
                      className="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-100 disabled:opacity-50"
                    >
                      <RefreshCw className={`w-4 h-4 ${isSyncing ? 'animate-spin' : ''}`} />
                      {isSyncing ? progressStatus || 'Syncing...' : 'Sync'}
                    </button>
                    <hr className="my-1 border-gray-200" />
                    <button
                      onClick={handleLogoutClick}
                      className="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-700 hover:bg-gray-100"
                    >
                      <LogOut className="w-4 h-4" />
                      Logout
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>
      </div>
    </header>
  );
}

const meta = {
  title: 'Components/Header',
  component: HeaderStory,
  parameters: {
    layout: 'fullscreen',
  },
  tags: ['autodocs'],
  argTypes: {
    onOpenSettings: { action: 'openSettings' },
    onSync: { action: 'sync' },
    onLogout: { action: 'logout' },
  },
} satisfies Meta<typeof HeaderStory>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {
  args: {
    athlete: mockAthlete,
    syncState: mockSyncState,
    isSyncing: false,
    onOpenSettings: () => {},
    onSync: () => {},
    onLogout: () => {},
  },
};

export const WithoutAvatar: Story = {
  args: {
    athlete: {
      ...mockAthlete,
      profile_medium: '',
    },
    syncState: mockSyncState,
    isSyncing: false,
    onOpenSettings: () => {},
    onSync: () => {},
    onLogout: () => {},
  },
};

export const Syncing: Story = {
  args: {
    athlete: mockAthlete,
    syncState: mockSyncState,
    isSyncing: true,
    progressStatus: '450 of ~1,200 activities synced',
    onOpenSettings: () => {},
    onSync: () => {},
    onLogout: () => {},
  },
};

export const NoSyncState: Story = {
  args: {
    athlete: mockAthlete,
    syncState: null,
    isSyncing: false,
    onOpenSettings: () => {},
    onSync: () => {},
    onLogout: () => {},
  },
};

export const DropdownOpen: Story = {
  args: {
    athlete: mockAthlete,
    syncState: mockSyncState,
    isSyncing: false,
    onOpenSettings: () => {},
    onSync: () => {},
    onLogout: () => {},
  },
  play: async ({ canvasElement }) => {
    // Auto-open the dropdown for this story
    const button = canvasElement.querySelector('button');
    if (button) {
      button.click();
    }
  },
};

// Sync Progress States

export const SyncRecentChecking: Story = {
  args: {
    athlete: mockAthlete,
    syncState: mockSyncState,
    isSyncing: true,
    progressStatus: 'Checking for new activities...',
    onOpenSettings: () => {},
    onSync: () => {},
    onLogout: () => {},
  },
};

export const DropdownWhileSyncing: Story = {
  args: {
    athlete: mockAthlete,
    syncState: mockSyncState,
    isSyncing: true,
    progressStatus: '450 of ~1,200 activities synced',
    onOpenSettings: () => {},
    onSync: () => {},
    onLogout: () => {},
  },
  play: async ({ canvasElement }) => {
    const button = canvasElement.querySelector('button');
    if (button) {
      button.click();
    }
  },
};

export const FetchingFullDataForPage: Story = {
  args: {
    athlete: mockAthlete,
    syncState: mockSyncState,
    isSyncing: true,
    progressStatus: 'Fetching full data for this page: 12 of 50',
    onOpenSettings: () => {},
    onSync: () => {},
    onLogout: () => {},
  },
};
