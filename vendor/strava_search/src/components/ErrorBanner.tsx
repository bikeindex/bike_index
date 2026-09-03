import { X, LogIn } from 'lucide-react';

interface ErrorBannerProps {
  message: string;
  onDismiss?: () => void;
  loginUrl?: string;
}

function isLoginError(message: string): boolean {
  return /log.in|not authenticated/i.test(message);
}

export function ErrorBanner({ message, onDismiss, loginUrl }: ErrorBannerProps) {
  const showLoginLink = loginUrl && isLoginError(message);
  const lines = message.split(/\n|\\n/);

  return (
    <div className="max-w-md bg-red-600 text-white px-4 py-3 rounded-lg shadow-lg">
      <div className="flex items-baseline justify-between gap-4">
        <div className="text-sm">
          {lines.length > 1 ? (
            <>
              <p className="font-bold">{lines[0]}</p>
              {lines.slice(1).map((line, i) => (
                <p key={i} className="mt-1">{line}</p>
              ))}
            </>
          ) : (
            <p className="font-medium">{message}</p>
          )}
          {showLoginLink && (
            <a
              href={loginUrl}
              className="inline-flex items-center gap-1 mt-4 text-white underline hover:text-red-100 font-bold"
            >
              Log in
              <LogIn className="w-4 h-4" />
            </a>
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
