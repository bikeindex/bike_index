export type UnitSystem = 'metric' | 'imperial';

export function getDefaultUnits(measurementPreference?: string, athleteCountry?: string): UnitSystem {
  // Use Strava athlete's measurement_preference if available
  if (measurementPreference === 'feet') {
    return 'imperial';
  }
  if (measurementPreference === 'meters') {
    return 'metric';
  }

  // Fall back to athlete country
  if (athleteCountry === 'United States') {
    return 'imperial';
  }

  // Also check browser locale as fallback
  const locale = navigator.language || '';
  if (locale.startsWith('en-US')) {
    return 'imperial';
  }

  return 'metric';
}
