import type { Preview } from '@storybook/react';
import React from 'react';
import { AuthProvider } from '../src/contexts/AuthContext';
import { PreferencesProvider } from '../src/contexts/PreferencesContext';
import '../src/index.css';

const preview: Preview = {
  globalTypes: {
    theme: {
      description: 'Toggle dark mode',
      toolbar: {
        title: 'Theme',
        icon: 'moon',
        items: [
          { value: 'light', title: 'Light', icon: 'sun' },
          { value: 'dark', title: 'Dark', icon: 'moon' },
        ],
        dynamicTitle: true,
      },
    },
  },
  initialGlobals: {
    theme: 'light',
  },
  decorators: [
    (Story, context) => {
      const theme = context.globals.theme || 'light';
      const isDark = theme === 'dark';
      // Override PreferencesProvider's default 'system' darkMode so it doesn't
      // clobber the Storybook toolbar toggle via document.documentElement.classList
      try {
        const stored = JSON.parse(localStorage.getItem('strava-search-preferences') || '{}');
        stored.darkMode = theme;
        localStorage.setItem('strava-search-preferences', JSON.stringify(stored));
      } catch { /* ignore */ }
      // Also set it directly in case PreferencesProvider already ran
      document.documentElement.classList.toggle('dark', isDark);
      return React.createElement(
        'div',
        {
          style: { background: isDark ? '#111827' : '#f9fafb', minHeight: '100vh' },
        },
        React.createElement(
          AuthProvider,
          null,
          React.createElement(PreferencesProvider, null, React.createElement(Story))
        )
      );
    },
  ],
  parameters: {
    controls: {
      matchers: {
        color: /(background|color)$/i,
        date: /Date$/i,
      },
    },
  },
};

export default preview;
