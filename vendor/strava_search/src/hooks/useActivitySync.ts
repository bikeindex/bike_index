import { useState, useCallback } from 'react';
import { useAuth } from '../contexts/AuthContext';
import {
  getAllActivities,
  getAthlete,
  getActivity,
  fetchEnrichedSince,
  fetchSyncStatus,
} from '../services/strava';
import { formatNumber } from '../utils/formatters';
import {
  saveActivities,
  saveGear,
  getSyncState,
  updateSyncState,
  getActivitiesForAthlete,
  getActivityById,
  type SyncState,
} from '../services/database';
interface SyncProgress {
  loaded: number;
  total: number | null;
  status: string;
  rateLimited?: boolean;
}

interface UseActivitySyncResult {
  isSyncing: boolean;
  isFetchingFullData: boolean;
  progress: SyncProgress | null;
  error: string | null;
  clearError: () => void;
  syncAll: () => Promise<void>;
  syncRecent: () => Promise<void>;
  syncEnriched: () => Promise<void>;
  fetchFullActivityData: (activityIds: number[], isForPage?: boolean) => Promise<void>;
}

export function useActivitySync(): UseActivitySyncResult {
  const { athlete, refreshSyncState } = useAuth();
  const [isSyncing, setIsSyncing] = useState(false);
  const [isFetchingFullData, setIsFetchingFullData] = useState(false);
  const [progress, setProgress] = useState<SyncProgress | null>(null);
  const [error, setError] = useState<string | null>(null);

  const clearError = useCallback(() => {
    setError(null);
  }, []);

  const syncAll = useCallback(async () => {
    if (!athlete || isSyncing) return;

    setIsSyncing(true);
    setError(null);
    setProgress({ loaded: 0, total: null, status: 'Checking sync status...' });

    try {
      // Wait for backend to finish syncing before fetching via proxy
      let syncStatus = await fetchSyncStatus();
      let estimatedTotal: number | null = syncStatus?.athlete_activity_count ?? null;

      const updateProgress = (status: typeof syncStatus) => {
        if (!status) return;
        const downloaded = status.activities_downloaded_count;
        const estimate = status.athlete_activity_count;
        // When downloaded exceeds estimate, the estimate was wrong — show actual count
        const displayTotal = estimate && downloaded >= estimate ? downloaded : estimate;
        const isEstimate = estimate !== null && downloaded < estimate;
        estimatedTotal = displayTotal;
        setProgress({
          loaded: downloaded,
          total: displayTotal,
          status: displayTotal
            ? `${formatNumber(downloaded)} of ${isEstimate ? '~' : ''}${formatNumber(displayTotal)} activities synced`
            : `${formatNumber(downloaded)} activities synced`,
          rateLimited: status.rate_limited,
        });
      };

      updateProgress(syncStatus);

      while (syncStatus && syncStatus.status !== 'synced' && syncStatus.status !== 'error') {
        await new Promise(resolve => setTimeout(resolve, 3000));
        syncStatus = await fetchSyncStatus();
        updateProgress(syncStatus);
      }

      if (syncStatus?.status === 'error') {
        setError('Backend sync encountered an error. Some activities may be missing.');
      }

      // Backend is synced — fetch activities via proxy
      setProgress({ loaded: 0, total: null, status: 'Loading activities...' });

      const freshAthlete = await getAthlete();
      await saveGear([...(freshAthlete.bikes || []), ...(freshAthlete.shoes || [])], athlete.id);

      let oldestActivityDate: string | null = null;
      let isFirstBatch = true;

      await getAllActivities({
        estimatedTotal: syncStatus?.activities_downloaded_count || estimatedTotal,
        onBatch: async (batch, totalSoFar) => {
          await saveActivities(batch, athlete.id);

          for (const activity of batch) {
            if (!oldestActivityDate || new Date(activity.start_date) < new Date(oldestActivityDate)) {
              oldestActivityDate = activity.start_date;
            }
          }

          if (isFirstBatch) {
            isFirstBatch = false;
            const syncState: SyncState = {
              athleteId: athlete.id,
              lastSyncedAt: Date.now(),
              oldestActivityDate: null,
              isInitialSyncComplete: true,
            };
            await updateSyncState(syncState);
            await refreshSyncState();
          }

          setProgress({
            loaded: totalSoFar,
            total: estimatedTotal,
            status: `${formatNumber(totalSoFar)}${estimatedTotal ? ` of ~${formatNumber(estimatedTotal)}` : ''} activities loaded`,
          });
        },
      });

      const finalSyncState: SyncState = {
        athleteId: athlete.id,
        lastSyncedAt: Date.now(),
        oldestActivityDate,
        isInitialSyncComplete: true,
      };
      await updateSyncState(finalSyncState);
      await refreshSyncState();
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Sync failed');
    } finally {
      setIsSyncing(false);
    }
  }, [athlete, isSyncing, refreshSyncState]);

  const syncRecent = useCallback(async () => {
    if (!athlete || isSyncing) return;

    setIsSyncing(true);
    setError(null);
    setProgress({ loaded: 0, total: null, status: 'Checking for new activities...' });

    try {
      // Get the most recent activity date from the database
      const existingActivities = await getActivitiesForAthlete(athlete.id);
      let afterDate: number | undefined;

      if (existingActivities.length > 0) {
        const mostRecent = existingActivities.reduce((newest, act) =>
          new Date(act.start_date) > new Date(newest.start_date) ? act : newest
        );
        afterDate = new Date(mostRecent.start_date).getTime();
      }

      // Sync gear
      const freshAthlete = await getAthlete();
      await saveGear([...(freshAthlete.bikes || []), ...(freshAthlete.shoes || [])], athlete.id);

      // Get new activities - save each batch progressively
      let newActivityCount = 0;

      await getAllActivities({
        after: afterDate,
        onBatch: async (batch, totalSoFar) => {
          await saveActivities(batch, athlete.id);
          newActivityCount = totalSoFar;

          setProgress({
            loaded: totalSoFar,
            total: null,
            status: `${formatNumber(totalSoFar)} new activities synced`,
          });
        },
      });

      // Update sync state
      const currentSyncState = await getSyncState(athlete.id);
      await updateSyncState({
        ...currentSyncState!,
        lastSyncedAt: Date.now(),
      });
      await refreshSyncState();

      setProgress({
        loaded: newActivityCount,
        total: newActivityCount,
        status: newActivityCount > 0
          ? `${formatNumber(newActivityCount)} new activities synced`
          : 'Already up to date!',
      });
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Sync failed');
    } finally {
      setIsSyncing(false);
    }
  }, [athlete, isSyncing, refreshSyncState]);

  const syncEnriched = useCallback(async () => {
    if (!athlete || isSyncing || isFetchingFullData) return;

    try {
      const activities = await getActivitiesForAthlete(athlete.id);
      const maxEnrichedAt = activities.reduce((max, activity) => {
        if (!activity.enriched_at) return max;
        const timestamp = Math.floor(new Date(activity.enriched_at).getTime() / 1000);
        return timestamp > max ? timestamp : max;
      }, 0);

      const enrichedActivities = await fetchEnrichedSince(maxEnrichedAt);
      if (enrichedActivities.length > 0) {
        await saveActivities(
          enrichedActivities,
          athlete.id
        );
      }

      const currentSyncState = await getSyncState(athlete.id);
      if (currentSyncState) {
        await updateSyncState({ ...currentSyncState, lastSyncedAt: Date.now() });
        await refreshSyncState();
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Enriched sync failed');
    }
  }, [athlete, isSyncing, isFetchingFullData, refreshSyncState]);

  const fetchFullActivityData = useCallback(async (activityIds: number[], isForPage: boolean = false) => {
    if (!athlete || isSyncing || isFetchingFullData || activityIds.length === 0) return;

    setIsFetchingFullData(true);
    setError(null);

    // Filter out activities that already have enriched data
    const idsToFetch: number[] = [];
    let alreadyEnrichedCount = 0;
    for (const id of activityIds) {
      const activity = await getActivityById(id);
      if (activity?.enriched_at) {
        alreadyEnrichedCount++;
      } else if (activity) {
        idsToFetch.push(id);
      }
    }

    if (alreadyEnrichedCount > 0) {
      console.log(`${alreadyEnrichedCount} activities already have full data`);
    }

    if (idsToFetch.length === 0) {
      setIsFetchingFullData(false);
      return;
    }

    const statusPrefix = isForPage ? 'Fetching full data for this page' : 'Fetching full data';
    setProgress({ loaded: 0, total: idsToFetch.length, status: `${statusPrefix}: 0 of ${formatNumber(idsToFetch.length)}` });

    const failedIds: number[] = [];
    try {
      for (let i = 0; i < idsToFetch.length; i++) {
        const activityId = idsToFetch[i];
        try {
          const fullActivity = await getActivity(activityId);
          await saveActivities([fullActivity], athlete.id);
        } catch {
          failedIds.push(activityId);
        }

        setProgress({
          loaded: i + 1,
          total: idsToFetch.length,
          status: `${statusPrefix}: ${formatNumber(i + 1)} of ${formatNumber(idsToFetch.length)}`,
        });

        // Small delay to avoid rate limiting
        if (i < idsToFetch.length - 1) {
          await new Promise((resolve) => setTimeout(resolve, 100));
        }
      }

      if (failedIds.length > 0) {
        setError(`Failed to fetch ${formatNumber(failedIds.length)} of ${formatNumber(idsToFetch.length)} activities`);
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to fetch full activity data');
    } finally {
      setIsFetchingFullData(false);
    }
  }, [athlete, isSyncing, isFetchingFullData]);

  return {
    isSyncing,
    isFetchingFullData,
    progress,
    error,
    clearError,
    syncAll,
    syncRecent,
    syncEnriched,
    fetchFullActivityData,
  };
}
