import { X } from 'lucide-react';

interface ErrorBannerProps {
  message: string;
  onDismiss?: () => void;
}

export function ErrorBanner({ message, onDismiss }: ErrorBannerProps) {
  return (
    <div className="max-w-md bg-red-600 text-white px-4 py-3 rounded-lg shadow-lg">
      <div className="flex items-start justify-between gap-4">
        <div className="text-sm">
          {message.includes('\n') ? (
            <>
              <p className="font-bold">{message.split('\n')[0]}</p>
              {message.split('\n').slice(1).map((line, i) => (
                <p key={i} className="mt-1">{line}</p>
              ))}
            </>
          ) : (
            <p className="font-medium">{message}</p>
          )}
        </div>
        {onDismiss && (
          <button
            onClick={onDismiss}
            className="p-1 hover:bg-red-700 rounded transition-colors"
            aria-label="Dismiss error"
          >
            <X className="w-4 h-4" />
          </button>
        )}
      </div>
    </div>
  );
}
