import { useState, useEffect, useMemo, useCallback } from 'react';
import { useAuth } from '../contexts/AuthContext';
import { usePreferences } from '../contexts/PreferencesContext';
import {
  getActivitiesForAthlete,
  getGearForAthlete,
  updateActivityInDb,
  type StoredActivity,
  type StoredGear,
} from '../services/database';
import { updateActivity as updateActivityApi, InsufficientPermissionsError } from '../services/strava';
import { useUrlFilters } from './useUrlFilters';
import type { SearchFilters, UpdatableActivity } from '../types/strava';

interface UpdateProgress {
  current: number;
  total: number;
}

interface UseActivitiesResult {
  activities: StoredActivity[];
  filteredActivities: StoredActivity[];
  gear: StoredGear[];
  isLoading: boolean;
  error: string | null;
  insufficientPermissions: boolean;
  filters: SearchFilters;
  setFilters: React.Dispatch<React.SetStateAction<SearchFilters>>;
  selectedIds: Set<number>;
  setSelectedIds: React.Dispatch<React.SetStateAction<Set<number>>>;
  selectAll: () => void;
  deselectAll: () => void;
  updateSelectedActivities: (updates: UpdatableActivity) => Promise<void>;
  isUpdating: boolean;
  updateProgress: UpdateProgress | null;
  refreshActivities: (silent?: boolean) => Promise<void>;
  activityTypes: string[];
}

const MILES_TO_KM = 1.60934;
const FEET_TO_METERS = 0.3048;

export function useActivities(): UseActivitiesResult {
  const { athlete, isAuthenticated } = useAuth();
  const { units } = usePreferences();
  const [activities, setActivities] = useState<StoredActivity[]>([]);
  const [gear, setGear] = useState<StoredGear[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filters, setFilters] = useUrlFilters();
  const [selectedIds, setSelectedIds] = useState<Set<number>>(new Set());
  const [isUpdating, setIsUpdating] = useState(false);
  const [updateProgress, setUpdateProgress] = useState<UpdateProgress | null>(null);
  const [insufficientPermissions, setInsufficientPermissions] = useState(false);

  const loadActivities = useCallback(async (silent = false) => {
    if (!athlete) {
      setIsLoading(false);
      return;
    }

    if (!silent) {
      setIsLoading(true);
    }
    setError(null);

    try {
      const [loadedActivities, loadedGear] = await Promise.all([
        getActivitiesForAthlete(athlete.id),
        getGearForAthlete(athlete.id),
      ]);

      // Sort by date descending
      loadedActivities.sort(
        (a, b) => new Date(b.start_date_in_zone).getTime() - new Date(a.start_date_in_zone).getTime()
      );

      setActivities(loadedActivities);
      setGear(loadedGear);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to load activities');
    } finally {
      if (!silent) {
        setIsLoading(false);
      }
    }
  }, [athlete]);

  useEffect(() => {
    if (isAuthenticated && athlete) {
      loadActivities();
    } else {
      setActivities([]);
      setGear([]);
      setIsLoading(false);
    }
  }, [isAuthenticated, athlete, loadActivities]);

  // Get unique activity types from the data (using sport_type for more specific types)
  const activityTypes = useMemo(() => {
    const types = new Set(activities.map((a) => a.sport_type));
    return Array.from(types).sort();
  }, [activities]);

  // Filter activities based on search criteria
  const filteredActivities = useMemo(() => {
    return activities.filter((activity) => {
      // Text search
      if (filters.query) {
        const query = filters.query.toLowerCase();
        const searchableText = [
          activity.title,
          activity.description,
          activity.device_name,
          // Include all segment locations for search
          ...(activity.segment_locations?.cities || []),
          ...(activity.segment_locations?.states || []),
          ...(activity.segment_locations?.countries || []),
        ]
          .filter(Boolean)
          .join(' ')
          .toLowerCase();

        if (!searchableText.includes(query)) {
          return false;
        }
      }

      // Activity type filter (using sport_type for more specific types)
      if (filters.activityTypes.length > 0) {
        if (!filters.activityTypes.includes(activity.sport_type)) {
          return false;
        }
      }

      // Gear filter
      if (filters.gearIds.length > 0) {
        if (!activity.gear_id || !filters.gearIds.includes(activity.gear_id)) {
          return false;
        }
      }

      // No equipment filter
      if (filters.noEquipment) {
        if (activity.gear_id) {
          return false;
        }
      }

      // Date range filter
      if (filters.dateFrom) {
        const activityDate = new Date(activity.start_date_in_zone);
        const fromDate = new Date(filters.dateFrom);
        fromDate.setHours(0, 0, 0, 0);
        if (activityDate < fromDate) {
          return false;
        }
      }

      if (filters.dateTo) {
        const activityDate = new Date(activity.start_date_in_zone);
        const toDate = new Date(filters.dateTo);
        toDate.setHours(23, 59, 59, 999);
        if (activityDate > toDate) {
          return false;
        }
      }

      // Distance range filter
      if (filters.distanceFrom !== null) {
        const distanceInKm = activity.distance_meters / 1000;
        const filterValueInKm = units === 'imperial' ? filters.distanceFrom * MILES_TO_KM : filters.distanceFrom;
        if (distanceInKm < filterValueInKm) {
          return false;
        }
      }

      if (filters.distanceTo !== null) {
        const distanceInKm = activity.distance_meters / 1000;
        const filterValueInKm = units === 'imperial' ? filters.distanceTo * MILES_TO_KM : filters.distanceTo;
        if (distanceInKm > filterValueInKm) {
          return false;
        }
      }

      // Elevation range filter
      if (filters.elevationFrom !== null) {
        const filterValueInMeters = units === 'imperial' ? filters.elevationFrom * FEET_TO_METERS : filters.elevationFrom;
        if (activity.total_elevation_gain_meters < filterValueInMeters) {
          return false;
        }
      }

      if (filters.elevationTo !== null) {
        const filterValueInMeters = units === 'imperial' ? filters.elevationTo * FEET_TO_METERS : filters.elevationTo;
        if (activity.total_elevation_gain_meters > filterValueInMeters) {
          return false;
        }
      }

      // Muted filter
      if (filters.mutedFilter === 'muted') {
        if (!activity.muted) {
          return false;
        }
      } else if (filters.mutedFilter === 'not_muted') {
        if (activity.muted) {
          return false;
        }
      }

      // Private filter
      if (filters.privateFilter === 'private') {
        if (!activity.private) {
          return false;
        }
      } else if (filters.privateFilter === 'not_private') {
        if (activity.private) {
          return false;
        }
      }

      // Photo filter
      if (filters.photoFilter === 'with_photo') {
        if ((activity.photos?.photo_count || 0) === 0) {
          return false;
        }
      } else if (filters.photoFilter === 'without_photo') {
        if ((activity.photos?.photo_count || 0) > 0) {
          return false;
        }
      }

      return true;
    });
  }, [activities, filters, units]);

  // Deselect activities that are no longer visible
  useEffect(() => {
    const filteredIdSet = new Set(filteredActivities.map((a) => a.id));
    setSelectedIds((prev) => {
      if (prev.size === 0) return prev;
      const pruned = new Set([...prev].filter((id) => filteredIdSet.has(id)));
      return pruned.size === prev.size ? prev : pruned;
    });
  }, [filteredActivities]);

  const selectAll = useCallback(() => {
    setSelectedIds(new Set(filteredActivities.map((a) => a.id)));
  }, [filteredActivities]);

  const deselectAll = useCallback(() => {
    setSelectedIds(new Set());
  }, []);

  const updateSelectedActivities = useCallback(
    async (updates: UpdatableActivity) => {
      if (selectedIds.size === 0 || isUpdating) return;

      setIsUpdating(true);
      setError(null);
      const total = selectedIds.size;
      setUpdateProgress({ current: 0, total });

      const errors: string[] = [];
      let successCount = 0;
      let current = 0;

      let hitPermissionsError = false;

      for (const id of selectedIds) {
        try {
          // Update on Strava
          const updatedActivity = await updateActivityApi(id, updates);

          // Update in local database
          await updateActivityInDb(id, updatedActivity);

          successCount++;
        } catch (err) {
          if (err instanceof InsufficientPermissionsError) {
            setInsufficientPermissions(true);
            hitPermissionsError = true;
            break;
          }
          errors.push(`Activity ${id}: ${err instanceof Error ? err.message : 'Failed'}`);
        }

        current++;
        setUpdateProgress({ current, total });

        // Small delay to avoid rate limiting
        await new Promise((resolve) => setTimeout(resolve, 100));
      }

      // Reload activities
      setUpdateProgress({ current: total, total });
      await loadActivities();

      if (hitPermissionsError) {
        setError('Insufficient Strava permissions to update activities. Please reconnect your Strava account.');
      } else if (errors.length > 0) {
        setError(`Updated ${successCount}/${selectedIds.size} activities. Errors: ${errors.join(', ')}`);
      }

      setSelectedIds(new Set());
      setIsUpdating(false);
      setUpdateProgress(null);
    },
    [selectedIds, isUpdating, loadActivities]
  );

  return {
    activities,
    filteredActivities,
    gear,
    isLoading,
    error,
    insufficientPermissions,
    filters,
    setFilters,
    selectedIds,
    setSelectedIds,
    selectAll,
    deselectAll,
    updateSelectedActivities,
    isUpdating,
    updateProgress,
    refreshActivities: loadActivities,
    activityTypes,
  };
}
