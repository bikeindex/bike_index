import { useState, useRef, useEffect } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { useActivitySync } from '../hooks/useActivitySync';
import { formatTimeAgo, formatDateTimeTitle } from '../utils/formatters';
import { RefreshCw, User, Settings, ChevronDown } from 'lucide-react';

interface HeaderProps {
  onOpenSettings: () => void;
  isFetchingFullData?: boolean;
  fetchProgress?: { status: string } | null;
}

export function Header({ onOpenSettings, isFetchingFullData: externalIsFetchingFullData, fetchProgress }: HeaderProps) {
  const { athlete, syncState } = useAuth();
  const { isSyncing, isFetchingFullData: hookIsFetchingFullData, syncRecent, progress: hookProgress } = useActivitySync();

  // Use external state if provided (from Dashboard), otherwise use hook state
  const isFetchingFullData = externalIsFetchingFullData ?? hookIsFetchingFullData;
  const progress = fetchProgress ?? hookProgress;
  const isWorking = isSyncing || isFetchingFullData;
  const [isDropdownOpen, setIsDropdownOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  // Close dropdown when clicking outside
  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (dropdownRef.current && !dropdownRef.current.contains(event.target as Node)) {
        setIsDropdownOpen(false);
      }
    }

    document.addEventListener('mousedown', handleClickOutside);
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, []);

  const handleSettingsClick = () => {
    setIsDropdownOpen(false);
    onOpenSettings();
  };

  const handleSyncClick = () => {
    setIsDropdownOpen(false);
    syncRecent();
  };

  return (
    <header className="bg-[#fc4c02] text-white shadow-lg">
      <div className="max-w-7xl mx-auto px-4 py-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            {isWorking && progress ? (
              <div className="flex items-center gap-2 text-sm font-bold">
                <RefreshCw className="w-4 h-4 animate-spin" />
                <span>{progress.status}</span>
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
              <div className="relative" ref={dropdownRef}>
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
                  <div className="absolute right-0 mt-2 w-48 bg-white dark:bg-gray-800 rounded-md shadow-lg py-1 z-[1040]">
                    <button
                      onClick={handleSettingsClick}
                      className="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700"
                    >
                      <Settings className="w-4 h-4" />
                      Settings
                    </button>
                    <button
                      onClick={handleSyncClick}
                      disabled={isWorking}
                      className="w-full flex items-center gap-2 px-4 py-2 text-sm text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 disabled:opacity-50"
                    >
                      <RefreshCw className={`w-4 h-4 ${isWorking ? 'animate-spin' : ''}`} />
                      {isWorking ? progress?.status || 'Working...' : 'Sync'}
                    </button>
                  </div>
                )}
              </div>
            )}
          </div>
        </div>

        {/* Mobile sync status row */}
        {syncState && (
          <div
            className="sm:hidden text-xs text-white/70 pt-1"
            title={formatDateTimeTitle(new Date(syncState.lastSyncedAt).toISOString())}
          >
            Last synced: {formatTimeAgo(new Date(syncState.lastSyncedAt).toISOString())}
          </div>
        )}
      </div>
    </header>
  );
}
