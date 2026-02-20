import { useState, useCallback } from 'react';
import { useAuth } from '../contexts/AuthContext';
import {
  getAllActivities,
  getAthleteGear,
  getAthleteStats,
  getActivity,
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
}

interface UseActivitySyncResult {
  isSyncing: boolean;
  isFetchingFullData: boolean;
  progress: SyncProgress | null;
  error: string | null;
  clearError: () => void;
  syncAll: () => Promise<void>;
  syncRecent: () => Promise<void>;
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
    setProgress({ loaded: 0, total: null, status: 'Starting sync...' });

    try {
      // Sync gear first
      const gear = await getAthleteGear();
      await saveGear(gear, athlete.id);

      // Get estimated total from athlete stats
      let estimatedTotal: number | null = null;
      try {
        estimatedTotal = await getAthleteStats(athlete.id);
      } catch {
        // Stats endpoint may fail, continue without total
      }

      let oldestActivityDate: string | null = null;
      let isFirstBatch = true;

      // Sync all activities - save each batch progressively
      await getAllActivities({
        onBatch: async (batch, totalSoFar) => {
          // Save this batch immediately
          await saveActivities(batch, athlete.id);

          // Track oldest activity date
          for (const activity of batch) {
            if (!oldestActivityDate || new Date(activity.start_date) < new Date(oldestActivityDate)) {
              oldestActivityDate = activity.start_date;
            }
          }

          // After first batch, mark initial sync as complete so activities appear
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
            status: `${formatNumber(totalSoFar)}${estimatedTotal ? ` of ~${formatNumber(estimatedTotal)}` : ''} activities synced`,
          });
        },
      });

      const finalSyncState: SyncState = {
        athleteId: athlete.id,
        lastSyncedAt: Date.now(),
        oldestActivityDate: oldestActivityDate,
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
      const gear = await getAthleteGear();
      await saveGear(gear, athlete.id);

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

  const fetchFullActivityData = useCallback(async (activityIds: number[], isForPage: boolean = false) => {
    if (!athlete || isSyncing || isFetchingFullData || activityIds.length === 0) return;

    setIsFetchingFullData(true);
    setError(null);

    // Filter out activities that already have enriched data
    const idsToFetch: number[] = [];
    let alreadyEnrichedCount = 0;
    for (const id of activityIds) {
      const activity = await getActivityById(id);
      if (activity && activity.enriched) {
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

    try {
      for (let i = 0; i < idsToFetch.length; i++) {
        const activityId = idsToFetch[i];
        try {
          const fullActivity = await getActivity(activityId);
          // Save with enriched flag
          await saveActivities([{ ...fullActivity, enriched: true }], athlete.id);
        } catch {
          // Skip failed activities silently
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
    fetchFullActivityData,
  };
}
