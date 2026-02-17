import type { Preview } from '@storybook/react';
import React from 'react';
import { AuthProvider } from '../src/contexts/AuthContext';
import { PreferencesProvider } from '../src/contexts/PreferencesContext';
import '../src/index.css';

const preview: Preview = {
  decorators: [
    (Story) =>
      React.createElement(
        AuthProvider,
        null,
        React.createElement(PreferencesProvider, null, React.createElement(Story))
      ),
  ],
  parameters: {
    controls: {
      matchers: {
        color: /(background|color)$/i,
        date: /Date$/i,
      },
    },
    backgrounds: {
      default: 'light',
      values: [
        { name: 'light', value: '#f9fafb' },
        { name: 'dark', value: '#1f2937' },
        { name: 'strava', value: '#fc4c02' },
      ],
    },
  },
};

export default preview;
