import { useState } from 'react';
import type { Meta, StoryObj } from '@storybook/react';
import { X, Trash2, AlertTriangle, RefreshCw, Sun, Moon } from 'lucide-react';
import { formatNumber, formatTimeAgo, formatDateTimeTitle } from '../utils/formatters';
import { mockSyncState } from './mocks';
import type { DarkMode } from '../contexts/PreferencesContext';

// Presentational Settings Modal for stories (no context dependencies)
interface SettingsModalStoryProps {
  activityCount: number;
  enrichedCount: number;
  isSyncing: boolean;
  progressStatus?: string;
  showDevConfig: boolean;
}

const darkModeOptions: { value: DarkMode; label: string; icon?: typeof Sun }[] = [
  { value: 'light', label: 'Light', icon: Sun },
  { value: 'dark', label: 'Dark', icon: Moon },
  { value: 'system', label: 'System' },
];

function SettingsModalStory({
  activityCount,
  enrichedCount,
  isSyncing,
  progressStatus,
  showDevConfig,
}: SettingsModalStoryProps) {
  const [units, setUnits] = useState<'imperial' | 'metric'>('imperial');
  const [darkMode, setDarkMode] = useState<DarkMode>('system');
  const [autoEnrich, setAutoEnrich] = useState(false);
  const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);

  return (
    <div data-modal="settings" className="fixed inset-0 bg-black/50 flex items-center justify-center z-[1040] p-4">
      <div className="bg-white dark:bg-gray-800 rounded-lg shadow-xl max-w-lg w-full max-h-[90vh] overflow-y-auto">
        <div className="sticky top-0 bg-white dark:bg-gray-800 border-b border-gray-100 dark:border-gray-700 px-6 py-4 flex items-center justify-between">
          <h2 className="text-lg font-semibold dark:text-gray-100">Settings</h2>
          <button className="p-1 hover:bg-gray-100 dark:hover:bg-gray-700 rounded">
            <X className="w-5 h-5 dark:text-gray-400" />
          </button>
        </div>

        <div className="p-6 space-y-6">
          {/* Sync section */}
          <div>
            <h3 className="font-medium text-gray-900 dark:text-gray-100 mb-3">Data Sync</h3>
            <div className="bg-gray-50 dark:bg-gray-700 rounded-lg p-4">
              <div className="flex items-center justify-between">
                <span className="text-sm text-gray-600 dark:text-gray-400">
                  Activities stored locally:
                </span>
                <span className="font-medium dark:text-gray-200">{formatNumber(activityCount)}</span>
              </div>
              <div className="flex items-center justify-between mt-0.5">
                <span className="text-sm text-gray-600 dark:text-gray-400">
                  Full activity data:
                </span>
                <span className="font-medium dark:text-gray-200">{formatNumber(enrichedCount)}</span>
              </div>
              <div className="flex items-center justify-between mt-0.5 mb-4">
                <span className="text-sm text-gray-600 dark:text-gray-400">
                  Last synced:
                </span>
                <span
                  className="font-medium dark:text-gray-200"
                  title={formatDateTimeTitle(new Date(mockSyncState.lastSyncedAt).toISOString())}
                >
                  {formatTimeAgo(new Date(mockSyncState.lastSyncedAt).toISOString())}
                </span>
              </div>

              <button
                disabled={isSyncing}
                className="w-full py-2 bg-[#fc4c02] text-white rounded-lg hover:bg-[#e34402] transition-colors disabled:opacity-50 flex items-center justify-center gap-2 mt-4"
              >
                {isSyncing ? (
                  <>
                    <RefreshCw className="w-4 h-4 animate-spin" />
                    {progressStatus || 'Syncing...'}
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
            <h3 className="font-medium text-gray-900 dark:text-gray-100 mb-3">Units</h3>
            <div className="flex gap-2">
              <button
                onClick={() => setUnits('imperial')}
                className={`flex-1 py-2 px-4 rounded-lg border transition-colors ${
                  units === 'imperial'
                    ? 'bg-[#fc4c02] text-white border-[#fc4c02]'
                    : 'border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 dark:text-gray-300'
                }`}
              >
                Imperial (mi, ft)
              </button>
              <button
                onClick={() => setUnits('metric')}
                className={`flex-1 py-2 px-4 rounded-lg border transition-colors ${
                  units === 'metric'
                    ? 'bg-[#fc4c02] text-white border-[#fc4c02]'
                    : 'border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 dark:text-gray-300'
                }`}
              >
                Metric (km, m)
              </button>
            </div>
          </div>

          {/* Appearance */}
          <div>
            <h3 className="font-medium text-gray-900 dark:text-gray-100 mb-3">Appearance</h3>
            <div className="flex gap-2">
              {darkModeOptions.map(({ value, label, icon: Icon }) => (
                <button
                  key={value}
                  onClick={() => setDarkMode(value)}
                  className={`flex-1 py-2 px-4 rounded-lg border transition-colors ${
                    darkMode === value
                      ? 'bg-[#fc4c02] text-white border-[#fc4c02]'
                      : 'border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 dark:text-gray-300'
                  }`}
                >
                  {Icon && <Icon className="w-4 h-4 inline mr-1.5 align-text-bottom" />}
                  {label}
                </button>
              ))}
            </div>
          </div>

          {/* Danger zone */}
          <div>
            <h3 className="font-medium text-red-600 mb-3">Danger Zone</h3>
            <div className="border border-red-200 dark:border-red-800 rounded-lg p-4">
              {showDeleteConfirm ? (
                <div className="space-y-3">
                  <div className="flex items-center gap-2 text-red-600">
                    <AlertTriangle className="w-5 h-5" />
                    <span className="font-medium">Are you sure?</span>
                  </div>
                  <p className="text-sm text-gray-600 dark:text-gray-400">
                    This will delete all locally stored data and log you out. Your
                    Strava data will not be affected.
                  </p>
                  <div className="flex gap-2">
                    <button
                      onClick={() => setShowDeleteConfirm(false)}
                      className="flex-1 py-2 border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors dark:text-gray-300"
                    >
                      Cancel
                    </button>
                    <button
                      className="flex-1 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition-colors"
                    >
                      Delete All Data
                    </button>
                  </div>
                </div>
              ) : (
                <button
                  onClick={() => setShowDeleteConfirm(true)}
                  className="w-full py-2 border border-red-300 dark:border-red-700 text-red-600 rounded-lg hover:bg-red-50 dark:hover:bg-red-900/20 transition-colors flex items-center justify-center gap-2"
                >
                  <Trash2 className="w-4 h-4" />
                  Clear All Local Data
                </button>
              )}
            </div>
          </div>
        </div>

        {/* Dev configuration */}
        {showDevConfig && (
          <div className="bg-gray-50 dark:bg-gray-700 px-6 py-4 border-t border-gray-100 dark:border-gray-600">
            <h3 className="font-medium text-gray-900 dark:text-gray-100 mb-3">Dev Configuration</h3>
            <div className="space-y-3">
              <label className="flex items-center justify-between cursor-pointer">
                <span className="text-sm text-gray-600 dark:text-gray-400">
                  Automatically fetch full activity data
                </span>
                <button
                  role="switch"
                  aria-checked={autoEnrich}
                  onClick={() => setAutoEnrich(!autoEnrich)}
                  className={`relative inline-flex h-6 w-11 items-center rounded-full transition-colors ${
                    autoEnrich ? 'bg-[#fc4c02]' : 'bg-gray-300 dark:bg-gray-500'
                  }`}
                >
                  <span
                    className={`inline-block h-4 w-4 transform rounded-full bg-white transition-transform ${
                      autoEnrich ? 'translate-x-6' : 'translate-x-1'
                    }`}
                  />
                </button>
              </label>
              <p className="text-xs text-gray-500 dark:text-gray-400">
                When enabled, fetches detailed data (location, photos, muted status) for each activity during sync. This is slower but provides more complete data.
              </p>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

const meta = {
  title: 'Modals/Settings',
  component: SettingsModalStory,
  parameters: {
    layout: 'fullscreen',
  },
  tags: ['autodocs'],
} satisfies Meta<typeof SettingsModalStory>;

export default meta;
type Story = StoryObj<typeof meta>;

export const Default: Story = {
  args: {
    activityCount: 1247,
    enrichedCount: 1180,
    isSyncing: false,
    showDevConfig: true,
  },
};

export const Syncing: Story = {
  args: {
    activityCount: 1247,
    enrichedCount: 1180,
    isSyncing: true,
    progressStatus: '450 of ~1,200 activities synced',
    showDevConfig: true,
  },
};

export const Production: Story = {
  args: {
    activityCount: 1247,
    enrichedCount: 1180,
    isSyncing: false,
    showDevConfig: false,
  },
};
