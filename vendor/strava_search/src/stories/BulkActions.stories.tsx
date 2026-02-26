import type { Meta, StoryObj } from '@storybook/react';
import { BulkActions } from '../components/BulkActions';
import { mockGear } from './mocks';

const meta = {
  title: 'Components/BulkActions',
  component: BulkActions,
  parameters: {
    layout: 'padded',
  },
  tags: ['autodocs'],
  argTypes: {
    onSelectAll: { action: 'selectAll' },
    onDeselectAll: { action: 'deselectAll' },
    onUpdateSelected: { action: 'updateSelected' },
    onPageChange: { action: 'pageChange' },
  },
} satisfies Meta<typeof BulkActions>;

export default meta;
type Story = StoryObj<typeof meta>;

const defaultArgs = {
  selectedCount: 0,
  pageCount: 50,
  totalPages: 3,
  currentPage: 1,
  onPageChange: () => {},
  onSelectAll: () => {},
  onDeselectAll: () => {},
  onUpdateSelected: async () => {},
  isUpdating: false,
  gear: mockGear,
  hasActivityWrite: true,
  authUrl: '/strava_integration/new?scope=strava_search',
};

export const NoneSelected: Story = {
  args: defaultArgs,
};

export const SomeSelected: Story = {
  args: { ...defaultArgs, selectedCount: 12 },
};

export const AllSelected: Story = {
  args: { ...defaultArgs, selectedCount: 50, currentPage: 2 },
};

export const Updating: Story = {
  args: { ...defaultArgs, selectedCount: 12, isUpdating: true },
};

export const NoGear: Story = {
  args: { ...defaultArgs, selectedCount: 5, gear: [] },
};

export const SinglePage: Story = {
  args: { ...defaultArgs, pageCount: 25, totalPages: 1 },
};
