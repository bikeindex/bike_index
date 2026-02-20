import { useState, useEffect } from 'react';
import { CheckSquare, Square, Edit3, Loader2, X, Tag, ChevronLeft, ChevronRight } from 'lucide-react';
import type { StoredGear } from '../services/database';
import type { UpdatableActivity } from '../types/strava';
import { ACTIVITY_TYPES } from '../types/strava';
import { formatNumber, formatActivityType } from '../utils/formatters';

interface BulkActionsProps {
  selectedCount: number;
  pageCount: number;
  totalPages: number;
  currentPage: number;
  onPageChange: (page: number) => void;
  onSelectAll: () => void;
  onDeselectAll: () => void;
  onUpdateSelected: (updates: UpdatableActivity) => Promise<void>;
  isUpdating: boolean;
  gear: StoredGear[];
}

const selectClasses = 'w-full p-2 border border-gray-300 dark:border-gray-600 dark:bg-gray-700 dark:text-gray-200 rounded-lg focus:ring-2 focus:ring-[#fc4c02] focus:border-transparent outline-none';

export function BulkActions({
  selectedCount,
  pageCount,
  totalPages,
  currentPage,
  onPageChange,
  onSelectAll,
  onDeselectAll,
  onUpdateSelected,
  isUpdating,
  gear,
}: BulkActionsProps) {
  const [showEditModal, setShowEditModal] = useState(false);

  const goToPage = (page: number) => {
    const validPage = Math.max(1, Math.min(page, totalPages));
    onPageChange(validPage);
  };
  const [editType, setEditType] = useState<'type' | 'gear' | 'tags' | null>(null);
  const [selectedType, setSelectedType] = useState('');
  const [selectedGearId, setSelectedGearId] = useState('');
  const [commuteValue, setCommuteValue] = useState<boolean | null>(null);
  const [trainerValue, setTrainerValue] = useState<boolean | null>(null);

  const handleUpdate = async () => {
    // Close modal first so only the full-page progress overlay is visible
    setShowEditModal(false);

    if (editType === 'type' && selectedType) {
      await onUpdateSelected({ type: selectedType as UpdatableActivity['type'] });
    } else if (editType === 'gear') {
      // Empty string means remove gear
      await onUpdateSelected({ gear_id: selectedGearId || '' });
    } else if (editType === 'tags') {
      const updates: UpdatableActivity = {};
      if (commuteValue !== null) {
        updates.commute = commuteValue;
      }
      if (trainerValue !== null) {
        updates.trainer = trainerValue;
      }
      if (Object.keys(updates).length > 0) {
        await onUpdateSelected(updates);
      }
    }
    closeModal();
  };

  const closeModal = () => {
    setShowEditModal(false);
    setEditType(null);
    setSelectedType('');
    setSelectedGearId('');
    setCommuteValue(null);
    setTrainerValue(null);
  };

  useEffect(() => {
    if (!showEditModal) return;
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        closeModal();
      }
    };
    document.addEventListener('keydown', handleEscape);
    return () => document.removeEventListener('keydown', handleEscape);
  }, [showEditModal]);

  return (
    <>
      {/* Selection controls - no card */}
      <div className="flex items-center justify-between px-1">
        <div className="flex items-center gap-3">
          <button
            onClick={selectedCount > 0 ? onDeselectAll : onSelectAll}
            className="flex items-center gap-2 text-sm text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-gray-200"
          >
            {selectedCount > 0 ? (
              <CheckSquare className="w-5 h-5 text-[#fc4c02]" />
            ) : (
              <Square className="w-5 h-5" />
            )}
            <span>
              {selectedCount > 0
                ? `${formatNumber(selectedCount)} selected`
                : totalPages > 1
                  ? `Select all on page (${formatNumber(pageCount)})`
                  : `Select all (${formatNumber(pageCount)})`}
            </span>
          </button>

          {selectedCount > 0 && (
            <button
              onClick={onDeselectAll}
              className="text-sm text-gray-500 hover:text-gray-700 dark:hover:text-gray-300"
            >
              Clear selection
            </button>
          )}
        </div>

        {/* Top pagination - only show when multiple pages */}
        {totalPages > 1 && (
          <div className="flex items-center gap-1 text-sm text-gray-600 dark:text-gray-400">
            <button
              onClick={() => goToPage(currentPage - 1)}
              disabled={currentPage === 1}
              className="p-1 rounded hover:bg-gray-100 dark:hover:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <ChevronLeft className="w-4 h-4" />
            </button>
            <span className="px-2">
              {currentPage} / {totalPages}
            </span>
            <button
              onClick={() => goToPage(currentPage + 1)}
              disabled={currentPage === totalPages}
              className="p-1 rounded hover:bg-gray-100 dark:hover:bg-gray-700 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              <ChevronRight className="w-4 h-4" />
            </button>
          </div>
        )}
      </div>

      {/* Bulk action buttons - in card, only shown when items selected */}
      {selectedCount > 0 && (
        <div className="flex flex-wrap items-center gap-2 bg-white dark:bg-gray-800 rounded-lg shadow-sm p-3">
          <button
            onClick={() => {
              setEditType('type');
              setShowEditModal(true);
            }}
            disabled={isUpdating}
            className="flex items-center gap-2 px-3 py-1.5 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors disabled:opacity-50"
          >
            {isUpdating ? (
              <Loader2 className="w-4 h-4 animate-spin" />
            ) : (
              <Edit3 className="w-4 h-4" />
            )}
            Change Type
          </button>

          <button
            onClick={() => {
              setEditType('gear');
              setShowEditModal(true);
            }}
            disabled={isUpdating}
            className="flex items-center gap-2 px-3 py-1.5 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors disabled:opacity-50"
          >
            {isUpdating ? (
              <Loader2 className="w-4 h-4 animate-spin" />
            ) : (
              <Edit3 className="w-4 h-4" />
            )}
            Change Gear
          </button>

          <button
            onClick={() => {
              setEditType('tags');
              setShowEditModal(true);
            }}
            disabled={isUpdating}
            className="flex items-center gap-2 px-3 py-1.5 bg-blue-600 text-white rounded-md hover:bg-blue-700 transition-colors disabled:opacity-50"
          >
            {isUpdating ? (
              <Loader2 className="w-4 h-4 animate-spin" />
            ) : (
              <Tag className="w-4 h-4" />
            )}
            Change Tags
          </button>
        </div>
      )}

      {/* Edit Modal */}
      {showEditModal && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-[1040] p-4">
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow-xl max-w-md w-full p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold dark:text-gray-100">
                {editType === 'type' && 'Change Activity Type'}
                {editType === 'gear' && 'Change Equipment'}
                {editType === 'tags' && 'Change Tags'}
              </h3>
              <button
                onClick={closeModal}
                className="p-1 hover:bg-gray-100 dark:hover:bg-gray-700 rounded"
              >
                <X className="w-5 h-5 dark:text-gray-400" />
              </button>
            </div>

            <p className="text-sm text-gray-600 dark:text-gray-400 mb-4">
              This will update {formatNumber(selectedCount)} selected activit{selectedCount === 1 ? 'y' : 'ies'} on Strava.
            </p>

            {editType === 'type' && (
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Select new activity type
                </label>
                <select
                  value={selectedType}
                  onChange={(e) => setSelectedType(e.target.value)}
                  className={selectClasses}
                >
                  <option value="">Choose a type...</option>
                  {ACTIVITY_TYPES.map((type) => (
                    <option key={type} value={type}>
                      {formatActivityType(type)}
                    </option>
                  ))}
                </select>
              </div>
            )}

            {editType === 'gear' && (
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                  Select equipment
                </label>
                <select
                  value={selectedGearId}
                  onChange={(e) => setSelectedGearId(e.target.value)}
                  className={selectClasses}
                >
                  <option value="">None (remove equipment)</option>
                  {gear.map((g) => (
                    <option key={g.id} value={g.id}>
                      {g.name}
                    </option>
                  ))}
                </select>
              </div>
            )}

            {editType === 'tags' && (
              <div className="space-y-4">
                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Commute
                  </label>
                  <select
                    value={commuteValue === null ? '' : commuteValue.toString()}
                    onChange={(e) => {
                      const val = e.target.value;
                      setCommuteValue(val === '' ? null : val === 'true');
                    }}
                    className={selectClasses}
                  >
                    <option value="">No change</option>
                    <option value="true">Mark as commute</option>
                    <option value="false">Remove commute tag</option>
                  </select>
                </div>

                <div>
                  <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-2">
                    Trainer / Indoor
                  </label>
                  <select
                    value={trainerValue === null ? '' : trainerValue.toString()}
                    onChange={(e) => {
                      const val = e.target.value;
                      setTrainerValue(val === '' ? null : val === 'true');
                    }}
                    className={selectClasses}
                  >
                    <option value="">No change</option>
                    <option value="true">Mark as trainer/indoor</option>
                    <option value="false">Remove trainer tag</option>
                  </select>
                </div>
              </div>
            )}

            <div className="flex gap-3 mt-6">
              <button
                onClick={closeModal}
                className="flex-1 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors dark:text-gray-300"
              >
                Cancel
              </button>
              <button
                onClick={handleUpdate}
                disabled={
                  isUpdating ||
                  (editType === 'type' && !selectedType) ||
                  (editType === 'tags' && commuteValue === null && trainerValue === null)
                }
                className="flex-1 px-4 py-2 bg-[#fc4c02] text-white rounded-lg hover:bg-[#e34402] transition-colors disabled:opacity-50 flex items-center justify-center gap-2"
              >
                {isUpdating && <Loader2 className="w-4 h-4 animate-spin" />}
                Update
              </button>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
