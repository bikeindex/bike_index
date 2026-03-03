import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, within } from '@testing-library/react';
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

function getDropdownOptions(label: string) {
  const combobox = screen.getByRole('combobox', { name: label });
  fireEvent.click(combobox);
  const listbox = screen.getByRole('listbox', { name: label });
  const options = within(listbox).getAllByRole('option').map((o) => o.textContent);
  fireEvent.click(combobox); // close
  return options;
}

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

      expect(screen.getByRole('combobox', { name: 'Country' })).toHaveTextContent('All (2 countries)');
      expect(screen.getByRole('combobox', { name: 'Region' })).toHaveTextContent('All (5 regions)');
      expect(screen.getByRole('combobox', { name: 'City' })).toHaveTextContent('All (22 cities)');
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
      const countryCombobox = screen.getByRole('combobox', { name: 'Country' });
      const regionCombobox = screen.getByRole('combobox', { name: 'Region' });
      const cityCombobox = screen.getByRole('combobox', { name: 'City' });

      expect(countryCombobox).toBeDisabled();
      expect(regionCombobox).toBeDisabled();
      expect(cityCombobox).toBeDisabled();

      expect(countryCombobox).toHaveTextContent('Loading...');
      expect(regionCombobox).toHaveTextContent('Loading...');
      expect(cityCombobox).toHaveTextContent('Loading...');
    });

    it('shows disabled location selects with N/A when no location data exists', () => {
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
      const countryCombobox = screen.getByRole('combobox', { name: 'Country' });
      const regionCombobox = screen.getByRole('combobox', { name: 'Region' });
      const cityCombobox = screen.getByRole('combobox', { name: 'City' });

      expect(countryCombobox).toBeDisabled();
      expect(regionCombobox).toBeDisabled();
      expect(cityCombobox).toBeDisabled();

      expect(countryCombobox).toHaveTextContent('N/A');
      expect(regionCombobox).toHaveTextContent('N/A');
      expect(cityCombobox).toHaveTextContent('N/A');
    });

    it('lists countries with full name and abbreviation', () => {
      render(<SearchFilters {...defaultProps} onFiltersChange={onFiltersChange} />);
      const options = getDropdownOptions('Country');
      expect(options).toContain('Germany');
      expect(options).toContain('US (United States)');
    });

    it('lists regions with country prefix, full name, and abbreviation', () => {
      render(<SearchFilters {...defaultProps} onFiltersChange={onFiltersChange} />);
      const options = getDropdownOptions('Region');
      expect(options).toContain('US: CA (California)');
      expect(options).toContain('US: IN (Indiana)');
      expect(options).toContain('US: IL (Illinois)');
      expect(options).toContain('Germany: Berlin');
      expect(options).toContain('Germany: BB (Brandenburg)');
    });

    it('displays cities with country and region abbreviations', () => {
      render(<SearchFilters {...defaultProps} onFiltersChange={onFiltersChange} />);
      const options = getDropdownOptions('City');
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
      const regionCombobox = screen.getByRole('combobox', { name: 'Region' });
      expect(regionCombobox).toHaveTextContent('All (2 regions)');

      const options = getDropdownOptions('Region');
      expect(options).toContain('Germany: Berlin');
      expect(options).toContain('Germany: BB (Brandenburg)');
      expect(options).not.toContain('US: CA (California)');

      expect(screen.getByRole('combobox', { name: 'City' })).toHaveTextContent('All (6 cities)');
    });

    it('filters cities when region is selected and updates placeholder count', () => {
      render(
        <SearchFilters
          {...defaultProps}
          filters={{ ...defaultFilters, region: 'Berlin' }}
          onFiltersChange={onFiltersChange}
        />,
      );
      const cityCombobox = screen.getByRole('combobox', { name: 'City' });
      expect(cityCombobox).toHaveTextContent('All (3 cities)');

      const options = getDropdownOptions('City');
      expect(options).toContain('Germany, Berlin: Berlin');
      expect(options).toContain('Germany, Berlin: Mitte');
      expect(options).toContain('Germany, Berlin: Pankow');
      expect(options).not.toContain('US, CA: Truckee');
    });

    it('calls onFiltersChange when country is selected', () => {
      render(<SearchFilters {...defaultProps} onFiltersChange={onFiltersChange} />);
      const countryCombobox = screen.getByRole('combobox', { name: 'Country' });
      fireEvent.click(countryCombobox);
      const listbox = screen.getByRole('listbox', { name: 'Country' });
      fireEvent.click(within(listbox).getByRole('option', { name: 'Germany' }));
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
      const countryCombobox = screen.getByRole('combobox', { name: 'Country' });
      fireEvent.click(countryCombobox);
      const listbox = screen.getByRole('listbox', { name: 'Country' });
      fireEvent.click(within(listbox).getByRole('option', { name: 'Germany' }));
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
      const regionCombobox = screen.getByRole('combobox', { name: 'Region' });
      fireEvent.click(regionCombobox);
      const listbox = screen.getByRole('listbox', { name: 'Region' });
      fireEvent.click(within(listbox).getByRole('option', { name: 'Germany: Berlin' }));
      expect(onFiltersChange).toHaveBeenCalledWith(
        expect.objectContaining({ region: 'Berlin', city: null }),
      );
    });

    it('allows selecting region without country', () => {
      render(<SearchFilters {...defaultProps} onFiltersChange={onFiltersChange} />);
      const regionCombobox = screen.getByRole('combobox', { name: 'Region' });
      fireEvent.click(regionCombobox);
      const listbox = screen.getByRole('listbox', { name: 'Region' });
      fireEvent.click(within(listbox).getByRole('option', { name: 'US: CA (California)' }));
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

      expect(screen.getByRole('combobox', { name: 'Country' })).toHaveTextContent('All (1 country)');
      const countryOptions = getDropdownOptions('Country');
      expect(countryOptions).toContain('KE (Kenya)');

      expect(screen.getByRole('combobox', { name: 'Region' })).toHaveTextContent('All (2 regions)');
      const regionOptions = getDropdownOptions('Region');
      expect(regionOptions).toContain('KE: Nakuru');
      expect(regionOptions).toContain('KE: Nakuru County');

      // Only one city despite three locations (one has nil city)
      expect(screen.getByRole('combobox', { name: 'City' })).toHaveTextContent('All (1 city)');
      const cityOptions = getDropdownOptions('City');
      expect(cityOptions).toContain('KE, Nakuru: Sulmac Village');
      expect(cityOptions).toHaveLength(2); // "All" + 1 city
    });

    it('allows selecting city without country or region', () => {
      render(<SearchFilters {...defaultProps} onFiltersChange={onFiltersChange} />);
      const cityCombobox = screen.getByRole('combobox', { name: 'City' });
      fireEvent.click(cityCombobox);
      const listbox = screen.getByRole('listbox', { name: 'City' });
      fireEvent.click(within(listbox).getByRole('option', { name: 'Germany, Berlin: Berlin' }));
      expect(onFiltersChange).toHaveBeenCalledWith(
        expect.objectContaining({ country: null, region: null, city: 'Berlin' }),
      );
    });
  });
});
