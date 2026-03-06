import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { SearchFilters } from './SearchFilters';
import { mockGear, mockActivities } from '../stories/mocks';
import type { SearchFilters as SearchFiltersType } from '../types/strava';

vi.mock('../contexts/PreferencesContext', () => ({
  usePreferences: () => ({ units: 'imperial' }),
}));

const defaultFilters: SearchFiltersType = {
  query: '',
  activityTypes: [],
  gearIds: [],
  noEquipment: false,
  dateFrom: null,
  dateTo: null,
  distanceFrom: null,
  distanceTo: null,
  elevationFrom: null,
  elevationTo: null,
  filtersExpanded: true,
  activityTypesExpanded: false,
  equipmentExpanded: false,
  updatePanelExpanded: false,
  mutedFilter: 'all',
  photoFilter: 'all',
  privateFilter: 'all',
  commuteFilter: 'all',
  trainerFilter: 'all',
  sufferScoreFrom: null,
  sufferScoreTo: null,
  kudosFrom: null,
  kudosTo: null,
  country: null,
  region: null,
  city: null,
  page: 1,
};

describe('SearchFilters', () => {
  let onFiltersChange: ReturnType<typeof vi.fn>;

  const defaultProps = {
    filters: defaultFilters,
    activities: mockActivities,
    activityTypes: ['Run', 'Ride', 'NordicSki', 'VirtualRide', 'EBikeRide'],
    gear: mockGear,
    totalCount: mockActivities.length,
    filteredCount: mockActivities.length,
  };

  beforeEach(() => {
    onFiltersChange = vi.fn();
  });

  describe('location filters', () => {
    it('shows all three location selects with placeholder counts', () => {
      render(<SearchFilters {...defaultProps} onFiltersChange={onFiltersChange} />);
      expect(screen.getByText('Country:')).toBeInTheDocument();
      expect(screen.getByText('Region:')).toBeInTheDocument();
      expect(screen.getByText('City:')).toBeInTheDocument();

      const countrySelect = screen.getByText('Country:').nextElementSibling as HTMLSelectElement;
      const regionSelect = screen.getByText('Region:').nextElementSibling as HTMLSelectElement;
      const citySelect = screen.getByText('City:').nextElementSibling as HTMLSelectElement;

      expect(countrySelect.options[0].text).toBe('All (2 countries)');
      expect(regionSelect.options[0].text).toBe('All (5 regions)');
      expect(citySelect.options[0].text).toBe('All (22 cities)');
    });

    it('shows disabled location selects with Loading placeholder while loading', () => {
      render(
        <SearchFilters
          {...defaultProps}
          activities={[]}
          isLoading={true}
          onFiltersChange={onFiltersChange}
        />,
      );
      const countrySelect = screen.getByText('Country:').nextElementSibling as HTMLSelectElement;
      const regionSelect = screen.getByText('Region:').nextElementSibling as HTMLSelectElement;
      const citySelect = screen.getByText('City:').nextElementSibling as HTMLSelectElement;

      expect(countrySelect.disabled).toBe(true);
      expect(regionSelect.disabled).toBe(true);
      expect(citySelect.disabled).toBe(true);

      expect(countrySelect.options[0].text).toBe('Loading...');
      expect(regionSelect.options[0].text).toBe('Loading...');
      expect(citySelect.options[0].text).toBe('Loading...');
    });

    it('shows disabled location selects with "No locations loaded" when no location data exists', () => {
      const activitiesWithoutLocations = mockActivities.map((a) => ({
        ...a,
        segment_locations: undefined,
      }));
      render(
        <SearchFilters
          {...defaultProps}
          activities={activitiesWithoutLocations}
          onFiltersChange={onFiltersChange}
        />,
      );
      const countrySelect = screen.getByText('Country:').nextElementSibling as HTMLSelectElement;
      const regionSelect = screen.getByText('Region:').nextElementSibling as HTMLSelectElement;
      const citySelect = screen.getByText('City:').nextElementSibling as HTMLSelectElement;

      expect(countrySelect.disabled).toBe(true);
      expect(regionSelect.disabled).toBe(true);
      expect(citySelect.disabled).toBe(true);

      expect(countrySelect.options[0].text).toBe('No locations loaded');
      expect(regionSelect.options[0].text).toBe('No locations loaded');
      expect(citySelect.options[0].text).toBe('No locations loaded');
    });

    it('lists countries with full name and abbreviation', () => {
      render(<SearchFilters {...defaultProps} onFiltersChange={onFiltersChange} />);
      const countrySelect = screen.getByText('Country:').nextElementSibling as HTMLSelectElement;
      const options = Array.from(countrySelect.options).map((o) => o.text);
      expect(options).toContain('Germany');
      expect(options).toContain('US (United States)');
    });

    it('lists regions with country prefix, full name, and abbreviation', () => {
      render(<SearchFilters {...defaultProps} onFiltersChange={onFiltersChange} />);
      const regionSelect = screen.getByText('Region:').nextElementSibling as HTMLSelectElement;
      const options = Array.from(regionSelect.options).map((o) => o.text);
      expect(options).toContain('US: CA (California)');
      expect(options).toContain('US: IN (Indiana)');
      expect(options).toContain('US: IL (Illinois)');
      expect(options).toContain('Germany: Berlin');
      expect(options).toContain('Germany: BB (Brandenburg)');
    });

    it('displays cities with country and region abbreviations', () => {
      render(<SearchFilters {...defaultProps} onFiltersChange={onFiltersChange} />);
      const citySelect = screen.getByText('City:').nextElementSibling as HTMLSelectElement;
      const options = Array.from(citySelect.options).map((o) => o.text);
      expect(options).toContain('US, CA: Truckee');
      expect(options).toContain('US, CA: San Francisco');
      expect(options).toContain('Germany, Berlin: Berlin');
      expect(options).toContain('US, IL: Chicago');
      expect(options).toContain('US, IN: Gary');
    });

    it('filters regions when country is selected and updates placeholder counts', () => {
      render(
        <SearchFilters
          {...defaultProps}
          filters={{ ...defaultFilters, country: 'Germany' }}
          onFiltersChange={onFiltersChange}
        />,
      );
      const regionSelect = screen.getByText('Region:').nextElementSibling as HTMLSelectElement;
      const options = Array.from(regionSelect.options).map((o) => o.text);
      expect(options).toContain('Germany: Berlin');
      expect(options).toContain('Germany: BB (Brandenburg)');
      expect(options).not.toContain('US: CA (California)');
      expect(regionSelect.options[0].text).toBe('All (2 regions)');

      const citySelect = screen.getByText('City:').nextElementSibling as HTMLSelectElement;
      expect(citySelect.options[0].text).toBe('All (6 cities)');
    });

    it('filters cities when region is selected and updates placeholder count', () => {
      render(
        <SearchFilters
          {...defaultProps}
          filters={{ ...defaultFilters, region: 'Berlin' }}
          onFiltersChange={onFiltersChange}
        />,
      );
      const citySelect = screen.getByText('City:').nextElementSibling as HTMLSelectElement;
      const options = Array.from(citySelect.options).map((o) => o.text);
      expect(options).toContain('Germany, Berlin: Berlin');
      expect(options).toContain('Germany, Berlin: Mitte');
      expect(options).toContain('Germany, Berlin: Pankow');
      expect(options).not.toContain('US, CA: Truckee');
      expect(citySelect.options[0].text).toBe('All (3 cities)');
    });

    it('calls onFiltersChange when country is selected', () => {
      render(<SearchFilters {...defaultProps} onFiltersChange={onFiltersChange} />);
      const countrySelect = screen.getByText('Country:').nextElementSibling as HTMLSelectElement;
      fireEvent.change(countrySelect, { target: { value: 'Germany' } });
      expect(onFiltersChange).toHaveBeenCalledWith(
        expect.objectContaining({ country: 'Germany' }),
      );
    });

    it('resets region and city when country changes', () => {
      render(
        <SearchFilters
          {...defaultProps}
          filters={{ ...defaultFilters, country: 'US', region: 'CA', city: 'Truckee' }}
          onFiltersChange={onFiltersChange}
        />,
      );
      const countrySelect = screen.getByText('Country:').nextElementSibling as HTMLSelectElement;
      fireEvent.change(countrySelect, { target: { value: 'Germany' } });
      expect(onFiltersChange).toHaveBeenCalledWith(
        expect.objectContaining({ country: 'Germany', region: null, city: null }),
      );
    });

    it('resets city when region changes', () => {
      render(
        <SearchFilters
          {...defaultProps}
          filters={{ ...defaultFilters, region: 'CA', city: 'Truckee' }}
          onFiltersChange={onFiltersChange}
        />,
      );
      const regionSelect = screen.getByText('Region:').nextElementSibling as HTMLSelectElement;
      fireEvent.change(regionSelect, { target: { value: 'Berlin' } });
      expect(onFiltersChange).toHaveBeenCalledWith(
        expect.objectContaining({ region: 'Berlin', city: null }),
      );
    });

    it('allows selecting region without country', () => {
      render(<SearchFilters {...defaultProps} onFiltersChange={onFiltersChange} />);
      const regionSelect = screen.getByText('Region:').nextElementSibling as HTMLSelectElement;
      fireEvent.change(regionSelect, { target: { value: 'CA' } });
      expect(onFiltersChange).toHaveBeenCalledWith(
        expect.objectContaining({ country: null, region: 'CA' }),
      );
    });

    it('handles locations with nil city and no region abbreviation mapping', () => {
      const kenyaActivity = {
        ...mockActivities[0],
        id: 99999,
        strava_id: '99999',
        segment_locations: {
          countries: { Kenya: 'KE' },
          locations: [
            { city: 'Sulmac Village', region: 'Nakuru', country: 'KE' },
            { city: 'Sulmac Village', region: 'Nakuru County', country: 'KE' },
            { region: 'Nakuru', country: 'KE' },
          ],
        },
      };
      render(
        <SearchFilters
          {...defaultProps}
          activities={[kenyaActivity]}
          onFiltersChange={onFiltersChange}
        />,
      );

      const countrySelect = screen.getByText('Country:').nextElementSibling as HTMLSelectElement;
      const countryOptions = Array.from(countrySelect.options).map((o) => o.text);
      expect(countryOptions).toContain('KE (Kenya)');
      expect(countrySelect.options[0].text).toBe('All (1 country)');

      const regionSelect = screen.getByText('Region:').nextElementSibling as HTMLSelectElement;
      const regionOptions = Array.from(regionSelect.options).map((o) => o.text);
      expect(regionOptions).toContain('KE: Nakuru');
      expect(regionOptions).toContain('KE: Nakuru County');
      expect(regionSelect.options[0].text).toBe('All (2 regions)');

      // Only one city despite three locations (one has nil city)
      const citySelect = screen.getByText('City:').nextElementSibling as HTMLSelectElement;
      const cityOptions = Array.from(citySelect.options).map((o) => o.text);
      expect(cityOptions).toContain('KE, Nakuru: Sulmac Village');
      expect(cityOptions).toHaveLength(2); // "All" + 1 city
      expect(citySelect.options[0].text).toBe('All (1 city)');
    });

    it('allows selecting city without country or region', () => {
      render(<SearchFilters {...defaultProps} onFiltersChange={onFiltersChange} />);
      const citySelect = screen.getByText('City:').nextElementSibling as HTMLSelectElement;
      fireEvent.change(citySelect, { target: { value: 'Berlin' } });
      expect(onFiltersChange).toHaveBeenCalledWith(
        expect.objectContaining({ country: null, region: null, city: 'Berlin' }),
      );
    });
  });
});
