import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { render, screen } from '@testing-library/react';
import { PreferencesProvider, usePreferences } from './PreferencesContext';
import { getDefaultUnits } from '../utils/units';

vi.mock('./AuthContext', () => ({
  useAuth: vi.fn(() => ({ athlete: mockAthlete })),
}));

import { useAuth } from './AuthContext';

let mockAthlete: { country?: string; measurement_preference?: string } | null = null;

// Mock matchMedia for dark mode detection
Object.defineProperty(window, 'matchMedia', {
  writable: true,
  value: vi.fn().mockImplementation((query: string) => ({
    matches: false,
    media: query,
    onchange: null,
    addListener: vi.fn(),
    removeListener: vi.fn(),
    addEventListener: vi.fn(),
    removeEventListener: vi.fn(),
    dispatchEvent: vi.fn(),
  })),
});

function TestConsumer() {
  const { units } = usePreferences();
  return <div data-testid="units">{units}</div>;
}

function renderWithProvider() {
  return render(
    <PreferencesProvider>
      <TestConsumer />
    </PreferencesProvider>
  );
}

describe('getDefaultUnits', () => {
  const originalLanguage = navigator.language;

  afterEach(() => {
    Object.defineProperty(navigator, 'language', { value: originalLanguage, configurable: true });
  });

  it('returns imperial when measurement_preference is feet', () => {
    expect(getDefaultUnits('feet')).toBe('imperial');
  });

  it('returns metric when measurement_preference is meters', () => {
    expect(getDefaultUnits('meters')).toBe('metric');
  });

  it('returns imperial when measurement_preference is feet regardless of country', () => {
    expect(getDefaultUnits('feet', 'France')).toBe('imperial');
  });

  it('returns metric when measurement_preference is meters regardless of country', () => {
    expect(getDefaultUnits('meters', 'United States')).toBe('metric');
  });

  it('falls back to country when measurement_preference is undefined', () => {
    expect(getDefaultUnits(undefined, 'United States')).toBe('imperial');
  });

  it('returns metric for non-US country without measurement_preference', () => {
    Object.defineProperty(navigator, 'language', { value: 'de-DE', configurable: true });
    expect(getDefaultUnits(undefined, 'Germany')).toBe('metric');
  });
});

describe('PreferencesProvider', () => {
  beforeEach(() => {
    localStorage.clear();
    mockAthlete = null;
    vi.mocked(useAuth).mockReturnValue({ athlete: null } as ReturnType<typeof useAuth>);
  });

  it('defaults to imperial when athlete measurement_preference is feet', () => {
    mockAthlete = { measurement_preference: 'feet', country: 'France' };
    vi.mocked(useAuth).mockReturnValue({ athlete: mockAthlete } as ReturnType<typeof useAuth>);

    renderWithProvider();
    expect(screen.getByTestId('units').textContent).toBe('imperial');
  });

  it('defaults to metric when athlete measurement_preference is meters', () => {
    mockAthlete = { measurement_preference: 'meters', country: 'United States' };
    vi.mocked(useAuth).mockReturnValue({ athlete: mockAthlete } as ReturnType<typeof useAuth>);

    renderWithProvider();
    expect(screen.getByTestId('units').textContent).toBe('metric');
  });

  it('falls back to country when measurement_preference is not set', () => {
    mockAthlete = { country: 'United States' };
    vi.mocked(useAuth).mockReturnValue({ athlete: mockAthlete } as ReturnType<typeof useAuth>);

    renderWithProvider();
    expect(screen.getByTestId('units').textContent).toBe('imperial');
  });

  it('uses stored preference over athlete measurement_preference', () => {
    localStorage.setItem('strava-search-preferences', JSON.stringify({ units: 'metric' }));
    mockAthlete = { measurement_preference: 'feet', country: 'United States' };
    vi.mocked(useAuth).mockReturnValue({ athlete: mockAthlete } as ReturnType<typeof useAuth>);

    renderWithProvider();
    expect(screen.getByTestId('units').textContent).toBe('metric');
  });
});
