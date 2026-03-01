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
    it('shows all three location selects when activities have location data', () => {
      render(<SearchFilters {...defaultProps} onFiltersChange={onFiltersChange} />);
      expect(screen.getByText('Country:')).toBeInTheDocument();
      expect(screen.getByText('Region:')).toBeInTheDocument();
      expect(screen.getByText('City:')).toBeInTheDocument();
    });

    it('does not show location selects when no activities have locations and not loading', () => {
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
      expect(screen.queryByText('Country:')).not.toBeInTheDocument();
      expect(screen.queryByText('Region:')).not.toBeInTheDocument();
      expect(screen.queryByText('City:')).not.toBeInTheDocument();
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
      expect(screen.getByText('Country:')).toBeInTheDocument();
      expect(screen.getByText('Region:')).toBeInTheDocument();
      expect(screen.getByText('City:')).toBeInTheDocument();

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

    it('lists countries from activities', () => {
      render(<SearchFilters {...defaultProps} onFiltersChange={onFiltersChange} />);
      const countrySelect = screen.getByText('Country:').nextElementSibling as HTMLSelectElement;
      const options = Array.from(countrySelect.options).map((o) => o.text);
      expect(options).toContain('Germany');
      expect(options).toContain('US');
    });

    it('lists regions from activities', () => {
      render(<SearchFilters {...defaultProps} onFiltersChange={onFiltersChange} />);
      const regionSelect = screen.getByText('Region:').nextElementSibling as HTMLSelectElement;
      const options = Array.from(regionSelect.options).map((o) => o.text);
      expect(options).toContain('CA');
      expect(options).toContain('IN');
      expect(options).toContain('IL');
      expect(options).toContain('Berlin');
      expect(options).toContain('BB');
    });

    it('displays cities with abbreviated region name', () => {
      render(<SearchFilters {...defaultProps} onFiltersChange={onFiltersChange} />);
      const citySelect = screen.getByText('City:').nextElementSibling as HTMLSelectElement;
      const options = Array.from(citySelect.options).map((o) => o.text);
      expect(options).toContain('Truckee, CA');
      expect(options).toContain('San Francisco, CA');
      expect(options).toContain('Berlin, Berlin');
      expect(options).toContain('Chicago, IL');
      expect(options).toContain('Gary, IN');
    });

    it('filters regions when country is selected', () => {
      render(
        <SearchFilters
          {...defaultProps}
          filters={{ ...defaultFilters, country: 'Germany' }}
          onFiltersChange={onFiltersChange}
        />,
      );
      const regionSelect = screen.getByText('Region:').nextElementSibling as HTMLSelectElement;
      const options = Array.from(regionSelect.options).map((o) => o.text);
      expect(options).toContain('Berlin');
      expect(options).toContain('BB');
      expect(options).not.toContain('CA');
    });

    it('filters cities when region is selected', () => {
      render(
        <SearchFilters
          {...defaultProps}
          filters={{ ...defaultFilters, region: 'Berlin' }}
          onFiltersChange={onFiltersChange}
        />,
      );
      const citySelect = screen.getByText('City:').nextElementSibling as HTMLSelectElement;
      const options = Array.from(citySelect.options).map((o) => o.text);
      expect(options).toContain('Berlin, Berlin');
      expect(options).toContain('Mitte, Berlin');
      expect(options).toContain('Pankow, Berlin');
      expect(options).not.toContain('Truckee, CA');
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
