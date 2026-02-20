import { useState } from 'react';
import { useAuth } from '../contexts/AuthContext';
import {
  setStravaCredentials,
  getStravaCredentials,
  hasStravaCredentials,
} from '../services/strava';
import { Activity, Settings, ExternalLink, AlertCircle } from 'lucide-react';

function getInitialCredentials() {
  return getStravaCredentials();
}

export function LoginPage() {
  const { login, error } = useAuth();
  const [showConfig, setShowConfig] = useState(!hasStravaCredentials());
  const [clientId, setClientId] = useState(() => getInitialCredentials().clientId);
  const [clientSecret, setClientSecret] = useState(() => getInitialCredentials().clientSecret);
  const [configError, setConfigError] = useState('');

  const handleSaveConfig = () => {
    if (!clientId.trim() || !clientSecret.trim()) {
      setConfigError('Please enter both Client ID and Client Secret');
      return;
    }
    setStravaCredentials(clientId.trim(), clientSecret.trim());
    setConfigError('');
    setShowConfig(false);
  };

  const handleConnect = () => {
    if (!hasStravaCredentials()) {
      setShowConfig(true);
      return;
    }
    login();
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-orange-50 to-orange-100 flex items-center justify-center p-4">
      <div className="bg-white rounded-2xl shadow-xl max-w-md w-full p-8">
        <div className="text-center mb-8">
          <div className="inline-flex items-center justify-center w-16 h-16 bg-[#fc4c02] rounded-full mb-4">
            <Activity className="w-8 h-8 text-white" />
          </div>
          <h1 className="text-2xl font-bold text-gray-900">Strava Search</h1>
          <p className="text-gray-600 mt-2">
            Search, filter, and bulk update your Strava activities
          </p>
        </div>

        {(error || configError) && (
          <div className="mb-6 p-3 bg-red-50 border border-red-200 rounded-lg flex items-center gap-2 text-red-700">
            <AlertCircle className="w-5 h-5 flex-shrink-0" />
            <span className="text-sm">{error || configError}</span>
          </div>
        )}

        {showConfig ? (
          <div className="space-y-4">
            <div className="p-4 bg-blue-50 rounded-lg text-sm text-blue-800">
              <p className="font-medium mb-2">Setup Instructions:</p>
              <ol className="list-decimal list-inside space-y-1 text-blue-700">
                <li>
                  Go to{' '}
                  <a
                    href="https://www.strava.com/settings/api"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="underline hover:text-blue-900"
                  >
                    Strava API Settings
                    <ExternalLink className="inline w-3 h-3 ml-1" />
                  </a>
                </li>
                <li>Create an application (or use existing one)</li>
                <li>
                  Set the callback URL to:{' '}
                  <code className="bg-blue-100 px-1 rounded text-xs break-all">
                    {window.location.origin}{window.location.pathname}
                  </code>
                </li>
                <li>Copy your Client ID and Client Secret below</li>
              </ol>
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Client ID
              </label>
              <input
                type="text"
                value={clientId}
                onChange={(e) => setClientId(e.target.value)}
                placeholder="Enter your Strava Client ID"
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#fc4c02] focus:border-transparent outline-none"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">
                Client Secret
              </label>
              <input
                type="password"
                value={clientSecret}
                onChange={(e) => setClientSecret(e.target.value)}
                placeholder="Enter your Strava Client Secret"
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-[#fc4c02] focus:border-transparent outline-none"
              />
            </div>

            <button
              onClick={handleSaveConfig}
              className="w-full py-3 bg-[#fc4c02] text-white rounded-lg font-medium hover:bg-[#e34402] transition-colors"
            >
              Save Configuration
            </button>

            <p className="text-xs text-gray-500 text-center">
              Your credentials are stored locally in your browser and never sent to any server except Strava.
            </p>
          </div>
        ) : (
          <div className="space-y-4">
            <button
              onClick={handleConnect}
              className="w-full py-3 bg-[#fc4c02] text-white rounded-lg font-medium hover:bg-[#e34402] transition-colors flex items-center justify-center gap-2"
            >
              <Activity className="w-5 h-5" />
              Connect with Strava
            </button>

            <button
              onClick={() => setShowConfig(true)}
              className="w-full py-2 text-gray-600 hover:text-gray-900 text-sm flex items-center justify-center gap-2"
            >
              <Settings className="w-4 h-4" />
              Change API Configuration
            </button>
          </div>
        )}

        <div className="mt-8 pt-6 border-t border-gray-100">
          <h3 className="font-medium text-gray-900 mb-2">Features:</h3>
          <ul className="text-sm text-gray-600 space-y-1">
            <li>• Search activities by name, description, or location</li>
            <li>• Filter by activity type, date range, and equipment</li>
            <li>• Bulk update activity type or equipment</li>
            <li>• All data stored locally in your browser</li>
            <li>• Works offline after initial sync</li>
          </ul>
        </div>
      </div>
    </div>
  );
}
