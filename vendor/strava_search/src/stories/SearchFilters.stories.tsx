import type { Meta, StoryObj } from '@storybook/react';
import { useState } from 'react';
import { SearchFilters } from '../components/SearchFilters';
import { mockGear } from './mocks';
import type { SearchFilters as SearchFiltersType } from '../types/strava';

const meta = {
  title: 'Components/SearchFilters',
  component: SearchFilters,
  parameters: {
    layout: 'padded',
  },
  tags: ['autodocs'],
} satisfies Meta<typeof SearchFilters>;

export default meta;
type Story = StoryObj<typeof meta>;

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

const SearchFiltersWrapper = (args: React.ComponentProps<typeof SearchFilters>) => {
  const [filters, setFilters] = useState(args.filters);
  return <SearchFilters {...args} filters={filters} onFiltersChange={setFilters} />;
};

export const Default: Story = {
  render: (args) => <SearchFiltersWrapper {...args} />,
  args: {
    filters: defaultFilters,
    onFiltersChange: () => {},
    activities: [],
    activityTypes: ['Run', 'Ride', 'Swim', 'Hike', 'VirtualRide', 'Walk'],
    gear: mockGear,
    totalCount: 150,
    filteredCount: 150,
  },
};

export const WithSearchQuery: Story = {
  render: (args) => <SearchFiltersWrapper {...args} />,
  args: {
    filters: { ...defaultFilters, query: 'morning run' },
    onFiltersChange: () => {},
    activities: [],
    activityTypes: ['Run', 'Ride', 'Swim', 'Hike', 'VirtualRide', 'Walk'],
    gear: mockGear,
    totalCount: 150,
    filteredCount: 12,
  },
};

export const WithActivityTypeFilter: Story = {
  render: (args) => <SearchFiltersWrapper {...args} />,
  args: {
    filters: { ...defaultFilters, activityTypes: ['Run', 'Hike'] },
    onFiltersChange: () => {},
    activities: [],
    activityTypes: ['Run', 'Ride', 'Swim', 'Hike', 'VirtualRide', 'Walk'],
    gear: mockGear,
    totalCount: 150,
    filteredCount: 45,
  },
};

export const WithDateRange: Story = {
  render: (args) => <SearchFiltersWrapper {...args} />,
  args: {
    filters: { ...defaultFilters, dateFrom: '2024-01-01', dateTo: '2024-01-31' },
    onFiltersChange: () => {},
    activities: [],
    activityTypes: ['Run', 'Ride', 'Swim', 'Hike', 'VirtualRide', 'Walk'],
    gear: mockGear,
    totalCount: 150,
    filteredCount: 28,
  },
};

export const WithGearFilter: Story = {
  render: (args) => <SearchFiltersWrapper {...args} />,
  args: {
    filters: { ...defaultFilters, gearIds: ['b12345'] },
    onFiltersChange: () => {},
    activities: [],
    activityTypes: ['Run', 'Ride', 'Swim', 'Hike', 'VirtualRide', 'Walk'],
    gear: mockGear,
    totalCount: 150,
    filteredCount: 67,
  },
};

export const WithMultipleFilters: Story = {
  render: (args) => <SearchFiltersWrapper {...args} />,
  args: {
    filters: {
      query: 'park',
      activityTypes: ['Run'],
      gearIds: ['g67890'],
      noEquipment: false,
      dateFrom: '2024-01-01',
      dateTo: null,
      distanceFrom: null,
      distanceTo: null,
      elevationFrom: null,
      elevationTo: null,
      filtersExpanded: true,
      activityTypesExpanded: true,
      equipmentExpanded: true,
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
    },
    onFiltersChange: () => {},
    activities: [],
    activityTypes: ['Run', 'Ride', 'Swim', 'Hike', 'VirtualRide', 'Walk'],
    gear: mockGear,
    totalCount: 150,
    filteredCount: 5,
  },
};

export const WithNoEquipmentFilter: Story = {
  render: (args) => <SearchFiltersWrapper {...args} />,
  args: {
    filters: { ...defaultFilters, noEquipment: true },
    onFiltersChange: () => {},
    activities: [],
    activityTypes: ['Run', 'Ride', 'Swim', 'Hike', 'VirtualRide', 'Walk'],
    gear: mockGear,
    totalCount: 150,
    filteredCount: 23,
  },
};

export const NoGear: Story = {
  render: (args) => <SearchFiltersWrapper {...args} />,
  args: {
    filters: defaultFilters,
    onFiltersChange: () => {},
    activities: [],
    activityTypes: ['Run', 'Ride', 'Swim'],
    gear: [],
    totalCount: 50,
    filteredCount: 50,
  },
};

export const NoResults: Story = {
  render: (args) => <SearchFiltersWrapper {...args} />,
  args: {
    filters: { ...defaultFilters, query: 'nonexistent activity' },
    onFiltersChange: () => {},
    activities: [],
    activityTypes: ['Run', 'Ride', 'Swim', 'Hike'],
    gear: mockGear,
    totalCount: 150,
    filteredCount: 0,
  },
};
