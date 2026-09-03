/* eslint-disable react-refresh/only-export-components */
/**
 * Embeddable Strava Search Component
 *
 * Requires window.stravaSearchConfig to be set by the host page.
 *
 * Usage in React:
 * ```tsx
 * import { StravaSearch } from 'strava-search/embed';
 * function MyApp() {
 *   return <StravaSearch />;
 * }
 * ```
 *
 * Usage in vanilla JS:
 * ```html
 * <div id="strava-search-root"></div>
 * <script type="module">
 *   import { mount } from './strava-search-embed.js';
 *   mount(document.getElementById('strava-search-root'));
 * </script>
 * ```
 */

import { StrictMode } from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { AuthProvider } from './contexts/AuthContext';
import App from './App';
import './index.css';

export interface StravaSearchProps {
  /** Custom class name for the container */
  className?: string;
  /** Custom styles for the container */
  style?: React.CSSProperties;
}

/**
 * React component for embedding Strava Search
 */
export function StravaSearch({ className, style }: StravaSearchProps) {
  return (
    <div className={className} style={style}>
      <AuthProvider>
        <App />
      </AuthProvider>
    </div>
  );
}

/**
 * Mount options for vanilla JS usage
 */
export interface MountOptions extends StravaSearchProps {
  /** Whether to use React Strict Mode */
  strictMode?: boolean;
}

/**
 * Mount Strava Search to a DOM element (vanilla JS)
 * Returns an object with an unmount function
 */
export function mount(
  element: HTMLElement,
  options: MountOptions = {}
): { unmount: () => void } {
  const { strictMode = true, ...props } = options;

  const root: Root = createRoot(element);

  const component = strictMode ? (
    <StrictMode>
      <StravaSearch {...props} />
    </StrictMode>
  ) : (
    <StravaSearch {...props} />
  );

  root.render(component);

  return {
    unmount: () => {
      root.unmount();
    },
  };
}

// Re-export useful types
export type { StravaActivity, StravaAthlete, StravaGear } from './types/strava';
export { useAuth } from './contexts/AuthContext';
export { useActivities } from './hooks/useActivities';
export { useActivitySync } from './hooks/useActivitySync';
