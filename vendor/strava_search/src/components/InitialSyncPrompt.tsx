import { Loader2 } from 'lucide-react';

interface InitialSyncOverlayProps {
  loaded: number;
  total: number | null;
  status: string;
}

export function InitialSyncOverlay({ loaded, total, status }: InitialSyncOverlayProps) {
  const progressPercent = total && total > 0 ? (loaded / total) * 100 : null;

  return (
    <div className="fixed inset-0 bg-gray-900/80 flex items-center justify-center z-[1040]">
      <div className="bg-white dark:bg-gray-800 rounded-lg shadow-xl p-8 max-w-md w-full mx-4">
        <div className="flex items-center justify-center mb-4">
          <Loader2 className="w-8 h-8 text-[#fc4c02] animate-spin" />
        </div>
        <h2 className="text-xl font-semibold text-center mb-2 dark:text-gray-100">
          Syncing Your Activities
        </h2>
        <p className="text-gray-600 dark:text-gray-400 text-center mb-6">
          {status}
        </p>
        {(progressPercent !== null || loaded > 0) && (
          <div className="w-full bg-gray-200 dark:bg-gray-700 rounded-full h-3">
            <div
              className="bg-[#fc4c02] h-3 rounded-full transition-all duration-300"
              style={{ width: `${progressPercent ?? 50}%` }}
            />
          </div>
        )}
        <p className="text-sm text-gray-500 dark:text-gray-400 text-center mt-4">
          Your activities will appear after they are downloaded.
        </p>
      </div>
    </div>
  );
}
