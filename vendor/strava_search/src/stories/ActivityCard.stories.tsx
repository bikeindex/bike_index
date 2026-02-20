import type { Meta, StoryObj } from '@storybook/react';
import { ActivityCard } from '../components/ActivityCard';
import { mockActivities, mockGear } from './mocks';

const meta = {
  title: 'Components/ActivityCard',
  component: ActivityCard,
  parameters: {
    layout: 'padded',
  },
  tags: ['autodocs'],
  argTypes: {
    isSelected: {
      control: 'boolean',
      description: 'Whether the activity is selected for bulk actions',
    },
    onToggleSelect: {
      action: 'toggled',
    },
  },
} satisfies Meta<typeof ActivityCard>;

export default meta;
type Story = StoryObj<typeof meta>;

export const PelotonRide: Story = {
  args: {
    activity: mockActivities[0],
    gear: mockGear,
    isSelected: false,
    onToggleSelect: () => {},
  },
};

export const NordicSki: Story = {
  args: {
    activity: mockActivities[1],
    gear: mockGear,
    isSelected: false,
    onToggleSelect: () => {},
  },
};

export const EBikeRide: Story = {
  args: {
    activity: mockActivities[2],
    gear: mockGear,
    isSelected: false,
    onToggleSelect: () => {},
  },
};

export const LongDistanceRide: Story = {
  args: {
    activity: mockActivities[3],
    gear: mockGear,
    isSelected: false,
    onToggleSelect: () => {},
  },
};

export const BerlinRide: Story = {
  args: {
    activity: mockActivities[4],
    gear: mockGear,
    isSelected: false,
    onToggleSelect: () => {},
  },
};

export const Selected: Story = {
  args: {
    activity: mockActivities[0],
    gear: mockGear,
    isSelected: true,
    onToggleSelect: () => {},
  },
};

export const NoGear: Story = {
  args: {
    activity: mockActivities[1], // Nordic ski has no gear
    gear: mockGear,
    isSelected: false,
    onToggleSelect: () => {},
  },
};

export const NoHeartRate: Story = {
  args: {
    activity: { ...mockActivities[0], average_heartrate: undefined, max_heartrate: undefined },
    gear: mockGear,
    isSelected: false,
    onToggleSelect: () => {},
  },
};
