import type { Meta, StoryObj } from '@storybook/react';
import { ActivityCard } from '../components/ActivityCard';
import { mockActivities, mockGear, babyHawkActivity, babyHawkGear } from './mocks';

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

export const RunActivity: Story = {
  args: {
    activity: mockActivities[0],
    gear: mockGear,
    isSelected: false,
    onToggleSelect: () => {},
  },
};

export const RideActivity: Story = {
  args: {
    activity: mockActivities[1],
    gear: mockGear,
    isSelected: false,
    onToggleSelect: () => {},
  },
};

export const VirtualRide: Story = {
  args: {
    activity: mockActivities[2],
    gear: mockGear,
    isSelected: false,
    onToggleSelect: () => {},
  },
};

export const SwimActivity: Story = {
  args: {
    activity: mockActivities[3],
    gear: mockGear,
    isSelected: false,
    onToggleSelect: () => {},
  },
};

export const HikeActivity: Story = {
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
    activity: { ...mockActivities[0], gear_id: undefined },
    gear: mockGear,
    isSelected: false,
    onToggleSelect: () => {},
  },
};

export const NoHeartRate: Story = {
  args: {
    activity: { ...mockActivities[0], has_heartrate: false, average_heartrate: undefined },
    gear: mockGear,
    isSelected: false,
    onToggleSelect: () => {},
  },
};

export const BabyHawk: Story = {
  args: {
    activity: babyHawkActivity,
    gear: [...mockGear, babyHawkGear],
    isSelected: false,
    onToggleSelect: () => {},
  },
};
