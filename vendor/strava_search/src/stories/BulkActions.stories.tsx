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
  selectedCount: 12,
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

export const Default: Story = {
  args: defaultArgs,
};

export const NeedsAuthorization: Story = {
  args: { ...defaultArgs, hasActivityWrite: false },
};
