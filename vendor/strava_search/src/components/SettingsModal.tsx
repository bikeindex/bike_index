import { useState, useEffect } from 'react';
import { X, Trash2, AlertTriangle, RefreshCw } from 'lucide-react';
import { useAuth } from '../contexts/AuthContext';
import { usePreferences } from '../contexts/PreferencesContext';
import { useActivitySync } from '../hooks/useActivitySync';
import {
  clearAllData,
  getActivitiesForAthlete,
} from '../services/database';
import { formatNumber, formatTimeAgo, formatDateTimeTitle } from '../utils/formatters';

interface SettingsModalProps {
  isOpen: boolean;
  onClose: () => void;
}

function SettingsModalContent({ onClose }: { onClose: () => void }) {
  const { athlete, syncState, logout } = useAuth();
  const { units, setUnits, autoEnrich, setAutoEnrich } = usePreferences();
  const isDev = import.meta.env.DEV;
  const { isSyncing, progress, syncRecent } = useActivitySync();
  const [activityCount, setActivityCount] = useState(0);
  const [enrichedCount, setEnrichedCount] = useState(0);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);

  useEffect(() => {
    const handleEscape = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose();
      }
    };
    document.addEventListener('keydown', handleEscape);
    return () => document.removeEventListener('keydown', handleEscape);
  }, [onClose]);

  useEffect(() => {
    if (athlete) {
      getActivitiesForAthlete(athlete.id).then((activities) => {
        setActivityCount(activities.length);
        const enriched = activities.filter(a => a.enriched).length;
        setEnrichedCount(enriched);
      });
    }
  }, [athlete]);

  const handleClearData = async () => {
    await clearAllData();
    await logout();
    onClose();
  };

  return (
    <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
      <div className="bg-white rounded-lg shadow-xl max-w-lg w-full max-h-[90vh] overflow-y-auto">
        <div className="sticky top-0 bg-white border-b border-gray-100 px-6 py-4 flex items-center justify-between">
          <h2 className="text-lg font-semibold">Settings</h2>
          <button onClick={onClose} className="p-1 hover:bg-gray-100 rounded">
            <X className="w-5 h-5" />
          </button>
        </div>

        <div className="p-6 space-y-6">
          {/* Sync section */}
          <div>
            <h3 className="font-medium text-gray-900 mb-3">Data Sync</h3>
            <div className="bg-gray-50 rounded-lg p-4">
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-600">
                  Activities stored locally:
                </span>
                <span className="font-medium">{formatNumber(activityCount)}</span>
              </div>
              <div className="flex items-center justify-between mt-0.5">
                <span className="text-sm text-gray-600">
                  Full activity data:
                </span>
                <span className="font-medium">{formatNumber(enrichedCount)}</span>
              </div>
              {syncState && (
                <div className="flex items-center justify-between mt-0.5 mb-4">
                  <span className="text-sm text-gray-600">
                    Last synced:
                  </span>
                  <span
                    className="font-medium"
                    title={formatDateTimeTitle(new Date(syncState.lastSyncedAt).toISOString())}
                  >
                    {formatTimeAgo(new Date(syncState.lastSyncedAt).toISOString())}
                  </span>
                </div>
              )}

              <button
                onClick={syncRecent}
                disabled={isSyncing}
                className="w-full py-2 bg-[#fc4c02] text-white rounded-lg hover:bg-[#e34402] transition-colors disabled:opacity-50 flex items-center justify-center gap-2 mt-4"
              >
                {isSyncing ? (
                  <>
                    <RefreshCw className="w-4 h-4 animate-spin" />
                    {progress?.status || 'Syncing...'}
                  </>
                ) : (
                  <>
                    <RefreshCw className="w-4 h-4" />
                    Sync Now
                  </>
                )}
              </button>
            </div>
          </div>

          {/* Units */}
          <div>
            <h3 className="font-medium text-gray-900 mb-3">Units</h3>
            <div className="flex gap-2">
              <button
                onClick={() => setUnits('imperial')}
                className={`flex-1 py-2 px-4 rounded-lg border transition-colors ${
                  units === 'imperial'
                    ? 'bg-[#fc4c02] text-white border-[#fc4c02]'
                    : 'border-gray-300 hover:bg-gray-50'
                }`}
              >
                Imperial (mi, ft)
              </button>
              <button
                onClick={() => setUnits('metric')}
                className={`flex-1 py-2 px-4 rounded-lg border transition-colors ${
                  units === 'metric'
                    ? 'bg-[#fc4c02] text-white border-[#fc4c02]'
                    : 'border-gray-300 hover:bg-gray-50'
                }`}
              >
                Metric (km, m)
              </button>
            </div>
          </div>

          {/* Danger zone */}
          <div>
            <h3 className="font-medium text-red-600 mb-3">Danger Zone</h3>
            <div className="border border-red-200 rounded-lg p-4">
              {showDeleteConfirm ? (
                <div className="space-y-3">
                  <div className="flex items-center gap-2 text-red-600">
                    <AlertTriangle className="w-5 h-5" />
                    <span className="font-medium">Are you sure?</span>
                  </div>
                  <p className="text-sm text-gray-600">
                    This will delete all locally stored data and log you out. Your
                    Strava data will not be affected.
                  </p>
                  <div className="flex gap-2">
                    <button
                      onClick={() => setShowDeleteConfirm(false)}
                      className="flex-1 py-2 border border-gray-300 rounded-lg hover:bg-gray-50 transition-colors"
                    >
                      Cancel
                    </button>
                    <button
                      onClick={handleClearData}
                      className="flex-1 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
                    >
                      Delete All Data
                    </button>
                  </div>
                </div>
              ) : (
                <button
                  onClick={() => setShowDeleteConfirm(true)}
                  className="w-full py-2 border border-red-300 text-red-600 rounded-lg hover:bg-red-50 transition-colors flex items-center justify-center gap-2"
                >
                  <Trash2 className="w-4 h-4" />
                  Clear All Local Data
                </button>
              )}
            </div>
          </div>
        </div>

        {/* Dev configuration - only in dev mode */}
        {isDev && (
          <div className="bg-gray-50 px-6 py-4 border-t border-gray-100">
            <h3 className="font-medium text-gray-900 mb-3">Dev Configuration</h3>
            <div className="space-y-3">
              <label className="flex items-center justify-between cursor-pointer">
                <span className="text-sm text-gray-600">
                  Automatically fetch full activity data
                </span>
                <button
                  role="switch"
                  aria-checked={autoEnrich}
                  onClick={() => setAutoEnrich(!autoEnrich)}
                  className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                    autoEnrich ? 'bg-[#fc4c02]' : 'bg-gray-300'
                  }`}
                >
                  <span
                    className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                      autoEnrich ? 'translate-x-6' : 'translate-x-1'
                    }`}
                  />
                </button>
              </label>
              <p className="text-xs text-gray-500">
                When enabled, fetches detailed data (location, photos, muted status) for each activity during sync. This is slower but provides more complete data.
              </p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

export function SettingsModal({ isOpen, onClose }: SettingsModalProps) {
  if (!isOpen) return null;
  return <SettingsModalContent onClose={onClose} />;
}
