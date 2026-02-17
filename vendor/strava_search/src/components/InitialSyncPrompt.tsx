import { Download, RefreshCw } from 'lucide-react';
import { useActivitySync } from '../hooks/useActivitySync';

export function InitialSyncPrompt() {
  const { isSyncing, progress, error, syncAll } = useActivitySync();

  return (
    <div className="min-h-[60vh] flex items-center justify-center">
      <div className="text-center max-w-md mx-auto px-4">
        {isSyncing ? (
          <div className="space-y-4">
            <RefreshCw className="w-12 h-12 text-[#fc4c02] animate-spin mx-auto" />
            <h2 className="text-xl font-semibold text-gray-900">
              Downloading Your Activities
            </h2>
            <p className="text-gray-600">
              {progress?.status || 'Starting sync...'}
            </p>
            {progress && progress.loaded > 0 && (
              <div className="bg-gray-100 rounded-full h-2 overflow-hidden">
                <div
                  className="bg-[#fc4c02] h-full transition-all duration-300"
                  style={{
                    width: progress.total
                      ? `${(progress.loaded / progress.total) * 100}%`
                      : '50%',
                  }}
                />
              </div>
            )}
            <p className="text-sm text-gray-500">
              This may take a few minutes depending on how many activities you have.
            </p>
          </div>
        ) : (
          <div className="space-y-4">
            <Download className="w-12 h-12 text-[#fc4c02] mx-auto" />
            <h2 className="text-xl font-semibold text-gray-900">
              Welcome to Strava Search!
            </h2>
            <p className="text-gray-600">
              To get started, we need to download your activities from Strava.
              This is a one-time setup that stores everything locally in your
              browser.
            </p>

            {error && (
              <div className="p-3 bg-red-50 border border-red-200 rounded-lg text-red-700 text-sm">
                {error}
              </div>
            )}

            <button
              onClick={syncAll}
              className="px-6 py-3 bg-[#fc4c02] text-white rounded-lg font-medium hover:bg-[#e34402] transition-colors inline-flex items-center gap-2"
            >
              <Download className="w-5 h-5" />
              Download My Activities
            </button>

            <p className="text-xs text-gray-500">
              Your data is stored only in your browser and never sent to any server
              except Strava's API.
            </p>
          </div>
        )}
      </div>
    </div>
  );
}
