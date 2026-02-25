import { useState, useCallback, useEffect, useMemo, useRef } from 'react';
import { useAuth } from './contexts/AuthContext';
import { usePreferences } from './contexts/PreferencesContext';
import { useActivities } from './hooks/useActivities';
import { useActivitySync } from './hooks/useActivitySync';
import { Header } from './components/Header';
import { ErrorBanner } from './components/ErrorBanner';
import { SearchFilters } from './components/SearchFilters';
import { ActivityList } from './components/ActivityList';
import { SettingsModal } from './components/SettingsModal';
import { Loader2 } from 'lucide-react';

function Dashboard() {
  const [showSettings, setShowSettings] = useState(false);
  const { syncState } = useAuth();
  const { autoEnrich } = usePreferences();
  const { isSyncing, isFetchingFullData, progress, error: syncError, clearError: clearSyncError, fetchFullActivityData, syncAll, syncEnriched } = useActivitySync();
  const {
    activities,
    filteredActivities,
    gear,
    isLoading,
    error,
    clearError,
    filters,
    setFilters,
    selectedIds,
    setSelectedIds,
    deselectAll,
    updateSelectedActivities,
    isUpdating,
    updateProgress,
    refreshActivities,
    activityTypes,
  } = useActivities();

  // Calculate displayed activities for current page
  const PAGE_SIZE = 50;
  const currentPage = filters.page;
  const startIndex = (currentPage - 1) * PAGE_SIZE;
  const endIndex = Math.min(startIndex + PAGE_SIZE, filteredActivities.length);
  const displayedActivityIds = useMemo(
    () => filteredActivities.slice(startIndex, endIndex).map(a => a.id),
    [filteredActivities, startIndex, endIndex]
  );

  // Stable key for the current page's activity IDs (only changes when IDs actually change)
  const displayedActivityIdsKey = useMemo(
    () => displayedActivityIds.join(','),
    [displayedActivityIds]
  );

  // Expose fetchFullActivityData on window for console access
  useEffect(() => {
    (window as unknown as { fetchFullActivityData: (ids?: number[]) => void }).fetchFullActivityData = (ids?: number[]) => {
      const isForPage = !ids;
      const activityIds = ids ?? displayedActivityIds;
      console.log(`Fetching full data for ${activityIds.length} activities${isForPage ? ' on this page' : ''}...`);
      fetchFullActivityData(activityIds, isForPage);
    };

    return () => {
      delete (window as unknown as { fetchFullActivityData?: unknown }).fetchFullActivityData;
    };
  }, [displayedActivityIds, fetchFullActivityData]);

  // Auto-fetch full activity data when autoEnrich is enabled (only when page changes)
  useEffect(() => {
    if (!autoEnrich || isSyncing || isFetchingFullData || displayedActivityIds.length === 0) {
      return;
    }

    const timeoutId = setTimeout(() => {
      fetchFullActivityData(displayedActivityIds, true);
    }, 1500);

    return () => clearTimeout(timeoutId);
    // eslint-disable-next-line react-hooks/exhaustive-deps -- only trigger when the page's activity IDs change
  }, [autoEnrich, displayedActivityIdsKey]);

  // Refresh activities when settings modal closes (in case of sync)
  const handleCloseSettings = useCallback(() => {
    setShowSettings(false);
    refreshActivities(true);
  }, [refreshActivities]);

  const handleToggleSelect = useCallback((id: number) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  }, [setSelectedIds]);

  // Auto-refresh activities while syncing or fetching full data
  useEffect(() => {
    if (isSyncing || isFetchingFullData) {
      const interval = setInterval(() => {
        refreshActivities(true); // Silent refresh to avoid page blink
      }, 2000); // Refresh every 2 seconds during sync/fetch
      return () => clearInterval(interval);
    }
  }, [isSyncing, isFetchingFullData, refreshActivities]);

  // Auto-refresh activities periodically (every 5 minutes)
  useEffect(() => {
    const interval = setInterval(() => {
      refreshActivities(true); // Silent refresh to avoid page blink
    }, 5 * 60 * 1000);

    return () => clearInterval(interval);
  }, [refreshActivities]);

  // Auto-sync enriched activities every 30 minutes
  useEffect(() => {
    const THIRTY_MINUTES = 30 * 60 * 1000;

    const maybeSync = () => {
      if (isSyncing || isFetchingFullData || !syncState?.isInitialSyncComplete) return;
      const elapsed = Date.now() - (syncState?.lastSyncedAt ?? 0);
      if (elapsed >= THIRTY_MINUTES) {
        syncEnriched();
      }
    };

    // Check immediately on mount
    maybeSync();

    // Check every minute
    const interval = setInterval(maybeSync, 60 * 1000);
    return () => clearInterval(interval);
  }, [isSyncing, isFetchingFullData, syncState?.lastSyncedAt, syncState?.isInitialSyncComplete, syncEnriched]);

  // Auto-start initial sync if no activities have been downloaded yet
  // Wait for isLoading to be false so IndexedDB has been checked first
  const initialSyncTriggered = useRef(false);
  useEffect(() => {
    if (!initialSyncTriggered.current && !isLoading && !syncState?.isInitialSyncComplete && !isSyncing && activities.length === 0) {
      initialSyncTriggered.current = true;
      syncAll();
    }
  }, [isLoading, syncState?.isInitialSyncComplete, isSyncing, activities.length, syncAll]);

  return (
    <div className="min-h-screen bg-gray-50 dark:bg-gray-900">
      <Header onOpenSettings={() => setShowSettings(true)} isFetchingFullData={isFetchingFullData} fetchProgress={progress} />
      {(syncError || error) && (
        <div className="fixed bottom-8 right-8 z-50 flex flex-col gap-2">
          {syncError && <ErrorBanner message={syncError} onDismiss={clearSyncError} />}
          {error && <ErrorBanner message={error} onDismiss={clearError} />}
        </div>
      )}

      <main className="max-w-7xl mx-auto px-4 py-6 space-y-6">

        <SearchFilters
          filters={filters}
          onFiltersChange={setFilters}
          activityTypes={activityTypes}
          gear={gear}
          totalCount={activities.length}
          filteredCount={filteredActivities.length}
        />

        <ActivityList
          activities={filteredActivities}
          gear={gear}
          isLoading={isLoading}
          selectedIds={selectedIds}
          onToggleSelect={handleToggleSelect}
          onSelectIds={(ids) => setSelectedIds(new Set(ids))}
          onDeselectAll={deselectAll}
          onUpdateSelected={updateSelectedActivities}
          isUpdating={isUpdating}
          filters={filters}
          onFiltersChange={setFilters}
        />
      </main>

      <SettingsModal isOpen={showSettings} onClose={handleCloseSettings} />

      {/* Full-page updating overlay */}
      {isUpdating && updateProgress && (
        <div className="fixed inset-0 bg-gray-900/80 flex items-center justify-center z-[1040]">
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow-xl p-8 max-w-md w-full mx-4">
            <div className="flex items-center justify-center mb-4">
              <Loader2 className="w-8 h-8 text-[#fc4c02] animate-spin" />
            </div>
            <h2 className="text-xl font-semibold text-center mb-2 dark:text-gray-100">Updating Activities</h2>
            <p className="text-gray-600 dark:text-gray-400 text-center mb-6">
              {updateProgress.current} of {updateProgress.total} activities updated
            </p>
            <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-3">
              <div
                className="bg-[#fc4c02] h-3 rounded-full transition-all duration-300"
                style={{ width: `${(updateProgress.current / updateProgress.total) * 100}%` }}
              />
            </div>
            <p className="text-sm text-gray-500 dark:text-gray-400 text-center mt-4">
              Please wait while your activities are being updated on Strava...
            </p>
          </div>
        </div>
      )}
    </div>
  );
}

export default function App() {
  const { isLoading } = useAuth();

  if (isLoading) {
    return (
      <div className="min-h-screen bg-gray-50 dark:bg-gray-900 flex items-center justify-center">
        <Loader2 className="w-8 h-8 text-[#fc4c02] animate-spin" />
      </div>
    );
  }

  return <Dashboard />;
}
