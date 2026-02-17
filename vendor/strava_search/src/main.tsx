import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { AuthProvider } from './contexts/AuthContext';
import { PreferencesProvider } from './contexts/PreferencesContext';
import App from './App';
import './index.css';

// Load dev tools in development
if (import.meta.env.DEV) {
  import('./testing/vcr');
  import('./services/strava').then((strava) => {
    (window as unknown as { strava: typeof strava }).strava = strava;
  });
  import('./services/database').then((db) => {
    (window as unknown as { db: typeof db }).db = db;
  });
}

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <AuthProvider>
      <PreferencesProvider>
        <App />
      </PreferencesProvider>
    </AuthProvider>
  </StrictMode>
);
