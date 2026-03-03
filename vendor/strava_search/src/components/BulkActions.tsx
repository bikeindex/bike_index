import { useState, useEffect } from 'react';
import { CheckSquare, Square, Loader2, X, ChevronLeft, ChevronRight, ChevronDown } from 'lucide-react';
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
  hasActivityWrite: boolean;
  authUrl: string;
  isOpen: boolean;
  onOpen: () => void;
  onClose: () => void;
}

const selectBase = 'w-full p-1.5 text-sm border border-gray-300 dark:border-gray-600 dark:bg-gray-700 rounded focus:ring-2 focus:ring-[#fc4c02] focus:border-transparent outline-none';
const selectClasses = (hasValue: boolean) => `${selectBase} ${hasValue ? 'text-gray-900 dark:text-gray-200' : 'text-gray-400 dark:text-gray-500'}`;
const labelClasses = 'block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1';

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
  hasActivityWrite,
  authUrl,
  isOpen,
  onOpen,
  onClose,
}: BulkActionsProps) {
  const [selectedType, setSelectedType] = useState('');
  const [selectedGearId, setSelectedGearId] = useState('');
  const [commuteValue, setCommuteValue] = useState('');
  const [trainerValue, setTrainerValue] = useState('');
  const [panelExpanded, setPanelExpanded] = useState(true);
  const showAuthModal = selectedCount > 0 && !hasActivityWrite;

  const handleOpen = () => {
    setPanelExpanded(true);
    onOpen();
  };

  useEffect(() => {
    if (!showAuthModal) return;
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onDeselectAll();
    };
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, [showAuthModal, onDeselectAll]);

  const goToPage = (page: number) => {
    const validPage = Math.max(1, Math.min(page, totalPages));
    onPageChange(validPage);
  };

  const hasChanges = !!(selectedType || selectedGearId || commuteValue || trainerValue);

  const handleSubmit = async () => {
    if (!hasChanges) return;
    const updates: UpdatableActivity = {};
    if (selectedType) updates.type = selectedType as UpdatableActivity['type'];
    if (selectedGearId) updates.gear_id = selectedGearId === '_none' ? '' : selectedGearId;
    if (commuteValue) updates.commute = commuteValue === 'true';
    if (trainerValue) updates.trainer = trainerValue === 'true';
    await onUpdateSelected(updates);
    setSelectedType('');
    setSelectedGearId('');
    setCommuteValue('');
    setTrainerValue('');
  };

  const handleClose = () => {
    setPanelExpanded(false);
    setTimeout(onClose, 200);
  };

  return (
    <>
      {/* Top bar with button and pagination */}
      <div className="flex items-center justify-between px-1">
        {!isOpen ? (
          <button
            onClick={handleOpen}
            className="px-3 py-1.5 text-sm border border-gray-300 dark:border-gray-600 text-gray-600 dark:text-gray-400 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
          >
            Select activities to update
          </button>
        ) : (
          <div />
        )}

        {/* Mini pagination */}
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

      {/* Update panel - accordion style */}
      {isOpen && (
        <div className="border border-gray-200 dark:border-gray-700 rounded-lg overflow-hidden">
          <button
            onClick={handleClose}
            className="w-full flex items-center justify-between px-3 py-2 bg-gray-50 dark:bg-gray-700 hover:bg-gray-100 dark:hover:bg-gray-600 transition-colors"
          >
            <div className="flex items-center gap-2">
              <span className="text-sm font-medium text-gray-700 dark:text-gray-300">Update checked activities</span>
              {selectedCount > 0 && (
                <span className="px-2 py-0.5 text-xs bg-gray-500 text-white rounded-full">
                  {formatNumber(selectedCount)}
                </span>
              )}
            </div>
            <ChevronDown
              className={`w-4 h-4 text-gray-500 transition-transform ${panelExpanded ? 'rotate-180' : ''}`}
            />
          </button>

          <div
            className="grid transition-[grid-template-rows] duration-200 ease-in-out"
            style={{ gridTemplateRows: panelExpanded ? '1fr' : '0fr' }}
          >
            <div className="overflow-hidden">
              <div className="p-3 space-y-3 border-t border-gray-200 dark:border-gray-700">
                {/* Select all / deselect all */}
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
                      ? `${formatNumber(selectedCount)} selected · Clear`
                      : totalPages > 1
                        ? `Select all on page (${formatNumber(pageCount)})`
                        : `Select all (${formatNumber(pageCount)})`}
                  </span>
                </button>

                {/* Update fields */}
                <div className="grid grid-cols-2 gap-3 max-w-lg">
                  <div>
                    <label htmlFor="bulk-type" className={labelClasses}>Activity Type</label>
                    <select
                      id="bulk-type"
                      value={selectedType}
                      onChange={(e) => setSelectedType(e.target.value)}
                      disabled={isUpdating}
                      className={selectClasses(!!selectedType)}
                    >
                      <option value="">No change</option>
                      {ACTIVITY_TYPES.map((type) => (
                        <option key={type} value={type}>
                          {formatActivityType(type)}
                        </option>
                      ))}
                    </select>
                  </div>

                  <div>
                    <label htmlFor="bulk-gear" className={labelClasses}>Equipment</label>
                    <select
                      id="bulk-gear"
                      value={selectedGearId}
                      onChange={(e) => setSelectedGearId(e.target.value)}
                      disabled={isUpdating}
                      className={selectClasses(!!selectedGearId)}
                    >
                      <option value="">No change</option>
                      <option value="_none">None (remove)</option>
                      {gear.map((g) => (
                        <option key={g.id} value={g.id}>
                          {g.name}
                        </option>
                      ))}
                    </select>
                  </div>

                  <div>
                    <label htmlFor="bulk-commute" className={labelClasses}>Commute</label>
                    <select
                      id="bulk-commute"
                      value={commuteValue}
                      onChange={(e) => setCommuteValue(e.target.value)}
                      disabled={isUpdating}
                      className={selectClasses(!!commuteValue)}
                    >
                      <option value="">No change</option>
                      <option value="true">Yes</option>
                      <option value="false">No</option>
                    </select>
                  </div>

                  <div>
                    <label htmlFor="bulk-trainer" className={labelClasses}>Trainer</label>
                    <select
                      id="bulk-trainer"
                      value={trainerValue}
                      onChange={(e) => setTrainerValue(e.target.value)}
                      disabled={isUpdating}
                      className={selectClasses(!!trainerValue)}
                    >
                      <option value="">No change</option>
                      <option value="true">Yes</option>
                      <option value="false">No</option>
                    </select>
                  </div>
                </div>

                <button
                  onClick={handleSubmit}
                  disabled={isUpdating || !hasChanges || selectedCount === 0}
                  className={`max-w-lg px-4 py-1.5 text-sm bg-[#fc4c02] text-white rounded hover:bg-[#e34402] transition-colors flex items-center justify-center gap-1.5 ${isUpdating || !hasChanges || selectedCount === 0 ? 'opacity-50 cursor-not-allowed' : ''}`}
                >
                  {isUpdating && <Loader2 className="w-3.5 h-3.5 animate-spin" />}
                  Update {formatNumber(selectedCount)} activities
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Authorization Modal */}
      {showAuthModal && (
        <div data-modal="auth" className="fixed inset-0 bg-black/50 flex items-center justify-center z-[1040] p-4">
          <div className="bg-white dark:bg-gray-800 rounded-lg shadow-xl max-w-md w-full p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold dark:text-gray-100">Authorization Required</h3>
              <button
                onClick={onDeselectAll}
                className="p-1 hover:bg-gray-100 dark:hover:bg-gray-700 rounded"
              >
                <X className="w-5 h-5 dark:text-gray-400" />
              </button>
            </div>
            <p className="text-gray-600 dark:text-gray-400 mb-6">
              You need to authorize updating Strava Activities
            </p>
            <a
              href={`${authUrl}&return_to=${encodeURIComponent(window.location.pathname + window.location.search)}`}
              className="block w-full px-4 py-2 bg-[#fc4c02] text-white rounded-lg hover:bg-[#e34402] transition-colors text-center"
            >
              Authorize
            </a>
          </div>
        </div>
      )}
    </>
  );
}
