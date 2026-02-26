import type { Meta, StoryObj } from '@storybook/react';
import { useState } from 'react';
import { ActivityList } from '../components/ActivityList';
import { mockActivities, mockGear } from './mocks';
import type { SearchFilters } from '../types/strava';

const meta = {
  title: 'Components/ActivityList',
  component: ActivityList,
  parameters: {
    layout: 'fullscreen',
  },
  tags: ['autodocs'],
} satisfies Meta<typeof ActivityList>;

export default meta;
type Story = StoryObj<typeof meta>;

const defaultFilters: SearchFilters = {
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
  page: 1,
};

const ActivityListWrapper = (args: React.ComponentProps<typeof ActivityList>) => {
  const [selectedIds, setSelectedIds] = useState(args.selectedIds);
  const [filters, setFilters] = useState(args.filters);

  const handleToggleSelect = (id: number) => {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });
  };

  const handleSelectIds = (ids: number[]) => {
    setSelectedIds(new Set(ids));
  };

  const handleDeselectAll = () => {
    setSelectedIds(new Set());
  };

  return (
    <div className="p-4 bg-gray-50 min-h-screen">
      <ActivityList
        {...args}
        selectedIds={selectedIds}
        onToggleSelect={handleToggleSelect}
        onSelectIds={handleSelectIds}
        onDeselectAll={handleDeselectAll}
        filters={filters}
        onFiltersChange={setFilters}
      />
    </div>
  );
};

export const Default: Story = {
  render: (args) => <ActivityListWrapper {...args} />,
  args: {
    activities: mockActivities,
    gear: mockGear,
    isLoading: false,
    selectedIds: new Set(),
    onToggleSelect: () => {},
    onSelectIds: () => {},
    onDeselectAll: () => {},
    onUpdateSelected: async () => {},
    isUpdating: false,
    filters: defaultFilters,
    onFiltersChange: () => {},
    hasActivityWrite: true,
    authUrl: '/strava_integration/new?scope=strava_search',
  },
};

export const Loading: Story = {
  render: (args) => <ActivityListWrapper {...args} />,
  args: {
    ...Default.args,
    activities: [],
    isLoading: true,
  },
};

export const Empty: Story = {
  render: (args) => <ActivityListWrapper {...args} />,
  args: {
    ...Default.args,
    activities: [],
  },
};

export const WithSelections: Story = {
  render: (args) => <ActivityListWrapper {...args} />,
  args: {
    ...Default.args,
    selectedIds: new Set([mockActivities[0].id, mockActivities[1].id]),
  },
};

export const Updating: Story = {
  render: (args) => <ActivityListWrapper {...args} />,
  args: {
    ...Default.args,
    selectedIds: new Set([mockActivities[0].id, mockActivities[1].id, mockActivities[2].id]),
    isUpdating: true,
  },
};

// Generate many activities for pagination testing
const manyActivities = Array.from({ length: 75 }, (_, i) => ({
  ...mockActivities[i % mockActivities.length],
  id: 2000 + i,
  strava_id: (2000 + i).toString(),
  title: `Activity ${i + 1} - ${mockActivities[i % mockActivities.length].title}`,
}));

export const ManyActivities: Story = {
  render: (args) => <ActivityListWrapper {...args} />,
  args: {
    ...Default.args,
    activities: manyActivities,
  },
};
