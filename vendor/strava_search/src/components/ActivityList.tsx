import { useCallback, useEffect, useRef } from 'react';
import { ActivityCard } from './ActivityCard';
import { BulkActions } from './BulkActions';
import type { StoredActivity, StoredGear } from '../services/database';
import type { UpdatableActivity, SearchFilters } from '../types/strava';
import { Loader2, ChevronLeft, ChevronRight } from 'lucide-react';
import { formatNumber } from '../utils/formatters';

interface ActivityListProps {
  activities: StoredActivity[];
  gear: StoredGear[];
  isLoading: boolean;
  selectedIds: Set<number>;
  onToggleSelect: (id: number) => void;
  onSelectIds: (ids: number[]) => void;
  onDeselectAll: () => void;
  onUpdateSelected: (updates: UpdatableActivity) => Promise<void>;
  isUpdating: boolean;
  filters: SearchFilters;
  onFiltersChange: (filters: SearchFilters) => void;
}

const PAGE_SIZE = 50;

export function ActivityList({
  activities,
  gear,
  isLoading,
  selectedIds,
  onToggleSelect,
  onSelectIds,
  onDeselectAll,
  onUpdateSelected,
  isUpdating,
  filters,
  onFiltersChange,
}: ActivityListProps) {
  const currentPage = filters.page;
  const prevActivitiesLength = useRef(activities.length);

  const totalPages = Math.ceil(activities.length / PAGE_SIZE);
  const startIndex = (currentPage - 1) * PAGE_SIZE;
  const endIndex = Math.min(startIndex + PAGE_SIZE, activities.length);
  const displayedActivities = activities.slice(startIndex, endIndex);

  // Reset to page 1 when activities change (e.g., filters applied)
  useEffect(() => {
    if (prevActivitiesLength.current !== activities.length) {
      prevActivitiesLength.current = activities.length;
      if (currentPage !== 1) {
        onFiltersChange({ ...filters, page: 1 });
      }
    }
  }, [activities.length, currentPage, filters, onFiltersChange]);

  // Ensure current page is valid
  useEffect(() => {
    if (totalPages > 0 && currentPage > totalPages) {
      onFiltersChange({ ...filters, page: totalPages });
    }
  }, [totalPages, currentPage, filters, onFiltersChange]);

  const goToPage = useCallback((page: number) => {
    const validPage = Math.max(1, Math.min(page, totalPages));
    onFiltersChange({ ...filters, page: validPage });
    // Scroll after state update processes
    setTimeout(() => {
      window.scrollTo({ top: 0, behavior: 'smooth' });
    }, 0);
  }, [totalPages, filters, onFiltersChange]);

  const selectPageActivities = useCallback(() => {
    onSelectIds(displayedActivities.map((a) => a.id));
  }, [displayedActivities, onSelectIds]);

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Loader2 className="w-8 h-8 text-[#fc4c02] animate-spin" />
      </div>
    );
  }

  if (activities.length === 0) {
    return (
      <div className="text-center py-12 text-gray-500">
        <p>No activities found</p>
        <p className="text-sm mt-1">
          Try adjusting your filters or sync your activities from Strava
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <BulkActions
        selectedCount={selectedIds.size}
        pageCount={displayedActivities.length}
        totalPages={totalPages}
        currentPage={currentPage}
        onPageChange={goToPage}
        onSelectAll={selectPageActivities}
        onDeselectAll={onDeselectAll}
        onUpdateSelected={onUpdateSelected}
        isUpdating={isUpdating}
        gear={gear}
      />

      <div className="space-y-3">
        {displayedActivities.map((activity) => (
          <ActivityCard
            key={activity.id}
            activity={activity}
            gear={gear}
            isSelected={selectedIds.has(activity.id)}
            onToggleSelect={() => onToggleSelect(activity.id)}
          />
        ))}
      </div>

      {/* Pagination */}
      {totalPages > 1 && (
        <div className="flex items-center justify-center gap-2 pt-4">
          <button
            onClick={() => goToPage(currentPage - 1)}
            disabled={currentPage === 1}
            className="p-2 rounded-lg hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <ChevronLeft className="w-5 h-5" />
          </button>

          <div className="flex items-center gap-1">
            {/* First page */}
            {currentPage > 2 && (
              <>
                <button
                  onClick={() => goToPage(1)}
                  className="px-3 py-1 rounded-lg hover:bg-gray-100"
                >
                  1
                </button>
                {currentPage > 3 && <span className="px-2 text-gray-400">...</span>}
              </>
            )}

            {/* Previous page */}
            {currentPage > 1 && (
              <button
                onClick={() => goToPage(currentPage - 1)}
                className="px-3 py-1 rounded-lg hover:bg-gray-100"
              >
                {currentPage - 1}
              </button>
            )}

            {/* Current page */}
            <button className="px-3 py-1 rounded-lg bg-[#fc4c02] text-white">
              {currentPage}
            </button>

            {/* Next page */}
            {currentPage < totalPages && (
              <button
                onClick={() => goToPage(currentPage + 1)}
                className="px-3 py-1 rounded-lg hover:bg-gray-100"
              >
                {currentPage + 1}
              </button>
            )}

            {/* Last page */}
            {currentPage < totalPages - 1 && (
              <>
                {currentPage < totalPages - 2 && <span className="px-2 text-gray-400">...</span>}
                <button
                  onClick={() => goToPage(totalPages)}
                  className="px-3 py-1 rounded-lg hover:bg-gray-100"
                >
                  {totalPages}
                </button>
              </>
            )}
          </div>

          <button
            onClick={() => goToPage(currentPage + 1)}
            disabled={currentPage === totalPages}
            className="p-2 rounded-lg hover:bg-gray-100 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            <ChevronRight className="w-5 h-5" />
          </button>

          <span className="ml-4 text-sm text-gray-500">
            Page {formatNumber(currentPage)} of {formatNumber(totalPages)}
          </span>
        </div>
      )}
    </div>
  );
}
